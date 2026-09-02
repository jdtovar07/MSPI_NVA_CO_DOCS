# ms_evidence — Implementación y Despliegue

| Campo | Valor |
|---|---|
| Repositorio | `MSPI_NVA_CO_MR_BACK/ms_evidence` |
| Fecha del documento | 2026-08-19 |
| Alcance | Build, Dockerfile, variables de entorno, CI/CD, infraestructura y configuración de almacenamiento de `ms_evidence` |

---

## 1. Build local con Gradle

Gradle Wrapper **9.3.0** (`tasks.named('wrapper') { gradleVersion = '9.3.0' }` en `main.gradle`). Comandos reales disponibles desde la raíz de `ms_evidence/`:

```bash
# Compilar
./gradlew.bat :app-service:compileJava

# Ejecutar pruebas (las 3 clases existentes en api-rest)
./gradlew.bat test

# Compilar sin pruebas (usado en el Dockerfile)
./gradlew :app-service:bootJar -x test --no-daemon

# Ejecutar el servicio directamente
./gradlew.bat :app-service:bootRun
```

El `README.md` documenta explícitamente `compileJava` y `test` como comandos de build, no `check` ni `assemble` a nivel raíz — coherente con que el pipeline CI (ver §4) tampoco los invoca.

Configuración del jar ejecutable (`applications/app-service/build.gradle`):

```groovy
jar {
    enabled = false
}

bootJar {
    archiveFileName = "${project.getParent().getName()}.${archiveExtension.get()}"
}
```

`project.getParent().getName()` resuelve al `rootProject.name` (`MsEvidence`, definido en `settings.gradle`), por lo que el artefacto generado es **`MsEvidence.jar`**, no `app-service.jar`. Se deshabilita el jar plano (`jar { enabled = false }`) para evitar el artefacto `-plain.jar` adicional que genera Spring Boot junto al *fat jar*.

## 2. Dockerfile (`deployment/Dockerfile`) — build multi-stage

```dockerfile
# docker build -f deployment/Dockerfile -t mspi/ms-evidence:dev .

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
RUN apk add --no-cache wget su-exec \
 && addgroup -S mspi && adduser -S mspi -G mspi
WORKDIR /app
COPY --from=build /workspace/applications/app-service/build/libs/*.jar /app/app.jar
RUN chown mspi:mspi /app/app.jar
EXPOSE 8086
ENV SERVER_PORT=8086 \
    EVIDENCE_STORAGE_DIR=/data/evidence \
    JAVA_OPTS="-XX:+UseContainerSupport -XX:MaxRAMPercentage=75.0 -Djava.security.egd=file:/dev/./urandom"
VOLUME ["/data/evidence"]
HEALTHCHECK --interval=30s --timeout=5s --start-period=90s --retries=3 \
  CMD wget -qO- "http://127.0.0.1:${SERVER_PORT}/actuator/health" || exit 1
ENTRYPOINT ["sh", "-c", "mkdir -p \"${EVIDENCE_STORAGE_DIR}\" && chown -R mspi:mspi \"${EVIDENCE_STORAGE_DIR}\" && exec su-exec mspi java $JAVA_OPTS -jar /app/app.jar"]
```

**Análisis del multi-stage:**

1. **Etapa `build`** (`eclipse-temurin:21-jdk-alpine`): copia solo `gradlew*`, archivos de configuración Gradle y los tres directorios de código fuente (`applications/`, `domain/`, `infrastructure/`) — no copia `deployment/` ni `docs/`. Normaliza CRLF→LF (`sed -i 's/\r$//' gradlew`) para checkouts en Windows y ejecuta `bootJar` saltando pruebas (`-x test`), sin *daemon* (`--no-daemon`).
2. **Etapa final** (`eclipse-temurin:21-jre-alpine`, solo JRE): instala `wget` (healthcheck) y **`su-exec`** (a diferencia de `ms_iam`, que solo instala `wget` y usa `USER mspi` estático). `ms_evidence` usa `su-exec` porque el `ENTRYPOINT` necesita ejecutar como `root` primero (para crear y ajustar permisos del volumen `EVIDENCE_STORAGE_DIR`) y luego bajar privilegios al usuario `mspi` antes de arrancar la JVM — una diferencia de diseño real respecto a `ms_iam` (que no maneja ningún volumen de datos propio y por tanto puede fijar `USER mspi` de forma estática en el Dockerfile).
3. **Volumen persistente**: `VOLUME ["/data/evidence"]` declara explícitamente el punto de montaje para los archivos de evidencia, reforzando que el almacenamiento es **local al contenedor/host**, no un servicio externo de object storage.
4. **`ENTRYPOINT` con inicialización de directorio**: `mkdir -p "${EVIDENCE_STORAGE_DIR}" && chown -R mspi:mspi "${EVIDENCE_STORAGE_DIR}" && exec su-exec mspi java ...` — garantiza que el directorio de almacenamiento exista y tenga los permisos correctos del usuario no privilegiado antes de que arranque la aplicación, incluso si el volumen se monta vacío o con propietario `root` por defecto de Docker.
5. **`JAVA_OPTS`**: detección de límites de contenedor (`UseContainerSupport`), heap limitado al 75% de la memoria asignada (`MaxRAMPercentage=75.0`), y `/dev/urandom` como fuente de entropía (evita bloqueos en operaciones criptográficas, relevante para el cálculo de SHA-256 en cada subida de archivo).
6. **Healthcheck nativo**: `wget` contra `/actuator/health` cada 30s, 90s de gracia inicial, 3 reintentos.

