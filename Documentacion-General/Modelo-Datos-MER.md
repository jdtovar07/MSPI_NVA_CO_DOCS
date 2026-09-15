# Modelo entidad-relación (MER)

Vista del modelo de datos MSPI para la wiki. Fuentes canónicas en este directorio.

## Diagrama (PDF)

<iframe src="MER-MSPI.pdf" width="100%" height="720" style="border:1px solid #e2e8f0;border-radius:8px;" title="MER MSPI PDF"></iframe>

[Descargar MER-MSPI.pdf](MER-MSPI.pdf) · diagrama regenerado desde el DBML consolidado

## Fuentes

| Artefacto | Descripción |
|---|---|
| [MER-MSPI.pdf](MER-MSPI.pdf) | Diagrama visual (dbml-renderer → PDF) |
| [MER-MSPI.sql](MER-MSPI.sql) | DDL consolidado (`pg_dump --schema-only` tras base + `patch-*.sql`) |
| [MER-MSPI.dbml](MER-MSPI.dbml) | Fuente dbdiagram / dbdocs |
| [dbdocs.io — MER-MSPI](https://dbdocs.io/jdtovar-2021a/MER-MSPI) | Vista interactiva online |

## Esquemas PostgreSQL

Instancia única particionada (**8**): `iam` · `org` · `catalog` · `assessment` · `evidence` · `reporting` · `audit` · `admin`.

Incluye, entre otros: `iam.password_reset_request` (`SOL-PWD`), columnas `request_number` en solicitudes de eliminación/ampliación (assessment/catalog), y esquemas `audit` / `admin` (extraídos desde `iam.*` vía patches).

Migraciones de extracción (código): `patch-audit-schema.sql` (`iam.audit_log` → `audit.audit_log`), `patch-admin-schema.sql` (`iam.system_config*` → `admin.*`).
