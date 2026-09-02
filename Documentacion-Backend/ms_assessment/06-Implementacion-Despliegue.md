# ms_assessment — Implementación y Despliegue

| Campo | Valor |
|---|---|
| Repositorio | `MSPI_NVA_CO_MR_BACK/ms_assessment` |
| Fecha del documento | 2026-08-19 |
| Alcance | Build, Dockerfile, variables de entorno, CI/CD y puesta en marcha local del microservicio `ms_assessment` |

---

## 1. Build local con Gradle

Gradle Wrapper **9.3.0** (`main.gradle`: `tasks.named('wrapper') { gradleVersion = '9.3.0' }`), idéntico al resto del ecosistema MSPI. Comandos reales disponibles desde `ms_assessment/`:

```bash
# Compilar y ejecutar pruebas + verificación de cobertura de todos los módulos
./gradlew clean check

# Compilar sin pruebas (usado en CI y en el Dockerfile)
./gradlew clean assemble

# Generar el jar ejecutable únicamente del módulo de aplicación
./gradlew :app-service:bootJar

# Ejecutar el servicio directamente
./gradlew :app-service:bootRun
```

El jar resultante se nombra `MsAssessment.jar` (no `app-service.jar`), por la misma convención que `ms_iam`:

```groovy
bootJar {
    archiveFileName = "${project.getParent().getName()}.${archiveExtension.get()}"
}
```

`project.getParent().getName()` resuelve a `MsAssessment` (`settings.gradle`: `rootProject.name = 'MsAssessment'`). El módulo `:model` no declara dependencias (`build.gradle` vacío), y `settings.gradle` incluye 6 subproyectos además del raíz (`:app-service`, `:model`, `:usecase`, `:common`, `:api-rest`, `:jpa-repository`, `:rest-consumer` — 7 en total).

## 2. Dockerfile (`deployment/Dockerfile`) — build multi-stage

```dockerfile
# docker build -f deployment/Dockerfile -t mspi/ms-assessment:dev .

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
RUN chown mspi:mspi /app/app.jar
USER mspi
EXPOSE 8084
ENV SERVER_PORT=8084 \
    JAVA_OPTS="-XX:+UseContainerSupport -XX:MaxRAMPercentage=75.0 -Djava.security.egd=file:/dev/./urandom"
HEALTHCHECK --interval=30s --timeout=5s --start-period=90s --retries=3 \
  CMD wget -qO- "http://127.0.0.1:${SERVER_PORT}/actuator/health" || exit 1
ENTRYPOINT ["sh", "-c", "exec java $JAVA_OPTS -jar /app/app.jar"]
```

Estructura **idéntica** a la de `ms_iam` (mismo patrón multi-stage, mismas imágenes base `eclipse-temurin:21-jdk-alpine` → `21-jre-alpine`, mismo usuario no privilegiado `mspi`, mismo healthcheck con `wget`), con la única diferencia funcional del puerto: `ms_assessment` usa `8084` en lugar de `8082`. Esto confirma un **arquetipo de Dockerfile compartido** entre los microservicios del ecosistema MSPI, replicado archivo por archivo con el número de puerto como única variable relevante.

- **Etapa `build`**: copia solo `gradlew*`, configuración Gradle y los 3 directorios de código fuente (`applications/`, `domain/`, `infrastructure/`) — no incluye `deployment/` ni `docs/` en el contexto de imagen. Normaliza CRLF→LF y ejecuta `bootJar -x test --no-daemon`.
- **Etapa final**: solo JRE, usuario/grupo `mspi` no root, `MaxRAMPercentage=75.0` para respetar límites de contenedor, `/dev/urandom` como fuente de entropía.
- **Healthcheck**: `GET /actuator/health` cada 30s, 90s de gracia inicial, 3 reintentos — es el que consumen los `depends_on: condition: service_healthy` de otros servicios (aunque, a diferencia de `ms_iam`, ningún otro microservicio del compose declara depender de `ms_assessment` con esa condición; es `ms_assessment` quien depende de `ms-iam` con `service_healthy` y de `ms-org`/`ms-catalog`/`ms-evidence` solo con `service_started`).

## 3. Variables de entorno

### 3.1 Variables de aplicación (`application.yaml`, `README.md` §Configuración)

