# Modelo entidad-relación (MER)

Vista del modelo de datos MSPI para la wiki. Fuentes canónicas en este directorio.

## Diagrama (PDF)

<iframe src="MER-MSPI.pdf" width="100%" height="720" style="border:1px solid #e2e8f0;border-radius:8px;" title="MER MSPI PDF"></iframe>

[Descargar MER-MSPI.pdf](MER-MSPI.pdf) · tamaño ~2.5 MB

## Fuentes

| Artefacto | Descripción |
|---|---|
| [MER-MSPI.pdf](MER-MSPI.pdf) | Diagrama visual exportado |
| [MER-MSPI.sql](MER-MSPI.sql) | DDL / referencia SQL |
| [MER-MSPI.dbml](MER-MSPI.dbml) | Fuente dbdiagram / dbdocs |
| [dbdocs.io — MER-MSPI](https://dbdocs.io/jdtovar-2021a/MER-MSPI) | Vista interactiva online |

## Esquemas PostgreSQL

Instancia única particionada (**8**): `iam` · `org` · `catalog` · `assessment` · `evidence` · `reporting` · `audit` · `admin`.

Migraciones de extracción (código): `patch-audit-schema.sql` (`iam.audit_log` → `audit.audit_log`), `patch-admin-schema.sql` (`iam.system_config*` → `admin.*`). Última revisión cruzada con código: **2026-10-19**.

!!! todo "Diagrama SVG/PNG embebido"
    Si el PDF no se renderiza en el visor del navegador embebido, usar el enlace de descarga o regenerar una imagen PNG desde el `.dbml` y sustituir el iframe. El PDF histórico puede aún mostrar tablas bajo `iam.*`; la fuente SQL/dbml de este repo ya refleja `audit`/`admin`.
