# Tipos de entidad MSPI y eliminación lógica de catálogo

| Campo | Valor |
|---|---|
| Fecha | 2026-10-11 |
| Alcance | Categorías territoriales oficiales del instrumento + soft-delete de escalas/bancos |

---

## 1. Tipos de entidad MSPI («categorías territoriales»)

En el instrumento oficial de evaluación MSPI, el **tipo de entidad** no es un rótulo libre arbitrario: son las **categorías territoriales oficiales** con las que MinTIC agrupa entidades del orden territorial según su categoría (Ley 617/2000: Especial, 1ª–6ª) y les asigna **metas de avance PHVA distintas**.

Fuente normativa del instrumento:

- [Instructivo del instrumento de evaluación MSPI (MinTIC)](https://gobiernodigital.mintic.gov.co/692/articles-5482_Instructivo_instrumento_Evaluacion_MSPI.pdf)

La tabla exacta que traduce categoría Ley 617 → Territorial A / B / C se toma de ese instructivo (no se inventa en código).

### 1.1 Códigos oficiales en catálogo

Tabla `catalog.entity_order_type`:

| Código | Etiqueta (UI) | Meta avance PHVA (`phva_expected_advance`) | Notas |
|---|---|---|---|
| `NACIONAL` | Nacional | **0.40** (40 %) | Entidades del orden nacional |
| `TERRITORIAL_A` | Territorial A | **0.35** (35 %) | Agrupa categorías Ley 617 según instructivo |
| `TERRITORIAL_B` | Territorial B | **0.30** (30 %) | Idem |
| `TERRITORIAL_C` | Territorial C | **0.25** (25 %) | Idem |
| `OTRA` | Otra | 0.25 (fallback técnico) | **No es categoría oficial MSPI**; exige texto libre |

Pesos oficiales Nacional → Territorial C: **0.40 / 0.35 / 0.30 / 0.25**.

### 1.2 Opción «Otra»

Cuando el evaluador selecciona `OTRA`:

- Debe informar `assessment.entity_type_other` (texto libre obligatorio).
- La publicación de la evaluación (`BORRADOR` → `CERRADA`) falla si falta ese texto.
- UI: paso `/evaluations/:id/entity-order-type` (`EntityOrderTypePageComponent`).

### 1.3 Snapshot en la evaluación

Al asignar el tipo, `ms_assessment` guarda:

- `entity_order_type_code`
- `entity_type_other` (solo relevante si `OTRA`)
- `phva_expected_advance_snapshot` (congelado desde el catálogo)

Así, cambios futuros en metas del catálogo no alteran evaluaciones ya tipadas.

---

## 2. Eliminación lógica de escalas y bancos de preguntas

Mismo patrón que la eliminación de evaluaciones (`assessment_deletion_request`): solicitud → aprobación → periodo de gracia → sweeper que setea `deleted_at`. **No hay borrado físico.**

### 2.1 Regla base vs creado

| Campo | Significado |
|---|---|
| `catalog.scale.is_base` / `catalog.question_bank.is_base` | `true` = elemento **base del instrumento MSPI** (sembrado); `false` = creado por el equipo |
| `deleted_at` | Soft-delete; listados/get filtran `deleted_at IS NULL` |

- Seed: Escala MSPI v1 (`a0000000-…-001`) y cualquier banco/escala base → `is_base = true`.
- Lo creado por AdminInstrumento/AdminSistema → `is_base = false`.
- **Bloqueo duro:** si `is_base = true`, la solicitud de eliminación responde con mensaje humano:  
  *«No se puede eliminar un elemento base del instrumento MSPI.»*
- En UI (`mf_assessment`): la acción «Solicitar eliminación» **solo** aparece si `base === false`.

### 2.2 Tabla `catalog.catalog_deletion_request`

| Campo | Descripción |
|---|---|
| `target_type` | `SCALE` \| `QUESTION_BANK` |
| `target_id` | UUID del elemento |
| `requested_by` | Usuario solicitante |
| `reason` | **Obligatorio** |
| `attachment_file_id` | Opcional → `evidence.evidence_file` (`relationType=CATALOG_DELETE`) |
| `status` | `PENDING` \| `APPROVED` \| `REJECTED` \| `CANCELLED` |
| `scheduled_deletion_at` | Programado al aprobar |
| `decision_by` / `decision_at` / `decision_comment` | Decisión |

Reglas:

- Una sola solicitud `PENDING` (o `APPROVED` en gracia) por target.
- Gracia: `catalogDeletionGraceDays` en config de `ms_iam` (default **5**; si no existe, se reutiliza `assessmentDeletionGraceDays`).
- Sweeper `@Scheduled` (`CatalogDeletionSweeper`): al vencer setea `deleted_at` en scale o question_bank.
- Cancelar durante la gracia = **Recuperar** (anula programación; no borra el historial de la solicitud).

### 2.3 Roles (catálogo global, sin membresía de evaluación)

| Acción | Roles |
|---|---|
| Solicitar | `AdminInstrumento` o `AdminSistema` |
| Aprobar / Rechazar | `AdminSistema` |

### 2.4 API (`ms_catalog`)

| Método | Ruta |
|---|---|
| `POST` | `/catalog/deletion-requests` |
| `POST` | `/catalog/deletion-requests/{id}/approve` |
| `POST` | `/catalog/deletion-requests/{id}/reject` |
| `POST` | `/catalog/deletion-requests/{id}/cancel` |
| `GET` | `/catalog/deletion-requests` (filtros `targetType`/`targetId`/`status`) |
| `GET` | `/catalog/deletion-requests/pending` |

### 2.5 UI (`mf_assessment`)

| Pantalla | Comportamiento |
|---|---|
| `/scales`, `/security-baseline` | Badge de estado; «Solicitar eliminación» solo si no es base; modal Motivo + Adjunto; aviso «Se eliminará el &lt;fecha&gt;» + «Recuperar» en gracia |
| `/catalog/deletion-requests` | Bandeja de aprobación (análoga a `/evaluations/deletion-requests`) |

DDL aditivo para volúmenes existentes: `docker-config/docker/postgres/init/patch-catalog-soft-delete.sql`.

---

*Ver también: eliminación de evaluaciones en `Documentacion-Backend/ms_assessment/04-Desarrollo.md` y flujos en `mf_assessment/docs/FLUJOS.md`.*
