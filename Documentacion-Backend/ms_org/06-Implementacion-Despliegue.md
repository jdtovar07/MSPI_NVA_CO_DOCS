# ms_org — Implementación y Despliegue

| Campo | Valor |
|---|---|
| Repositorio | `MSPI_NVA_CO_MR_BACK/ms_org` |
| Fecha del documento | 2026-08-19 |
| Alcance | Build, Dockerfile, variables de entorno, CI/CD y puesta en marcha local del microservicio `ms_org` |

---

## 1. Build local con Gradle

El proyecto usa **Gradle Wrapper 9.3.0** (`gradlew` / `gradlew.bat`, `main.gradle`: `tasks.named('wrapper') { gradleVersion = '9.3.0' }`). Comandos reales disponibles desde la raíz de `ms_org/`:

```bash
# Compilar (verificado en README.md)
./gradlew.bat :app-service:compileJava

# Ejecutar pruebas de todos los módulos
./gradlew test

# Ejecutar el servicio directamente
./gradlew.bat :app-service:bootRun

# Compilar sin pruebas (usado en el Dockerfile)
./gradlew :app-service:bootJar -x test --no-daemon
```

A diferencia de `ms_iam` (cuyo `app-service/build.gradle` renombra explícitamente el jar a `MsIam.jar`), el `applications/app-service/build.gradle` de `ms_org` **sí aplica la misma convención**:

```groovy
bootJar {
    archiveFileName = "${project.getParent().getName()}.${archiveExtension.get()}"
}
```

`project.getParent().getName()` resuelve a `MsOrg` (`settings.gradle`: `rootProject.name = 'MsOrg'`), por lo que el artefacto generado se llama **`MsOrg.jar`**. También se deshabilita el jar plano (`jar { enabled = false }`) para evitar el artefacto `-plain.jar` adicional que genera Spring Boot.

## 2. Dockerfile (`deployment/Dockerfile`) — build multi-stage

```dockerfile
# docker build -f deployment/Dockerfile -t mspi/ms-org:dev .

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
EXPOSE 8083
ENV SERVER_PORT=8083 \
    JAVA_OPTS="-XX:+UseContainerSupport -XX:MaxRAMPercentage=75.0 -Djava.security.egd=file:/dev/./urandom"
HEALTHCHECK --interval=30s --timeout=5s --start-period=90s --retries=3 \
  CMD wget -qO- "http://127.0.0.1:${SERVER_PORT}/actuator/health" || exit 1
ENTRYPOINT ["sh", "-c", "exec java $JAVA_OPTS -jar /app/app.jar"]
```

**Análisis del multi-stage** (patrón idéntico al de `ms_iam`, salvo puerto y nombre de imagen):

1. **Etapa `build`** (`eclipse-temurin:21-jdk-alpine`): copia solo lo necesario para compilar (`gradlew*`, ficheros de configuración Gradle, `applications/`, `domain/`, `infrastructure/`) — **no copia `deployment/` ni `docs/`**. Normaliza CRLF→LF en `gradlew` (tolerancia a *checkouts* en Windows), y ejecuta `bootJar` sin pruebas (`-x test`) y sin *daemon* (`--no-daemon`).
2. **Etapa final** (`eclipse-temurin:21-jre-alpine`, solo JRE): imagen mínima, usuario/grupo de sistema no privilegiado `mspi`, copia únicamente el jar generado y ejecuta el proceso como ese usuario.
3. **Variables de entorno del contenedor**: `SERVER_PORT=8083` por defecto; `JAVA_OPTS` habilita `UseContainerSupport`, limita el heap al 75% de la memoria asignada al contenedor, y usa `/dev/urandom` como fuente de entropía.
4. **Healthcheck nativo de Docker**: `wget` (instalado explícitamente) contra `/actuator/health` cada 30s, con 90s de gracia inicial y 3 reintentos — es el healthcheck que consumirían otros servicios que declaren `depends_on: ms-org: condition: service_healthy` en `docker-compose.apps.yml`.

## 3. Variables de entorno

### 3.1 Variables de aplicación (verificadas en `application.yaml` y `README.md`)