| Variable | Obligatoria | Descripción | Valor por defecto |
|---|---|---|---|
| `SERVER_PORT` | No | Puerto HTTP del servicio | `8084` |
| `JWT_ISSUER_URI` | Sí (prod) | *Issuer* esperado en los JWT validados | `https://keycloak-production-4a95.up.railway.app/realms/iam` |
| `JWT_JWK_SET_URI` | No | URL alterna del JWK Set (Docker: hostname interno `keycloak`) | `""` |
| `INTERNAL_API_KEY` | Sí (prod) | Clave compartida para `/internal/**` y llamadas salientes a `ms_catalog`/`ms_evidence`/`ms_iam` | `""` (si vacía, `/internal/**` responde 503) |
| `MS_ORG_URL` | Recomendada | Base de `ms_org` | `http://localhost:8083` |
| `MS_CATALOG_URL` | Recomendada | Base de `ms_catalog` | `http://localhost:8085` |
| `MS_EVIDENCE_URL` | Recomendada | Base de `ms_evidence` | `http://localhost:8086` |
| `MS_IAM_URL` | Recomendada | Base de `ms_iam` | `http://localhost:8082` |
| `CORS_ALLOWED_ORIGINS` | No | Orígenes CORS permitidos, separados por coma | *(sin valor por defecto — `${CORS_ALLOWED_ORIGINS}` sin `:`, obligatoria en `application.yaml` si Spring resuelve estrictamente el placeholder)* |
| `SPRING_DATASOURCE_*` / `DB_CREDENTIAL` | Prod | Conexión PostgreSQL | — |
| `INFISICAL_SITE_URL`, `INFISICAL_PROJECT_ID`, `INFISICAL_ENVIRONMENT`, credenciales | Prod (si se usa Infisical) | Configuración de Infisical | — |

**Discrepancia detectada entre `README.md` y el código real**: el `README.md` de `ms_assessment` afirma en su sección "Compilar y ejecutar" que *"El esquema `assessment` se aplica al arranque (`spring.sql.init.mode: always`)"*, pero `application.yaml` define explícitamente `spring.sql.init.mode: never` y `hibernate.ddl-auto: none`. El comportamiento real (verificado en el archivo de configuración, no en el README) es que **el microservicio no ejecuta DDL automáticamente**, igual que `ms_iam` y el resto del ecosistema (coherente con `RNF-07` en `01-Planificacion.md`). Se documenta aquí como hallazgo explícito de mantenimiento: el README debe corregirse para no inducir a error a un desarrollador que asuma que el esquema se crea solo.

### 3.2 Variables de orquestación local (`docker-config/docker/env-mspi-docker.env.example`)

El archivo de ejemplo compartido declara, entre otras, `MS_ASSESSMENT_URL=http://ms-assessment:8084` (usada por otros microservicios como `ms_reporting` para consumir la API interna de `ms_assessment`), confirmando que este microservicio también actúa como **proveedor** dentro de la red `mspi-net`, no solo como consumidor de `ms_org`/`ms_catalog`/`ms_evidence`/`ms_iam`.

No se encontró un archivo `.env.example` propio dentro de `ms_assessment/`; las variables se documentan en `README.md` y se materializan en el `.env` compartido de `docker-config/`, igual que en `ms_iam`.

## 4. Pipeline CI/CD (`bitbucket-pipelines.yml`)

```yaml
image: amazoncorretto:21

pipelines:
  branches:
    dev:
      - step: *build_app       # ./gradlew clean assemble
      - step: *deploy_railway  # railway up --service $RAILWAY_SERVICE --ci
```

Estructura **idéntica** a la de `ms_iam` (mismas dos etapas, misma imagen base, mismo *caching* de `~/.gradle/caches`, mismo mecanismo de despliegue):

1. **`Build App`** — instala herramientas (`unzip git findutils which tar gzip`), ejecuta `./gradlew clean assemble` (sin `test` ni `check`), publica `build/libs/**`, `build/reports/**`, `applications/**/build/libs/**` como artefactos.
2. **`Deploy to Railway`** — instala CLI de Railway, valida `RAILWAY_TOKEN`/`RAILWAY_SERVICE` (aborta si faltan), despliega con `railway up --service "$RAILWAY_SERVICE" --ci`.
3. **Disparo**: solo definida para la rama `dev`; sin pipeline para `main`/`master` ni pull requests.

**Misma limitación real que `ms_iam`**: el pipeline no ejecuta `test`/`check` antes de desplegar, por lo que ni las 10 clases de prueba existentes ni el umbral de cobertura del 80% actúan como *gate* de calidad antes de producción. Dado que la cobertura de pruebas de `ms_assessment` está aún más concentrada (solo `:usecase` y parte de `:api-rest`, ver `05-Pruebas.md`) que la de `ms_iam`, esta ausencia de *gate* es proporcionalmente más relevante aquí: código sin ninguna prueba (persistencia, adaptadores REST salientes, 8 de 9 controladores) llega a producción sin ninguna verificación automatizada, ni siquiera de compilación de pruebas.

No se encontró evidencia de análisis SonarQube ni escaneo de seguridad en el pipeline, pese a que el plugin SonarQube está preconfigurado en `build.gradle`/`main.gradle`.

## 5. Infraestructura de despliegue local (Docker Compose)

`ms_assessment` está declarado en `docker-config/docker/docker-compose.apps.yml`, dentro del proyecto Compose `mspi-apps`:

