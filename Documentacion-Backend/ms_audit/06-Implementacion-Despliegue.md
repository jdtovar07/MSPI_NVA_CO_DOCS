# ms_audit — Implementación y Despliegue

| Campo | Valor |
|---|---|
| Repositorio | `MSPI_NVA_CO_MR_BACK/ms_audit` |
| Estado | Activo |
| Alcance | Build, Docker, variables de entorno, Compose y esquema PostgreSQL de `ms_audit` |

---

## 1. Build local

Desde `MSPI_NVA_CO_MR_BACK/ms_audit/`:

```bash
./gradlew :app-service:compileJava
./gradlew test
./gradlew :app-service:bootJar -x test --no-daemon
./gradlew :app-service:bootRun
```

Root project: `MsAudit` (`settings.gradle`). Artefacto fat-jar generado por módulo `:app-service`.

## 2. Dockerfile

Archivo: `ms_audit/deployment/Dockerfile`

- Multi-stage: `eclipse-temurin:21-jdk-alpine` (build) → `eclipse-temurin:21-jre-alpine` (runtime).
- Build: `./gradlew :app-service:bootJar -x test --no-daemon`.
- Runtime: usuario `mspi` vía `su-exec`; `EXPOSE 8088`; `SERVER_PORT=8088`.
- `HEALTHCHECK`: `wget` → `http://127.0.0.1:${SERVER_PORT}/actuator/health` (interval 30s, start-period 90s).
- Imagen Compose: `mspi/ms-audit:dev`.

## 3. Docker Compose

Archivo: `docker-config/docker/docker-compose.apps.yml`

| Campo | Valor |
|---|---|
| Servicio | `ms-audit` |
| `container_name` | `ms_audit` |
| Imagen | `mspi/ms-audit:dev` |
| Context build | `../../ms_audit` |
| Dockerfile | `deployment/Dockerfile` |
| Puerto host:contenedor | `8088:8088` |
| `SERVER_PORT` | `"8088"` |

Consumidores en red Compose usan `MS_AUDIT_URL=http://ms-audit:8088` (`docker-config/docker/env-mspi-docker.env`).

## 4. Variables de entorno

| Variable | Obligatoria | Descripción | Default / nota |
|---|---|---|---|
| `SERVER_PORT` | No | Puerto HTTP | `8088` |
| `INTERNAL_API_KEY` | Sí (S2S) | Clave compartida header `X-Internal-Api-Key` | Vacía → rutas internas no operativas / 503 según filtro |
| `CORS_ALLOWED_ORIGINS` | Sí (frontend) | Orígenes CORS separados por coma | `cors.allowed-origins` sin default en YAML |
| `JWT_ISSUER_URI` | Sí (prod) | Issuer Keycloak realm `iam` | Valor Railway por defecto en YAML |
| `JWT_JWK_SET_URI` | No | JWK Set alterno | `""` |
| `DB_CREDENTIAL` | **Sí** | JSON Infisical (`DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USERNAME`, `DB_PASSWORD`) | Sin fallback H2 |
| `MS_ASSESSMENT_URL` | No | Cliente outbound trail | `http://localhost:8084` |
| `MS_CATALOG_URL` | No | Cliente outbound trail | `http://localhost:8085` |
| `MS_IAM_URL` | No | Cliente outbound trail | `http://localhost:8082` |
| Infisical (`INFISICAL_*`) | Prod | Carga de secretos | `InfisicalConfig` |

En productores: `MS_AUDIT_URL` (local `http://localhost:8088`, Docker `http://ms-audit:8088`).

## 5. Base de datos

- Esquema: `audit` (tabla `audit.audit_log`).
- Migración: `docker-config/docker/postgres/init/patch-audit-schema.sql` (idempotente; migra desde `iam.audit_log` si existe).
- La aplicación **no** aplica DDL (`spring.sql.init.mode: never`, `hibernate.ddl-auto: none`).

## 6. Checklist de despliegue

1. Aplicar `patch-audit-schema.sql` sobre PostgreSQL.
2. Definir `DB_CREDENTIAL`, `INTERNAL_API_KEY`, `JWT_ISSUER_URI`, `CORS_ALLOWED_ORIGINS`.
3. Alinear `INTERNAL_API_KEY` con `ms_iam`, `ms_assessment`, `ms_catalog`.
4. Configurar `MS_AUDIT_URL` en productores.
5. Levantar servicio Compose `ms-audit` (o Railway/equivalente) y verificar `/actuator/health`.
6. Probar `POST /internal/audit/events` (202) y `GET /audit/events` con JWT AdminSistema.

### Pruebas en CI

El pipeline de Bitbucket ejecuta `./gradlew clean test jacocoTestReport assemble` y publica XML de resultados y reportes JaCoCo. Detalle de cobertura: `05-Pruebas.md`.
