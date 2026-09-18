# ms_admin — Implementación y Despliegue

| Campo | Valor |
|---|---|
| Repositorio | `MSPI_NVA_CO_MR_BACK/ms_admin` |
| Estado | Activo |
| Alcance | Build, Docker, variables de entorno, Compose y esquema PostgreSQL de `ms_admin` |

---

## 1. Build local

Desde `MSPI_NVA_CO_MR_BACK/ms_admin/`:

```bash
./gradlew :app-service:compileJava
./gradlew test
./gradlew :app-service:bootJar -x test --no-daemon
./gradlew :app-service:bootRun
```

Root project: `MsAdmin` (`settings.gradle`).

## 2. Dockerfile

Archivo: `ms_admin/deployment/Dockerfile`

- Multi-stage Temurin 21 Alpine (JDK build → JRE runtime).
- `./gradlew :app-service:bootJar -x test --no-daemon`.
- Usuario `mspi` + `su-exec`; `EXPOSE 8089`; `SERVER_PORT=8089`.
- `HEALTHCHECK` contra `/actuator/health` (30s / start-period 90s).
- Imagen Compose: `mspi/ms-admin:dev`.

## 3. Docker Compose

Archivo: `docker-config/docker/docker-compose.apps.yml`

| Campo | Valor |
|---|---|
| Servicio | `ms-admin` |
| `container_name` | `ms_admin` |
| Imagen | `mspi/ms-admin:dev` |
| Context | `../../ms_admin` |
| Dockerfile | `deployment/Dockerfile` |
| Puertos | `8089:8089` |
| `SERVER_PORT` | `"8089"` |

En red Docker: `MS_ADMIN_URL=http://ms-admin:8089` (`docker-config/docker/env-mspi-docker.env`).

## 4. Variables de entorno

| Variable | Obligatoria | Descripción | Default / nota |
|---|---|---|---|
| `SERVER_PORT` | No | Puerto HTTP | `8089` |
| `INTERNAL_API_KEY` | Sí (S2S) | Header `X-Internal-Api-Key` | Compartida con assessment/catalog |
| `CORS_ALLOWED_ORIGINS` | Sí (frontend) | Orígenes CORS | Sin default en YAML |
| `JWT_ISSUER_URI` | Sí (prod) | Issuer Keycloak `iam` | Default Railway en YAML |
| `JWT_JWK_SET_URI` | No | JWK Set | `""` |
| `DB_CREDENTIAL` | **Sí** | JSON conexión PostgreSQL (Infisical) | Sin fallback H2 |
| Infisical (`INFISICAL_*`) | Prod | Carga de secretos | `InfisicalConfig` |

Consumidores:

- `MS_ADMIN_URL` (local `http://localhost:8089`, Docker `http://ms-admin:8089`).
- Frontend: `msAdminUrl` en `mf_shell`.

## 5. Base de datos

- Esquemas/tablas: `admin.system_config`, `admin.system_config_history`.
- Migración: `docker-config/docker/postgres/init/patch-admin-schema.sql` (idempotente; migra desde `iam.*` si aplica).
- App sin DDL automático.

## 6. Checklist de despliegue

1. Aplicar `patch-admin-schema.sql`.
2. Definir `DB_CREDENTIAL`, `INTERNAL_API_KEY`, `JWT_ISSUER_URI`, `CORS_ALLOWED_ORIGINS`.
3. Alinear API key con `ms_assessment` y `ms_catalog`.
4. Configurar `MS_ADMIN_URL` / `msAdminUrl`.
5. Levantar servicio `ms-admin` y verificar `/actuator/health`.
6. Probar `GET/PUT /system/config` (AdminSistema) y `GET /internal/system/config` (API key).

### Pruebas en CI

El pipeline de Bitbucket ejecuta `./gradlew clean test jacocoTestReport assemble` y publica XML de resultados y reportes JaCoCo. Detalle de cobertura: `05-Pruebas.md`.
