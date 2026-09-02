# ms_reporting — Implementación y Despliegue

| Campo | Valor |
|---|---|
| Repositorio | `MSPI_NVA_CO_MR_BACK/ms_reporting` |
| Fecha del documento | 2026-08-19 |
| Alcance | Build, Dockerfile, variables de entorno, CI/CD e infraestructura de despliegue del microservicio `ms_reporting` |

---

## 1. Build local con Gradle

El proyecto usa **Gradle Wrapper 9.3.0** (`gradlew`/`gradlew.bat`, fijado en `main.gradle`: `tasks.named('wrapper') { gradleVersion = '9.3.0' }`). Comandos reales disponibles desde la raíz de `ms_reporting/` (documentados en el propio `README.md`):

```bash
# Compilar el módulo de aplicación
./gradlew.bat :app-service:compileJava

# Ejecutar únicamente las pruebas del módulo de casos de uso
./gradlew.bat :usecase:test

# Ejecutar la tarea test en todos los subproyectos
./gradlew.bat test

# Generar el jar ejecutable (usado por el Dockerfile, saltando pruebas)
./gradlew :app-service:bootJar -x test --no-daemon

# Ejecutar el servicio directamente
./gradlew.bat :app-service:bootRun
```

El jar resultante **no** se renombra con el patrón `${rootProject.name}.jar` visto en otros microservicios del sistema (p. ej. `MsIam.jar`): `applications/app-service/build.gradle` no sobreescribe `bootJar.archiveFileName`, por lo que el artefacto conserva el nombre por defecto de Spring Boot Gradle Plugin (típicamente `app-service.jar` o `app-service-<version>.jar`). El `Dockerfile` copia el artefacto con un glob (`COPY --from=build /workspace/applications/app-service/build/libs/*.jar /app/app.jar`), por lo que el nombre exacto es irrelevante para el contenedor final, que siempre expone `/app/app.jar`.

## 2. Dockerfile (`deployment/Dockerfile`) — build multi-stage

```dockerfile
# docker build -f deployment/Dockerfile -t mspi/ms-reporting:dev .

FROM eclipse-temurin:21-jdk-alpine AS build
WORKDIR /workspace
RUN apk add --no-cache bash
COPY gradlew gradlew.bat settings.gradle main.gradle build.gradle ./
COPY gradle gradle
COPY applications applications
COPY domain domain
COPY infrastructure infrastructure
RUN sed -i 's/\r$//' gradlew && chmod +x gradlew && ./gradlew :app-service:bootJar -x test --no-daemon

FROM eclipse-temurin:21-jre-alpine
RUN apk add --no-cache wget \
 && addgroup -S mspi && adduser -S mspi -G mspi
WORKDIR /app
COPY --from=build /workspace/applications/app-service/build/libs/*.jar /app/app.jar
RUN mkdir -p /data/report-outputs && chown -R mspi:mspi /data/report-outputs /app/app.jar
USER mspi
EXPOSE 8087
ENV SERVER_PORT=8087 \
    REPORT_OUTPUT_DIR=/data/report-outputs \
    JAVA_OPTS="-XX:+UseContainerSupport -XX:MaxRAMPercentage=75.0 -Djava.security.egd=file:/dev/./urandom"
HEALTHCHECK --interval=30s --timeout=5s --start-period=120s --retries=3 \
  CMD wget -qO- "http://127.0.0.1:${SERVER_PORT}/actuator/health" || exit 1
ENTRYPOINT ["sh", "-c", "exec java $JAVA_OPTS -jar /app/app.jar"]
```

**Análisis del multi-stage:**