```yaml
ms-assessment:
  <<: *mspi-service
  build:
    context: ../../ms_assessment
    dockerfile: deployment/Dockerfile
  image: mspi/ms-assessment:dev
  container_name: ms_assessment
  depends_on:
    ms-iam:
      condition: service_healthy
    ms-org:
      condition: service_started
    ms-catalog:
      condition: service_started
    ms-evidence:
      condition: service_started
  environment:
    SERVER_PORT: "8084"
  ports:
    - "8084:8084"
```

`ms_assessment` es el microservicio con **más dependencias declaradas** de todo el compose (4 servicios en `depends_on`), reflejando su rol de integrador: consume `ms_org` (validación de organización), `ms_catalog` (todo el contenido evaluable) y `ms_evidence` (levantamiento documental) en tiempo de creación/publicación/diagnóstico, y depende de `ms_iam` para auditoría e identidad. Solo la dependencia hacia `ms-iam` exige `service_healthy` (arranque bloqueante); las demás solo exigen `service_started` (arranque no bloqueante, tolerando que esos servicios aún no respondan cuando `ms_assessment` inicia, ya que sus llamadas ocurren en tiempo de petición, no en el arranque).

`ms_reporting` (Módulo 9, microservicio consumidor de la API interna de `ms_assessment`) se declara en el mismo compose con `MS_ASSESSMENT_URL` apuntando a `http://ms-assessment:8084`, aunque no se encontró un `depends_on` explícito de `ms-reporting` hacia `ms-assessment` en el fragmento de compose revisado.

Secuencia de arranque documentada en el propio compose (comentario inicial):

```bash
docker network create mspi-net                 # una sola vez
cp env-mspi-docker.env.example env-mspi-docker.env   # y completar secretos reales
docker compose -f docker-compose.apps.yml --env-file env-mspi-docker.env up -d --build
```

## 6. Puesta en marcha local (dos modalidades)

### 6.1 Ejecución directa con Gradle (desarrollo rápido, sin Docker)

```bash
cd ms_assessment
export JWT_ISSUER_URI=http://localhost:8080/realms/iam
export MS_ORG_URL=http://localhost:8083
export MS_CATALOG_URL=http://localhost:8085
export MS_EVIDENCE_URL=http://localhost:8086
export MS_IAM_URL=http://localhost:8082
export INTERNAL_API_KEY=mspi-local-internal-key-2026
./gradlew :app-service:bootRun
```

A diferencia de `ms_iam` (que puede arrancar contra H2 en memoria sin `DB_CREDENTIAL`), **no se detectó configuración de base de datos en memoria en `ms_assessment`**: `application.yaml` no declara ningún perfil ni dependencia H2 en ningún `build.gradle` del proyecto (`runtimeOnly 'org.postgresql:postgresql'` es la única dependencia de base de datos declarada, en `jpa-repository` y `app-service`). Esto implica que **`ms_assessment` requiere PostgreSQL real incluso para desarrollo local** — no tiene el mecanismo de *fallback* a base de datos embebida que sí existe en `ms_iam`.

Como `spring.sql.init.mode: never`, el esquema `assessment` debe aplicarse manualmente contra esa instancia PostgreSQL antes del primer arranque (`applications/app-service/src/main/resources/schema.sql`).

### 6.2 Ejecución vía Docker Compose (entorno integrado completo)

```powershell
docker network create mspi-net
cd docker-config\docker
Copy-Item env-mspi-docker.env.example env-mspi-docker.env
# completar INTERNAL_API_KEY y revisar URLs de los 4 microservicios consumidos
docker compose -f docker-compose.apps.yml --env-file env-mspi-docker.env up -d --build
```

Requiere, además de PostgreSQL/Keycloak levantados, que `ms-org`, `ms-catalog`, `ms-evidence` e `ms-iam` estén operativos (o al menos arrancados) en la red `mspi-net`, dado que la creación de una evaluación depende de los cuatro. El síntoma típico de un esquema no aplicado (por analogía con el patrón documentado en `ms_iam`) sería un error 500 al invocar `POST /assessments` con mensaje de relación inexistente (`relation "assessment.assessment" does not exist`), aunque este mensaje específico no está documentado en el `README.md` de `ms_assessment` (a diferencia del caso análogo sí documentado en `ms_iam`).

## 7. Resumen de puertos y endpoints técnicos

| Elemento | Valor |
|---|---|
| Puerto HTTP | `8084` (contenedor y `SERVER_PORT` por defecto) |
| Healthcheck | `GET /actuator/health` |
| Info de build | `GET /actuator/info` |
| Nombre de imagen local | `mspi/ms-assessment:dev` |
| Nombre del contenedor | `ms_assessment` |
| Nombre del jar | `MsAssessment.jar` |
| Esquema de base de datos | `assessment` (PostgreSQL compartido `MSPI`) |
| Dependencias de arranque (compose) | `ms-iam` (bloqueante), `ms-org`/`ms-catalog`/`ms-evidence` (no bloqueante) |
