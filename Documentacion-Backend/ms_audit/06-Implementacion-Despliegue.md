# ms_audit — Implementación y Despliegue

| Campo | Valor |
|---|---|
| Repositorio | `MSPI_NVA_CO_MR_BACK/ms_audit` |
| Fecha del documento | 2026-08-18 |
| Alcance | Estado real de build, contenerización, variables de entorno, CI/CD e infraestructura de `ms_audit`, y el contexto de despliegue del sistema MSPI del que carece |

---

## 1. Estado de build

`ms_audit` **no tiene ningún artefacto de build**. No existe:

- `build.gradle`, `settings.gradle`, `pom.xml`, `package.json` ni ningún manifiesto de dependencias.
- Código fuente compilable en ningún lenguaje.
- Un `gradlew`/`gradlew.bat` propio (los demás microservicios del monorepo sí lo incluyen).

No hay, por tanto, un comando de build (`./gradlew build`, `mvn package`, `npm run build`) que documentar para este repositorio.

## 2. Estado de contenerización

`ms_audit` **no tiene `Dockerfile`**. No hay carpeta `deployment/` (presente en `ms_iam` y otros microservicios del monorepo con `deployment/Dockerfile`), ni ninguna imagen Docker construible desde este repositorio.

### 2.1 Confirmación en la orquestación del sistema

`docker-config/docker/docker-compose.apps.yml`, que orquesta todos los microservicios del sistema MSPI para entorno local, **no declara ningún servicio `ms-audit`**. Los servicios efectivamente definidos son:

```
ms-iam        → puerto 8082
ms-org        → puerto 8083 (depends_on ms-iam)
ms-catalog    → puerto 8085
ms-evidence   → (según compose)
ms-assessment → puerto 8084 (depends_on ms-iam, ms-org, ms-catalog, ms-evidence)
ms-reporting  → (según compose)
ms-admin      → (según compose)
```

No aparece `ms-audit` en ningún punto del archivo, ni como servicio propio ni como dependencia (`depends_on`) de otro servicio. Esto confirma, desde la infraestructura declarativa, lo mismo que confirma el código fuente: **`ms_audit` no está desplegado ni es desplegable hoy**.

## 3. Variables de entorno

No hay variables de entorno propias de `ms_audit` porque no hay aplicación que las consuma. Las variables relevantes al **flujo de auditoría actual**, verificadas en `ms_iam` y `ms_assessment`, y que un futuro `ms_audit` tendría que reemplazar o extender, son:

| Variable | Microservicio | Uso actual | Rol en la migración futura |
|---|---|---|---|
| `MS_IAM_URL` | `ms_assessment` | URL base del cliente REST hacia `ms_iam` (default `http://localhost:8082`) | Se reemplazaría por `MS_AUDIT_URL` en el paso 4 del plan de migración (`MIGRATION-NOTES.md`) |
| `INTERNAL_API_KEY` | `ms_assessment` (productor) y `ms_iam` (consumidor, `app.internal-api-key`) | Clave compartida para autenticar `POST /internal/audit/events` | Debería reutilizarse o re-emitirse de forma equivalente para `ms_audit` |
| `SERVER_PORT` | Todos los microservicios (vía `docker-compose.apps.yml`) | Puerto de escucha del contenedor | `ms_audit` necesitaría un puerto propio no colisionante con los ya asignados (8082–8087 aprox., según el compose) |

## 4. CI/CD

No existe ningún archivo de pipeline (`bitbucket-pipelines.yml`, `.github/workflows/*`, `Jenkinsfile`, `azure-pipelines.yml`) dentro de `ms_audit/`. A modo de contraste, `ms_iam` sí tiene `bitbucket-pipelines.yml` con despliegue a Railway (ver `06-Implementacion-Despliegue.md` del piloto `ms_iam`). `ms_audit` no participa de ningún flujo de integración o despliegue continuo porque no hay nada que integrar o desplegar.

## 5. Infraestructura del sistema MSPI (contexto, sin participación de ms_audit)

Para contextualizar dónde encajaría `ms_audit` si se implementara, la infraestructura local del sistema (`docker-config/`) incluye:

- **Docker Compose** (`docker-config/docker/docker-compose.apps.yml`) para orquestar los microservicios backend.
- **Keycloak** como Identity Provider, con scripts de configuración (`docker-config/docker/keycloak/scripts/setup-keycloak.ps1`).
- **PostgreSQL** como base de datos compartida (particionada por esquema: `iam`, `org`, `catalog`, `evidence`, `assessment`, y `audit` reservado para el futuro).
- Documentación operativa en `docker-config/docs/docker/DEPLOY-DOCKER.md` y `docker-config/docs/local/README.md`.

Ninguno de estos artefactos referencia a `ms_audit`. El esquema `audit` en PostgreSQL, mencionado como reservado en `docs/proyecto/DB-MER.txt`, **no tiene un script `CREATE SCHEMA audit` ni tablas creadas** en ninguno de los scripts SQL revisados (`docker-config/docs/backend/MER-SEED-LINEA-BASE.sql`, `ms_iam/applications/app-service/src/main/resources/schema-iam-mvp.sql`); solo existe como comentario/nota de diseño en el MER.

## 6. Pasos de "despliegue" planificados (documentales, del plan de migración)

Estos son los únicos pasos con relación a la puesta en producción de `ms_audit` que existen como documentación, extraídos de `docs/MIGRATION-NOTES.md`:

1. Implementar la ingesta equivalente (mismo contrato HTTP o versión v2) — implica, como mínimo, crear el proyecto base (build, Dockerfile, entrada en `docker-compose.apps.yml`), inexistente hoy.
2. Configurar el periodo de *dual-write*: los productores (`ms_assessment`) escribirían simultáneamente a `ms_iam` y a `ms_audit`, o se activaría mediante un *feature flag* no especificado (nombre de variable, mecanismo).
3. Ejecutar el *backfill* histórico desde `iam.audit_log`, lo cual requeriría un script de migración de datos (no existente) que resuelva la referencia `actor_user_id → iam."user"(id)` documentada en `03-Diseno.md`.
4. Reconfigurar `MS_IAM_URL` a `MS_AUDIT_URL` (y variables equivalentes) en todos los productores.
5. Deprecar y eventualmente retirar `POST /internal/audit/events` de `ms_iam`.

Ninguno de estos pasos tiene fecha, responsable ni entorno objetivo (desarrollo/staging/producción) asignado en la documentación disponible.

## 7. Conclusión

En términos de implementación y despliegue, `ms_audit` se encuentra en **estado pre-proyecto**: no hay build, no hay imagen de contenedor, no hay variables de entorno propias, no hay pipeline de CI/CD y no hay presencia en la orquestación de infraestructura del sistema MSPI. Toda actividad de despliegue relacionada con auditoría ocurre hoy como parte del despliegue de `ms_iam`.
