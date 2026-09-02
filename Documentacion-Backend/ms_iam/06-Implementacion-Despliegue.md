# ms_iam — Implementación y Despliegue

| Campo | Valor |
|---|---|
| Repositorio | `MSPI_NVA_CO_MR_BACK/ms_iam` |
| Fecha del documento | 2026-08-18 |
| Alcance | Build, Dockerfile, variables de entorno, CI/CD y puesta en marcha local del microservicio `ms_iam` |

---

## 1. Build local con Gradle

El proyecto usa **Gradle Wrapper 9.3.0** (`gradlew` / `gradlew.bat`, definido en `main.gradle`: `tasks.named('wrapper') { gradleVersion = '9.3.0' }`). Comandos reales disponibles desde la raíz de `ms_iam/`:

```bash
# Compilar y ejecutar pruebas + verificación de cobertura de todos los módulos
./gradlew clean check

# Compilar sin pruebas (usado en CI y en el Dockerfile)
./gradlew clean assemble

# Generar el jar ejecutable únicamente del módulo de aplicación
./gradlew :app-service:bootJar

# Ejecutar el servicio directamente (perfil H2 por defecto)
./gradlew :app-service:bootRun
```

El jar resultante se nombra explícitamente `MsIam.jar` (no `app-service.jar`), por configuración en `applications/app-service/build.gradle`:

```groovy
bootJar {
    archiveFileName = "${project.getParent().getName()}.${archiveExtension.get()}"
}
```

`project.getParent().getName()` resuelve al nombre del `rootProject` (`MsIam`, definido en `settings.gradle`: `rootProject.name = 'MsIam'`). También se registra una tarea auxiliar `explodedJar` que copia el jar descomprimido a `build/exploded`, y se deshabilita el jar plano por defecto (`jar { enabled = false }`) para evitar el artefacto `-plain.jar` que Spring Boot genera junto al *fat jar*.

## 2. Dockerfile (`deployment/Dockerfile`) — build multi-stage

```dockerfile
# Build: desde la raíz del repo (ms_iam/)
#   docker build -f deployment/Dockerfile -t mspi/ms-iam:dev .
# JAR: MsIam.jar (bootJar archiveFileName = rootProject.name)

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
EXPOSE 8082
ENV SERVER_PORT=8082 \
    JAVA_OPTS="-XX:+UseContainerSupport -XX:MaxRAMPercentage=75.0 -Djava.security.egd=file:/dev/./urandom"
HEALTHCHECK --interval=30s --timeout=5s --start-period=90s --retries=3 \
  CMD wget -qO- "http://127.0.0.1:${SERVER_PORT}/actuator/health" || exit 1
ENTRYPOINT ["sh", "-c", "exec java $JAVA_OPTS -jar /app/app.jar"]
```

**Análisis del multi-stage:**

1. **Etapa `build`** (`eclipse-temurin:21-jdk-alpine`): copia solo lo estrictamente necesario para compilar (`gradlew*`, archivos de configuración Gradle, y los 4 directorios de código fuente `applications/`, `domain/`, `infrastructure/`) — **no copia `deployment/` ni `docs/`**, minimizando el contexto de build. Normaliza finales de línea CRLF→LF (`sed -i 's/\r$//' gradlew`) para tolerar checkouts en Windows, y ejecuta `bootJar` **saltando las pruebas** (`-x test`) y sin *daemon* de Gradle (`--no-daemon`), apropiado para builds de CI efímeros.
2. **Etapa final** (`eclipse-temurin:21-jre-alpine`, solo JRE, no JDK): imagen mínima, agrega usuario y grupo del sistema no privilegiados (`mspi`), copia únicamente el jar generado, y ejecuta el proceso como ese usuario (`USER mspi`) — buena práctica de seguridad de contenedores (no ejecutar como root).
3. **Variables de entorno del contenedor**: `SERVER_PORT=8082` por defecto; `JAVA_OPTS` habilita detección de límites de contenedor (`UseContainerSupport`) y limita el heap al 75% de la memoria asignada al contenedor (`MaxRAMPercentage=75.0`), además de usar `/dev/urandom` como fuente de entropía para evitar bloqueos en operaciones criptográficas (relevante para la generación de secretos TOTP).
4. **Healthcheck nativo de Docker**: usa `wget` (instalado explícitamente porque Alpine no lo trae por defecto) contra `/actuator/health` cada 30s, con 90s de periodo de gracia inicial y 3 reintentos — este healthcheck es el que consumen los `depends_on: condition: service_healthy` de otros microservicios en `docker-compose.apps.yml`.