| Variable | Obligatoria | Descripción | Valor por defecto |
|---|---|---|---|
| `SERVER_PORT` | No | Puerto HTTP del servicio | `8083` |
| `MS_IAM_URL` | Sí | Base URL de `ms_iam`, usada por `IamRestClientConfig` | — |
| `BASE_URL_LOCATION_API` | Sí | Base URL de la API Country State City | — |
| `LOCATION_API_KEY` | Sí | API key del proveedor de ubicación (`X-CSCAPI-KEY`) — sin ella, el catálogo devuelve listas vacías (`LocationCatalogAdapter.hasApiKey()`) | — |
| `JWT_ISSUER_URI` | Sí (prod) | *Issuer* Keycloak (realm `iam`) | `https://keycloak-production-4a95.up.railway.app/realms/iam` |
| `JWT_JWK_SET_URI` | No | URL alterna del JWK Set (útil si difiere del *issuer* visible, p. ej. en Docker) | `""` |
| `CORS_ALLOWED_ORIGINS` | Sí (para consumo desde front) | Orígenes CORS permitidos, separados por coma | — |
| `INFISICAL_SITE_URL` | Sí (prod) | URL del servidor Infisical | — |
| `INFISICAL_PROJECT_ID` | Sí (prod) | ID del proyecto en Infisical | — |
| `INFISICAL_ENVIRONMENT` | Sí (prod) | Slug del entorno (dev/staging/prod) | — |
| `INFISICAL_CLIENT_ID` + `INFISICAL_CLIENT_SECRET` | Sí* | Credenciales *machine identity* para Infisical | — |
| `INFISICAL_ACCESS_TOKEN` | Sí* | Alternativa al par client id/secret | — |
| `INFISICAL_SECRET_PATH` | No | Ruta de secretos dentro de Infisical | `/` |
| `DB_CREDENTIAL` | **Sí, siempre** | JSON `{DB_HOST, DB_PORT, DB_NAME, DB_USERNAME, DB_PASSWORD}` — **sin ella el servicio no arranca** (`DBCredentialConfig` lanza `IllegalStateException`); no existe fallback a H2 como en `ms_iam` | — |

\* Una de las dos formas de autenticación Infisical.

**Diferencia clave frente a `ms_iam`**: `ms_org` **requiere PostgreSQL real incluso en desarrollo local**; no hay perfil ni motor embebido alternativo configurado en `application.yaml` ni en `build.gradle` (`jpa-repository/build.gradle` no declara dependencia de H2).

### 3.2 Variables de orquestación local (esperadas en `docker-config/docker/env-mspi-docker.env.example`, ver documentación de `ms_iam` para el archivo compartido)

```env
DB_CREDENTIAL={"DB_HOST":"postgres_mspi_local","DB_PORT":"5432","DB_NAME":"MSPI","DB_USERNAME":"admin","DB_PASSWORD":"admin123"}
JWT_ISSUER_URI=http://localhost:8080/realms/iam
JWT_JWK_SET_URI=http://keycloak:8080/realms/iam/protocol/openid-connect/certs
MS_IAM_URL=http://ms-iam:8082
BASE_URL_LOCATION_API=https://api.countrystatecity.in/v1
LOCATION_API_KEY=cambiar-por-tu-api-key
CORS_ALLOWED_ORIGINS=http://localhost:4200,http://localhost:3000
```

No se encontró en `ms_org/` un archivo `.env.example` propio del microservicio (mismo patrón documentado en `ms_iam`); las variables se materializan en el `.env` compartido de `docker-config/`.

## 4. Pipeline CI/CD (`bitbucket-pipelines.yml`)

```yaml
image: amazoncorretto:21

pipelines:
  branches:
    dev:
      - step: *build_app       # ./gradlew clean assemble
      - step: *deploy_railway  # railway up --service $RAILWAY_SERVICE --ci
```

**Etapas reales** (idéntico patrón a `ms_iam`):

1. **`Build App`** — imagen base `amazoncorretto:21`; instala herramientas (`unzip git findutils which tar gzip`), da permisos de ejecución a `gradlew`, ejecuta `./gradlew clean assemble`. Publica como artefactos `build/libs/**`, `build/reports/**` y `applications/**/build/libs/**`. **No ejecuta `test` ni `check`.**
2. **`Deploy to Railway`** — instala la CLI de Railway, valida `RAILWAY_TOKEN` y `RAILWAY_SERVICE` (aborta con mensaje explícito si faltan), despliega con `railway up --service "$RAILWAY_SERVICE" --ci`.
3. **Disparo**: la pipeline **solo está definida para la rama `dev`**; no hay pipeline para `main`/`master` ni para *pull requests*. Único *cache* configurado: el estándar de Gradle (`~/.gradle/caches`).