1. **Etapa `build`** (`eclipse-temurin:21-jdk-alpine`): copia solo lo necesario para compilar (archivos Gradle raíz, `gradle/`, y los 3 directorios de código fuente `applications/`, `domain/`, `infrastructure/`) — **no copia `deployment/` ni `docs/`**, minimizando el contexto de build. Normaliza CRLF→LF del script `gradlew` (tolerancia a checkouts en Windows) y compila con `-x test --no-daemon`, apropiado para un build de CI/imagen efímero.
2. **Etapa final** (`eclipse-temurin:21-jre-alpine`, solo JRE): agrega usuario/grupo de sistema no privilegiados `mspi`, **crea el directorio de la caché de artefactos** (`/data/report-outputs`, consumido por `FileSystemReportOutputStorage`) con permisos del usuario `mspi`, copia el jar y ejecuta como ese usuario — a diferencia de otros microservicios del sistema, aquí el `Dockerfile` sí prepara explícitamente un directorio de datos porque `ms_reporting` escribe artefactos binarios en el sistema de archivos del contenedor.
3. **Variables de entorno del contenedor**: `SERVER_PORT=8087`, `REPORT_OUTPUT_DIR=/data/report-outputs` (coincide con el volumen `mspi_report_outputs` declarado en `docker-compose.apps.yml`), `JAVA_OPTS` con detección de límites de contenedor y heap limitado al 75%.
4. **`HEALTHCHECK` nativo de Docker**: `wget` contra `/actuator/health` cada 30s, con **120s** de periodo de gracia inicial (mayor que el de otros microservicios como `ms_iam`, que usa 90s) — razonable dado que este microservicio puede tener un arranque algo más pesado por las dependencias de generación de documentos, aunque el arranque de Spring Boot en sí no invoca LibreOffice.
5. **Ausencia notable: LibreOffice no está instalado en la imagen**. Ni la etapa `build` ni la etapa final ejecutan `apk add libreoffice` (o similar); el `README.md` documenta `LIBREOFFICE_PATH` como variable opcional y advierte "Sin LibreOffice el job PDF falla con mensaje explícito". Esto implica que, tal como está definida hoy la imagen `mspi/ms-reporting:dev`, **el tipo de reporte `FULL_DIAGNOSTIC_PDF` fallará en producción** salvo que se: (a) monte un binario de LibreOffice desde el host/volumen y se apunte `LIBREOFFICE_PATH` a él, (b) se extienda esta imagen con una capa que instale LibreOffice, o (c) se desactive expresamente con `REPORT_PDF_CONVERSION_ENABLED=false` (lo cual también deshabilitaría esa funcionalidad, no la resuelve). Es una brecha de despliegue real, coherente con el comentario del `.env.example` de Docker Compose (§4).

## 3. Variables de entorno

### 3.1 Variables de aplicación (`application.yaml`, `README.md`)

| Variable | Obligatoria | Descripción | Valor por defecto |
|---|---|---|---|
| `SERVER_PORT` | No | Puerto HTTP | `8087` |
| `JWT_ISSUER_URI` | Sí (prod) | *Issuer* Keycloak esperado en los JWT | `https://keycloak-production-4a95.up.railway.app/realms/iam` |
| `JWT_JWK_SET_URI` | No | JWK Set alterno (útil si difiere del *issuer*, p. ej. en Docker) | `""` |
| `CORS_ALLOWED_ORIGINS` | Sí | Orígenes CORS permitidos | — (sin default definido en `application.yaml`, se espera vía entorno) |
| `INTERNAL_API_KEY` | Sí (S2S) | Clave para `X-Internal-Api-Key` hacia `ms_assessment`/`ms_evidence`/`ms_catalog`, y para validar peticiones internas entrantes | `""` |
| `MS_ASSESSMENT_URL` | No | Base URL de `ms_assessment` | `http://localhost:8084` |
| `MS_EVIDENCE_URL` | No | Base URL de `ms_evidence` | `http://localhost:8086` |
| `MS_CATALOG_URL` | No | Base URL de `ms_catalog` | `http://localhost:8085` |
| `MS_IAM_URL` | No | Reservada para integraciones IAM futuras (no consumida por ningún caso de uso actual) | `http://localhost:8082` |
| `REPORT_OUTPUT_DIR` | No | Directorio de la caché local de artefactos generados | `/data/report-outputs` |
| `REPORT_ARCHIVE_TO_EVIDENCE` | No | Habilita/deshabilita el archivado *best effort* en `ms_evidence` | `true` |
| `LIBREOFFICE_PATH` | No | Ruta al ejecutable `soffice` para la conversión XLSX→PDF | (busca `soffice` en `PATH` y rutas típicas de Windows) |
| `REPORT_PDF_CONVERSION_ENABLED` | No | `false` deshabilita la conversión XLSX→PDF (falla explícitamente `FULL_DIAGNOSTIC_PDF`) | `true` |
| `DB_CREDENTIAL` / `INFISICAL_*` | Sí (prod) | Credenciales de base de datos y configuración del gestor de secretos Infisical | — |

### 3.2 Variables de orquestación local (`docker-config/docker/env-mspi-docker.env.example`, `docker-compose.apps.yml`)

El archivo de ejemplo compartido de Docker Compose contiene una nota explícita sobre este microservicio:

```env
# LibreOffice (opcional; PDF en ms_reporting requiere imagen extendida o montar binario)
```

Y la definición del servicio en `docker-compose.apps.yml` confirma el volumen dedicado para la caché de artefactos:

```yaml
ms-reporting:
  <<: *mspi-service
  build:
    context: ../../ms_reporting
    dockerfile: deployment/Dockerfile
  image: mspi/ms-reporting:dev
  container_name: ms_reporting
  environment:
    SERVER_PORT: "8087"
    REPORT_OUTPUT_DIR: "/data/report-outputs"
  volumes:
    - mspi_report_outputs:/data/report-outputs
  ports:
    - "8087:8087"
```