## 3. Variables de entorno

### 3.1 Variables de aplicación (`application.yaml`, `docs/README.md` §8)

| Variable | Obligatoria | Descripción | Valor por defecto |
|---|---|---|---|
| `SERVER_PORT` | No | Puerto HTTP del servicio | `8082` |
| `KEYCLOAK_TOKEN_URI` | Sí | URL del *token endpoint* OAuth2 de Keycloak | — |
| `KEYCLOAK_CLIENT_ID` | Sí | Cliente OAuth2 del backend (`mspi-backend`) | — |
| `KEYCLOAK_CLIENT_SECRET` | Depende | Requerido si el cliente Keycloak exige autenticación confidencial | — |
| `KEYCLOAK_ADMIN_REALM_URL` | Sí (gestión de usuarios) | Base de la Admin REST API de Keycloak | `""` |
| `JWT_ISSUER_URI` | Sí | *Issuer* esperado en los JWT validados | — |
| `JWT_JWK_SET_URI` | No | URL alterna del JWK Set (si difiere del *issuer*, p. ej. en Docker donde el *issuer* del token es `localhost` pero el JWKS se resuelve por el hostname interno `keycloak`) | `""` |
| `INTERNAL_API_KEY` | Sí (prod) | Clave compartida para proteger `/internal/**` | `""` (si vacía, responde 503) |
| `MS_ORG_URL` | Recomendada | URL base de `ms_org`, consumida para validar organizaciones | `http://localhost:8083` |
| `BREVO_API_KEY` | Sí (envío de correo) | Clave de API de Brevo | — |
| `BREVO_FROM_EMAIL` | Sí (envío de correo) | Remitente de correos transaccionales | — |
| `APP_MAIL_LOGO_URL` | No | Logo embebido en las plantillas de correo | `""` |
| `APP_TOTP_ISSUER` | No | Nombre del emisor mostrado en apps autenticadoras TOTP | `MSPI` |
| `DB_CREDENTIAL` | Prod | JSON con credenciales PostgreSQL (`DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USERNAME`, `DB_PASSWORD`) | — (sin ella, cae a H2 en memoria) |
| `CORS_ALLOWED_ORIGINS` | No | Orígenes CORS permitidos, separados por coma | `""` |
| `INFISICAL_SITE_URL`, `INFISICAL_PROJECT_ID`, `INFISICAL_ENVIRONMENT` | Prod (si se usa Infisical) | Configuración del proyecto/entorno en Infisical | — |
| `INFISICAL_CLIENT_ID` + `INFISICAL_CLIENT_SECRET` **o** `INFISICAL_ACCESS_TOKEN` | Prod (si se usa Infisical) | Credenciales de autenticación contra Infisical | — |
| `INFISICAL_SECRET_PATH` | No | Ruta dentro del proyecto Infisical de donde leer secretos | `/` |

### 3.2 Variables de orquestación local (`docker-config/docker/env-mspi-docker.env.example`)

El archivo de ejemplo para Docker Compose local confirma valores concretos usados en desarrollo integrado:

```env
DB_CREDENTIAL={"DB_HOST":"postgres_mspi_local","DB_PORT":"5432","DB_NAME":"MSPI","DB_USERNAME":"admin","DB_PASSWORD":"admin123"}

# JWT: iss del token = localhost (login navegador). JWKS desde el contenedor keycloak en mspi-net.
JWT_ISSUER_URI=http://localhost:8080/realms/iam
JWT_JWK_SET_URI=http://keycloak:8080/realms/iam/protocol/openid-connect/certs

# Keycloak Admin API (desde la red Docker, hostname del servicio)
KEYCLOAK_TOKEN_URI=http://keycloak:8080/realms/iam/protocol/openid-connect/token
KEYCLOAK_ADMIN_REALM_URL=http://keycloak:8080/admin/realms/iam
KEYCLOAK_CLIENT_ID=mspi-backend
KEYCLOAK_CLIENT_SECRET=mspi-backend-secret-local

BREVO_API_KEY=cambiar-por-tu-api-key
BREVO_FROM_EMAIL=no-reply@ejemplo.com

INTERNAL_API_KEY=mspi-local-internal-key-2026

MS_IAM_URL=http://ms-iam:8082
MS_ORG_URL=http://ms-org:8083
```

Este archivo evidencia una particularidad de diseño relevante: **el `JWT_ISSUER_URI` apunta a `localhost:8080`** (porque los navegadores de los desarrolladores obtienen el token con esa URL visible), **mientras que `JWT_JWK_SET_URI` apunta al hostname interno `keycloak:8080`** dentro de la red Docker `mspi-net` — de ahí que `SecurityConfig.jwtDecoder()` soporte configurar ambos por separado (`withJwkSetUri` + validación manual del *issuer* con `JwtValidators.createDefaultWithIssuer`), en vez de depender únicamente de `withIssuerLocation` (que intentaría resolver el JWKS desde el propio *issuer*, inalcanzable desde dentro del contenedor).

No se encontró en `ms_iam/` un archivo `.env.example` propio del microservicio; las variables se documentan en `docs/README.md` y se materializan en el `.env` compartido de `docker-config/`.

## 4. Pipeline CI/CD (`bitbucket-pipelines.yml`)

```yaml
image: amazoncorretto:21

pipelines:
  branches:
    dev:
      - step: *build_app       # ./gradlew clean assemble
      - step: *deploy_railway  # railway up --service $RAILWAY_SERVICE --ci
```

**Etapas reales:**

1. **`Build App`** — imagen base `amazoncorretto:21`; instala herramientas (`unzip git findutils which tar gzip`), da permisos de ejecución a `gradlew`, y ejecuta `./gradlew clean assemble`. Publica como artefactos `build/libs/**`, `build/reports/**` y `applications/**/build/libs/**`. **No ejecuta `test` ni `check`** — es decir, el pipeline actual no corre las 21 clases de prueba ni valida el umbral de cobertura del 80% antes de desplegar (ver observación en `05-Pruebas.md`).
2. **`Deploy to Railway`** — instala la CLI de Railway (`curl -fsSL https://railway.app/install.sh | sh`), valida que existan las variables de pipeline `RAILWAY_TOKEN` y `RAILWAY_SERVICE` (aborta con mensaje explícito si faltan), y despliega con `railway up --service "$RAILWAY_SERVICE" --ci`.
3. **Disparo**: la pipeline **solo está definida para la rama `dev`** (`pipelines.branches.dev`); no hay pipeline configurada para `main`/`master` ni para *pull requests* en el archivo revisado, y no hay *caching* de nada salvo el caché estándar de Gradle (`~/.gradle/caches`).

No se encontró evidencia de análisis SonarQube, escaneo de seguridad (SAST/dependencias) ni notificaciones (Slack/Teams) en el pipeline, pese a que el proyecto Gradle sí tiene el plugin de SonarQube preconfigurado (ver `05-Pruebas.md` §4) — es decir, la infraestructura de calidad existe en el build pero no está conectada al pipeline de CI actual.

## 5. Infraestructura de despliegue local (Docker Compose)

`ms_iam` está declarado en `docker-config/docker/docker-compose.apps.yml`, dentro del proyecto Compose `mspi-apps`, junto a otros 5 microservicios activos (`ms-org`, `ms-catalog`, `ms-evidence`, y al menos un `ms-frontend`/gateway que depende de todos). Requiere que la infraestructura base (red Docker `mspi-net`, PostgreSQL y Keycloak) esté levantada primero mediante los compose independientes en `docker-config/docker/postgres/docker-compose.yml` y `docker-config/docker/keycloak/docker-compose.yml`.