No se encontró evidencia de análisis SonarQube ni de escaneo de seguridad (SAST/dependencias) en el pipeline, pese a que el proyecto Gradle sí tiene el plugin de SonarQube preconfigurado (`build.gradle` raíz) — misma observación que en `ms_iam`: la infraestructura de calidad existe en el build pero no está conectada al CI actual.

## 5. Infraestructura de despliegue local (Docker Compose)

Consistente con lo documentado para `ms_iam`, `ms_org` se declara en `docker-config/docker/docker-compose.apps.yml` dentro del proyecto Compose `mspi-apps`, requiriendo que la infraestructura base (red `mspi-net`, PostgreSQL, Keycloak) esté levantada primero. Patrón esperado de definición del servicio (por analogía directa con `ms_iam`, mismo `docker-compose.apps.yml`):

```yaml
ms-org:
  <<: *mspi-service
  build:
    context: ../../ms_org
    dockerfile: deployment/Dockerfile
  image: mspi/ms-org:dev
  container_name: ms_org
  environment:
    SERVER_PORT: "8083"
  ports:
    - "8083:8083"
  depends_on:
    ms-iam:
      condition: service_healthy
```

`ms_org` depende de `ms_iam` para el flujo de creación/actualización de organización (llamadas salientes a `POST /users` y `POST /users/disable-by-email`), por lo que un arranque razonable del stack local debería garantizar que `ms_iam` esté saludable antes de que `ms_org` reciba tráfico de creación de organizaciones — aunque, a diferencia del arranque *bloqueante* documentado para `ms_iam` respecto a otros servicios, `ms_org` sí puede **arrancar** sin `ms_iam` disponible (no hay verificación de conectividad en el arranque), y solo fallará en tiempo de ejecución al primer `POST /organizations`.

Secuencia de arranque general documentada a nivel de repositorio contenedor:

```bash
docker network create mspi-net                 # una sola vez
cp env-mspi-docker.env.example env-mspi-docker.env   # y completar secretos reales
docker compose -f docker-compose.apps.yml --env-file env-mspi-docker.env up -d --build
```

## 6. Puesta en marcha local (Gradle directo, sin Docker)

```bash
cd ms_org
export MS_IAM_URL=http://localhost:8082
export BASE_URL_LOCATION_API=https://api.countrystatecity.in/v1
export LOCATION_API_KEY=...
export JWT_ISSUER_URI=http://localhost:8080/realms/iam
export CORS_ALLOWED_ORIGINS=http://localhost:4200
export DB_CREDENTIAL='{"DB_HOST":"localhost","DB_PORT":"5432","DB_NAME":"MSPI","DB_USERNAME":"admin","DB_PASSWORD":"admin123"}'
./gradlew.bat :app-service:bootRun
```

Prerrequisitos según `README.md`:

1. **PostgreSQL con esquema `org` ya creado** (DDL de referencia en `applications/app-service/src/main/resources/schema.sql`, pensado originalmente para H2 pero anotado como "Desarrollo local (H2). En otros entornos usar migraciones" — nótese que, pese a este comentario en el propio archivo, el `build.gradle` de `jpa-repository` **no incluye el driver H2**, por lo que en la práctica el esquema debe aplicarse manualmente contra PostgreSQL incluso en desarrollo local, ya que `spring.sql.init.mode: never` impide su ejecución automática).
2. `MS_IAM_URL`, `BASE_URL_LOCATION_API` y `LOCATION_API_KEY` configurados.
3. Keycloak accesible, con un token JWT que incluya el rol `AdminSistema` (para `/organizations/**`) o `Lector` (para `/organizations/my-organization`).

## 7. Resumen de puertos y endpoints técnicos

| Elemento | Valor |
|---|---|
| Puerto HTTP | `8083` (contenedor y `SERVER_PORT` por defecto) |
| Healthcheck | `GET /actuator/health` |
| Info de build | `GET /actuator/info` |
| Nombre de imagen local | `mspi/ms-org:dev` |
| Nombre del contenedor | `ms_org` |
| Nombre del jar | `MsOrg.jar` |
| Esquema de base de datos | `org` (PostgreSQL, sin fallback H2) |