## 3. Variables de entorno

### 3.1 Variables de aplicación (`application.yaml`, `README.md`)

| Variable | Obligatoria | Descripción | Valor por defecto |
|---|---|---|---|
| `SERVER_PORT` | No | Puerto HTTP del servicio | `8086` |
| `JWT_ISSUER_URI` | Sí (prod) | *Issuer* Keycloak realm `iam` | `https://keycloak-production-4a95.up.railway.app/realms/iam` |
| `JWT_JWK_SET_URI` | No | URL alterna del JWK Set | `""` |
| `CORS_ALLOWED_ORIGINS` | Sí (frontend) | Orígenes CORS permitidos, separados por coma | — (`cors.allowed-origins` sin default en YAML) |
| `INTERNAL_API_KEY` | Sí (S2S) | Clave compartida para header `X-Internal-Api-Key` | `""` (si vacía, rutas `/internal/**` responden 503) |
| `EVIDENCE_STORAGE_DIR` | No | Raíz del filesystem para objetos almacenados | `./data/evidence` (`/data/evidence` en el contenedor) |
| `EVIDENCE_BUCKET` | No | Nombre lógico de "bucket" en metadatos (no es un bucket real) | `mspi-evidence` |
| `DB_CREDENTIAL` | **Sí, siempre** | JSON de conexión PostgreSQL (`DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USERNAME`, `DB_PASSWORD`) | — (sin fallback; la app no arranca) |
| `INFISICAL_SITE_URL`, `INFISICAL_PROJECT_ID`, `INFISICAL_ENVIRONMENT` | Prod (si se usa Infisical) | Configuración del proyecto/entorno en Infisical | — |
| `INFISICAL_CLIENT_ID` + `INFISICAL_CLIENT_SECRET` **o** `INFISICAL_ACCESS_TOKEN` | Prod (si se usa Infisical) | Autenticación contra Infisical | — |
| `INFISICAL_SECRET_PATH` | No | Ruta del proyecto Infisical de donde leer secretos | `/` |

**Diferencia real frente a `ms_iam`**: `ms_iam` cae a H2 en memoria si `DB_CREDENTIAL` no está configurado; `ms_evidence` **no tiene ese fallback** — `DBCredentialConfig.dbSecret` lanza `IllegalStateException("DB_CREDENTIAL (desde Infisical) es obligatorio...")` de forma incondicional si la variable está vacía, sin distinguir entorno de desarrollo o producción.

### 3.2 Variables de orquestación local (`docker-config/docker/docker-compose.apps.yml`, `env-mspi-docker.env.example`)

```yaml
ms-evidence:
  <<: *mspi-service
  build:
    context: ../../ms_evidence
    dockerfile: deployment/Dockerfile
  image: mspi/ms-evidence:dev
  container_name: ms_evidence
  environment:
    SERVER_PORT: "8086"
    EVIDENCE_STORAGE_DIR: /data/evidence
  volumes:
    - mspi_evidence_data:/data/evidence
  ports:
    - "8086:8086"
```

- El volumen nombrado **`mspi_evidence_data`** persiste los archivos físicos entre reinicios del contenedor, montado sobre `/data/evidence` (coincide con el `ENV EVIDENCE_STORAGE_DIR` del Dockerfile).
- `env-mspi-docker.env.example` declara `MS_EVIDENCE_URL=http://ms-evidence:8086`, la URL interna que otros microservicios de la red Docker (`ms_assessment`, `ms_reporting`) usan para invocar el canal `/internal/**`.
- `ms_assessment` declara `ms-evidence: condition: service_started` en su propio `depends_on` (no `service_healthy`), a diferencia de la dependencia estricta que otros servicios tienen sobre `ms-iam` — es decir, `ms_evidence` **no es un servicio de arranque bloqueante** de la misma forma que `ms_iam`; basta con que el contenedor haya iniciado, no que su healthcheck haya pasado.

## 4. Pipeline CI/CD (`bitbucket-pipelines.yml`)

```yaml
image: amazoncorretto:21

pipelines:
  branches:
    dev:
      - step: *build_app       # ./gradlew clean assemble
      - step: *deploy_railway  # railway up --service $RAILWAY_SERVICE --ci
```