```yaml
ms-iam:
  <<: *mspi-service          # restart, env_file, red mspi-net, extra_hosts
  build:
    context: ../../ms_iam
    dockerfile: deployment/Dockerfile
  image: mspi/ms-iam:dev
  container_name: ms_iam
  environment:
    SERVER_PORT: "8082"
  ports:
    - "8082:8082"
```

Los demás microservicios (`ms-org`, y por extensión los que dependen de autenticación) declaran:

```yaml
depends_on:
  ms-iam:
    condition: service_healthy
```

Esto confirma que `ms_iam` es un **servicio de arranque temprano y bloqueante** para el resto del sistema: ningún otro microservicio que dependa de IAM arranca hasta que el `HEALTHCHECK` del `Dockerfile` de `ms_iam` reporte éxito.

Secuencia de arranque documentada en el propio compose (comentario inicial del archivo):

```bash
docker network create mspi-net                 # una sola vez
cp env-mspi-docker.env.example env-mspi-docker.env   # y completar secretos reales
docker compose -f docker-compose.apps.yml --env-file env-mspi-docker.env up -d --build
```

## 6. Puesta en marcha local (dos modalidades)

### 6.1 Ejecución directa con Gradle (desarrollo rápido, sin Docker)

```bash
cd ms_iam
export KEYCLOAK_TOKEN_URI=http://localhost:8080/realms/iam/protocol/openid-connect/token
export KEYCLOAK_CLIENT_ID=mspi-backend
export KEYCLOAK_CLIENT_SECRET=mspi-backend-secret-local
export JWT_ISSUER_URI=http://localhost:8080/realms/iam
export BREVO_API_KEY=...
export BREVO_FROM_EMAIL=...
./gradlew :app-service:bootRun
```

Sin `DB_CREDENTIAL` configurada, el servicio arranca contra **H2 en memoria** (`jdbc:h2:mem:iam`), con consola habilitada en `/h2` (`spring.h2.console.enabled: true`). Como `spring.sql.init.mode: never`, las tablas **no se crean automáticamente** ni siquiera en H2: es responsabilidad del desarrollador aplicar `schema-iam-mvp.sql` manualmente contra la instancia H2, o usar un cliente que ejecute el script al iniciar.

### 6.2 Ejecución vía Docker Compose (entorno integrado completo)

Requiere Keycloak con el *realm* `iam` importado (`docker-config/docker/keycloak/imports/iam-realm.json`) y el cliente `mspi-backend` con *service account* habilitado y roles `realm-management` (`manage-users`, etc.) asignados — de lo contrario `KeycloakAdminAdapter` recibirá 403 al intentar crear/gestionar usuarios (el propio `GlobalExceptionHandler.handleRestClientResponse` detecta este caso específico y devuelve un mensaje guiando a ejecutar `docker-config/docker/keycloak/scripts/setup-keycloak.ps1`).

```powershell
docker network create mspi-net
cd docker-config\docker
Copy-Item env-mspi-docker.env.example env-mspi-docker.env
# completar BREVO_API_KEY, BREVO_FROM_EMAIL y revisar INTERNAL_API_KEY
docker compose -f docker-compose.apps.yml --env-file env-mspi-docker.env up -d --build
```

Tras el arranque, la base de datos PostgreSQL debe tener aplicado `schema-iam-mvp.sql` (o `schema-iam-patch.sql` sobre una BD preexistente); el propio `docs/README.md` documenta el síntoma típico de omitir este paso: `POST /auth/login` devuelve 500 con `relation "iam.audit_log" does not exist`. El script `apply-all-schemas.ps1` en `docker-config/docker/postgres/scripts` automatiza la aplicación de los esquemas de todos los microservicios.

## 7. Resumen de puertos y endpoints técnicos

| Elemento | Valor |
|---|---|
| Puerto HTTP | `8082` (contenedor y `SERVER_PORT` por defecto) |
| Healthcheck | `GET /actuator/health` |
| Info de build | `GET /actuator/info` |
| Nombre de imagen local | `mspi/ms-iam:dev` |
| Nombre del contenedor | `ms_iam` |
| Nombre del jar | `MsIam.jar` |