`mspi_report_outputs` es un volumen Docker nombrado, no un `bind mount` al host — los artefactos generados persisten entre reinicios del contenedor mientras el volumen no se elimine explícitamente (`docker volume rm`/`docker compose down -v`).

## 4. Pipeline CI/CD

**No existe `bitbucket-pipelines.yml` en la raíz de `ms_reporting`.** Se verificó explícitamente la ausencia de este archivo (a diferencia de `ms_assessment`, `ms_catalog`, `ms_evidence`, `ms_iam` y `ms_org`, que sí lo tienen en el mismo repositorio contenedor `MSPI_NVA_CO_MR_BACK`). Esto significa que, con la evidencia disponible en el repositorio:

- No hay evidencia de compilación automática (`./gradlew clean assemble`) en ningún sistema de integración continua para este microservicio.
- No hay evidencia de despliegue automatizado (p. ej. a Railway, como sí ocurre para `ms_iam` mediante `railway up --service $RAILWAY_SERVICE --ci`).
- La construcción de la imagen Docker y su despliegue, de existir en producción, dependerían de un proceso manual o de un pipeline externo no versionado en este repositorio.

Esta es una **brecha operativa significativa** frente al resto del ecosistema MSPI y se documenta como tal; no se debe inferir ni inventar un pipeline que no está presente en el código.

## 5. Infraestructura de despliegue local (Docker Compose)

`ms_reporting` está declarado en `docker-config/docker/docker-compose.apps.yml`, proyecto Compose `mspi-apps`, junto a los demás microservicios backend. Requiere que la infraestructura base (red Docker `mspi-net`, PostgreSQL y Keycloak) esté levantada primero mediante los *compose* independientes en `docker-config/docker/postgres/` y `docker-config/docker/keycloak/`.

A diferencia de `ms_iam` u `ms_org`, la definición de `ms-reporting` en el *compose* **no declara `depends_on`** hacia otros microservicios backend (ni hacia `ms-assessment` ni `ms-evidence`), pese a que en tiempo de ejecución (al procesar un job) sí los necesita — la dependencia es puramente funcional/en tiempo de petición, no de arranque, lo cual es coherente con que `ms_reporting` no es un servicio bloqueante para el resto del sistema.

Secuencia de arranque (heredada del patrón común documentado en `docker-config/docker/README.md`):

```bash
docker network create mspi-net                 # una sola vez
cp env-mspi-docker.env.example env-mspi-docker.env   # y completar secretos reales
docker compose -f docker-compose.apps.yml --env-file env-mspi-docker.env up -d --build
```

El esquema de base de datos `reporting` debe estar aplicado previamente en PostgreSQL (`schema.sql`, replicado como `docker-config/docker/postgres/init/` junto con `MER-SEED-REPORTING.sql` para los seeds de plantillas — ver la observación sobre seeds desactualizados en `02-Analisis.md`).

## 6. Puesta en marcha local sin Docker

```bash
cd ms_reporting
export JWT_ISSUER_URI=http://localhost:8080/realms/iam
export CORS_ALLOWED_ORIGINS=http://localhost:4200
export INTERNAL_API_KEY=mspi-local-internal-key-2026
export MS_ASSESSMENT_URL=http://localhost:8084
export MS_EVIDENCE_URL=http://localhost:8086
export MS_CATALOG_URL=http://localhost:8085
./gradlew.bat :app-service:bootRun
```

Requisitos adicionales documentados en el `README.md`:

1. PostgreSQL con `schema.sql` aplicado (el servicio **no** ejecuta DDL: `spring.sql.init.mode: never`).
2. `ms_assessment`, `ms_evidence` y `ms_catalog` en ejecución con la misma `INTERNAL_API_KEY`.
3. Un JWT con acceso a `/reports/**` (cualquier usuario autenticado, sin restricción de rol adicional).
4. Para probar `FULL_DIAGNOSTIC_PDF` localmente en Windows, LibreOffice instalado y, si no está en `PATH`, `LIBREOFFICE_PATH` apuntando al ejecutable (p. ej. `C:\Program Files\LibreOffice\program\soffice.exe`, resuelto automáticamente como candidato por `LibreOfficePdfConverter` incluso sin configurar la variable).

## 7. Resumen de puertos y endpoints técnicos

| Elemento | Valor |
|---|---|
| Puerto HTTP | `8087` (contenedor y `SERVER_PORT` por defecto) |
| Healthcheck | `GET /actuator/health` |
| Info de build | `GET /actuator/info` |
| Nombre de imagen local | `mspi/ms-reporting:dev` |
| Nombre del contenedor | `ms_reporting` |
| Volumen de datos | `mspi_report_outputs` → `/data/report-outputs` |
| Esquema de base de datos | `reporting` (PostgreSQL) |
| Pipeline CI/CD | **No existe** (`bitbucket-pipelines.yml` ausente en este microservicio) |