**Etapas reales** (idéntico patrón al de `ms_iam` y `ms_org` en el mismo repositorio):

1. **`Build App`** — imagen `amazoncorretto:21`; instala herramientas (`unzip git findutils which tar gzip`), da permisos a `gradlew`, ejecuta `./gradlew clean assemble`. Publica `build/libs/**`, `build/reports/**`, `applications/**/build/libs/**` como artefactos. **No ejecuta `test` ni `check`** antes del despliegue.
2. **`Deploy to Railway`** — instala la CLI de Railway, valida `RAILWAY_TOKEN` y `RAILWAY_SERVICE` (aborta si faltan), despliega con `railway up --service "$RAILWAY_SERVICE" --ci`.
3. **Disparo**: pipeline definida **solo para la rama `dev`**; sin pipeline para `main`/`master` ni *pull requests*; solo caché estándar de Gradle (`~/.gradle/caches`).

No se encontró evidencia de análisis SonarQube, escaneo de seguridad, ni notificaciones en el pipeline, pese a que el proyecto Gradle tiene el plugin SonarQube preconfigurado (ver `05-Pruebas.md`).

## 5. Infraestructura de despliegue local (Docker Compose)

`ms_evidence` está declarado en `docker-config/docker/docker-compose.apps.yml` (proyecto Compose `mspi-apps`) junto a `ms-iam`, `ms-org`, `ms-catalog`, `ms-assessment`, `ms-reporting` y un frontend. Requiere que la infraestructura base (red Docker `mspi-net`, PostgreSQL, Keycloak) esté levantada primero mediante los compose independientes de `docker-config/docker/postgres` y `docker-config/docker/keycloak`.

Secuencia de arranque documentada en el propio compose:

```bash
docker network create mspi-net
cp env-mspi-docker.env.example env-mspi-docker.env   # completar secretos reales
docker compose -f docker-compose.apps.yml --env-file env-mspi-docker.env up -d --build
```

`ms_assessment` y `ms_reporting` consumen `ms_evidence` internamente vía `MS_EVIDENCE_URL=http://ms-evidence:8086`, dentro de la red `mspi-net`.

## 6. Puesta en marcha local (dos modalidades)

### 6.1 Ejecución directa con Gradle (sin Docker)

```bash
cd ms_evidence
export DB_CREDENTIAL='{"DB_HOST":"localhost","DB_PORT":"5432","DB_NAME":"MSPI","DB_USERNAME":"admin","DB_PASSWORD":"admin123"}'
export JWT_ISSUER_URI=http://localhost:8080/realms/iam
export CORS_ALLOWED_ORIGINS=http://localhost:3000
export INTERNAL_API_KEY=mspi-local-internal-key
export EVIDENCE_STORAGE_DIR=./data/evidence
./gradlew.bat :app-service:bootRun
```

A diferencia de `ms_iam`, aquí `DB_CREDENTIAL` es **obligatorio incluso en desarrollo local** — sin él, la aplicación aborta el arranque (`IllegalStateException`) antes de exponer cualquier endpoint. El directorio `EVIDENCE_STORAGE_DIR` debe existir o ser creable con permisos de escritura por el proceso que ejecuta Gradle (`LocalFileStorageAdapter` lo crea con `Files.createDirectories` si no existe).

El esquema `evidence` debe aplicarse manualmente contra PostgreSQL (`schema.sql`), dado que `spring.sql.init.mode: never` y `hibernate.ddl-auto: none` impiden cualquier creación automática de tablas.

### 6.2 Ejecución vía Docker Compose (entorno integrado)

```powershell
docker network create mspi-net
cd docker-config\docker
Copy-Item env-mspi-docker.env.example env-mspi-docker.env
# completar INTERNAL_API_KEY, DB_CREDENTIAL y revisar CORS_ALLOWED_ORIGINS
docker compose -f docker-compose.apps.yml --env-file env-mspi-docker.env up -d --build
```

Requiere PostgreSQL levantado con el esquema `evidence` aplicado (script `apply-all-schemas.ps1` de `docker-config/docker/postgres/scripts`, si existe para este microservicio) y Keycloak con el realm `iam` importado para validar los JWT entrantes.

## 7. Resumen de puertos y endpoints técnicos

| Elemento | Valor |
|---|---|
| Puerto HTTP | `8086` (contenedor y `SERVER_PORT` por defecto) |
| Healthcheck | `GET /actuator/health` |
| Info de build | `GET /actuator/info` |
| Nombre de imagen local | `mspi/ms-evidence:dev` |
| Nombre del contenedor | `ms_evidence` |
| Nombre del jar | `MsEvidence.jar` |
| Volumen de datos | `mspi_evidence_data:/data/evidence` (Docker Compose) |
| Esquema PostgreSQL | `evidence` |
