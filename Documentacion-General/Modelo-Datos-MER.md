# Modelo entidad-relación (MER)

Vista del modelo de datos MSPI para la wiki. Fuentes canónicas en este directorio. El diagrama completo es **SVG vectorial** (nítido a cualquier zoom); debajo hay `erDiagram` Mermaid por esquema.

## Diagrama completo (SVG vectorial)

**Contexto.** Vista global generada con `dbml-renderer` desde [`MER-MSPI.dbml`](MER-MSPI.dbml) (esquema real: base + `patch-*.sql` del init Docker). Incluye `iam.password_reset_request`, radicados `request_number` (`SOL-*`) y esquemas `audit` / `admin`.

<object data="MER-MSPI.svg" type="image/svg+xml" width="100%" height="720" style="border:1px solid #e2e8f0;border-radius:8px;background:#fff" title="MER MSPI SVG"></object>

[Descargar MER-MSPI.svg](MER-MSPI.svg) · vectorial (Graphviz / dbml-renderer)

## Fuentes

| Artefacto | Descripción |
|---|---|
| [MER-MSPI.svg](MER-MSPI.svg) | Diagrama visual vectorial |
| [MER-MSPI.sql](MER-MSPI.sql) | DDL consolidado (`pg_dump --schema-only` tras base + patches) |
| [MER-MSPI.dbml](MER-MSPI.dbml) | Fuente dbdiagram / dbdocs |
| [dbdocs.io — MER-MSPI](https://dbdocs.io/jdtovar-2021a/MER-MSPI) | Vista interactiva online |

## Esquemas PostgreSQL

Instancia única particionada (**8**): `iam` · `org` · `catalog` · `assessment` · `evidence` · `reporting` · `audit` · `admin`.

Incluye, entre otros: `iam.password_reset_request` (`SOL-PWD`), columnas `request_number` en solicitudes de eliminación/ampliación (assessment/catalog), y esquemas `audit` / `admin` (extraídos desde `iam.*` vía patches).

Migraciones de extracción (código): `patch-audit-schema.sql` (`iam.audit_log` → `audit.audit_log`), `patch-admin-schema.sql` (`iam.system_config*` → `admin.*`).

---

## Cómo leer los `erDiagram`

| Notación | Significado |
|---|---|
| `\|\|--o{` | Uno a muchos |
| `\|\|--\|\|` | Uno a uno |
| `PK` / `UK` | Clave primaria / única |
| Sin línea entre esquemas | Referencia lógica (UUID sin FK física), p. ej. `audit` → `assessment` |

Los diagramas listan columnas clave (no todas). Fuente de verdad: [`MER-MSPI.sql`](MER-MSPI.sql).

---

## 1. Esquema `iam` (ms_iam :8082)

**Contexto.** Identidad local ligada a Keycloak (`keycloak_sub`), roles, TOTP, notificaciones y solicitudes de reenvío de contraseña (`SOL-PWD`). La bitácora y la config global ya no viven aquí (`audit` / `admin`).

```mermaid
erDiagram
  iam_user ||--o{ iam_user_role : asigna
  iam_role ||--o{ iam_user_role : otorga
  iam_user ||--o| iam_user_totp : "2FA"
  iam_user ||--o{ iam_notification : recibe
  iam_user ||--o{ iam_password_reset_request : "target / requester"

  iam_user {
    uuid id PK
    varchar keycloak_sub UK
    varchar email UK
    uuid organization_id
    boolean must_change_password
    varchar status
  }
  iam_role {
    uuid id PK
    varchar name UK
  }
  iam_user_role {
    uuid user_id PK
    uuid role_id PK
  }
  iam_user_totp {
    varchar keycloak_sub PK
    varchar secret
    timestamptz enabled_at
  }
  iam_notification {
    uuid id PK
    uuid user_id
    boolean is_read
    timestamptz read_at
    timestamptz cleared_at
  }
  iam_password_reset_request {
    uuid id PK
    uuid target_user_id
    varchar request_number UK
    uuid requested_by
    varchar status
    boolean email_sent
  }
```

---

## 2. Esquema `org` (ms_org :8083)

**Contexto.** Maestro de entidades evaluadas, contactos y plantillas de áreas/temas reutilizables al crear evaluaciones.

```mermaid
erDiagram
  org_organization ||--o{ org_organization_contact : tiene
  org_organization ||--o{ org_organization_area_base : plantilla
  org_organization_area_base ||--o{ org_organization_area_base_topic : temas

  org_organization {
    uuid id PK
    varchar name
    varchar identifier
    varchar type
    varchar status
  }
  org_organization_contact {
    uuid id PK
    uuid organization_id FK
    boolean is_primary
  }
  org_organization_area_base {
    uuid id PK
    uuid organization_id FK
    varchar area_name
  }
  org_organization_area_base_topic {
    uuid id PK
    uuid area_base_id FK
    varchar topic
  }
```

---

## 3. Esquema `catalog` (ms_catalog :8085)

**Contexto.** Instrumento versionado (plantilla, escalas, bancos, Anexo A, PHVA, madurez, NIST) y soft-delete de escalas/bancos con radicado `SOL-CAT`.

```mermaid
erDiagram
  catalog_template ||--o{ catalog_template_version : versiona
  catalog_scale ||--o{ catalog_scale_version : versiona
  catalog_template_version ||--o{ catalog_control_catalog_node : snapshot
  catalog_control_catalog_node ||--o| catalog_control_rule : reglas
  catalog_scale ||--o{ catalog_deletion_request : "target SCALE"
  catalog_question_bank ||--o{ catalog_deletion_request : "target BANK"

  catalog_template {
    uuid id PK
    varchar name UK
  }
  catalog_template_version {
    uuid id PK
    uuid template_id FK
    varchar status
  }
  catalog_scale {
    uuid id PK
    boolean is_base
    timestamptz deleted_at
  }
  catalog_question_bank {
    uuid id PK
    boolean is_base
    timestamptz deleted_at
  }
  catalog_control_catalog_node {
    uuid id PK
    uuid template_version_id FK
    varchar node_type
    varchar code
  }
  catalog_control_rule {
    uuid control_node_id PK
  }
  catalog_deletion_request {
    uuid id PK
    varchar target_type
    uuid target_id
    varchar request_number UK
    varchar status
    timestamptz scheduled_deletion_at
  }
  catalog_entity_order_type {
    varchar code PK
    varchar label
  }
```

---

## 4. Esquema `assessment` (ms_assessment :8084)

**Contexto.** Ejecución del instrumento: evaluación, miembros, respuestas, gaps, locks, ampliación (`SOL-AMPL`) y eliminación lógica (`SOL-ELIM`) con gracia.

```mermaid
erDiagram
  assessment ||--o{ assessment_member : equipo
  assessment ||--o{ assessment_control_node : arbol
  assessment ||--o{ assessment_deletion_request : elimina
  assessment ||--o{ assessment_extension_request : amplía
  assessment ||--o| assessment_edit_lock : bloqueo
  assessment_control_node ||--o| control_response : respuesta
  assessment ||--o{ gap_register : brechas

  assessment {
    uuid id PK
    uuid organization_id
    uuid template_version_id
    date due_date
    varchar priority
    varchar status
    timestamptz deleted_at
  }
  assessment_member {
    uuid id PK
    uuid assessment_id FK
    uuid user_id
    boolean is_leader
  }
  assessment_control_node {
    uuid id PK
    uuid assessment_id FK
    varchar node_type
    varchar code
  }
  control_response {
    uuid assessment_control_node_id PK
    numeric score
  }
  assessment_deletion_request {
    uuid id PK
    uuid assessment_id FK
    varchar request_number UK
    varchar status
    timestamptz scheduled_deletion_at
  }
  assessment_extension_request {
    uuid id PK
    uuid assessment_id FK
    varchar request_number UK
    int days
    varchar status
  }
  assessment_edit_lock {
    uuid assessment_id PK
    uuid locked_by_user_id
  }
  gap_register {
    uuid id PK
    uuid assessment_id FK
    varchar priority
  }
```

---

## 5. Esquema `evidence` (ms_evidence :8086)

**Contexto.** Archivos de evidencia (objeto en storage), contexto de evaluación y entregables de levantamiento documental.

```mermaid
erDiagram
  evidence_file ||--o{ lifting_document_delivery : adjunta
  assessment_context ||--o{ lifting_answer : responde

  evidence_file {
    uuid id PK
    uuid assessment_id
    varchar relation_type
    uuid relation_id
    varchar filename
    varchar sha256
    varchar storage_key
  }
  assessment_context {
    uuid id PK
    uuid assessment_id
  }
  lifting_document_delivery {
    uuid id PK
    uuid evidence_file_id FK
    varchar status
  }
  lifting_answer {
    uuid id PK
    uuid assessment_context_id
  }
  process_scope_metric {
    uuid id PK
    uuid assessment_id
  }
```

---

## 6. Esquema `reporting` (ms_reporting :8087)

**Contexto.** Plantillas de informe, jobs de generación (Excel/PDF) y caché analítica.

```mermaid
erDiagram
  report_template ||--o{ report_generation_job : usa
  report_generation_job ||--o{ report_job_assessment : incluye
  excel_workbook_template ||--o{ excel_sheet_mapping : hojas

  report_template {
    uuid id PK
    varchar code
    varchar output_format
  }
  report_generation_job {
    uuid id PK
    uuid organization_id
    uuid template_id
    varchar status
  }
  report_job_assessment {
    uuid job_id PK
    uuid assessment_id PK
  }
  excel_workbook_template {
    uuid id PK
    varchar code
  }
  excel_sheet_mapping {
    uuid id PK
    uuid workbook_template_id FK
  }
  analytics_cache {
    uuid id PK
    varchar cache_key UK
  }
```

---

## 7. Esquema `audit` (ms_audit :8088)

**Contexto.** Bitácora central append-only. `assessment_id` y `actor_user_id` son UUID **sin FK** (desacople). Los radicados se correlacionan en `metadata_json.requestNumber`.

```mermaid
erDiagram
  audit_log {
    bigserial id PK
    varchar event_type
    varchar entity_type
    varchar entity_id
    uuid assessment_id
    uuid actor_user_id
    timestamptz occurred_at
    jsonb metadata_json
  }
```

---

## 8. Esquema `admin` (ms_admin :8089)

**Contexto.** Configuración global versionada (plazos, gracia, MIME, etc.). `updated_by` / `changed_by` son UUID **sin FK** a `iam.user`.

```mermaid
erDiagram
  admin_system_config ||--o{ admin_system_config_history : historial

  admin_system_config {
    varchar key PK
    jsonb value_json
    int version
    uuid updated_by
    timestamptz updated_at
  }
  admin_system_config_history {
    bigserial id PK
    varchar key
    int version
    jsonb value_json
    uuid changed_by
  }
```
