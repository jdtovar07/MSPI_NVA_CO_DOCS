-- MER-MSPI.sql
-- Esquema PostgreSQL consolidado (8 esquemas activos): iam, org, catalog, assessment,
-- evidence, reporting, audit, admin.
-- Fuente: MER base + patch-*.sql de MSPI_NVA_CO_MR_BACK/docker-config/docker/postgres/init/
-- Generado con pg_dump --schema-only tras aplicar todos los parches idempotentes.
-- Sin datos de seed; solo DDL (schemas, tables, sequences, indexes, FK, comments).

CREATE SCHEMA admin;

CREATE SCHEMA assessment;

CREATE SCHEMA audit;

CREATE SCHEMA catalog;

CREATE SCHEMA evidence;

CREATE SCHEMA iam;

CREATE SCHEMA org;

CREATE SCHEMA reporting;

CREATE TABLE admin.system_config (
    key character varying(120) NOT NULL,
    value_json jsonb NOT NULL,
    version integer DEFAULT 1 NOT NULL,
    updated_by uuid,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);

COMMENT ON TABLE admin.system_config IS 'Configuración global (ms_admin :8089). updated_by UUID sin FK.';

COMMENT ON COLUMN admin.system_config.key IS 'Claves relevantes Módulo 1:
- evidence.allowedMimeTypes → ["application/pdf","application/vnd.openxmlformats-officedocument.wordprocessingml.document","image/png","image/jpeg"]
- evidence.maxFileSizeBytes
- assessment.autosaveIntervalSeconds
';

CREATE TABLE admin.system_config_history (
    id bigint NOT NULL,
    key character varying(120) NOT NULL,
    version integer NOT NULL,
    value_json jsonb NOT NULL,
    changed_by uuid,
    changed_at timestamp with time zone DEFAULT now() NOT NULL,
    summary character varying(500)
);

COMMENT ON TABLE admin.system_config_history IS 'Historial de configuración global; changed_by UUID sin FK.';

CREATE SEQUENCE admin.system_config_history_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE admin.system_config_history_id_seq OWNED BY admin.system_config_history.id;

CREATE TABLE assessment.assessment (
    id uuid NOT NULL,
    organization_id uuid NOT NULL,
    template_version_id uuid NOT NULL,
    name character varying(220) NOT NULL,
    organization_name_snapshot character varying(220) NOT NULL,
    evaluation_date date NOT NULL,
    due_date date,
    period_label character varying(120),
    contact character varying(254),
    evaluator_display_name character varying(200) NOT NULL,
    prepared_by character varying(200),
    auditor_id uuid,
    auditor_display_name character varying(200),
    created_by uuid NOT NULL,
    entity_order_type_code character varying(20),
    entity_type_other character varying(220),
    phva_expected_advance_snapshot numeric(5,4),
    status character varying(30) DEFAULT 'BORRADOR'::character varying NOT NULL,
    status_changed_at timestamp with time zone,
    status_changed_by uuid,
    published_at timestamp with time zone,
    published_by uuid,
    cloned_from_assessment_id uuid,
    priority character varying(10) DEFAULT 'Media'::character varying NOT NULL,
    row_version integer DEFAULT 0 NOT NULL,
    last_saved_at timestamp with time zone,
    deleted_at timestamp with time zone,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

COMMENT ON TABLE assessment.assessment IS 'INICIALIZACIÓN OBLIGATORIA al crear (HU-CFG-01 criterio 2 — levantamiento vacío):
1. assessment (status=BORRADOR, snapshots de org y evaluador).
2. assessment_member (created_by como EVALUATOR, is_leader=true).
3. evidence.assessment_context (fila vacía, todos los textos NULL).
4. evidence.process_scope_metric (total=0, in_scope=0, coverage=NULL).
5. evidence.lifting_document_delivery × 43 (delivery_status=NOT_DELIVERED, sin archivos).
6. assessment_control_node + control_response por cada control hoja del template
   (score_status=PENDING, score_value=NULL — sin calificar; el progreso arranca en 0%).
7. assessment_phva_item por cada fila de catalog.phva_item_catalog del template
   (snapshot código, componente, scoring_mode, inherit_rule, origen).
8. phva_item_response solo para ítems scoring_mode=MANUAL
   (score_status=SCORED, score_value=0 — "requisitos PHVA manuales en cero").
9. assessment_maturity_requirement por cada fila de catalog.maturity_requirement_catalog
   (snapshot código, origen, scoring_mode, inherit_rule, referencias origen).
10. assessment_maturity_threshold por cada maturity_threshold del catálogo del template
    (copia level, is_na, expected_value — congela umbrales al crear evaluación).
11. assessment_maturity_requirement_response solo para scoring_mode=MANUAL
    (score_status=SCORED, score_value=0 — R5, R9, R10 en cero).
12. assessment_nist_ciber_item por cada fila de catalog.nist_ciber_item_catalog del template
    (snapshot función, subcategoría, scoring_mode, origen, iso_control_code, position).
13. nist_ciber_item_response solo para scoring_mode=MANUAL
    (score_status=SCORED, score_value=0 — requisitos NIST puros en cero).
Clonación (HU-CFG-01): copiar snapshots 7–13 + respuestas MANUAL/PHVA/Madurez/Ciber del origen.
Relaciones 1:1: assessment_context, process_scope_metric.
Varias evaluaciones por organization_id permitidas (regla de negocio HU-CFG-01).
';

COMMENT ON COLUMN assessment.assessment.organization_id IS 'Entidad evaluada. Validar en ms_org al crear.';

COMMENT ON COLUMN assessment.assessment.template_version_id IS 'Versión del instrumento MSPI aplicada.';

COMMENT ON COLUMN assessment.assessment.name IS 'Título de la evaluación (ej. ''MSPI 2026 - Entidad X'')';

COMMENT ON COLUMN assessment.assessment.organization_name_snapshot IS 'Copia de org.name al crear. Cabecera en todas las pantallas.';

COMMENT ON COLUMN assessment.assessment.evaluation_date IS 'Fecha de evaluación diligenciada por el evaluador (HU-CFG-01 criterio 1).';

COMMENT ON COLUMN assessment.assessment.due_date IS 'Fecha límite de la evaluación (created_at + assessmentDueDays); se amplía al aprobar una solicitud de ampliación.';

COMMENT ON COLUMN assessment.assessment.period_label IS 'Período de la evaluación ej. ''2025-Q1'', ''Vigencia 2026'' (HU-CFG-01: vinculada a entidad y período).';

COMMENT ON COLUMN assessment.assessment.contact IS 'Contacto de la entidad para esta evaluación (HU-CFG-01 criterio 1).';

COMMENT ON COLUMN assessment.assessment.evaluator_display_name IS 'Snapshot del nombre del evaluador líder al crear.';

COMMENT ON COLUMN assessment.assessment.created_by IS 'Evaluador que creó la evaluación (FK usuario).';

COMMENT ON COLUMN assessment.assessment.entity_order_type_code IS 'NACIONAL|TERRITORIAL_A|TERRITORIAL_B|TERRITORIAL_C|OTRA';

COMMENT ON COLUMN assessment.assessment.entity_type_other IS 'Texto libre obligatorio cuando entity_order_type_code = OTRA.';

COMMENT ON COLUMN assessment.assessment.phva_expected_advance_snapshot IS 'Copia de catalog.entity_order_type.phva_expected_advance al asignar/cambiar tipo.';

COMMENT ON COLUMN assessment.assessment.status IS 'BORRADOR | EN_DILIGENCIAMIENTO → editable (autoguardado)
EN_REVISION → revisión (módulos posteriores)
CERRADA → publicada, solo lectura (HU-CFG-01). Clonable.
';

COMMENT ON COLUMN assessment.assessment.published_at IS 'Momento de publicación (status=CERRADA).';

COMMENT ON COLUMN assessment.assessment.cloned_from_assessment_id IS 'Origen si esta evaluación se creó por clonación (HU-CFG-01).';

COMMENT ON COLUMN assessment.assessment.priority IS 'Prioridad operativa: Alta | Media | Baja';

COMMENT ON COLUMN assessment.assessment.row_version IS 'Bloqueo optimista. Incrementar en cada PATCH; 409 si no coincide.';

COMMENT ON COLUMN assessment.assessment.last_saved_at IS 'Último autoguardado exitoso.';

COMMENT ON COLUMN assessment.assessment.deleted_at IS 'Borrado lógico: momento en que la evaluación fue eliminada tras aprobarse la solicitud y vencer el periodo de gracia. NULL = activa.';

CREATE TABLE assessment.assessment_area (
    id uuid NOT NULL,
    assessment_id uuid NOT NULL,
    area_preset_code character varying(40),
    area_name character varying(160) NOT NULL,
    description character varying(400),
    "position" integer DEFAULT 0 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

COMMENT ON TABLE assessment.assessment_area IS 'Una fila por área institucional de la evaluación. UI lista las 8 áreas Excel vía preset + permite temas hijos assessment_area_topic.
';

COMMENT ON COLUMN assessment.assessment_area.area_preset_code IS 'NULL si área manual o legado; recomendado llenar al crear desde preset.';

CREATE TABLE assessment.assessment_area_topic (
    id uuid NOT NULL,
    area_id uuid NOT NULL,
    topic character varying(220) NOT NULL,
    process_description character varying(400),
    default_steward_role_code character varying(60),
    staff_name character varying(200),
    staff_role character varying(160),
    staff_contact character varying(200),
    notes character varying(700),
    "position" integer DEFAULT 0 NOT NULL
);

COMMENT ON TABLE assessment.assessment_area_topic IS 'Propagación (HU-AR-01 #21): al guardar, ms_assessment recalcula la persona efectiva en control_response
donde steward_source=FROM_AREA, assessment_id coincide y assessment_control_node.default_steward_role_code
igual a topic.default_steward_role_code (no NULL).
Ambigüedad (varias filas mismo código dentro de la evaluación): elegir determinísticamente, p. ej. mayor position
o updated_at más reciente; documentar regla única en app.
No persiste en control_response hasta M3 cuando existan filas assessment_control_node; puede materializarse
en tiempo de lectura (join) antes de ese snapshot si se desea MVP solo áreas (#18-20).
';

COMMENT ON COLUMN assessment.assessment_area_topic.process_description IS 'HU-AR-01 criterio 20: proceso a cargo del líder de proceso.';

COMMENT ON COLUMN assessment.assessment_area_topic.default_steward_role_code IS 'Si NULL, la fila es solo texto/tema sin participar en propagación masiva (#21).
Área "Líderes de proceso": varias filas mismo code LIDER_PROCESO con distinto process_description.
';

COMMENT ON COLUMN assessment.assessment_area_topic.staff_role IS 'Cargo texto captura (opcional diferencia respecto steward_role.label).';

COMMENT ON COLUMN assessment.assessment_area_topic."position" IS 'Orden dentro del área; desempate al propagar si varias filas mismos default_steward_role_code.';

CREATE TABLE assessment.assessment_control_node (
    id uuid NOT NULL,
    assessment_id uuid NOT NULL,
    source_catalog_node_id uuid NOT NULL,
    parent_id uuid,
    "position" integer NOT NULL,
    node_type character varying(20) NOT NULL,
    control_type character varying(10),
    code character varying(40),
    iso_code character varying(40),
    title character varying(300) NOT NULL,
    description text,
    test_guidance text,
    iso_domain_code character varying(20),
    mspi_tag character varying(120),
    ciber_tag character varying(120),
    is_scored boolean DEFAULT false NOT NULL,
    rules_json jsonb,
    default_steward_role_code character varying(60)
);

COMMENT ON COLUMN assessment.assessment_control_node.node_type IS 'DOMAIN | OBJECTIVE | SUB_OBJECTIVE | CONTROL (snapshot desde catálogo).';

COMMENT ON COLUMN assessment.assessment_control_node.control_type IS 'ADMIN | TECH — HU-TEC-01 filtra rama técnica en API.';

COMMENT ON COLUMN assessment.assessment_control_node.iso_code IS 'HU-ADM-01 / HU-TEC-01 / HU-ADM-04: snapshot ISO 27001:2013 desde catalog.control_catalog_node.iso_code.';

COMMENT ON COLUMN assessment.assessment_control_node.ciber_tag IS 'Metadata Excel; evaluación NIST (M7) usa nist_ciber_item_catalog, no este campo.';

COMMENT ON COLUMN assessment.assessment_control_node.default_steward_role_code IS 'Copia desde catalog.control_catalog_node al crear snapshot de evaluación (HU-AR-01).';

CREATE TABLE assessment.assessment_deletion_request (
    id uuid NOT NULL,
    assessment_id uuid NOT NULL,
    requested_by uuid NOT NULL,
    requested_by_name character varying(200),
    reason text NOT NULL,
    attachment_file_id uuid,
    status character varying(20) DEFAULT 'PENDING'::character varying NOT NULL,
    scheduled_deletion_at timestamp with time zone,
    decision_by uuid,
    decision_by_name character varying(200),
    decision_at timestamp with time zone,
    decision_comment text,
    request_number character varying(32),
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

COMMENT ON TABLE assessment.assessment_deletion_request IS 'Solicitudes de eliminación (borrado lógico) de una evaluación, con aprobación y periodo de gracia.';

COMMENT ON COLUMN assessment.assessment_deletion_request.status IS 'PENDING|APPROVED|REJECTED|CANCELLED';

COMMENT ON COLUMN assessment.assessment_deletion_request.scheduled_deletion_at IS 'Fecha programada del borrado lógico (aprobación + assessmentDeletionGraceDays).';

COMMENT ON COLUMN assessment.assessment_deletion_request.request_number IS 'Código legible SOL-ELIM-###### (sin UUID).';

CREATE TABLE assessment.assessment_edit_lock (
    assessment_id uuid NOT NULL,
    locked_by_user_id uuid NOT NULL,
    lock_token uuid NOT NULL,
    acquired_at timestamp with time zone DEFAULT now() NOT NULL,
    expires_at timestamp with time zone NOT NULL
);

COMMENT ON TABLE assessment.assessment_edit_lock IS 'HU-CFG-01 caso borde: dos evaluadores no editan a la vez.
Estrategia recomendada: row_version (optimista) en assessment + opcional esta tabla (pesimista).
Si no hay fila en edit_lock, solo aplica optimista. Si hay fila, solo locked_by puede editar hasta expires_at.
';

COMMENT ON COLUMN assessment.assessment_edit_lock.lock_token IS 'Token que el cliente debe enviar en cada PATCH.';

COMMENT ON COLUMN assessment.assessment_edit_lock.expires_at IS 'TTL ej. 15-30 min; liberar al publicar o al cerrar sesión.';

CREATE TABLE assessment.assessment_extension_request (
    id uuid NOT NULL,
    assessment_id uuid NOT NULL,
    requested_by uuid NOT NULL,
    requested_by_name character varying(200),
    reason text NOT NULL,
    attachment_file_id uuid,
    days integer NOT NULL,
    status character varying(20) DEFAULT 'PENDING'::character varying NOT NULL,
    decision_by uuid,
    decision_by_name character varying(200),
    decision_at timestamp with time zone,
    decision_comment text,
    request_number character varying(32),
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

COMMENT ON TABLE assessment.assessment_extension_request IS 'Solicitudes de ampliación de plazo de una evaluación vencida o por vencer.';

COMMENT ON COLUMN assessment.assessment_extension_request.days IS 'Días de ampliación (assessmentExtensionDays vigente al solicitar).';

COMMENT ON COLUMN assessment.assessment_extension_request.status IS 'PENDING|APPROVED|REJECTED';

COMMENT ON COLUMN assessment.assessment_extension_request.request_number IS 'Código legible SOL-AMPL-###### (sin UUID).';

CREATE TABLE assessment.assessment_maturity_requirement (
    id uuid NOT NULL,
    assessment_id uuid NOT NULL,
    source_catalog_requirement_id uuid NOT NULL,
    code character varying(40) NOT NULL,
    title character varying(280) NOT NULL,
    description text,
    source_type character varying(12) NOT NULL,
    source_element_code character varying(40) NOT NULL,
    scoring_mode character varying(12) NOT NULL,
    inherit_rule character varying(24) DEFAULT 'NONE'::character varying NOT NULL,
    source_control_code character varying(40),
    source_catalog_control_node_id uuid,
    source_assessment_control_node_id uuid,
    source_phva_item_code character varying(40),
    composite_phva_codes jsonb,
    source_catalog_phva_item_id uuid,
    source_assessment_phva_item_id uuid,
    "position" integer NOT NULL
);

COMMENT ON TABLE assessment.assessment_maturity_requirement IS 'Una fila por requisito Rn del instrumento (~50 por evaluación).
INHERITED: UI solo lectura para F_n; effective_score (F_n) se calcula al listar/consolidar.
Resolución INHERITED:
  CONTROL_SCORE      → control_response del source_assessment_control_node (NA ⇒ F_n=N/A).
  PHVA_ITEM_SCORE    → effective_score del phva_item (manual o heredado M5).
  PHVA_COMPOSITE_AVG → avg(effective_score) de ítems listados en composite_phva_codes.
Si origen no resuelto (typo catálogo): error configuración en startup/seed, no en runtime silencioso.
Si F_n no disponible (#N/A Excel): API devuelve null + etiqueta "requiere calificación" (HU-MAD-01 #64).
';

COMMENT ON COLUMN assessment.assessment_maturity_requirement.code IS 'Snapshot R1, R2, … R55';

COMMENT ON COLUMN assessment.assessment_maturity_requirement.source_type IS 'ADMIN|TECH|PHVA|MATURITY';

COMMENT ON COLUMN assessment.assessment_maturity_requirement.scoring_mode IS 'MANUAL|INHERITED';

COMMENT ON COLUMN assessment.assessment_maturity_requirement.source_control_code IS 'Código control origen ej. AD.4.1.1, T.7.1.4 (trazabilidad).';

COMMENT ON COLUMN assessment.assessment_maturity_requirement.source_catalog_control_node_id IS 'Snapshot FK catálogo; resolver assessment_control_node en runtime.';

COMMENT ON COLUMN assessment.assessment_maturity_requirement.source_assessment_control_node_id IS 'Opcional: materializar al crear evaluación si existe nodo control origen en snapshot de controles.
';

COMMENT ON COLUMN assessment.assessment_maturity_requirement.source_catalog_phva_item_id IS 'PHVA_ITEM_SCORE: ítem catálogo único.';

COMMENT ON COLUMN assessment.assessment_maturity_requirement.source_assessment_phva_item_id IS 'Opcional: materializar FK PHVA al crear evaluación (un ítem). R41 usa composite_phva_codes on-read.
';

CREATE TABLE assessment.assessment_maturity_requirement_response (
    id uuid NOT NULL,
    assessment_id uuid NOT NULL,
    maturity_requirement_id uuid NOT NULL,
    score_status character varying(10) DEFAULT 'SCORED'::character varying NOT NULL,
    score_value integer,
    updated_by uuid,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    version integer DEFAULT 0 NOT NULL
);

COMMENT ON TABLE assessment.assessment_maturity_requirement_response IS '1:1 con assessment_maturity_requirement donde scoring_mode=MANUAL (R5, R9, R10 en seed MSPI v1).
NO crear fila para INHERITED (F_n = función de control_response / PHVA on-read).
PATCH permitido solo en requisitos MANUAL; invalidar cache MATURITY si existe.
';

COMMENT ON COLUMN assessment.assessment_maturity_requirement_response.score_status IS 'HU-MAD-01 — SCORED | NA (misma escala 0–100 que controles/PHVA).
Al crear evaluación: solo MANUAL con SCORED y score_value=0.
';

COMMENT ON COLUMN assessment.assessment_maturity_requirement_response.score_value IS '0 | 20 | 40 | 60 | 80 | 100 cuando score_status=SCORED; NULL si NA.
F_n para MANUAL = score_value (o N/A si score_status=NA).
Validación contra catalog.scale_level al PATCH.
';

CREATE TABLE assessment.assessment_maturity_threshold (
    id uuid NOT NULL,
    assessment_id uuid NOT NULL,
    maturity_requirement_id uuid NOT NULL,
    level integer NOT NULL,
    is_na boolean DEFAULT false NOT NULL,
    expected_value integer
);

COMMENT ON TABLE assessment.assessment_maturity_threshold IS 'Copia de catalog.maturity_threshold al crear/clonar evaluación (HU-CFG-01).
nivelCumple(L) y matriz HU-MAD-02 usan solo filas con is_na=false para el nivel L.
';

COMMENT ON COLUMN assessment.assessment_maturity_threshold.level IS '1..5';

COMMENT ON COLUMN assessment.assessment_maturity_threshold.expected_value IS 'NULL si is_na=true';

CREATE TABLE assessment.assessment_member (
    assessment_id uuid NOT NULL,
    user_id uuid NOT NULL,
    member_role character varying(20) NOT NULL,
    is_leader boolean DEFAULT false NOT NULL,
    assigned_at timestamp with time zone DEFAULT now() NOT NULL
);

COMMENT ON TABLE assessment.assessment_member IS 'Equipo de la evaluación. El líder suele coincidir con created_by.';

COMMENT ON COLUMN assessment.assessment_member.member_role IS 'EVALUATOR|REVIEWER|READER';

COMMENT ON COLUMN assessment.assessment_member.is_leader IS 'true = evaluador líder (HU-CFG-01)';

CREATE TABLE assessment.assessment_metadata (
    assessment_id uuid NOT NULL,
    period character varying(120),
    scope text,
    prepared_by character varying(200),
    approved_by character varying(200),
    start_date date,
    end_date date,
    notes text
);

COMMENT ON TABLE assessment.assessment_metadata IS 'Metadatos extendidos. row_version de concurrencia está en assessment.assessment.row_version.';

COMMENT ON COLUMN assessment.assessment_metadata.period IS 'Período fiscal o vigencia (complementario a evaluation_date)';

COMMENT ON COLUMN assessment.assessment_metadata.start_date IS 'Rango complementario; NO reemplaza evaluation_date de assessment.';

CREATE TABLE assessment.assessment_nist_ciber_item (
    id uuid NOT NULL,
    assessment_id uuid NOT NULL,
    source_catalog_item_id uuid NOT NULL,
    function_id uuid NOT NULL,
    function_code character varying(20) NOT NULL,
    function_name character varying(120),
    subcategory_id uuid NOT NULL,
    subcategory_code character varying(40) NOT NULL,
    title character varying(300),
    scoring_mode character varying(12) NOT NULL,
    source_type character varying(12) NOT NULL,
    inherit_rule character varying(24) DEFAULT 'NONE'::character varying NOT NULL,
    iso_control_code character varying(80),
    source_catalog_control_node_id uuid,
    source_assessment_control_node_id uuid,
    "position" integer NOT NULL
);

COMMENT ON TABLE assessment.assessment_nist_ciber_item IS 'Una fila por ítem Ciber del instrumento (~188 por evaluación en MSPI v1).
INHERITED: UI solo lectura; effective_score (c_i) = score del control hoja (NA ⇒ N/A, excluido del promedio).
MANUAL: editable vía nist_ciber_item_response.
Si control origen sin calificar: effective_score null + requiresRating=true (no error Excel #N/A).
Invalidar cache NIST al cambiar control_response o nist_ciber_item_response MANUAL.
';

COMMENT ON COLUMN assessment.assessment_nist_ciber_item.function_id IS 'Snapshot función NIST (agrupación promedios).';

COMMENT ON COLUMN assessment.assessment_nist_ciber_item.function_code IS 'Snapshot GV|ID|PR|DE|RS|RC (CSF 2.0) — denormalizado para API.';

COMMENT ON COLUMN assessment.assessment_nist_ciber_item.function_name IS 'Snapshot nombre de función NIST (p. ej. Gobernar) — denormalizado del catálogo.';

COMMENT ON COLUMN assessment.assessment_nist_ciber_item.subcategory_code IS 'Snapshot ID.AM-1, PR.AC-1, …';

COMMENT ON COLUMN assessment.assessment_nist_ciber_item.scoring_mode IS 'MANUAL|INHERITED';

COMMENT ON COLUMN assessment.assessment_nist_ciber_item.source_type IS 'ADMIN|TECH|NIST';

COMMENT ON COLUMN assessment.assessment_nist_ciber_item.iso_control_code IS 'NULL en filas MANUAL puras NIST.';

COMMENT ON COLUMN assessment.assessment_nist_ciber_item.source_catalog_control_node_id IS 'FK catálogo control hoja; resolver assessment_control_node en runtime.';

COMMENT ON COLUMN assessment.assessment_nist_ciber_item.source_assessment_control_node_id IS 'Opcional: materializar al crear evaluación si existe nodo control origen en snapshot de controles.
';

CREATE TABLE assessment.assessment_phva_item (
    id uuid NOT NULL,
    assessment_id uuid NOT NULL,
    source_catalog_item_id uuid NOT NULL,
    code character varying(40) NOT NULL,
    component character varying(10) NOT NULL,
    title character varying(280) NOT NULL,
    description text,
    test_guidance text,
    scoring_mode character varying(12) NOT NULL,
    inherit_rule character varying(24) DEFAULT 'NONE'::character varying NOT NULL,
    source_control_code character varying(40),
    source_catalog_control_node_id uuid,
    source_assessment_control_node_id uuid,
    "position" integer NOT NULL,
    parent_code character varying(40),
    node_type character varying(12) DEFAULT 'ITEM'::character varying NOT NULL
);

COMMENT ON TABLE assessment.assessment_phva_item IS 'Una fila por requisito PHVA del instrumento (~17 por evaluación).
INHERITED: UI solo lectura; effective_score se calcula al listar/consolidar (no persiste en phva_item_response).
Resolución INHERITED:
  CONTROL_SCORE  → control_response.score_value del source_assessment_control_node (hoja).
  CONTROL_ROLLUP → rollup del nodo ADMIN referenciado (objetivo/dominio según seed).
  ANEXO_A_OVERALL→ promedio global Anexo A (rollup ADMIN ∪ TECH a nivel raíz; ver HU-DIAG-01).
';

COMMENT ON COLUMN assessment.assessment_phva_item.code IS 'Snapshot P.1, I.2, E.1, M.1, …';

COMMENT ON COLUMN assessment.assessment_phva_item.component IS 'PLAN|DO|CHECK|ACT';

COMMENT ON COLUMN assessment.assessment_phva_item.scoring_mode IS 'MANUAL|INHERITED — copia desde catálogo al crear evaluación.';

COMMENT ON COLUMN assessment.assessment_phva_item.inherit_rule IS 'NONE|CONTROL_SCORE|CONTROL_ROLLUP|ANEXO_A_OVERALL';

COMMENT ON COLUMN assessment.assessment_phva_item.source_catalog_control_node_id IS 'Snapshot FK catálogo; resolver a assessment_control_node en runtime.';

COMMENT ON COLUMN assessment.assessment_phva_item.source_assessment_control_node_id IS 'Opcional: FK materializada al crear evaluación si existe nodo control origen en el snapshot de controles.
Si NULL, resolver on-read por source_catalog_control_node_id + assessment_id.
';

CREATE TABLE assessment.assessment_status_history (
    id bigint NOT NULL,
    assessment_id uuid NOT NULL,
    old_status character varying(30) NOT NULL,
    new_status character varying(30) NOT NULL,
    note text,
    changed_by uuid NOT NULL,
    changed_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE SEQUENCE assessment.assessment_status_history_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE assessment.assessment_status_history_id_seq OWNED BY assessment.assessment_status_history.id;

CREATE TABLE assessment.control_comment (
    id uuid NOT NULL,
    thread_id uuid NOT NULL,
    author_user_id uuid NOT NULL,
    body text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE assessment.control_comment_thread (
    id uuid NOT NULL,
    control_response_id uuid NOT NULL,
    created_by uuid NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    is_resolved boolean DEFAULT false NOT NULL,
    resolved_by uuid,
    resolved_at timestamp with time zone
);

CREATE TABLE assessment.control_response (
    id uuid NOT NULL,
    assessment_id uuid NOT NULL,
    control_node_id uuid NOT NULL,
    score_status character varying(10) DEFAULT 'PENDING'::character varying NOT NULL,
    score_value integer,
    evidence_text text,
    gap_text text,
    recommendation_text text,
    control_status character varying(30) DEFAULT 'PENDIENTE'::character varying NOT NULL,
    steward_source character varying(14) DEFAULT 'FROM_AREA'::character varying NOT NULL,
    steward_custom_name character varying(200),
    steward_custom_staff_role character varying(160),
    steward_custom_contact character varying(200),
    updated_by uuid,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    version integer DEFAULT 0 NOT NULL
);

COMMENT ON COLUMN assessment.control_response.score_status IS 'HU-ADM-01 #23 / HU-TEC-01 #40 — dominio: PENDING | SCORED | NA.
Al crear evaluación (HU-CFG-01): score_status=PENDING y score_value=NULL (sin calificar).
El rollup / progress solo cuenta hojas SCORED con score_value no nulo.
';

COMMENT ON COLUMN assessment.control_response.score_value IS 'Escala MSPI discreta (HU-ADM-01 #23 / HU-TEC-01 #40): 0 | 20 | 40 | 60 | 80 | 100.
Reglas:
  * score_status=''PENDING'' ⇒ score_value IS NULL
  * score_status=''NA''      ⇒ score_value IS NULL
  * score_status=''SCORED''  ⇒ score_value IN (0,20,40,60,80,100)
Validación contra catalog.scale_level publicada al PATCH (ms_catalog).
';

COMMENT ON COLUMN assessment.control_response.evidence_text IS 'HU-ADM-01 #25 / HU-TEC-01 #40: evidencia textual. Adjuntos: evidence.evidence_file relation_type=CONTROL_RESPONSE.';

COMMENT ON COLUMN assessment.control_response.gap_text IS 'HU-ADM-01 #25 / HU-TEC-01 #40: brecha identificada (texto).';

COMMENT ON COLUMN assessment.control_response.recommendation_text IS 'HU-ADM-01 #25 / HU-TEC-01 #40: recomendación; obligatoriedad vía catalog.control_rule.';

COMMENT ON COLUMN assessment.control_response.steward_source IS 'HU-AR-01 criterios 21-22:
FROM_AREA → persona mostrada/notificada viene de assessment_area_topic.default_steward_role_code = node''s default_steward_role_code (propagación).
CUSTOM → se usan steward_custom_*; no se sobrescribe al actualizar assignments por área.
';

COMMENT ON COLUMN assessment.control_response.steward_custom_staff_role IS 'Cargo texto capturado en override (opcional UI).';

CREATE TABLE assessment.control_review (
    id uuid NOT NULL,
    control_response_id uuid NOT NULL,
    review_status character varying(20) NOT NULL,
    comment text,
    severity character varying(20),
    reviewed_by uuid NOT NULL,
    reviewed_at timestamp with time zone DEFAULT now() NOT NULL
);

COMMENT ON COLUMN assessment.control_review.review_status IS 'VALIDATED|NEEDS_CHANGES';

CREATE TABLE assessment.gap_action (
    id uuid NOT NULL,
    gap_id uuid NOT NULL,
    description text NOT NULL,
    owner character varying(200),
    due_date date,
    status character varying(20) DEFAULT 'PENDIENTE'::character varying NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE assessment.gap_register (
    id uuid NOT NULL,
    assessment_id uuid NOT NULL,
    control_response_id uuid,
    title character varying(220),
    gap_text text NOT NULL,
    priority character varying(10) DEFAULT 'MEDIA'::character varying NOT NULL,
    owner character varying(200),
    due_date date,
    status character varying(20) DEFAULT 'PENDIENTE'::character varying NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);

COMMENT ON TABLE assessment.gap_register IS 'HU-REP-03 (Módulo 9): listado priorizado de brechas (score < 60) se obtiene on-read desde
assessment_control_node (hoja) + control_response + steward efectivo (HU-AR-01);
brecha(c) = 100 - score_value. gap_register es extensión opcional para recomendaciones/plan de acción
persistidas por el evaluador (no sustituye el listado calculado de REP-03).
Módulo 8 (HU-DIAG): el tablero Portada NO usa esta tabla; usa rollup por dominio y resúmenes PHVA/Madurez/NIST.
';

CREATE TABLE assessment.nist_ciber_item_response (
    id uuid NOT NULL,
    assessment_id uuid NOT NULL,
    nist_ciber_item_id uuid NOT NULL,
    score_status character varying(10) DEFAULT 'SCORED'::character varying NOT NULL,
    score_value integer,
    evidence_text text,
    gap_text text,
    updated_by uuid,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    version integer DEFAULT 0 NOT NULL
);

COMMENT ON TABLE assessment.nist_ciber_item_response IS '1:1 con assessment_nist_ciber_item donde scoring_mode=MANUAL (~13 filas típicas MSPI v1).
NO crear fila para INHERITED (c_i = control_response on-read).
PATCH permitido solo en ítems MANUAL; invalidar cache NIST si existe.
';

COMMENT ON COLUMN assessment.nist_ciber_item_response.score_status IS 'HU-CIB-01 — SCORED | NA (misma escala 0–100 que controles).
Al crear evaluación: solo filas MANUAL con SCORED y score_value=0.
';

COMMENT ON COLUMN assessment.nist_ciber_item_response.score_value IS '0 | 20 | 40 | 60 | 80 | 100 cuando score_status=SCORED; NULL si NA.
effective_score para MANUAL = score_value (o excluido si NA).
Validación contra catalog.scale_level al PATCH.
';

CREATE TABLE assessment.phva_item_response (
    id uuid NOT NULL,
    assessment_id uuid NOT NULL,
    phva_item_id uuid NOT NULL,
    score_status character varying(10) DEFAULT 'SCORED'::character varying NOT NULL,
    score_value integer,
    evidence_text text,
    gap_text text,
    updated_by uuid,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    version integer DEFAULT 0 NOT NULL
);

COMMENT ON TABLE assessment.phva_item_response IS '1:1 con assessment_phva_item donde scoring_mode=MANUAL.
NO crear fila para INHERITED (valor efectivo = función de control_response / rollup / Anexo A).
Promedio componente C: avg(effective_score de ítems del componente), excluyendo NA.
Si todos NA en un componente → avance componente = 0 (HU-PHVA-01 caso borde).
';

COMMENT ON COLUMN assessment.phva_item_response.score_status IS 'HU-PHVA-01..04 — SCORED | NA (misma escala que controles).
CHECK: score_status IN (''SCORED'',''NA'').
Al crear evaluación: solo filas MANUAL con SCORED y score_value=0.
';

COMMENT ON COLUMN assessment.phva_item_response.score_value IS '0 | 20 | 40 | 60 | 80 | 100 cuando score_status=SCORED; NULL si NA o sin calificar.
Validación contra catalog.scale_level al PATCH.
';

CREATE SEQUENCE assessment.seq_deletion_request_number
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

CREATE SEQUENCE assessment.seq_extension_request_number
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

CREATE TABLE audit.audit_log (
    id bigint NOT NULL,
    event_type character varying(80) NOT NULL,
    entity_type character varying(80) NOT NULL,
    entity_id character varying(120) NOT NULL,
    assessment_id uuid,
    actor_user_id uuid,
    occurred_at timestamp with time zone DEFAULT now() NOT NULL,
    ip character varying(64),
    user_agent character varying(400),
    before_json jsonb,
    after_json jsonb,
    metadata_json jsonb
);

COMMENT ON TABLE audit.audit_log IS 'Auditoría central (ms_audit :8088). assessment_id/actor_user_id sin FK.';

COMMENT ON COLUMN audit.audit_log.event_type IS 'Autenticación (ms_iam, entity_type=AUTH; entity_id=usernameOrEmail):
- AUTH_LOGIN_SUCCESS
- AUTH_LOGIN_FAILED
- AUTH_LOGIN_INACTIVE
Eventos Módulo 1 / negocio:
- ASSESSMENT_CREATED
- ASSESSMENT_PUBLISHED (status → CERRADA)
- ASSESSMENT_CLONED
- ENTITY_ORDER_TYPE_CHANGED (HU-CFG-02; before_json/after_json)
- STEWARD_PROPAGATED (opcional HU-AR-01; tras guardar assignments de áreas)
- INVENTORY_DELIVERY_UPDATED
';

COMMENT ON COLUMN audit.audit_log.entity_type IS 'AUTH|ASSESSMENT|ORGANIZATION|USER|...';

COMMENT ON COLUMN audit.audit_log.assessment_id IS 'UUID de evaluación opcional; sin FK a assessment (desacople).';

COMMENT ON COLUMN audit.audit_log.actor_user_id IS 'UUID de usuario opcional; sin FK a iam.user (desacople).';

CREATE SEQUENCE audit.audit_log_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE audit.audit_log_id_seq OWNED BY audit.audit_log.id;

CREATE TABLE catalog.assessment_area_preset (
    code character varying(40) NOT NULL,
    label character varying(160) NOT NULL,
    "position" integer NOT NULL,
    active boolean DEFAULT true NOT NULL
);

COMMENT ON TABLE catalog.assessment_area_preset IS 'Al crear evaluación, ms_assessment puede inicializar assessment_area filas desde este preset
(area_name ≈ label o copia exacta para paridad Excel). El evaluador complementa topics y datos de contacto.
';

COMMENT ON COLUMN catalog.assessment_area_preset.code IS 'Ej. AREA_CONTROL_INTERNO | AREA_GESTION_HUMANA | AREA_LIDERES_PROCESO | AREA_COMPRAS |
AREA_CONTINUIDAD | AREA_SEG_FISICA | AREA_TICS | AREA_SEG_INFORMACION
';

CREATE TABLE catalog.catalog_deletion_request (
    id uuid NOT NULL,
    target_type character varying(20) NOT NULL,
    target_id uuid NOT NULL,
    requested_by uuid NOT NULL,
    requested_by_name character varying(200),
    reason text NOT NULL,
    attachment_file_id uuid,
    status character varying(20) DEFAULT 'PENDING'::character varying NOT NULL,
    scheduled_deletion_at timestamp with time zone,
    decision_by uuid,
    decision_by_name character varying(200),
    decision_at timestamp with time zone,
    decision_comment text,
    request_number character varying(32),
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

COMMENT ON TABLE catalog.catalog_deletion_request IS 'Solicitudes de eliminación lógica de escalas o bancos de preguntas.';

COMMENT ON COLUMN catalog.catalog_deletion_request.target_type IS 'SCALE|QUESTION_BANK';

COMMENT ON COLUMN catalog.catalog_deletion_request.status IS 'PENDING|APPROVED|REJECTED|CANCELLED';

COMMENT ON COLUMN catalog.catalog_deletion_request.scheduled_deletion_at IS 'Fecha programada del borrado lógico (aprobación + catalogDeletionGraceDays).';

COMMENT ON COLUMN catalog.catalog_deletion_request.request_number IS 'Código legible SOL-CAT-###### (sin UUID).';

CREATE TABLE catalog.control_catalog_node (
    id uuid NOT NULL,
    template_version_id uuid NOT NULL,
    parent_id uuid,
    "position" integer NOT NULL,
    node_type character varying(20) NOT NULL,
    control_type character varying(10),
    code character varying(40),
    iso_code character varying(40),
    title character varying(300) NOT NULL,
    description text,
    test_guidance text,
    iso_domain_code character varying(20),
    mspi_tag character varying(120),
    ciber_tag character varying(120),
    is_scored boolean DEFAULT false NOT NULL,
    default_steward_role_code character varying(60),
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

COMMENT ON TABLE catalog.control_catalog_node IS 'HU-ADM-02 / HU-ADM-03 / HU-TEC-02 — Reglas de cálculo (en código, sin tabla extra):
  calcular(nodo):
    si nodo.es_hoja (is_scored=true)           → control_response.score_value (N/A excluido)
    si nodo tiene un único hijo                → calcular(hijo) (sin redondeo)
    si nodo tiene varios hijos                 → round_half_up(avg([calcular(h) for h in hijos]))
  Reglas:
    * Excluir hijos cuyo cálculo retorne N/A; si TODOS son N/A, el nodo es N/A.
    * round_half_up: floor(x + 0.5).
    * Dominio promedia hijos directos (objetivos en ADMIN; objetivos en TECH) — no hojas en un salto.
    * HU-TEC-02 #43-45: misma función recursiva; TECH puede tener SUB_OBJECTIVE intermedio (ej. A.9.3 → A.9.3.1).
  API rollup: filtrar assessment_control_node por control_type=ADMIN|TECH antes de calcular raíces.
  Cache opcional: reporting.analytics_cache kind IN (''ROLLUP'',''ROLLUP_ADMIN'',''ROLLUP_TECH'').
';

COMMENT ON COLUMN catalog.control_catalog_node.node_type IS 'DOMAIN | OBJECTIVE | SUB_OBJECTIVE | CONTROL.
ADMIN (M3): DOMAIN → OBJECTIVE → CONTROL (3 niveles; AD.x.y.z en hoja).
TECH (M4): DOMAIN → OBJECTIVE → SUB_OBJECTIVE → CONTROL (4 niveles cuando aplica; T.x.y.z en hoja).
Alternativa válida: OBJECTIVE anidado (padre OBJECTIVE → hijo OBJECTIVE) sin SUB_OBJECTIVE explícito;
el rollup solo usa parent_id + is_scored, no el nombre del tipo.
';

COMMENT ON COLUMN catalog.control_catalog_node.control_type IS 'ADMIN | TECH. Aplica a nodos de la rama; en hojas is_scored=true típicamente.';

COMMENT ON COLUMN catalog.control_catalog_node.code IS 'ID interno MSPI (no confundir con iso_code):
ADMIN: AD.x (dominio), AD.x.y (objetivo), AD.x.y.z (hoja).
TECH:  T.x (dominio), T.x.y (objetivo), T.x.y.z (sub-objetivo o hoja según profundidad del dominio).
HU-TEC-01 #41: prefijo T. HU-TEC-01 #42: ISO en iso_code (A.9.x.y, A.10.x.y, …).
';

COMMENT ON COLUMN catalog.control_catalog_node.iso_code IS 'HU-ADM-01 / HU-TEC-01 + HU-ADM-04: referencia ISO 27001:2013 específica del nodo.
Ej. A.5.1.1 en control hoja, A.5.1 en objetivo, A.5 en dominio.
Distinto de iso_domain_code (que solo apunta al dominio raíz) y de code (ID interno AD/T).
';

COMMENT ON COLUMN catalog.control_catalog_node.ciber_tag IS 'Metadata Excel; evaluación NIST (M7) usa nist_ciber_item_catalog, no este campo.';

COMMENT ON COLUMN catalog.control_catalog_node.default_steward_role_code IS 'HU-ADM-01 / HU-TEC-01 + HU-AR-01: cargo predeterminado del control (hoja ISO). Solo control_type ADMIN|TECH en nodos CONTROL hoja típicamente.
NULL en secciones o nodos sin responsable definido en Excel.
';

CREATE TABLE catalog.control_rule (
    id uuid NOT NULL,
    control_node_id uuid NOT NULL,
    requires_evidence boolean DEFAULT false NOT NULL,
    requires_gap boolean DEFAULT false NOT NULL,
    requires_recommendation boolean DEFAULT false NOT NULL,
    recommendation_rule_type character varying(20) DEFAULT 'THRESHOLD'::character varying NOT NULL,
    recommendation_threshold_value integer,
    requires_test_checklist boolean DEFAULT false NOT NULL,
    max_files integer,
    max_text_len jsonb
);

COMMENT ON TABLE catalog.control_rule IS 'Una fila por control hoja (ADMIN o TECH). HU-ADM-01 #25 y HU-TEC-01 #40 comparten reglas.
Seed: generar por cada nodo con is_scored=true y control_type IN (ADMIN, TECH).
';

COMMENT ON COLUMN catalog.control_rule.recommendation_rule_type IS 'ALWAYS|THRESHOLD|NEVER';

CREATE TABLE catalog.entity_order_type (
    code character varying(20) NOT NULL,
    label character varying(80) NOT NULL,
    phva_expected_advance numeric(5,4) NOT NULL,
    "position" integer NOT NULL,
    active boolean DEFAULT true NOT NULL
);

COMMENT ON TABLE catalog.entity_order_type IS 'HU-CFG-02: 4 tipos oficiales MSPI (NACIONAL, TERRITORIAL_A, TERRITORIAL_B, TERRITORIAL_C) + OTRA (texto libre en assessment.entity_type_other).
Seed obligatorio. Territorial B/C: confirmar phva_expected_advance con MinTIC.
assessment guarda snapshot en phva_expected_advance_snapshot al asignar o cambiar tipo.
Regla app: entity_order_type_code obligatorio antes de publicar (status=CERRADA); si OTRA, entity_type_other obligatorio.
';

COMMENT ON COLUMN catalog.entity_order_type.code IS 'NACIONAL|TERRITORIAL_A|TERRITORIAL_B|TERRITORIAL_C|OTRA';

COMMENT ON COLUMN catalog.entity_order_type.phva_expected_advance IS 'Fracción 0..1. Ejemplos documentados:
- NACIONAL = 0.40 (40%)
- TERRITORIAL_A = 0.35 (35%)
- TERRITORIAL_B/C = confirmar con política MinTIC antes de seed.
';

COMMENT ON COLUMN catalog.entity_order_type."position" IS 'Orden de presentación en UI';

CREATE TABLE catalog.iso_domain (
    code character varying(20) NOT NULL,
    name character varying(220) NOT NULL,
    description character varying(600),
    control_type character varying(10) NOT NULL,
    display_position integer NOT NULL,
    active boolean DEFAULT true NOT NULL
);

COMMENT ON COLUMN catalog.iso_domain.code IS 'Dominios ISO 27001:2013 del instrumento MSPI (14 dominios — HU-DIAG-01 #91).
Administrativos (M3 / HU-DIAG-01 #94): A.5, A.6, A.7, A.8, A.15, A.17, A.18.
Técnicos (M4 / HU-DIAG-01 #94): A.9, A.10, A.11, A.12, A.13, A.14, A.16.
Debe existir exactamente un nodo control_catalog_node.node_type=DOMAIN por (template, iso_domain_code, control_type).
';

COMMENT ON COLUMN catalog.iso_domain.name IS 'Nombre legible en tablero Portada (columna dominio).';

COMMENT ON COLUMN catalog.iso_domain.control_type IS 'ADMIN | TECH — hoja origen del dominio (HU-DIAG-01 #94).';

COMMENT ON COLUMN catalog.iso_domain.display_position IS 'Orden de fila en Portada Excel (F19..F32). Seed sugerido:
ADMIN: A.5=1, A.6=2, A.7=3, A.8=4, A.15=5, A.17=6, A.18=7.
TECH:  A.9=8, A.10=9, A.11=10, A.12=11, A.13=12, A.14=13, A.16=14.
';

CREATE TABLE catalog.lifting_document_item_catalog (
    id uuid NOT NULL,
    template_version_id uuid NOT NULL,
    item_number integer NOT NULL,
    block character varying(30) NOT NULL,
    title character varying(300) NOT NULL,
    required_text text NOT NULL,
    hints text,
    is_required boolean DEFAULT true NOT NULL,
    is_process_metric boolean DEFAULT false NOT NULL,
    "position" integer NOT NULL
);

COMMENT ON TABLE catalog.lifting_document_item_catalog IS 'HU-CFG-05: por template_version publicada deben existir exactamente 43 filas.
Rangos de item_number por block (validar en seed y en app):
  BASICA → 1..34 | IMPLEMENTACION → 35..37 | EVALUACION → 38..40 | MEJORA_CONTINUA → 41..43
item_number=43 → is_process_metric=true; datos numéricos en evidence.process_scope_metric.
';

COMMENT ON COLUMN catalog.lifting_document_item_catalog.item_number IS '1..43. Ítem 43 = métrica de procesos MSPI.';

COMMENT ON COLUMN catalog.lifting_document_item_catalog.block IS 'Bloque según Excel:
- BASICA (ítems 1-34)
- IMPLEMENTACION (35-37)
- EVALUACION (38-40)
- MEJORA_CONTINUA (41-43)
';

COMMENT ON COLUMN catalog.lifting_document_item_catalog.title IS 'Nombre/descripción del documento solicitado';

COMMENT ON COLUMN catalog.lifting_document_item_catalog.required_text IS 'Texto oficial del requisito (paridad Excel)';

COMMENT ON COLUMN catalog.lifting_document_item_catalog.is_process_metric IS 'true solo item_number=43';

COMMENT ON COLUMN catalog.lifting_document_item_catalog."position" IS 'Orden dentro del bloque (mayor importancia = menor position; menor position = más importante)';

CREATE TABLE catalog.lifting_question_catalog (
    id uuid NOT NULL,
    template_version_id uuid NOT NULL,
    code character varying(40) NOT NULL,
    section character varying(120),
    question_text text NOT NULL,
    field_type character varying(30) NOT NULL,
    is_required boolean DEFAULT false NOT NULL,
    "position" integer NOT NULL,
    options_json jsonb
);

COMMENT ON TABLE catalog.lifting_question_catalog IS 'Complementario. HU-CFG-03/04 usan evidence.assessment_context como fuente principal.';

COMMENT ON COLUMN catalog.lifting_question_catalog.field_type IS 'TEXT|TEXTAREA|NUMBER|SELECT|MULTISELECT|DATE';

CREATE TABLE catalog.maturity_requirement_catalog (
    id uuid NOT NULL,
    template_version_id uuid NOT NULL,
    code character varying(40) NOT NULL,
    title character varying(280) NOT NULL,
    description text,
    source_type character varying(12) NOT NULL,
    source_element_code character varying(40) NOT NULL,
    scoring_mode character varying(12) DEFAULT 'INHERITED'::character varying NOT NULL,
    inherit_rule character varying(24) DEFAULT 'NONE'::character varying NOT NULL,
    source_control_node_id uuid,
    source_phva_item_code character varying(40),
    composite_phva_codes jsonb,
    "position" integer NOT NULL,
    active boolean DEFAULT true NOT NULL
);

COMMENT ON TABLE catalog.maturity_requirement_catalog IS 'HU-MAD-01..02 — catálogo paramétrico hoja Madurez (~50 requisitos por template_version publicada).
Fuente de verdad umbrales: maturity_threshold (5 filas por requisito, is_na donde Excel dice N/A).
Orígenes manuales (seed): R5, R9, R10 — source_type=MATURITY, scoring_mode=MANUAL, inherit_rule=NONE.
Orígenes PHVA (ej.): R4,R7→P.1; R11→P.6; R40→P.8; R46→M.2; R41→PHVA_COMPOSITE_AVG.
Validación app:
  inherit_rule=NONE ⇒ scoring_mode=MANUAL y source_type=MATURITY.
  CONTROL_SCORE ⇒ source_control_node_id NOT NULL y source_type IN (ADMIN,TECH).
  PHVA_ITEM_SCORE ⇒ source_phva_item_code NOT NULL y source_type=PHVA.
  PHVA_COMPOSITE_AVG ⇒ composite_phva_codes NOT NULL (array no vacío).
Sub-filas auxiliares del Excel (debajo de R4, R41) NO se modelan como filas BD en v1;
  solo las filas Rn del Anexo A Historias v2. Diferencia documentada vs conteo Excel Portada.
';

COMMENT ON COLUMN catalog.maturity_requirement_catalog.code IS 'R1..R55 (Anexo A MSPI v1: ~50 filas Rn; sin R54).';

COMMENT ON COLUMN catalog.maturity_requirement_catalog.source_type IS 'ADMIN | TECH | PHVA | MATURITY — hoja origen (HU-MAD-01 #60).
ADMIN/TECH → inherit_rule=CONTROL_SCORE.
PHVA       → PHVA_ITEM_SCORE o PHVA_COMPOSITE_AVG.
MATURITY   → scoring_mode=MANUAL (R5, R9, R10).
';

COMMENT ON COLUMN catalog.maturity_requirement_catalog.source_element_code IS 'Elemento en hoja origen: AD.4.1.1, T.7.1.4, P.6, R5, I.5+E.1+… (trazabilidad Excel/VLOOKUP).
Para MATURITY manual suele coincidir con code (R5, R9) o etiqueta Excel (R10→R9).
';

COMMENT ON COLUMN catalog.maturity_requirement_catalog.scoring_mode IS 'INHERITED → F_n derivado on-read; sin PATCH de score en Madurez.
MANUAL    → evaluador califica en hoja Madurez (maturity_requirement_response).
';

COMMENT ON COLUMN catalog.maturity_requirement_catalog.inherit_rule IS 'NONE               → scoring_mode=MANUAL.
CONTROL_SCORE      → F_n = control_response.score_value del control hoja (ADMIN o TECH).
PHVA_ITEM_SCORE    → F_n = effective_score de assessment_phva_item (source_phva_item_code).
PHVA_COMPOSITE_AVG → F_n = round_half_up(avg(effective_score)) sobre composite_phva_codes (R41).
';

COMMENT ON COLUMN catalog.maturity_requirement_catalog.source_control_node_id IS 'CONTROL_SCORE: nodo hoja en catálogo (control_type ADMIN o TECH según source_type).
En evaluación: resolver assessment_control_node por source_catalog_node_id.
';

COMMENT ON COLUMN catalog.maturity_requirement_catalog.source_phva_item_code IS 'PHVA_ITEM_SCORE: P.1, P.6, P.8, M.2, … (un solo ítem PHVA).';

COMMENT ON COLUMN catalog.maturity_requirement_catalog.composite_phva_codes IS 'PHVA_COMPOSITE_AVG: array JSON ordenado de códigos PHVA.
Seed R41: ["I.5","E.1","E.2","E.3","M.1"] — promedio de effective_score (excl. NA).
';

CREATE TABLE catalog.maturity_requirement_control_map (
    id uuid NOT NULL,
    requirement_id uuid NOT NULL,
    control_node_id uuid NOT NULL
);

COMMENT ON TABLE catalog.maturity_requirement_control_map IS 'Enlace explícito requisito ↔ control (trazabilidad). Implementación v1: preferir
maturity_requirement_catalog.source_control_node_id (1:1). Esta tabla es opcional
para seeds que prefieren normalizar el mapa; debe ser coherente con source_control_node_id.
';

CREATE TABLE catalog.maturity_threshold (
    id uuid NOT NULL,
    requirement_id uuid NOT NULL,
    level integer NOT NULL,
    is_na boolean DEFAULT false NOT NULL,
    expected_value integer
);

COMMENT ON TABLE catalog.maturity_threshold IS 'HU-MAD-02 — matriz de umbrales. Participación en nivelCumple(L):
  solo requisitos n con fila (n,L) donde is_na=false.
estado(F_n,U): si is_na o F_n es N/A → celda N/A; si F_n null sin calificar → tratar como 0 o
  mensaje "requiere calificación" (HU-MAD-01 #64) según política UI.
';

COMMENT ON COLUMN catalog.maturity_threshold.level IS '1..5 — N1 Inicial … N5 Optimizado';

COMMENT ON COLUMN catalog.maturity_threshold.is_na IS 'TRUE → celda N/A (requisito no se evalúa en este nivel; HU-MAD-02 #67).
FALSE → expected_value obligatorio (0|20|40|60|80|100 según escala).
';

COMMENT ON COLUMN catalog.maturity_threshold.expected_value IS 'Umbral U_{n,L} del Excel. NULL cuando is_na=true.
CHECK app: (is_na AND expected_value IS NULL) OR (NOT is_na AND expected_value IS NOT NULL).
';

CREATE TABLE catalog.nist_ciber_item_catalog (
    id uuid NOT NULL,
    template_version_id uuid NOT NULL,
    function_id uuid NOT NULL,
    subcategory_id uuid NOT NULL,
    title character varying(300),
    scoring_mode character varying(12) DEFAULT 'INHERITED'::character varying NOT NULL,
    source_type character varying(12) NOT NULL,
    inherit_rule character varying(24) DEFAULT 'NONE'::character varying NOT NULL,
    source_control_node_id uuid,
    iso_control_code character varying(80),
    "position" integer NOT NULL,
    active boolean DEFAULT true NOT NULL
);

COMMENT ON TABLE catalog.nist_ciber_item_catalog IS 'HU-CIB-01..03 — fuente de verdad de la hoja Ciber por instrumento publicado.
Paridad Excel MSPI v1:
  ~13 filas NIST puras (MANUAL, source_type=NIST, ej. ID.GV-4 sin A.x.y.z).
  ~175 filas con VLOOKUP a Administrativas/Técnicas (INHERITED, iso_control_code + control hoja).
Un control ISO puede generar varias filas (varias subcategorías / funciones); misma calificación en todas.
Promedio por función (HU-CIB-02): avg sobre todas las filas activas de la función con score calculable (excl. NA);
  cada fila del catálogo cuenta en su función (réplica filas repetidas del Excel, no deduplicar por control).
Validación app al publicar template:
  MANUAL ⇒ inherit_rule=NONE, source_type=NIST, source_control_node_id IS NULL.
  INHERITED ⇒ inherit_rule=CONTROL_SCORE, source_type IN (ADMIN,TECH), source_control_node_id NOT NULL.
  function_id = subcategory.function_id.
Coherencia: por cada fila INHERITED existe fila equivalente en nist_mapping (opcional script de validación).
';

COMMENT ON COLUMN catalog.nist_ciber_item_catalog.function_id IS 'Denormalizado desde nist_subcategory.function_id — acelera agrupación HU-CIB-02.
Debe coincidir con la función de subcategory_id.
';

COMMENT ON COLUMN catalog.nist_ciber_item_catalog.title IS 'Texto fila Ciber / descripción corta (opcional; UI puede usar subcategory.description).';

COMMENT ON COLUMN catalog.nist_ciber_item_catalog.scoring_mode IS 'INHERITED → calificación on-read desde control hoja (HU-CIB-01 #81).
MANUAL    → calificación en hoja Ciber (HU-CIB-01 #82) — requisitos 100% NIST sin ISO.
';

COMMENT ON COLUMN catalog.nist_ciber_item_catalog.source_type IS 'ADMIN | TECH | NIST — hoja origen (HU-CIB-01 #80).
NIST  → solo cuando scoring_mode=MANUAL (sin control ISO).
ADMIN/TECH → scoring_mode=INHERITED con source_control_node_id.
';

COMMENT ON COLUMN catalog.nist_ciber_item_catalog.inherit_rule IS 'NONE           → scoring_mode=MANUAL.
CONTROL_SCORE  → F_i = control_response.score_value del control hoja (réplica VLOOKUP Administrativas/Técnicas).
';

COMMENT ON COLUMN catalog.nist_ciber_item_catalog.source_control_node_id IS 'CONTROL_SCORE: nodo hoja en catálogo (control_type ADMIN o TECH según source_type).
En evaluación: resolver assessment_control_node por source_catalog_node_id.
NULL cuando scoring_mode=MANUAL (subcategoría NIST pura).
';

COMMENT ON COLUMN catalog.nist_ciber_item_catalog.iso_control_code IS 'Referencia ISO 27001 (A.5.1.1, …) para filas INHERITED — columna C Excel / trazabilidad.
NULL en filas MANUAL puras NIST.
';

COMMENT ON COLUMN catalog.nist_ciber_item_catalog."position" IS 'Orden de fila en hoja Ciber (1..~201). Filas 1–13 típicamente MANUAL; 26–201 INHERITED.
Filas 14–25 reservadas/vacías en Excel original — no sembrar o marcar inactive si no aplican.
';

CREATE TABLE catalog.nist_function (
    id uuid NOT NULL,
    code character varying(20) NOT NULL,
    name character varying(120) NOT NULL,
    "position" integer DEFAULT 0 NOT NULL
);

COMMENT ON TABLE catalog.nist_function IS 'Catálogo global de funciones NIST (no varía por template_version).
Agrupación HU-CIB-02: promedio(f) sobre filas cuya subcategoría pertenece a function_id.
';

COMMENT ON COLUMN catalog.nist_function.code IS 'ID = Identificar | PR = Proteger | DE = Detectar | RS = Responder | RC = Recuperar.
HU-CIB-01 #80 — cinco funciones del NIST CSF.
';

COMMENT ON COLUMN catalog.nist_function.name IS 'Nombre en español para UI (Identificar, Proteger, …).';

COMMENT ON COLUMN catalog.nist_function."position" IS 'Orden de presentación en tablero/radar (1..5).';

CREATE TABLE catalog.nist_mapping (
    id uuid NOT NULL,
    template_version_id uuid NOT NULL,
    subcategory_id uuid NOT NULL,
    control_node_id uuid,
    iso_control_code character varying(80)
);

COMMENT ON TABLE catalog.nist_mapping IS 'Trazabilidad control ↔ subcategoría para detalle de control (HU-ADM-04 #38) y seeds.
Debe ser coherente con filas INHERITED de nist_ciber_item_catalog (mismo template, subcategory, control).
NO sustituye el catálogo de filas Ciber: la evaluación y promedios usan nist_ciber_item_catalog + snapshot.
';

COMMENT ON COLUMN catalog.nist_mapping.control_node_id IS 'Control hoja ADMIN o TECH (is_scored=true). NULL solo si fila es subcategoría NIST sin ISO (no aplica aquí;
esas filas viven solo en nist_ciber_item_catalog con scoring_mode=MANUAL).
';

COMMENT ON COLUMN catalog.nist_mapping.iso_control_code IS 'A.x.y.z — clave VLOOKUP Excel (columna C hoja Ciber).';

CREATE TABLE catalog.nist_subcategory (
    id uuid NOT NULL,
    function_id uuid NOT NULL,
    code character varying(40) NOT NULL,
    description text,
    active boolean DEFAULT true NOT NULL
);

COMMENT ON TABLE catalog.nist_subcategory IS 'Subcategorías NIST CSF referenciadas por la hoja Ciber.
Un mismo iso_control_code puede mapear a varias subcategorías (varias filas Ciber).
';

COMMENT ON COLUMN catalog.nist_subcategory.code IS 'ID.AM-1, PR.AC-1, DE.CM-1, RS.RP-1, RC.RP-1, …';

CREATE TABLE catalog.phva_item_catalog (
    id uuid NOT NULL,
    template_version_id uuid NOT NULL,
    code character varying(40) NOT NULL,
    component character varying(10) NOT NULL,
    title character varying(280) NOT NULL,
    description text,
    test_guidance text,
    scoring_mode character varying(12) DEFAULT 'MANUAL'::character varying NOT NULL,
    inherit_rule character varying(24) DEFAULT 'NONE'::character varying NOT NULL,
    source_control_code character varying(40),
    source_control_node_id uuid,
    "position" integer NOT NULL,
    active boolean DEFAULT true NOT NULL,
    parent_code character varying(40),
    node_type character varying(12) DEFAULT 'ITEM'::character varying NOT NULL
);

COMMENT ON TABLE catalog.phva_item_catalog IS 'HU-PHVA-01..04 — catálogo paramétrico de la hoja PHVA (~17 filas por template_version).
Seed MSPI v1 (referencia Historias v2):
  PLAN (8 en promedio): P.1 MANUAL; P.2 INHERITED CONTROL_ROLLUP→AD.1; P.3 MANUAL; P.4→AD.2.1.1;
    P.5→AD.4.1.1; P.6 MANUAL; P.8 MANUAL; P.9→AD.3.2.2  (P.7 no aplica en promedio documentado).
  DO (4): I.1,I.3,I.4 MANUAL; I.2 INHERITED ANEXO_A_OVERALL.
  CHECK (3): E.1,E.2,E.3 MANUAL.
  ACT (2): M.1,M.2 MANUAL.
Validación app: inherit_rule≠NONE ⇒ scoring_mode=INHERITED y source_control_node_id NOT NULL
  (excepto ANEXO_A_OVERALL que no requiere source_control_node_id).
';

COMMENT ON COLUMN catalog.phva_item_catalog.code IS 'P.1, P.2, I.2, E.1, M.1, … (~17 requisitos por template publicado).';

COMMENT ON COLUMN catalog.phva_item_catalog.component IS 'PLAN | DO | CHECK | ACT
PLAN = Planificación (peso 40) | DO = Implementación (20) | CHECK = Evaluación desempeño (20) | ACT = Mejora (20)
';

COMMENT ON COLUMN catalog.phva_item_catalog.scoring_mode IS 'MANUAL    → evaluador califica en hoja PHVA (phva_item_response).
INHERITED → solo lectura; valor derivado on-read (sin PATCH de score).
';

COMMENT ON COLUMN catalog.phva_item_catalog.inherit_rule IS 'NONE              → scoring_mode=MANUAL (sin origen externo).
CONTROL_SCORE     → copiar score de control hoja ADMIN (source_control_node_id = hoja).
CONTROL_ROLLUP    → copiar promedio rollup del nodo ADMIN interno (objetivo/dominio; source = nodo padre).
ANEXO_A_OVERALL   → promedio total Anexo A ADMIN+TECH (solo I.2; HU-PHVA-02 / HU-DIAG-01).
';

COMMENT ON COLUMN catalog.phva_item_catalog.source_control_code IS 'Código instrumento origen ej. AD.1, AD.2.1.1, AD.4.1.1, AD.3.2.2 (trazabilidad Excel).';

COMMENT ON COLUMN catalog.phva_item_catalog.source_control_node_id IS 'Nodo catálogo origen para INHERITED (CONTROL_SCORE o CONTROL_ROLLUP).
En evaluación se resuelve vía assessment_control_node.source_catalog_node_id.
';

CREATE TABLE catalog.question_bank (
    id uuid NOT NULL,
    name character varying(160) NOT NULL,
    description character varying(500),
    scale_id uuid,
    status character varying(20) DEFAULT 'DRAFT'::character varying NOT NULL,
    is_base boolean DEFAULT false NOT NULL,
    deleted_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);

COMMENT ON COLUMN catalog.question_bank.is_base IS 'true = elemento base del instrumento MSPI (no eliminable).';

COMMENT ON COLUMN catalog.question_bank.deleted_at IS 'Borrado lógico tras aprobación y gracia. NULL = activa.';

CREATE TABLE catalog.question_bank_question (
    id uuid NOT NULL,
    question_bank_id uuid NOT NULL,
    code character varying(60) NOT NULL,
    domain character varying(40),
    control character varying(120),
    question_text text NOT NULL,
    category character varying(120),
    evaluation_type character varying(30),
    expected_evidence character varying(1000),
    compliance_criteria character varying(1000),
    mspi_level character varying(60),
    nist_function character varying(60),
    is_active boolean DEFAULT true NOT NULL,
    scale_id uuid,
    "position" integer DEFAULT 0 NOT NULL,
    is_selected boolean DEFAULT true NOT NULL,
    is_required boolean DEFAULT false NOT NULL
);

CREATE TABLE catalog.scale (
    id uuid NOT NULL,
    name character varying(140) NOT NULL,
    description character varying(400),
    is_base boolean DEFAULT false NOT NULL,
    deleted_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

COMMENT ON COLUMN catalog.scale.is_base IS 'true = elemento base del instrumento MSPI (no eliminable).';

COMMENT ON COLUMN catalog.scale.deleted_at IS 'Borrado lógico tras aprobación y gracia. NULL = activa.';

CREATE TABLE catalog.scale_band (
    id uuid NOT NULL,
    scale_version_id uuid NOT NULL,
    min_value integer NOT NULL,
    max_value integer NOT NULL,
    label character varying(60) NOT NULL,
    "position" integer NOT NULL
);

COMMENT ON COLUMN catalog.scale_band.label IS 'INEXISTENTE|INICIAL|REPETIBLE|EFECTIVO|GESTIONADO|OPTIMIZADO';

CREATE TABLE catalog.scale_level (
    id uuid NOT NULL,
    scale_version_id uuid NOT NULL,
    label character varying(80) NOT NULL,
    value integer,
    is_na boolean DEFAULT false NOT NULL,
    criteria_text character varying(1200),
    "position" integer NOT NULL
);

COMMENT ON COLUMN catalog.scale_level.value IS '0|20|40|60|80|100; null si is_na=true';

CREATE TABLE catalog.scale_version (
    id uuid NOT NULL,
    scale_id uuid NOT NULL,
    version integer NOT NULL,
    status character varying(20) DEFAULT 'DRAFT'::character varying NOT NULL,
    published_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

COMMENT ON COLUMN catalog.scale_version.status IS 'DRAFT|PUBLISHED';

CREATE SEQUENCE catalog.seq_catalog_deletion_request_number
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

CREATE TABLE catalog.steward_role (
    code character varying(60) NOT NULL,
    label character varying(160) NOT NULL,
    sort_order integer DEFAULT 0 NOT NULL,
    active boolean DEFAULT true NOT NULL
);

COMMENT ON TABLE catalog.steward_role IS 'HU-AR-01 regla: el cargo es metadata del instrumento; seed en ms_catalog.
Cada control hoja (ADM/TEC) referencia un default_steward_role_code; cada fila assessment_area_topic puede
cubrir el mismo código para asignar funcionario que luego se propaga a todos los control_response con FROM_AREA.
';

COMMENT ON COLUMN catalog.steward_role.code IS 'Código estable ej. RESP_CONTROL_INTERNO | RESP_GESTION_HUMANA | LIDER_PROCESO_COMPRAS |
RESP_COMPRAS | RESP_CONTINUIDAD | RESP_SEG_FISICA | RESP_TICS | RESP_SI
(ajustar nomenclatura exacta al seed oficial / Excel).
';

COMMENT ON COLUMN catalog.steward_role.label IS 'Etiqueta UI y reporte, ej. Responsable de SI';

CREATE TABLE catalog.template (
    id uuid NOT NULL,
    name character varying(180) NOT NULL,
    description character varying(500),
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE catalog.template_version (
    id uuid NOT NULL,
    template_id uuid NOT NULL,
    scale_version_id uuid NOT NULL,
    version integer NOT NULL,
    status character varying(20) DEFAULT 'DRAFT'::character varying NOT NULL,
    published_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    maturity_global_rule character varying(40),
    maturity_crit_thresholds jsonb,
    phva_weights jsonb,
    phva_caps jsonb,
    nist_function_targets jsonb
);

COMMENT ON TABLE catalog.template_version IS 'Toda evaluación referencia una template_version publicada (FK assessment.template_version_id).';

COMMENT ON COLUMN catalog.template_version.status IS 'DRAFT|PUBLISHED';

COMMENT ON COLUMN catalog.template_version.maturity_global_rule IS 'MIN|AVG|MAJORITY — legacy Excel; HU-MAD no lo usa en v1.';

COMMENT ON COLUMN catalog.template_version.maturity_crit_thresholds IS 'HU-MAD-05 — umbrales de conteo de MENOR por nivel → SUFICIENTE | INTERMEDIO | CRÍTICO.
Seed MSPI v1 (límites exclusivos superiores, igual pseudocódigo Historias v2):
{
  "1": {"sufficientMax": 3, "intermediateMax": 7},
  "2": {"sufficientMax": 7, "intermediateMax": 15},
  "3": {"sufficientMax": 14, "intermediateMax": 30},
  "4": {"sufficientMax": 20, "intermediateMax": 40},
  "5": {"sufficientMax": 20}
}
Interpretación: menores(L) < sufficientMax → SUFICIENTE;
  menores(L) < intermediateMax → INTERMEDIO; si no → CRÍTICO.
Nivel 5: sin rango INTERMEDIO explícito (≥ intermediateMax ⇒ CRÍTICO).
requisitos(L) = { n : maturity_threshold(n,L).is_na = false }.
';

COMMENT ON COLUMN catalog.template_version.phva_weights IS 'HU-PHVA-01..05 — pesos por componente (enteros, suma = 100). Seed MSPI v1:
{"PLAN": 40, "DO": 20, "CHECK": 20, "ACT": 20}
PLAN=Planificación | DO=Implementación | CHECK=Evaluación desempeño | ACT=Mejora continua
';

COMMENT ON COLUMN catalog.template_version.phva_caps IS 'HU-PHVA-01..05 — topes de avance ponderado por componente (mismo esquema de claves que phva_weights).
Seed MSPI v1: {"PLAN": 40, "DO": 20, "CHECK": 20, "ACT": 20}
L_C_capado = min(cap[C], (avg(requisitos C) × peso[C]) / 100)
';

COMMENT ON COLUMN catalog.template_version.nist_function_targets IS 'HU-CIB-02 #86 — meta de cumplimiento por función NIST (configurable por template publicada).
Seed MSPI v1 (por defecto 60 en las cinco funciones; ideal para radar HU-CIB-03):
{
  "ID": 60, "PR": 60, "DE": 60, "RS": 60, "RC": 60,
  "ideal": 100
}
Claves ID|PR|DE|RS|RC = catalog.nist_function.code.
estado(f) = ALCANZA si promedio(f) ≥ meta(f); NO ALCANZA si promedio(f) < meta(f).
brecha(f) = meta(f) - promedio(f) cuando NO ALCANZA (≥ 0).
';

CREATE TABLE evidence.assessment_context (
    assessment_id uuid NOT NULL,
    mission text,
    context_analysis text,
    process_map text,
    organigram text,
    self_perception_concern text,
    self_perception_maturity text,
    self_perception_phva_component text,
    updated_by uuid,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    version integer DEFAULT 0 NOT NULL
);

COMMENT ON TABLE evidence.assessment_context IS 'HU-CFG-03/04: solo texto; no participa en cálculos numéricos (criterio 11).
Adjuntos HU-CFG-03: evidence.evidence_file con relation_type=CONTEXT,
relation_id=assessment_id, context_field=MISSION|CONTEXT_ANALYSIS|PROCESS_MAP|ORGANIGRAM.
MIME: pdf, docx, png, jpg, jpeg (validar contra admin.system_config evidence.allowedMimeTypes).
HU-CFG-04: comparación en reporte es responsabilidad de reporting (Módulo 8/9), datos aquí.
';

COMMENT ON COLUMN evidence.assessment_context.assessment_id IS 'Relación 1:1 con assessment. Crear fila vacía al crear evaluación.';

COMMENT ON COLUMN evidence.assessment_context.self_perception_concern IS '¿Qué le preocupa a la entidad?';

COMMENT ON COLUMN evidence.assessment_context.self_perception_maturity IS '¿En qué nivel de madurez considera estar?';

COMMENT ON COLUMN evidence.assessment_context.self_perception_phva_component IS '¿En qué componente PHVA cree estar?';

COMMENT ON COLUMN evidence.assessment_context.version IS 'Versión para autoguardado del bloque contexto.';

CREATE TABLE evidence.evidence_file (
    id uuid NOT NULL,
    assessment_id uuid,
    relation_type character varying(20) NOT NULL,
    relation_id uuid NOT NULL,
    context_field character varying(30),
    filename character varying(260) NOT NULL,
    content_type character varying(120) NOT NULL,
    size_bytes bigint NOT NULL,
    sha256 character varying(80) NOT NULL,
    bucket character varying(120) NOT NULL,
    object_key character varying(500) NOT NULL,
    uploaded_by uuid NOT NULL,
    uploaded_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone
);

COMMENT ON TABLE evidence.evidence_file IS 'Múltiples archivos por ítem de inventario (HU-CFG-05) vía LIFTING_DOC + mismo relation_id.
HU-REP-01..04: un evidence_file por report_generation_job completado (PDF o XLSX); content_type application/pdf
  o application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.
';

COMMENT ON COLUMN evidence.evidence_file.relation_type IS 'CONTROL_RESPONSE (alias documental CONTROL) → relation_id = assessment_control_node.id
  Usado por HU-ADM-01 #25 y HU-TEC-01 #40 para adjuntos de evidencia del control.
LIFTING_DOC → relation_id = lifting_document_delivery.id
CONTEXT → relation_id = assessment.id (ver context_field)
GLOBAL | GAP_ACTION | REPORT_OUTPUT
';

COMMENT ON COLUMN evidence.evidence_file.relation_id IS 'REPORT_OUTPUT → relation_id = reporting.report_generation_job.id (HU-REP-01/02/03/04).
GAP_ACTION → relation_id = assessment.gap_register.id
';

COMMENT ON COLUMN evidence.evidence_file.context_field IS 'Solo si relation_type=CONTEXT: MISSION|CONTEXT_ANALYSIS|PROCESS_MAP|ORGANIGRAM';

CREATE TABLE evidence.lifting_answer (
    id uuid NOT NULL,
    assessment_id uuid NOT NULL,
    question_catalog_id uuid NOT NULL,
    answer_json jsonb NOT NULL,
    updated_by uuid,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    version integer DEFAULT 0 NOT NULL
);

CREATE TABLE evidence.lifting_document_delivery (
    id uuid NOT NULL,
    assessment_id uuid NOT NULL,
    document_item_catalog_id uuid NOT NULL,
    delivery_status character varying(20) DEFAULT 'NOT_DELIVERED'::character varying NOT NULL,
    delivered_name character varying(260),
    notes text,
    validated_by uuid,
    validated_at timestamp with time zone,
    updated_by uuid,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    version integer DEFAULT 0 NOT NULL
);

COMMENT ON TABLE evidence.lifting_document_delivery IS 'FK compuesta lógica: (assessment_id, document_item_catalog_id) única.
Archivos: evidence_file.relation_type=LIFTING_DOC, relation_id=id (esta tabla).
';

COMMENT ON COLUMN evidence.lifting_document_delivery.delivery_status IS 'HU-CFG-05 (entregado / no entregado / parcial):
- DELIVERED
- NOT_DELIVERED
- PARTIAL
Regla sugerida: PARTIAL si hay delivered_name o adjuntos pero incompleto; manual permitido.
';

COMMENT ON COLUMN evidence.lifting_document_delivery.delivered_name IS 'Nombre del documento entregado (HU-CFG-05).';

COMMENT ON COLUMN evidence.lifting_document_delivery.notes IS 'Observaciones del evaluador.';

CREATE TABLE evidence.process_scope_metric (
    assessment_id uuid NOT NULL,
    total_processes integer DEFAULT 0 NOT NULL,
    in_scope_processes integer DEFAULT 0 NOT NULL,
    coverage numeric(6,4),
    in_scope_exceeds_total boolean DEFAULT false NOT NULL,
    updated_by uuid,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);

COMMENT ON TABLE evidence.process_scope_metric IS 'Relación 1:1 con assessment. Crear al crear evaluación con ceros.
';

COMMENT ON COLUMN evidence.process_scope_metric.total_processes IS 'Total procesos de la entidad. 0 → coverage NULL (no aplica).';

COMMENT ON COLUMN evidence.process_scope_metric.in_scope_processes IS 'Procesos en alcance del MSPI.';

COMMENT ON COLUMN evidence.process_scope_metric.coverage IS 'HU-CFG-05 ítem 43: %MSPI = in_scope_processes / total_processes.
Calculado en app/trigger: NULL si total_processes=0 (UI muestra "no aplica").
Si total_processes>0: round(4 decimales). Ej. 5/20 = 0.25 (25%).
';

COMMENT ON COLUMN evidence.process_scope_metric.in_scope_exceeds_total IS 'HU-CFG-05: true si in_scope_processes > total_processes → advertencia en UI.';

CREATE TABLE iam.login_attempt (
    identifier character varying(254) NOT NULL,
    failed_count integer DEFAULT 0 NOT NULL,
    locked_until timestamp with time zone,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE iam.notification (
    id uuid NOT NULL,
    user_id uuid NOT NULL,
    type character varying(40) NOT NULL,
    priority character varying(10) DEFAULT 'MEDIUM'::character varying NOT NULL,
    title character varying(200) NOT NULL,
    message character varying(1000) NOT NULL,
    assessment_id uuid,
    assessment_name character varying(200),
    is_read boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    action_url character varying(400),
    read_at timestamp with time zone,
    cleared_at timestamp with time zone
);

COMMENT ON COLUMN iam.notification.read_at IS 'Momento en que el usuario marcó la notificación como leída';

COMMENT ON COLUMN iam.notification.cleared_at IS 'Borrado lógico tras limpieza; NULL = visible en listado';

CREATE TABLE iam.password_reset_request (
    id uuid NOT NULL,
    target_user_id uuid NOT NULL,
    target_user_name character varying(200),
    target_user_email character varying(254),
    request_number character varying(32),
    requested_by uuid NOT NULL,
    requested_by_name character varying(200),
    reason text,
    status character varying(20) DEFAULT 'PENDING'::character varying NOT NULL,
    decision_by uuid,
    decision_by_name character varying(200),
    decision_at timestamp with time zone,
    decision_comment text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    executed_at timestamp with time zone,
    email_sent boolean DEFAULT false NOT NULL,
    email_error text
);

COMMENT ON TABLE iam.password_reset_request IS 'Solicitudes de reenvío de contraseña temporal + reset 2FA (aprobación AdminSistema).';

COMMENT ON COLUMN iam.password_reset_request.request_number IS 'Código legible SOL-PWD-###### (sin UUID).';

COMMENT ON COLUMN iam.password_reset_request.status IS 'PENDING|APPROVED|REJECTED|CANCELLED';

COMMENT ON COLUMN iam.password_reset_request.email_sent IS 'true si el correo con la temporal se envió tras aprobar; false = reintentable.';

CREATE TABLE iam.role (
    id uuid NOT NULL,
    name character varying(60) NOT NULL,
    description character varying(300)
);

COMMENT ON TABLE iam.role IS 'Opcional si los roles vienen SOLO de Keycloak.';

COMMENT ON COLUMN iam.role.name IS 'AdminSistema|AdminInstrumento|Evaluador|Revisor|Lector';

CREATE SEQUENCE iam.seq_password_reset_request_number
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

CREATE TABLE iam."user" (
    id uuid NOT NULL,
    keycloak_sub character varying(80) NOT NULL,
    full_name character varying(200) NOT NULL,
    email character varying(254) NOT NULL,
    organization_id uuid,
    must_change_password boolean DEFAULT false NOT NULL,
    password_hash character varying(255),
    failed_attempts integer DEFAULT 0 NOT NULL,
    locked_until timestamp with time zone,
    status character varying(20) DEFAULT 'ACTIVE'::character varying NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);

COMMENT ON COLUMN iam."user".keycloak_sub IS 'Subject (sub) del JWT Keycloak. Identificador estable del usuario.';

COMMENT ON COLUMN iam."user".organization_id IS 'Opcional. Obligatorio para rol Lector. ms_org valida existencia.';

COMMENT ON COLUMN iam."user".must_change_password IS 'Primer login o política: fuerza cambio de contraseña.';

COMMENT ON COLUMN iam."user".password_hash IS 'NO usar con Keycloak.';

COMMENT ON COLUMN iam."user".failed_attempts IS 'NO usar con Keycloak.';

COMMENT ON COLUMN iam."user".locked_until IS 'NO usar con Keycloak.';

COMMENT ON COLUMN iam."user".status IS 'ACTIVE|INACTIVE';

CREATE TABLE iam.user_role (
    user_id uuid NOT NULL,
    role_id uuid NOT NULL,
    assigned_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE iam.user_totp (
    keycloak_sub character varying(80) NOT NULL,
    secret character varying(255) NOT NULL,
    enabled_at timestamp with time zone
);

COMMENT ON TABLE iam.user_totp IS 'Implementado en ms_iam. Keycloak no almacena el secreto TOTP de la app.';

COMMENT ON COLUMN iam.user_totp.keycloak_sub IS 'Mismo sub que iam.user. 2FA TOTP opcional (ms_iam /auth/totp/*).';

COMMENT ON COLUMN iam.user_totp.secret IS 'Secreto Base32; se persiste en setup y se activa en verify.';

COMMENT ON COLUMN iam.user_totp.enabled_at IS 'NULL hasta verificar el primer código TOTP válido.';

CREATE TABLE org.organization (
    id uuid NOT NULL,
    name character varying(220) NOT NULL,
    identifier character varying(40),
    type character varying(40),
    status character varying(20) DEFAULT 'ACTIVE'::character varying NOT NULL,
    email character varying(160),
    address character varying(250),
    city character varying(120),
    department character varying(120),
    country character varying(120),
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);

COMMENT ON COLUMN org.organization.name IS 'Nombre legal de la entidad. Cabecera UI: assessment.organization_name_snapshot.';

COMMENT ON COLUMN org.organization.identifier IS 'NIT u otro identificador';

COMMENT ON COLUMN org.organization.type IS 'Sector legal: PUBLIC|PRIVATE|EDU|OTHER. NO confundir con catalog.entity_order_type (MSPI).';

CREATE TABLE org.organization_area_base (
    id uuid NOT NULL,
    organization_id uuid NOT NULL,
    area_name character varying(160) NOT NULL,
    description character varying(300),
    is_critical boolean DEFAULT false NOT NULL,
    "position" integer DEFAULT 0 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE org.organization_area_base_topic (
    id uuid NOT NULL,
    area_base_id uuid NOT NULL,
    topic character varying(220) NOT NULL,
    process_description character varying(400),
    default_steward_role_code character varying(60),
    staff_name character varying(200),
    staff_role character varying(160),
    staff_contact character varying(200),
    notes character varying(600),
    "position" integer DEFAULT 0 NOT NULL
);

COMMENT ON COLUMN org.organization_area_base_topic.process_description IS 'HU-AR-01: descripción del proceso (p. ej. líder de proceso específico).';

COMMENT ON COLUMN org.organization_area_base_topic.default_steward_role_code IS 'Código del cargo Responsable Excel (HU-AR-01). Debe igualar catalog/assessment_control_node.default_steward_role_code
para propagación masiva de persona asignada a ese cargo en esta fila temática.
';

COMMENT ON COLUMN org.organization_area_base_topic.staff_role IS 'Cargo textual mostrado (puede coincidir con steward_role.label); captura.';

CREATE TABLE org.organization_contact (
    id uuid NOT NULL,
    organization_id uuid NOT NULL,
    full_name character varying(200) NOT NULL,
    role character varying(120),
    email character varying(254),
    phone character varying(40),
    is_primary boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

COMMENT ON TABLE org.organization_contact IS 'Contacto maestro de la org. HU-CFG-01 ''contacto'' de la evaluación va en assessment.contact (por evaluación).';

CREATE TABLE reporting.analytics_cache (
    id uuid NOT NULL,
    assessment_id uuid NOT NULL,
    kind character varying(30) NOT NULL,
    payload_json jsonb NOT NULL,
    source_hash character varying(80) NOT NULL,
    computed_at timestamp with time zone DEFAULT now() NOT NULL
);

COMMENT ON TABLE reporting.analytics_cache IS 'UNIQUE (assessment_id, kind): una fila por agregado por evaluación (COMPARATIVE: usar assessment_id = PRIMARY).
Módulo 8: ms_assessment on-read en tablero activo; Módulo 9: ms_reporting materializa al generar PDF/Excel async.
HU-DIAG #93: tablero sin cache obligatorio; jobs M9 recomiendan recompute DIAGNOSTIC+GAPS antes de FULL_DIAGNOSTIC_PDF.
COMPARATIVE: kind único por job_id puede almacenarse con assessment_id = evaluación PRIMARY y payload referencia jobId.
';

COMMENT ON COLUMN reporting.analytics_cache.kind IS 'Kinds por agregado (HU-DIAG / ms_reporting — todos opcionales, invalidar con source_hash al cambiar scores):

ROLLUP | ROLLUP_ADMIN | ROLLUP_TECH — árbol recursivo completo (M3/M4 detalle; base de DIAG-01).
  payload: {overallAverage, overallBandLabel, roots:[RollupNode...]} (misma forma que API scores/rollup).

DOMAIN_EFFECTIVENESS — HU-DIAG-01 tabla Portada (14 dominios + total).
  payload: {
    domains:[{
      isoDomainCode, name, controlType, displayPosition,
      currentScore, targetScore:100, bandLabel,
      assessmentControlNodeId, calculable:boolean
    }],
    overallAverage, overallBandLabel,
    adminDomainCount:7, techDomainCount:7
  }
  Cálculo: extraer nodos node_type=DOMAIN del rollup (o join iso_domain.display_position ORDER BY).

PHVA — HU-DIAG-02 (+ PHVA-05).
  payload: {
    components:[{code,label,weight,cap,avgK,weightedL,cappedL,expectedWeight,breach,
      drillDownQuery:"/assessments/{id}/phva/items?component={code}"}],
    totalCapped, totalExpected:100,
    entityExpectedAdvance, overallBreach,
    visualizationHint:"STACKED_BAR|DONUT"
  }

MATURITY — HU-DIAG-03 (+ MAD-04..05).
  payload: {
    nivelAlcanzado,
    levels:[{
      level, nivelCumple, menoresCount, totalRequirements, compliancePercent,
      categoria, drillDownQuery:"/assessments/{id}/maturity/requirements?level={L}&status=MENOR"
    }],
    blockingToNextLevel:{
      targetLevel, targetLevelLabel,
      blockingRequirements:[{requirementId,code,title,level,status:"MENOR",effectiveScore}]
    },
    matrixSummary opcional (misma que API maturity/summary.matrix, recortada)
  }
  totalRequirements(L) = #{req : threshold(req,L).is_na = false}
  compliancePercent(L) = round( (totalRequirements(L) - menores(L)) / totalRequirements(L) * 100 )
  blockingToNextLevel: si nivelAlcanzado=''NO ALCANZA NIVEL INICIAL'' → targetLevel=1 y reqs MENOR en L=1;
    si no, primer L con nivelCumple(L)=false → reqs MENOR en ese L (HU-DIAG-03 #101).

NIST — HU-DIAG-04 (+ CIB-02..03).
  payload: {
    functions:[{code,name,avgScore,target,ideal:100,status,breach,validCount}],
    visualizationHint:"RADAR|BAR",
    drillDownQuery:"/assessments/{id}/nist/items?functionCode={code}"
  }

DIAGNOSTIC — snapshot completo Portada (cache BFF para M8/M9 REP-01).
  payload: {
    assessmentHeader:{organizationName,evaluationDate,evaluator,periodLabel,scaleVersionId},
    domainEffectiveness: <DOMAIN_EFFECTIVENESS payload>,
    phva: <PHVA payload>,
    maturity: <MATURITY payload>,
    nist: <NIST payload>,
    selfPerceptionComparison:{
      subjective:{concern,maturityText,phvaComponentText},
      objective:{maturityLevel,phvaLeadingComponentCode,phvaLeadingComponentLabel,
        domainOverallAverage,domainOverallBand}
    },
    computedAt
  }
  selfPerceptionComparison: texto libre (evidence.assessment_context) vs campos calculados;
    phvaLeadingComponent = componente con mayor cappedL (desempate: PLAN>DO>CHECK>ACT).

SCALE_PUBLISHED — HU-REP-01 sección escala (#106).
  payload: { scaleVersionId, levels:[{value,label,criteriaText,isNa}], bands:[{min,max,label}] }

GAPS — HU-REP-01 sección brechas + HU-REP-03 listado/export (#112–115).
  payload: {
    threshold:60,
    items:[{
      assessmentControlNodeId, controlCode, isoCode, isoDomainCode, controlType,
      title, currentScore, gapTo100,  // gapTo100 = 100 - score
      recommendation,  // COALESCE(control_response.recommendation_text, assessment_control_node.test_guidance)
      stewardName, stewardRole, areaName,
      gapText, priority
    }],
    filtersApplied:{ isoDomainCode, stewardRoleCode },
    sortedBy:"DOMAIN_THEN_SCORE_ASC"
  }
  Regla inclusión: is_scored=true AND score_status=SCORED AND score_value IS NOT NULL AND score_value < threshold (default 60).

COMPARATIVE — HU-REP-04 (#116–118).
  payload: {
    organizationId,
    assessments:[{ assessmentId, evaluationDate, periodLabel, sortOrder, role }],
    domains:[{
      isoDomainCode, name,
      values:[{ assessmentId, score, bandLabel }],
      delta:{ fromAssessmentId, toAssessmentId, scoreDiff, trend }
      // trend: IMPROVED | UNCHANGED | REGRESSED (UI verde/rojo #118)
    }],
    phva:{ values:[{ assessmentId, totalCapped }], delta, trend },
    maturity:{ values:[{ assessmentId, nivelAlcanzado }], delta, trend },
    nist:{ functions:[{ code, values:[{ assessmentId, avgScore }], delta, trend }] }
  }
';

COMMENT ON COLUMN reporting.analytics_cache.source_hash IS 'Hash estable de inputs (assessment.updated_at + max(score updated_at) + template_version_id)
para invalidar cache al PATCH control/phva/madurez/nist.
';

CREATE TABLE reporting.excel_sheet_mapping (
    id uuid NOT NULL,
    workbook_template_id uuid NOT NULL,
    sheet_key character varying(40) NOT NULL,
    excel_sheet_name character varying(80) NOT NULL,
    sheet_order integer NOT NULL,
    excel_layer character varying(12) NOT NULL,
    populate_mode character varying(20) DEFAULT 'VALUES_ONLY'::character varying NOT NULL,
    data_source character varying(40) NOT NULL,
    cell_map_json jsonb
);

COMMENT ON COLUMN reporting.excel_sheet_mapping.sheet_key IS 'PORTADA | LEVANTAMIENTO | AREAS | ADMINISTRATIVAS | TECNICAS | PHVA | MADUREZ | CIBER | ESCALA
';

COMMENT ON COLUMN reporting.excel_sheet_mapping.excel_sheet_name IS 'Nombre de pestaña en el archivo .xlsx.';

COMMENT ON COLUMN reporting.excel_sheet_mapping.sheet_order IS 'Orden 1..9 en el libro exportado.';

COMMENT ON COLUMN reporting.excel_sheet_mapping.excel_layer IS 'CAPTURE | CALC | CONFIG — capa lógica Historias v2.';

COMMENT ON COLUMN reporting.excel_sheet_mapping.populate_mode IS 'VALUES_ONLY — escribir solo celdas de entrada/calificación (HU-REP-02 #111 preserva fórmulas del template).
FORMULA_PRESERVE — no tocar celdas con fórmula en plantilla (detección por named range o mapa).
';

COMMENT ON COLUMN reporting.excel_sheet_mapping.data_source IS 'Origen de datos al exportar:
  DIAGNOSTIC_DASHBOARD | LIFTING | AREAS | CONTROLS_ADMIN | CONTROLS_TECH |
  PHVA_ITEMS | MATURITY_MATRIX | NIST_ITEMS | SCALE_CATALOG
';

COMMENT ON COLUMN reporting.excel_sheet_mapping.cell_map_json IS 'Opcional — mapa técnico hoja Excel → campos (paridad 1:1 Excel):
{ "ranges": [{ "namedRange":"ADM_SCORE_AD_1_1", "field":"controlResponses[code=AD.1.1].scoreValue" }, ...] }
Si null, ms_reporting usa convención documentada en código por sheet_key.
';

CREATE TABLE reporting.excel_workbook_template (
    id uuid NOT NULL,
    code character varying(60) NOT NULL,
    name character varying(120) NOT NULL,
    version integer DEFAULT 1 NOT NULL,
    storage_path character varying(500) NOT NULL,
    sheet_count integer DEFAULT 9 NOT NULL,
    active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

COMMENT ON TABLE reporting.excel_workbook_template IS 'Las 9 hojas del instrumento MinTIC (Historias v2 visión producto + REP-02 #109):
  1 Portada (resultados — datos desde M8/dashboard, no captura manual en Excel)
  2 Levantamiento (M1 — lifting_document_delivery + process_scope_metric + context)
  3 Áreas involucradas (M2 — assessment_area + assessment_area_topic)
  4 Administrativas (M3 — control_response hojas ADMIN)
  5 Técnicas (M4 — control_response hojas TECH)
  6 PHVA (M5 — phva items; INHERITED como valor efectivo en celda o fórmula externa según template)
  7 Madurez (M6 — matriz requisitos; mayoría derivada on-read)
  8 Ciber (M7 — filas nist ciber effective_score)
  9 Escala de evaluación (catálogo — scale_level + scale_band; referencia paramétrica)
Detalle de celdas destino por hoja: excel_sheet_mapping.cell_map_json (opcional en implementación).
';

COMMENT ON COLUMN reporting.excel_workbook_template.code IS 'MSPI_INSTRUMENT_XLSX_V1 — HU-REP-02.';

COMMENT ON COLUMN reporting.excel_workbook_template.storage_path IS 'Plantilla .xlsx maestra; fórmulas NO se sobrescriben al exportar (#111).';

CREATE TABLE reporting.report_generation_job (
    id uuid NOT NULL,
    assessment_id uuid NOT NULL,
    organization_id uuid NOT NULL,
    template_id uuid,
    workbook_template_id uuid,
    report_type character varying(40) NOT NULL,
    status character varying(20) DEFAULT 'PENDING'::character varying NOT NULL,
    page_format character varying(10),
    request_params jsonb,
    requested_by uuid NOT NULL,
    requested_at timestamp with time zone DEFAULT now() NOT NULL,
    started_at timestamp with time zone,
    finished_at timestamp with time zone,
    progress_pct integer,
    output_file_id uuid,
    error_message text
);

COMMENT ON TABLE reporting.report_generation_job IS 'Flujo async: PENDING → RUNNING → COMPLETED|FAILED.
Al COMPLETED: output_file_id poblado; cliente descarga vía ms_evidence o URL firmada.
Invalidar/rehacer: nuevo job; no versionar output en la misma fila (inmutabilidad del entregable).
';

COMMENT ON COLUMN reporting.report_generation_job.assessment_id IS 'Evaluación principal del reporte. HU-REP-04: evaluación “actual”; comparadas en report_job_assessment.
';

COMMENT ON COLUMN reporting.report_generation_job.organization_id IS 'HU-REP-04 #116: validar que todas las evaluaciones del job pertenecen a esta organización.
Denormalizado desde assessment.organization_id al crear el job.
';

COMMENT ON COLUMN reporting.report_generation_job.workbook_template_id IS 'Solo si report_type=EXCEL_INSTRUMENT_EXPORT.';

COMMENT ON COLUMN reporting.report_generation_job.report_type IS 'FULL_DIAGNOSTIC_PDF     — HU-REP-01 (Jasper + diagnostic dashboard + gaps + scale).
EXCEL_INSTRUMENT_EXPORT — HU-REP-02 (plantilla excel_workbook_template).
GAP_LIST_PDF | GAP_LIST_XLSX — HU-REP-03 (#115 export).
COMPARATIVE_DIAGNOSTIC_PDF | COMPARATIVE_DIAGNOSTIC_XLSX — HU-REP-04 (requiere ≥2 filas report_job_assessment).
DIAGNOSTIC_WIDGET_PNG | DIAGNOSTIC_WIDGET_PDF — widget M8 opcional (cliente o server).
';

COMMENT ON COLUMN reporting.report_generation_job.status IS 'PENDING | RUNNING | COMPLETED | FAILED | CANCELLED';

COMMENT ON COLUMN reporting.report_generation_job.page_format IS 'A4 | LETTER — HU-REP-01 #108. NULL si XLSX.';

COMMENT ON COLUMN reporting.report_generation_job.request_params IS 'Parámetros del job (filtros y opciones):
REP-03: { "gapThreshold": 60, "isoDomainCode": "A.5", "stewardRoleCode": "RESP_TICS", "sortBy": "DOMAIN|SCORE" }
REP-04: { "baselineAssessmentId": "uuid", "comparisonAssessmentIds": ["uuid",...] }  (redundante con report_job_assessment)
REP-01: { "includeContext": true, "includeGapActionPlan": false }
';

COMMENT ON COLUMN reporting.report_generation_job.progress_pct IS '0..100 para UI de progreso async.';

COMMENT ON COLUMN reporting.report_generation_job.output_file_id IS 'HU-REP-01/02/03/04: archivo generado. evidence_file.relation_type=REPORT_OUTPUT, relation_id=job.id.
';

CREATE TABLE reporting.report_job_assessment (
    id uuid NOT NULL,
    job_id uuid NOT NULL,
    assessment_id uuid NOT NULL,
    role character varying(20) NOT NULL,
    sort_order integer DEFAULT 0 NOT NULL
);

COMMENT ON TABLE reporting.report_job_assessment IS 'CHECK aplicación: organization_id de cada assessment = job.organization_id.
HU-REP-04 #117–118: ms_reporting calcula deltas on-read o cache kind=COMPARATIVE.
';

COMMENT ON COLUMN reporting.report_job_assessment.role IS 'PRIMARY — evaluación ancla (report_generation_job.assessment_id debe coincidir).
COMPARISON — evaluación adicional HU-REP-04 (#116, mínimo 2 filas por job comparativo).
BASELINE — opcional etiqueta semántica para la más antigua en UI.
';

COMMENT ON COLUMN reporting.report_job_assessment.sort_order IS 'Orden en tablas comparativas (0 = actual típicamente).';

CREATE TABLE reporting.report_template (
    id uuid NOT NULL,
    code character varying(60) NOT NULL,
    name character varying(120) NOT NULL,
    output_format character varying(10) NOT NULL,
    version integer DEFAULT 1 NOT NULL,
    storage_path character varying(500) NOT NULL,
    sections_json jsonb,
    active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

COMMENT ON COLUMN reporting.report_template.code IS 'Código estable del artefacto:
  FULL_DIAGNOSTIC_V1 (HU-REP-01 PDF),
  MSPI_INSTRUMENT_XLSX_V1 (HU-REP-02 plantilla maestra),
  GAP_LIST_V1 (HU-REP-03 PDF),
  COMPARATIVE_DIAGNOSTIC_V1 (HU-REP-04 PDF).
';

COMMENT ON COLUMN reporting.report_template.output_format IS 'PDF | XLSX';

COMMENT ON COLUMN reporting.report_template.storage_path IS 'PDF: ruta JRXML Jasper (classpath o bucket).
XLSX: ruta plantilla Excel maestra con fórmulas intactas (HU-REP-02 #110–111).
';

COMMENT ON COLUMN reporting.report_template.sections_json IS 'HU-REP-01 — secciones del PDF y orden de render:
{
  "sections": [
    {"key":"COVER","label":"Portada","source":"assessment+organization"},
    {"key":"SCALE","label":"Escala de evaluación","source":"catalog.scale_version"},
    {"key":"DOMAINS","label":"Evaluación por dominio","source":"diagnostic.domainEffectiveness"},
    {"key":"PHVA","label":"Avance PHVA","source":"diagnostic.phva"},
    {"key":"MATURITY","label":"Nivel de madurez","source":"diagnostic.maturity"},
    {"key":"NIST","label":"Desempeño NIST","source":"diagnostic.nist"},
    {"key":"GAPS","label":"Brechas y recomendaciones","source":"gaps.list"},
    {"key":"CONTEXT","label":"Misión y contexto","source":"evidence.assessment_context","optional":true}
  ],
  "footer": {"showEvaluator":true,"showEvaluationDate":true}
}
';

ALTER TABLE ONLY admin.system_config_history ALTER COLUMN id SET DEFAULT nextval('admin.system_config_history_id_seq'::regclass);

ALTER TABLE ONLY assessment.assessment_status_history ALTER COLUMN id SET DEFAULT nextval('assessment.assessment_status_history_id_seq'::regclass);

ALTER TABLE ONLY audit.audit_log ALTER COLUMN id SET DEFAULT nextval('audit.audit_log_id_seq'::regclass);

ALTER TABLE ONLY admin.system_config_history
    ADD CONSTRAINT system_config_history_pkey PRIMARY KEY (id);

ALTER TABLE ONLY admin.system_config
    ADD CONSTRAINT system_config_pkey PRIMARY KEY (key);

ALTER TABLE ONLY assessment.assessment_area
    ADD CONSTRAINT assessment_area_pkey PRIMARY KEY (id);

ALTER TABLE ONLY assessment.assessment_area_topic
    ADD CONSTRAINT assessment_area_topic_pkey PRIMARY KEY (id);

ALTER TABLE ONLY assessment.assessment_control_node
    ADD CONSTRAINT assessment_control_node_pkey PRIMARY KEY (id);

ALTER TABLE ONLY assessment.assessment_deletion_request
    ADD CONSTRAINT assessment_deletion_request_pkey PRIMARY KEY (id);

ALTER TABLE ONLY assessment.assessment_deletion_request
    ADD CONSTRAINT assessment_deletion_request_request_number_key UNIQUE (request_number);

ALTER TABLE ONLY assessment.assessment_edit_lock
    ADD CONSTRAINT assessment_edit_lock_pkey PRIMARY KEY (assessment_id);

ALTER TABLE ONLY assessment.assessment_extension_request
    ADD CONSTRAINT assessment_extension_request_pkey PRIMARY KEY (id);

ALTER TABLE ONLY assessment.assessment_extension_request
    ADD CONSTRAINT assessment_extension_request_request_number_key UNIQUE (request_number);

ALTER TABLE ONLY assessment.assessment_maturity_requirement
    ADD CONSTRAINT assessment_maturity_requirement_pkey PRIMARY KEY (id);

ALTER TABLE ONLY assessment.assessment_maturity_requirement_response
    ADD CONSTRAINT assessment_maturity_requirement_response_pkey PRIMARY KEY (id);

ALTER TABLE ONLY assessment.assessment_maturity_threshold
    ADD CONSTRAINT assessment_maturity_threshold_pkey PRIMARY KEY (id);

ALTER TABLE ONLY assessment.assessment_metadata
    ADD CONSTRAINT assessment_metadata_pkey PRIMARY KEY (assessment_id);

ALTER TABLE ONLY assessment.assessment_nist_ciber_item
    ADD CONSTRAINT assessment_nist_ciber_item_pkey PRIMARY KEY (id);

ALTER TABLE ONLY assessment.assessment_phva_item
    ADD CONSTRAINT assessment_phva_item_pkey PRIMARY KEY (id);

ALTER TABLE ONLY assessment.assessment
    ADD CONSTRAINT assessment_pkey PRIMARY KEY (id);

ALTER TABLE ONLY assessment.assessment_status_history
    ADD CONSTRAINT assessment_status_history_pkey PRIMARY KEY (id);

ALTER TABLE ONLY assessment.control_comment
    ADD CONSTRAINT control_comment_pkey PRIMARY KEY (id);

ALTER TABLE ONLY assessment.control_comment_thread
    ADD CONSTRAINT control_comment_thread_pkey PRIMARY KEY (id);

ALTER TABLE ONLY assessment.control_response
    ADD CONSTRAINT control_response_pkey PRIMARY KEY (id);

ALTER TABLE ONLY assessment.control_review
    ADD CONSTRAINT control_review_control_response_id_key UNIQUE (control_response_id);

ALTER TABLE ONLY assessment.control_review
    ADD CONSTRAINT control_review_pkey PRIMARY KEY (id);

ALTER TABLE ONLY assessment.gap_action
    ADD CONSTRAINT gap_action_pkey PRIMARY KEY (id);

ALTER TABLE ONLY assessment.gap_register
    ADD CONSTRAINT gap_register_pkey PRIMARY KEY (id);

ALTER TABLE ONLY assessment.nist_ciber_item_response
    ADD CONSTRAINT nist_ciber_item_response_pkey PRIMARY KEY (id);

ALTER TABLE ONLY assessment.phva_item_response
    ADD CONSTRAINT phva_item_response_pkey PRIMARY KEY (id);

ALTER TABLE ONLY audit.audit_log
    ADD CONSTRAINT audit_log_pkey PRIMARY KEY (id);

ALTER TABLE ONLY catalog.assessment_area_preset
    ADD CONSTRAINT assessment_area_preset_pkey PRIMARY KEY (code);

ALTER TABLE ONLY catalog.catalog_deletion_request
    ADD CONSTRAINT catalog_deletion_request_pkey PRIMARY KEY (id);

ALTER TABLE ONLY catalog.catalog_deletion_request
    ADD CONSTRAINT catalog_deletion_request_request_number_key UNIQUE (request_number);

ALTER TABLE ONLY catalog.control_catalog_node
    ADD CONSTRAINT control_catalog_node_pkey PRIMARY KEY (id);

ALTER TABLE ONLY catalog.control_rule
    ADD CONSTRAINT control_rule_control_node_id_key UNIQUE (control_node_id);

ALTER TABLE ONLY catalog.control_rule
    ADD CONSTRAINT control_rule_pkey PRIMARY KEY (id);

ALTER TABLE ONLY catalog.entity_order_type
    ADD CONSTRAINT entity_order_type_pkey PRIMARY KEY (code);

ALTER TABLE ONLY catalog.iso_domain
    ADD CONSTRAINT iso_domain_pkey PRIMARY KEY (code);

ALTER TABLE ONLY catalog.lifting_document_item_catalog
    ADD CONSTRAINT lifting_document_item_catalog_pkey PRIMARY KEY (id);

ALTER TABLE ONLY catalog.lifting_question_catalog
    ADD CONSTRAINT lifting_question_catalog_pkey PRIMARY KEY (id);

ALTER TABLE ONLY catalog.maturity_requirement_catalog
    ADD CONSTRAINT maturity_requirement_catalog_pkey PRIMARY KEY (id);

ALTER TABLE ONLY catalog.maturity_requirement_control_map
    ADD CONSTRAINT maturity_requirement_control_map_pkey PRIMARY KEY (id);

ALTER TABLE ONLY catalog.maturity_threshold
    ADD CONSTRAINT maturity_threshold_pkey PRIMARY KEY (id);

ALTER TABLE ONLY catalog.nist_ciber_item_catalog
    ADD CONSTRAINT nist_ciber_item_catalog_pkey PRIMARY KEY (id);

ALTER TABLE ONLY catalog.nist_function
    ADD CONSTRAINT nist_function_code_key UNIQUE (code);

ALTER TABLE ONLY catalog.nist_function
    ADD CONSTRAINT nist_function_pkey PRIMARY KEY (id);

ALTER TABLE ONLY catalog.nist_mapping
    ADD CONSTRAINT nist_mapping_pkey PRIMARY KEY (id);

ALTER TABLE ONLY catalog.nist_subcategory
    ADD CONSTRAINT nist_subcategory_code_key UNIQUE (code);

ALTER TABLE ONLY catalog.nist_subcategory
    ADD CONSTRAINT nist_subcategory_pkey PRIMARY KEY (id);

ALTER TABLE ONLY catalog.phva_item_catalog
    ADD CONSTRAINT phva_item_catalog_pkey PRIMARY KEY (id);

ALTER TABLE ONLY catalog.question_bank
    ADD CONSTRAINT question_bank_name_key UNIQUE (name);

ALTER TABLE ONLY catalog.question_bank
    ADD CONSTRAINT question_bank_pkey PRIMARY KEY (id);

ALTER TABLE ONLY catalog.question_bank_question
    ADD CONSTRAINT question_bank_question_pkey PRIMARY KEY (id);

ALTER TABLE ONLY catalog.scale_band
    ADD CONSTRAINT scale_band_pkey PRIMARY KEY (id);

ALTER TABLE ONLY catalog.scale_level
    ADD CONSTRAINT scale_level_pkey PRIMARY KEY (id);

ALTER TABLE ONLY catalog.scale
    ADD CONSTRAINT scale_name_key UNIQUE (name);

ALTER TABLE ONLY catalog.scale
    ADD CONSTRAINT scale_pkey PRIMARY KEY (id);

ALTER TABLE ONLY catalog.scale_version
    ADD CONSTRAINT scale_version_pkey PRIMARY KEY (id);

ALTER TABLE ONLY catalog.steward_role
    ADD CONSTRAINT steward_role_pkey PRIMARY KEY (code);

ALTER TABLE ONLY catalog.template
    ADD CONSTRAINT template_name_key UNIQUE (name);

ALTER TABLE ONLY catalog.template
    ADD CONSTRAINT template_pkey PRIMARY KEY (id);

ALTER TABLE ONLY catalog.template_version
    ADD CONSTRAINT template_version_pkey PRIMARY KEY (id);

ALTER TABLE ONLY evidence.assessment_context
    ADD CONSTRAINT assessment_context_pkey PRIMARY KEY (assessment_id);

ALTER TABLE ONLY evidence.evidence_file
    ADD CONSTRAINT evidence_file_pkey PRIMARY KEY (id);

ALTER TABLE ONLY evidence.lifting_answer
    ADD CONSTRAINT lifting_answer_pkey PRIMARY KEY (id);

ALTER TABLE ONLY evidence.lifting_document_delivery
    ADD CONSTRAINT lifting_document_delivery_pkey PRIMARY KEY (id);

ALTER TABLE ONLY evidence.process_scope_metric
    ADD CONSTRAINT process_scope_metric_pkey PRIMARY KEY (assessment_id);

ALTER TABLE ONLY iam.login_attempt
    ADD CONSTRAINT login_attempt_pkey PRIMARY KEY (identifier);

ALTER TABLE ONLY iam.notification
    ADD CONSTRAINT notification_pkey PRIMARY KEY (id);

ALTER TABLE ONLY iam.password_reset_request
    ADD CONSTRAINT password_reset_request_pkey PRIMARY KEY (id);

ALTER TABLE ONLY iam.password_reset_request
    ADD CONSTRAINT password_reset_request_request_number_key UNIQUE (request_number);

ALTER TABLE ONLY iam.role
    ADD CONSTRAINT role_name_key UNIQUE (name);

ALTER TABLE ONLY iam.role
    ADD CONSTRAINT role_pkey PRIMARY KEY (id);

ALTER TABLE ONLY iam."user"
    ADD CONSTRAINT user_email_key UNIQUE (email);

ALTER TABLE ONLY iam."user"
    ADD CONSTRAINT user_keycloak_sub_key UNIQUE (keycloak_sub);

ALTER TABLE ONLY iam."user"
    ADD CONSTRAINT user_pkey PRIMARY KEY (id);

ALTER TABLE ONLY iam.user_totp
    ADD CONSTRAINT user_totp_pkey PRIMARY KEY (keycloak_sub);

ALTER TABLE ONLY org.organization_area_base
    ADD CONSTRAINT organization_area_base_pkey PRIMARY KEY (id);

ALTER TABLE ONLY org.organization_area_base_topic
    ADD CONSTRAINT organization_area_base_topic_pkey PRIMARY KEY (id);

ALTER TABLE ONLY org.organization_contact
    ADD CONSTRAINT organization_contact_pkey PRIMARY KEY (id);

ALTER TABLE ONLY org.organization
    ADD CONSTRAINT organization_pkey PRIMARY KEY (id);

ALTER TABLE ONLY reporting.analytics_cache
    ADD CONSTRAINT analytics_cache_pkey PRIMARY KEY (id);

ALTER TABLE ONLY reporting.excel_sheet_mapping
    ADD CONSTRAINT excel_sheet_mapping_pkey PRIMARY KEY (id);

ALTER TABLE ONLY reporting.excel_workbook_template
    ADD CONSTRAINT excel_workbook_template_code_key UNIQUE (code);

ALTER TABLE ONLY reporting.excel_workbook_template
    ADD CONSTRAINT excel_workbook_template_pkey PRIMARY KEY (id);

ALTER TABLE ONLY reporting.report_generation_job
    ADD CONSTRAINT report_generation_job_pkey PRIMARY KEY (id);

ALTER TABLE ONLY reporting.report_job_assessment
    ADD CONSTRAINT report_job_assessment_pkey PRIMARY KEY (id);

ALTER TABLE ONLY reporting.report_template
    ADD CONSTRAINT report_template_pkey PRIMARY KEY (id);

CREATE INDEX idx_admin_system_config_history_key_changed ON admin.system_config_history USING btree (key, changed_at DESC);

CREATE UNIQUE INDEX assessment_area_assessment_id_area_name_idx ON assessment.assessment_area USING btree (assessment_id, area_name);

CREATE INDEX assessment_area_assessment_id_area_preset_code_idx ON assessment.assessment_area USING btree (assessment_id, area_preset_code);

CREATE INDEX assessment_area_assessment_id_idx ON assessment.assessment_area USING btree (assessment_id);

CREATE INDEX assessment_area_topic_area_id_default_steward_role_code_idx ON assessment.assessment_area_topic USING btree (area_id, default_steward_role_code);

CREATE INDEX assessment_area_topic_area_id_idx ON assessment.assessment_area_topic USING btree (area_id);

CREATE INDEX assessment_area_topic_area_id_position_idx ON assessment.assessment_area_topic USING btree (area_id, "position");

CREATE INDEX assessment_cloned_from_assessment_id_idx ON assessment.assessment USING btree (cloned_from_assessment_id);

CREATE UNIQUE INDEX assessment_control_node_assessment_id_code_idx ON assessment.assessment_control_node USING btree (assessment_id, code);

CREATE INDEX assessment_control_node_assessment_id_control_type_idx ON assessment.assessment_control_node USING btree (assessment_id, control_type);

CREATE INDEX assessment_control_node_assessment_id_idx ON assessment.assessment_control_node USING btree (assessment_id);

CREATE INDEX assessment_control_node_assessment_id_iso_code_idx ON assessment.assessment_control_node USING btree (assessment_id, iso_code);

CREATE INDEX assessment_control_node_assessment_id_iso_domain_code_idx ON assessment.assessment_control_node USING btree (assessment_id, iso_domain_code);

CREATE INDEX assessment_control_node_assessment_id_parent_id_position_idx ON assessment.assessment_control_node USING btree (assessment_id, parent_id, "position");

CREATE UNIQUE INDEX assessment_control_node_assessment_id_source_catalog_node_i_idx ON assessment.assessment_control_node USING btree (assessment_id, source_catalog_node_id);

CREATE INDEX assessment_created_by_idx ON assessment.assessment USING btree (created_by);

CREATE INDEX assessment_deletion_request_assessment_id_status_idx ON assessment.assessment_deletion_request USING btree (assessment_id, status);

CREATE UNIQUE INDEX assessment_deletion_request_number_uidx ON assessment.assessment_deletion_request USING btree (request_number);

CREATE INDEX assessment_edit_lock_expires_at_idx ON assessment.assessment_edit_lock USING btree (expires_at);

CREATE INDEX assessment_edit_lock_locked_by_user_id_idx ON assessment.assessment_edit_lock USING btree (locked_by_user_id);

CREATE INDEX assessment_entity_order_type_code_idx ON assessment.assessment USING btree (entity_order_type_code);

CREATE INDEX assessment_evaluation_date_idx ON assessment.assessment USING btree (evaluation_date);

CREATE INDEX assessment_extension_request_assessment_id_status_idx ON assessment.assessment_extension_request USING btree (assessment_id, status);

CREATE UNIQUE INDEX assessment_extension_request_number_uidx ON assessment.assessment_extension_request USING btree (request_number);

CREATE UNIQUE INDEX assessment_maturity_requireme_assessment_id_maturity_requir_idx ON assessment.assessment_maturity_requirement_response USING btree (assessment_id, maturity_requirement_id);

CREATE UNIQUE INDEX assessment_maturity_requireme_assessment_id_source_catalog__idx ON assessment.assessment_maturity_requirement USING btree (assessment_id, source_catalog_requirement_id);

CREATE INDEX assessment_maturity_requireme_assessment_id_source_type_pos_idx ON assessment.assessment_maturity_requirement USING btree (assessment_id, source_type, "position");

CREATE INDEX assessment_maturity_requireme_source_assessment_control_nod_idx ON assessment.assessment_maturity_requirement USING btree (source_assessment_control_node_id);

CREATE INDEX assessment_maturity_requireme_source_assessment_phva_item_i_idx ON assessment.assessment_maturity_requirement USING btree (source_assessment_phva_item_id);

CREATE INDEX assessment_maturity_requirement__assessment_id_score_status_idx ON assessment.assessment_maturity_requirement_response USING btree (assessment_id, score_status);

CREATE UNIQUE INDEX assessment_maturity_requirement_assessment_id_code_idx ON assessment.assessment_maturity_requirement USING btree (assessment_id, code);

CREATE INDEX assessment_maturity_requirement_assessment_id_idx ON assessment.assessment_maturity_requirement USING btree (assessment_id);

CREATE INDEX assessment_maturity_requirement_assessment_id_scoring_mode_idx ON assessment.assessment_maturity_requirement USING btree (assessment_id, scoring_mode);

CREATE INDEX assessment_maturity_requirement_response_assessment_id_idx ON assessment.assessment_maturity_requirement_response USING btree (assessment_id);

CREATE INDEX assessment_maturity_threshold_assessment_id_idx ON assessment.assessment_maturity_threshold USING btree (assessment_id);

CREATE INDEX assessment_maturity_threshold_assessment_id_level_idx ON assessment.assessment_maturity_threshold USING btree (assessment_id, level);

CREATE UNIQUE INDEX assessment_maturity_threshold_maturity_requirement_id_level_idx ON assessment.assessment_maturity_threshold USING btree (maturity_requirement_id, level);

CREATE INDEX assessment_member_assessment_id_member_role_idx ON assessment.assessment_member USING btree (assessment_id, member_role);

CREATE UNIQUE INDEX assessment_member_assessment_id_user_id_idx ON assessment.assessment_member USING btree (assessment_id, user_id);

CREATE INDEX assessment_member_user_id_idx ON assessment.assessment_member USING btree (user_id);

CREATE INDEX assessment_nist_ciber_item_assessment_id_function_code_posi_idx ON assessment.assessment_nist_ciber_item USING btree (assessment_id, function_code, "position");

CREATE INDEX assessment_nist_ciber_item_assessment_id_idx ON assessment.assessment_nist_ciber_item USING btree (assessment_id);

CREATE UNIQUE INDEX assessment_nist_ciber_item_assessment_id_position_idx ON assessment.assessment_nist_ciber_item USING btree (assessment_id, "position");

CREATE INDEX assessment_nist_ciber_item_assessment_id_scoring_mode_idx ON assessment.assessment_nist_ciber_item USING btree (assessment_id, scoring_mode);

CREATE UNIQUE INDEX assessment_nist_ciber_item_assessment_id_source_catalog_ite_idx ON assessment.assessment_nist_ciber_item USING btree (assessment_id, source_catalog_item_id);

CREATE INDEX assessment_nist_ciber_item_assessment_id_source_type_idx ON assessment.assessment_nist_ciber_item USING btree (assessment_id, source_type);

CREATE INDEX assessment_nist_ciber_item_assessment_id_subcategory_code_idx ON assessment.assessment_nist_ciber_item USING btree (assessment_id, subcategory_code);

CREATE INDEX assessment_nist_ciber_item_source_assessment_control_node_i_idx ON assessment.assessment_nist_ciber_item USING btree (source_assessment_control_node_id);

CREATE INDEX assessment_organization_id_idx ON assessment.assessment USING btree (organization_id);

CREATE INDEX assessment_organization_id_status_idx ON assessment.assessment USING btree (organization_id, status);

CREATE UNIQUE INDEX assessment_phva_item_assessment_id_code_idx ON assessment.assessment_phva_item USING btree (assessment_id, code);

CREATE INDEX assessment_phva_item_assessment_id_component_position_idx ON assessment.assessment_phva_item USING btree (assessment_id, component, "position");

CREATE INDEX assessment_phva_item_assessment_id_idx ON assessment.assessment_phva_item USING btree (assessment_id);

CREATE INDEX assessment_phva_item_assessment_id_scoring_mode_idx ON assessment.assessment_phva_item USING btree (assessment_id, scoring_mode);

CREATE UNIQUE INDEX assessment_phva_item_assessment_id_source_catalog_item_id_idx ON assessment.assessment_phva_item USING btree (assessment_id, source_catalog_item_id);

CREATE INDEX assessment_phva_item_source_assessment_control_node_id_idx ON assessment.assessment_phva_item USING btree (source_assessment_control_node_id);

CREATE INDEX assessment_status_history_assessment_id_changed_at_idx ON assessment.assessment_status_history USING btree (assessment_id, changed_at);

CREATE INDEX assessment_status_idx ON assessment.assessment USING btree (status);

CREATE INDEX assessment_template_version_id_idx ON assessment.assessment USING btree (template_version_id);

CREATE INDEX control_comment_thread_control_response_id_idx ON assessment.control_comment_thread USING btree (control_response_id);

CREATE INDEX control_comment_thread_id_created_at_idx ON assessment.control_comment USING btree (thread_id, created_at);

CREATE INDEX control_comment_thread_is_resolved_idx ON assessment.control_comment_thread USING btree (is_resolved);

CREATE UNIQUE INDEX control_response_assessment_id_control_node_id_idx ON assessment.control_response USING btree (assessment_id, control_node_id);

CREATE INDEX control_response_assessment_id_control_status_idx ON assessment.control_response USING btree (assessment_id, control_status);

CREATE INDEX control_response_assessment_id_idx ON assessment.control_response USING btree (assessment_id);

CREATE INDEX control_response_assessment_id_score_status_idx ON assessment.control_response USING btree (assessment_id, score_status);

CREATE INDEX control_response_assessment_id_steward_source_idx ON assessment.control_response USING btree (assessment_id, steward_source);

CREATE INDEX gap_action_gap_id_idx ON assessment.gap_action USING btree (gap_id);

CREATE INDEX gap_action_gap_id_status_idx ON assessment.gap_action USING btree (gap_id, status);

CREATE INDEX gap_register_assessment_id_idx ON assessment.gap_register USING btree (assessment_id);

CREATE INDEX gap_register_assessment_id_priority_idx ON assessment.gap_register USING btree (assessment_id, priority);

CREATE INDEX gap_register_assessment_id_status_idx ON assessment.gap_register USING btree (assessment_id, status);

CREATE INDEX nist_ciber_item_response_assessment_id_idx ON assessment.nist_ciber_item_response USING btree (assessment_id);

CREATE UNIQUE INDEX nist_ciber_item_response_assessment_id_nist_ciber_item_id_idx ON assessment.nist_ciber_item_response USING btree (assessment_id, nist_ciber_item_id);

CREATE INDEX nist_ciber_item_response_assessment_id_score_status_idx ON assessment.nist_ciber_item_response USING btree (assessment_id, score_status);

CREATE INDEX phva_item_response_assessment_id_idx ON assessment.phva_item_response USING btree (assessment_id);

CREATE UNIQUE INDEX phva_item_response_assessment_id_phva_item_id_idx ON assessment.phva_item_response USING btree (assessment_id, phva_item_id);

CREATE INDEX phva_item_response_assessment_id_score_status_idx ON assessment.phva_item_response USING btree (assessment_id, score_status);

CREATE INDEX audit_log_actor_user_id_occurred_at_idx ON audit.audit_log USING btree (actor_user_id, occurred_at);

CREATE INDEX audit_log_assessment_id_occurred_at_idx ON audit.audit_log USING btree (assessment_id, occurred_at);

CREATE INDEX audit_log_entity_type_entity_id_idx ON audit.audit_log USING btree (entity_type, entity_id);

CREATE INDEX audit_log_event_type_occurred_at_idx ON audit.audit_log USING btree (event_type, occurred_at);

CREATE INDEX idx_audit_audit_log_actor_occurred ON audit.audit_log USING btree (actor_user_id, occurred_at);

CREATE INDEX idx_audit_audit_log_assessment_occurred ON audit.audit_log USING btree (assessment_id, occurred_at);

CREATE INDEX idx_audit_audit_log_entity ON audit.audit_log USING btree (entity_type, entity_id);

CREATE INDEX idx_audit_audit_log_event_occurred ON audit.audit_log USING btree (event_type, occurred_at);

CREATE INDEX assessment_area_preset_position_idx ON catalog.assessment_area_preset USING btree ("position");

CREATE UNIQUE INDEX catalog_deletion_request_number_uidx ON catalog.catalog_deletion_request USING btree (request_number);

CREATE INDEX catalog_deletion_request_status_scheduled_deletion_at_idx ON catalog.catalog_deletion_request USING btree (status, scheduled_deletion_at);

CREATE INDEX catalog_deletion_request_status_scheduled_idx ON catalog.catalog_deletion_request USING btree (status, scheduled_deletion_at);

CREATE INDEX catalog_deletion_request_target_status_idx ON catalog.catalog_deletion_request USING btree (target_type, target_id, status);

CREATE INDEX catalog_deletion_request_target_type_target_id_status_idx ON catalog.catalog_deletion_request USING btree (target_type, target_id, status);

CREATE INDEX catalog_question_bank_deleted_at_idx ON catalog.question_bank USING btree (deleted_at);

CREATE INDEX catalog_scale_deleted_at_idx ON catalog.scale USING btree (deleted_at);

CREATE UNIQUE INDEX control_catalog_node_template_version_id_code_idx ON catalog.control_catalog_node USING btree (template_version_id, code);

CREATE INDEX control_catalog_node_template_version_id_idx ON catalog.control_catalog_node USING btree (template_version_id);

CREATE INDEX control_catalog_node_template_version_id_iso_code_idx ON catalog.control_catalog_node USING btree (template_version_id, iso_code);

CREATE INDEX control_catalog_node_template_version_id_iso_domain_code_idx ON catalog.control_catalog_node USING btree (template_version_id, iso_domain_code);

CREATE INDEX control_catalog_node_template_version_id_parent_id_position_idx ON catalog.control_catalog_node USING btree (template_version_id, parent_id, "position");

CREATE INDEX iso_domain_active_idx ON catalog.iso_domain USING btree (active);

CREATE INDEX iso_domain_control_type_display_position_idx ON catalog.iso_domain USING btree (control_type, display_position);

CREATE INDEX lifting_document_item_catalog_template_version_id_block_pos_idx ON catalog.lifting_document_item_catalog USING btree (template_version_id, block, "position");

CREATE UNIQUE INDEX lifting_document_item_catalog_template_version_id_item_numb_idx ON catalog.lifting_document_item_catalog USING btree (template_version_id, item_number);

CREATE UNIQUE INDEX lifting_question_catalog_template_version_id_code_idx ON catalog.lifting_question_catalog USING btree (template_version_id, code);

CREATE INDEX lifting_question_catalog_template_version_id_section_idx ON catalog.lifting_question_catalog USING btree (template_version_id, section);

CREATE INDEX maturity_requirement_catalog_source_control_node_id_idx ON catalog.maturity_requirement_catalog USING btree (source_control_node_id);

CREATE UNIQUE INDEX maturity_requirement_catalog_template_version_id_code_idx ON catalog.maturity_requirement_catalog USING btree (template_version_id, code);

CREATE INDEX maturity_requirement_catalog_template_version_id_scoring_mo_idx ON catalog.maturity_requirement_catalog USING btree (template_version_id, scoring_mode);

CREATE INDEX maturity_requirement_catalog_template_version_id_source_typ_idx ON catalog.maturity_requirement_catalog USING btree (template_version_id, source_type, "position");

CREATE UNIQUE INDEX maturity_requirement_control__requirement_id_control_node_i_idx ON catalog.maturity_requirement_control_map USING btree (requirement_id, control_node_id);

CREATE INDEX maturity_requirement_control_map_requirement_id_idx ON catalog.maturity_requirement_control_map USING btree (requirement_id);

CREATE UNIQUE INDEX maturity_threshold_requirement_id_level_idx ON catalog.maturity_threshold USING btree (requirement_id, level);

CREATE INDEX nist_ciber_item_catalog_source_control_node_id_idx ON catalog.nist_ciber_item_catalog USING btree (source_control_node_id);

CREATE INDEX nist_ciber_item_catalog_subcategory_id_idx ON catalog.nist_ciber_item_catalog USING btree (subcategory_id);

CREATE INDEX nist_ciber_item_catalog_template_version_id_function_id_pos_idx ON catalog.nist_ciber_item_catalog USING btree (template_version_id, function_id, "position");

CREATE UNIQUE INDEX nist_ciber_item_catalog_template_version_id_position_idx ON catalog.nist_ciber_item_catalog USING btree (template_version_id, "position");

CREATE INDEX nist_ciber_item_catalog_template_version_id_scoring_mode_idx ON catalog.nist_ciber_item_catalog USING btree (template_version_id, scoring_mode);

CREATE INDEX nist_ciber_item_catalog_template_version_id_source_type_idx ON catalog.nist_ciber_item_catalog USING btree (template_version_id, source_type);

CREATE UNIQUE INDEX nist_ciber_item_catalog_template_version_id_subcategory_id__idx ON catalog.nist_ciber_item_catalog USING btree (template_version_id, subcategory_id, source_control_node_id);

CREATE INDEX nist_mapping_template_version_id_control_node_id_idx ON catalog.nist_mapping USING btree (template_version_id, control_node_id);

CREATE INDEX nist_mapping_template_version_id_idx ON catalog.nist_mapping USING btree (template_version_id);

CREATE UNIQUE INDEX nist_mapping_template_version_id_subcategory_id_control_nod_idx ON catalog.nist_mapping USING btree (template_version_id, subcategory_id, control_node_id);

CREATE INDEX nist_mapping_template_version_id_subcategory_id_idx ON catalog.nist_mapping USING btree (template_version_id, subcategory_id);

CREATE UNIQUE INDEX nist_subcategory_function_id_code_idx ON catalog.nist_subcategory USING btree (function_id, code);

CREATE INDEX nist_subcategory_function_id_idx ON catalog.nist_subcategory USING btree (function_id);

CREATE UNIQUE INDEX phva_item_catalog_template_version_id_code_idx ON catalog.phva_item_catalog USING btree (template_version_id, code);

CREATE INDEX phva_item_catalog_template_version_id_component_position_idx ON catalog.phva_item_catalog USING btree (template_version_id, component, "position");

CREATE INDEX phva_item_catalog_template_version_id_scoring_mode_idx ON catalog.phva_item_catalog USING btree (template_version_id, scoring_mode);

CREATE INDEX question_bank_deleted_at_idx ON catalog.question_bank USING btree (deleted_at);

CREATE INDEX scale_band_scale_version_id_idx ON catalog.scale_band USING btree (scale_version_id);

CREATE INDEX scale_band_scale_version_id_position_idx ON catalog.scale_band USING btree (scale_version_id, "position");

CREATE INDEX scale_deleted_at_idx ON catalog.scale USING btree (deleted_at);

CREATE INDEX scale_level_scale_version_id_idx ON catalog.scale_level USING btree (scale_version_id);

CREATE INDEX scale_level_scale_version_id_position_idx ON catalog.scale_level USING btree (scale_version_id, "position");

CREATE UNIQUE INDEX scale_level_scale_version_id_value_idx ON catalog.scale_level USING btree (scale_version_id, value);

CREATE UNIQUE INDEX scale_version_scale_id_version_idx ON catalog.scale_version USING btree (scale_id, version);

CREATE INDEX scale_version_status_idx ON catalog.scale_version USING btree (status);

CREATE INDEX steward_role_sort_order_idx ON catalog.steward_role USING btree (sort_order);

CREATE INDEX template_version_status_idx ON catalog.template_version USING btree (status);

CREATE UNIQUE INDEX template_version_template_id_version_idx ON catalog.template_version USING btree (template_id, version);

CREATE INDEX evidence_file_assessment_id_idx ON evidence.evidence_file USING btree (assessment_id);

CREATE INDEX evidence_file_assessment_id_relation_type_idx ON evidence.evidence_file USING btree (assessment_id, relation_type);

CREATE INDEX evidence_file_assessment_id_relation_type_relation_id_idx ON evidence.evidence_file USING btree (assessment_id, relation_type, relation_id);

CREATE INDEX evidence_file_relation_type_relation_id_idx ON evidence.evidence_file USING btree (relation_type, relation_id);

CREATE INDEX evidence_file_sha256_idx ON evidence.evidence_file USING btree (sha256);

CREATE INDEX lifting_answer_assessment_id_idx ON evidence.lifting_answer USING btree (assessment_id);

CREATE UNIQUE INDEX lifting_answer_assessment_id_question_catalog_id_idx ON evidence.lifting_answer USING btree (assessment_id, question_catalog_id);

CREATE INDEX lifting_document_delivery_assessment_id_delivery_status_idx ON evidence.lifting_document_delivery USING btree (assessment_id, delivery_status);

CREATE UNIQUE INDEX lifting_document_delivery_assessment_id_document_item_catal_idx ON evidence.lifting_document_delivery USING btree (assessment_id, document_item_catalog_id);

CREATE INDEX lifting_document_delivery_assessment_id_idx ON evidence.lifting_document_delivery USING btree (assessment_id);

CREATE UNIQUE INDEX password_reset_request_number_uidx ON iam.password_reset_request USING btree (request_number);

CREATE INDEX password_reset_request_status_created_at_idx ON iam.password_reset_request USING btree (status, created_at);

CREATE INDEX password_reset_request_status_idx ON iam.password_reset_request USING btree (status, created_at DESC);

CREATE INDEX password_reset_request_target_status_idx ON iam.password_reset_request USING btree (target_user_id, status);

CREATE INDEX password_reset_request_target_user_id_status_idx ON iam.password_reset_request USING btree (target_user_id, status);

CREATE INDEX user_email_idx ON iam."user" USING btree (email);

CREATE INDEX user_organization_id_idx ON iam."user" USING btree (organization_id);

CREATE INDEX user_role_role_id_idx ON iam.user_role USING btree (role_id);

CREATE UNIQUE INDEX user_role_user_id_role_id_idx ON iam.user_role USING btree (user_id, role_id);

CREATE UNIQUE INDEX organization_area_base_organization_id_area_name_idx ON org.organization_area_base USING btree (organization_id, area_name);

CREATE INDEX organization_area_base_organization_id_idx ON org.organization_area_base USING btree (organization_id);

CREATE INDEX organization_area_base_topic_area_base_id_default_steward_r_idx ON org.organization_area_base_topic USING btree (area_base_id, default_steward_role_code);

CREATE INDEX organization_area_base_topic_area_base_id_idx ON org.organization_area_base_topic USING btree (area_base_id);

CREATE INDEX organization_contact_organization_id_idx ON org.organization_contact USING btree (organization_id);

CREATE INDEX organization_contact_organization_id_is_primary_idx ON org.organization_contact USING btree (organization_id, is_primary);

CREATE INDEX organization_identifier_idx ON org.organization USING btree (identifier);

CREATE UNIQUE INDEX organization_name_identifier_idx ON org.organization USING btree (name, identifier);

CREATE INDEX organization_name_idx ON org.organization USING btree (name);

CREATE UNIQUE INDEX analytics_cache_assessment_id_kind_idx ON reporting.analytics_cache USING btree (assessment_id, kind);

CREATE INDEX analytics_cache_computed_at_idx ON reporting.analytics_cache USING btree (computed_at);

CREATE UNIQUE INDEX excel_sheet_mapping_workbook_template_id_sheet_key_idx ON reporting.excel_sheet_mapping USING btree (workbook_template_id, sheet_key);

CREATE INDEX excel_sheet_mapping_workbook_template_id_sheet_order_idx ON reporting.excel_sheet_mapping USING btree (workbook_template_id, sheet_order);

CREATE INDEX report_generation_job_assessment_id_requested_at_idx ON reporting.report_generation_job USING btree (assessment_id, requested_at);

CREATE INDEX report_generation_job_organization_id_requested_at_idx ON reporting.report_generation_job USING btree (organization_id, requested_at);

CREATE INDEX report_generation_job_report_type_status_idx ON reporting.report_generation_job USING btree (report_type, status);

CREATE INDEX report_generation_job_status_idx ON reporting.report_generation_job USING btree (status);

CREATE INDEX report_job_assessment_assessment_id_idx ON reporting.report_job_assessment USING btree (assessment_id);

CREATE UNIQUE INDEX report_job_assessment_job_id_assessment_id_idx ON reporting.report_job_assessment USING btree (job_id, assessment_id);

CREATE UNIQUE INDEX report_template_code_version_idx ON reporting.report_template USING btree (code, version);

CREATE INDEX report_template_output_format_active_idx ON reporting.report_template USING btree (output_format, active);

ALTER TABLE ONLY assessment.assessment_area
    ADD CONSTRAINT assessment_area_area_preset_code_fkey FOREIGN KEY (area_preset_code) REFERENCES catalog.assessment_area_preset(code) DEFERRABLE;

ALTER TABLE ONLY assessment.assessment_area
    ADD CONSTRAINT assessment_area_assessment_id_fkey FOREIGN KEY (assessment_id) REFERENCES assessment.assessment(id) DEFERRABLE;

ALTER TABLE ONLY assessment.assessment_area_topic
    ADD CONSTRAINT assessment_area_topic_area_id_fkey FOREIGN KEY (area_id) REFERENCES assessment.assessment_area(id) DEFERRABLE;

ALTER TABLE ONLY assessment.assessment_area_topic
    ADD CONSTRAINT assessment_area_topic_default_steward_role_code_fkey FOREIGN KEY (default_steward_role_code) REFERENCES catalog.steward_role(code) DEFERRABLE;

ALTER TABLE ONLY assessment.assessment
    ADD CONSTRAINT assessment_cloned_from_assessment_id_fkey FOREIGN KEY (cloned_from_assessment_id) REFERENCES assessment.assessment(id) DEFERRABLE;

ALTER TABLE ONLY assessment.assessment_control_node
    ADD CONSTRAINT assessment_control_node_assessment_id_fkey FOREIGN KEY (assessment_id) REFERENCES assessment.assessment(id) DEFERRABLE;

ALTER TABLE ONLY assessment.assessment_control_node
    ADD CONSTRAINT assessment_control_node_default_steward_role_code_fkey FOREIGN KEY (default_steward_role_code) REFERENCES catalog.steward_role(code) DEFERRABLE;

ALTER TABLE ONLY assessment.assessment_control_node
    ADD CONSTRAINT assessment_control_node_iso_domain_code_fkey FOREIGN KEY (iso_domain_code) REFERENCES catalog.iso_domain(code) DEFERRABLE;

ALTER TABLE ONLY assessment.assessment_control_node
    ADD CONSTRAINT assessment_control_node_parent_id_fkey FOREIGN KEY (parent_id) REFERENCES assessment.assessment_control_node(id) DEFERRABLE;

ALTER TABLE ONLY assessment.assessment_control_node
    ADD CONSTRAINT assessment_control_node_source_catalog_node_id_fkey FOREIGN KEY (source_catalog_node_id) REFERENCES catalog.control_catalog_node(id) DEFERRABLE;

ALTER TABLE ONLY assessment.assessment
    ADD CONSTRAINT assessment_created_by_fkey FOREIGN KEY (created_by) REFERENCES iam."user"(id) DEFERRABLE;

ALTER TABLE ONLY assessment.assessment_deletion_request
    ADD CONSTRAINT assessment_deletion_request_assessment_id_fkey FOREIGN KEY (assessment_id) REFERENCES assessment.assessment(id) DEFERRABLE;

ALTER TABLE ONLY assessment.assessment_deletion_request
    ADD CONSTRAINT assessment_deletion_request_attachment_file_id_fkey FOREIGN KEY (attachment_file_id) REFERENCES evidence.evidence_file(id) DEFERRABLE;

ALTER TABLE ONLY assessment.assessment_deletion_request
    ADD CONSTRAINT assessment_deletion_request_decision_by_fkey FOREIGN KEY (decision_by) REFERENCES iam."user"(id) DEFERRABLE;

ALTER TABLE ONLY assessment.assessment_deletion_request
    ADD CONSTRAINT assessment_deletion_request_requested_by_fkey FOREIGN KEY (requested_by) REFERENCES iam."user"(id) DEFERRABLE;

ALTER TABLE ONLY assessment.assessment_edit_lock
    ADD CONSTRAINT assessment_edit_lock_assessment_id_fkey FOREIGN KEY (assessment_id) REFERENCES assessment.assessment(id) DEFERRABLE;

ALTER TABLE ONLY assessment.assessment_edit_lock
    ADD CONSTRAINT assessment_edit_lock_locked_by_user_id_fkey FOREIGN KEY (locked_by_user_id) REFERENCES iam."user"(id) DEFERRABLE;

ALTER TABLE ONLY assessment.assessment
    ADD CONSTRAINT assessment_entity_order_type_code_fkey FOREIGN KEY (entity_order_type_code) REFERENCES catalog.entity_order_type(code) DEFERRABLE;

ALTER TABLE ONLY assessment.assessment_extension_request
    ADD CONSTRAINT assessment_extension_request_assessment_id_fkey FOREIGN KEY (assessment_id) REFERENCES assessment.assessment(id) DEFERRABLE;

ALTER TABLE ONLY assessment.assessment_extension_request
    ADD CONSTRAINT assessment_extension_request_attachment_file_id_fkey FOREIGN KEY (attachment_file_id) REFERENCES evidence.evidence_file(id) DEFERRABLE;

ALTER TABLE ONLY assessment.assessment_extension_request
    ADD CONSTRAINT assessment_extension_request_decision_by_fkey FOREIGN KEY (decision_by) REFERENCES iam."user"(id) DEFERRABLE;

ALTER TABLE ONLY assessment.assessment_extension_request
    ADD CONSTRAINT assessment_extension_request_requested_by_fkey FOREIGN KEY (requested_by) REFERENCES iam."user"(id) DEFERRABLE;

ALTER TABLE ONLY assessment.assessment_maturity_requirement
    ADD CONSTRAINT assessment_maturity_requireme_source_assessment_control_no_fkey FOREIGN KEY (source_assessment_control_node_id) REFERENCES assessment.assessment_control_node(id) DEFERRABLE;

ALTER TABLE ONLY assessment.assessment_maturity_requirement
    ADD CONSTRAINT assessment_maturity_requireme_source_assessment_phva_item__fkey FOREIGN KEY (source_assessment_phva_item_id) REFERENCES assessment.assessment_phva_item(id) DEFERRABLE;

ALTER TABLE ONLY assessment.assessment_maturity_requirement
    ADD CONSTRAINT assessment_maturity_requireme_source_catalog_requirement_i_fkey FOREIGN KEY (source_catalog_requirement_id) REFERENCES catalog.maturity_requirement_catalog(id) DEFERRABLE;

ALTER TABLE ONLY assessment.assessment_maturity_requirement
    ADD CONSTRAINT assessment_maturity_requiremen_source_catalog_phva_item_id_fkey FOREIGN KEY (source_catalog_phva_item_id) REFERENCES catalog.phva_item_catalog(id) DEFERRABLE;

ALTER TABLE ONLY assessment.assessment_maturity_requirement
    ADD CONSTRAINT assessment_maturity_requirement_assessment_id_fkey FOREIGN KEY (assessment_id) REFERENCES assessment.assessment(id) DEFERRABLE;

ALTER TABLE ONLY assessment.assessment_maturity_requirement_response
    ADD CONSTRAINT assessment_maturity_requirement_re_maturity_requirement_id_fkey FOREIGN KEY (maturity_requirement_id) REFERENCES assessment.assessment_maturity_requirement(id) DEFERRABLE;

ALTER TABLE ONLY assessment.assessment_maturity_requirement_response
    ADD CONSTRAINT assessment_maturity_requirement_response_assessment_id_fkey FOREIGN KEY (assessment_id) REFERENCES assessment.assessment(id) DEFERRABLE;

ALTER TABLE ONLY assessment.assessment_maturity_requirement_response
    ADD CONSTRAINT assessment_maturity_requirement_response_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES iam."user"(id) DEFERRABLE;

ALTER TABLE ONLY assessment.assessment_maturity_threshold
    ADD CONSTRAINT assessment_maturity_threshold_assessment_id_fkey FOREIGN KEY (assessment_id) REFERENCES assessment.assessment(id) DEFERRABLE;

ALTER TABLE ONLY assessment.assessment_maturity_threshold
    ADD CONSTRAINT assessment_maturity_threshold_maturity_requirement_id_fkey FOREIGN KEY (maturity_requirement_id) REFERENCES assessment.assessment_maturity_requirement(id) DEFERRABLE;

ALTER TABLE ONLY assessment.assessment_member
    ADD CONSTRAINT assessment_member_assessment_id_fkey FOREIGN KEY (assessment_id) REFERENCES assessment.assessment(id) DEFERRABLE;

ALTER TABLE ONLY assessment.assessment_member
    ADD CONSTRAINT assessment_member_user_id_fkey FOREIGN KEY (user_id) REFERENCES iam."user"(id) DEFERRABLE;

ALTER TABLE ONLY assessment.assessment_metadata
    ADD CONSTRAINT assessment_metadata_assessment_id_fkey FOREIGN KEY (assessment_id) REFERENCES assessment.assessment(id) DEFERRABLE;

ALTER TABLE ONLY assessment.assessment_nist_ciber_item
    ADD CONSTRAINT assessment_nist_ciber_item_assessment_id_fkey FOREIGN KEY (assessment_id) REFERENCES assessment.assessment(id) DEFERRABLE;

ALTER TABLE ONLY assessment.assessment_nist_ciber_item
    ADD CONSTRAINT assessment_nist_ciber_item_function_id_fkey FOREIGN KEY (function_id) REFERENCES catalog.nist_function(id) DEFERRABLE;

ALTER TABLE ONLY assessment.assessment_nist_ciber_item
    ADD CONSTRAINT assessment_nist_ciber_item_source_assessment_control_node__fkey FOREIGN KEY (source_assessment_control_node_id) REFERENCES assessment.assessment_control_node(id) DEFERRABLE;

ALTER TABLE ONLY assessment.assessment_nist_ciber_item
    ADD CONSTRAINT assessment_nist_ciber_item_source_catalog_item_id_fkey FOREIGN KEY (source_catalog_item_id) REFERENCES catalog.nist_ciber_item_catalog(id) DEFERRABLE;

ALTER TABLE ONLY assessment.assessment_nist_ciber_item
    ADD CONSTRAINT assessment_nist_ciber_item_subcategory_id_fkey FOREIGN KEY (subcategory_id) REFERENCES catalog.nist_subcategory(id) DEFERRABLE;

ALTER TABLE ONLY assessment.assessment
    ADD CONSTRAINT assessment_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES org.organization(id) DEFERRABLE;

ALTER TABLE ONLY assessment.assessment_phva_item
    ADD CONSTRAINT assessment_phva_item_assessment_id_fkey FOREIGN KEY (assessment_id) REFERENCES assessment.assessment(id) DEFERRABLE;

ALTER TABLE ONLY assessment.assessment_phva_item
    ADD CONSTRAINT assessment_phva_item_source_assessment_control_node_id_fkey FOREIGN KEY (source_assessment_control_node_id) REFERENCES assessment.assessment_control_node(id) DEFERRABLE;

ALTER TABLE ONLY assessment.assessment_phva_item
    ADD CONSTRAINT assessment_phva_item_source_catalog_item_id_fkey FOREIGN KEY (source_catalog_item_id) REFERENCES catalog.phva_item_catalog(id) DEFERRABLE;

ALTER TABLE ONLY assessment.assessment
    ADD CONSTRAINT assessment_published_by_fkey FOREIGN KEY (published_by) REFERENCES iam."user"(id) DEFERRABLE;

ALTER TABLE ONLY assessment.assessment
    ADD CONSTRAINT assessment_status_changed_by_fkey FOREIGN KEY (status_changed_by) REFERENCES iam."user"(id) DEFERRABLE;

ALTER TABLE ONLY assessment.assessment_status_history
    ADD CONSTRAINT assessment_status_history_assessment_id_fkey FOREIGN KEY (assessment_id) REFERENCES assessment.assessment(id) DEFERRABLE;

ALTER TABLE ONLY assessment.assessment_status_history
    ADD CONSTRAINT assessment_status_history_changed_by_fkey FOREIGN KEY (changed_by) REFERENCES iam."user"(id) DEFERRABLE;

ALTER TABLE ONLY assessment.assessment
    ADD CONSTRAINT assessment_template_version_id_fkey FOREIGN KEY (template_version_id) REFERENCES catalog.template_version(id) DEFERRABLE;

ALTER TABLE ONLY assessment.control_comment
    ADD CONSTRAINT control_comment_author_user_id_fkey FOREIGN KEY (author_user_id) REFERENCES iam."user"(id) DEFERRABLE;

ALTER TABLE ONLY assessment.control_comment_thread
    ADD CONSTRAINT control_comment_thread_control_response_id_fkey FOREIGN KEY (control_response_id) REFERENCES assessment.control_response(id) DEFERRABLE;

ALTER TABLE ONLY assessment.control_comment_thread
    ADD CONSTRAINT control_comment_thread_created_by_fkey FOREIGN KEY (created_by) REFERENCES iam."user"(id) DEFERRABLE;

ALTER TABLE ONLY assessment.control_comment
    ADD CONSTRAINT control_comment_thread_id_fkey FOREIGN KEY (thread_id) REFERENCES assessment.control_comment_thread(id) DEFERRABLE;

ALTER TABLE ONLY assessment.control_comment_thread
    ADD CONSTRAINT control_comment_thread_resolved_by_fkey FOREIGN KEY (resolved_by) REFERENCES iam."user"(id) DEFERRABLE;

ALTER TABLE ONLY assessment.control_response
    ADD CONSTRAINT control_response_assessment_id_fkey FOREIGN KEY (assessment_id) REFERENCES assessment.assessment(id) DEFERRABLE;

ALTER TABLE ONLY assessment.control_response
    ADD CONSTRAINT control_response_control_node_id_fkey FOREIGN KEY (control_node_id) REFERENCES assessment.assessment_control_node(id) DEFERRABLE;

ALTER TABLE ONLY assessment.control_response
    ADD CONSTRAINT control_response_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES iam."user"(id) DEFERRABLE;

ALTER TABLE ONLY assessment.control_review
    ADD CONSTRAINT control_review_control_response_id_fkey FOREIGN KEY (control_response_id) REFERENCES assessment.control_response(id) DEFERRABLE;

ALTER TABLE ONLY assessment.control_review
    ADD CONSTRAINT control_review_reviewed_by_fkey FOREIGN KEY (reviewed_by) REFERENCES iam."user"(id) DEFERRABLE;

ALTER TABLE ONLY assessment.gap_action
    ADD CONSTRAINT gap_action_gap_id_fkey FOREIGN KEY (gap_id) REFERENCES assessment.gap_register(id) DEFERRABLE;

ALTER TABLE ONLY assessment.gap_register
    ADD CONSTRAINT gap_register_assessment_id_fkey FOREIGN KEY (assessment_id) REFERENCES assessment.assessment(id) DEFERRABLE;

ALTER TABLE ONLY assessment.gap_register
    ADD CONSTRAINT gap_register_control_response_id_fkey FOREIGN KEY (control_response_id) REFERENCES assessment.control_response(id) DEFERRABLE;

ALTER TABLE ONLY assessment.nist_ciber_item_response
    ADD CONSTRAINT nist_ciber_item_response_assessment_id_fkey FOREIGN KEY (assessment_id) REFERENCES assessment.assessment(id) DEFERRABLE;

ALTER TABLE ONLY assessment.nist_ciber_item_response
    ADD CONSTRAINT nist_ciber_item_response_nist_ciber_item_id_fkey FOREIGN KEY (nist_ciber_item_id) REFERENCES assessment.assessment_nist_ciber_item(id) DEFERRABLE;

ALTER TABLE ONLY assessment.nist_ciber_item_response
    ADD CONSTRAINT nist_ciber_item_response_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES iam."user"(id) DEFERRABLE;

ALTER TABLE ONLY assessment.phva_item_response
    ADD CONSTRAINT phva_item_response_assessment_id_fkey FOREIGN KEY (assessment_id) REFERENCES assessment.assessment(id) DEFERRABLE;

ALTER TABLE ONLY assessment.phva_item_response
    ADD CONSTRAINT phva_item_response_phva_item_id_fkey FOREIGN KEY (phva_item_id) REFERENCES assessment.assessment_phva_item(id) DEFERRABLE;

ALTER TABLE ONLY assessment.phva_item_response
    ADD CONSTRAINT phva_item_response_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES iam."user"(id) DEFERRABLE;

ALTER TABLE ONLY catalog.catalog_deletion_request
    ADD CONSTRAINT catalog_deletion_request_attachment_file_id_fkey FOREIGN KEY (attachment_file_id) REFERENCES evidence.evidence_file(id) DEFERRABLE;

ALTER TABLE ONLY catalog.catalog_deletion_request
    ADD CONSTRAINT catalog_deletion_request_decision_by_fkey FOREIGN KEY (decision_by) REFERENCES iam."user"(id) DEFERRABLE;

ALTER TABLE ONLY catalog.catalog_deletion_request
    ADD CONSTRAINT catalog_deletion_request_requested_by_fkey FOREIGN KEY (requested_by) REFERENCES iam."user"(id) DEFERRABLE;

ALTER TABLE ONLY catalog.control_catalog_node
    ADD CONSTRAINT control_catalog_node_default_steward_role_code_fkey FOREIGN KEY (default_steward_role_code) REFERENCES catalog.steward_role(code) DEFERRABLE;

ALTER TABLE ONLY catalog.control_catalog_node
    ADD CONSTRAINT control_catalog_node_iso_domain_code_fkey FOREIGN KEY (iso_domain_code) REFERENCES catalog.iso_domain(code) DEFERRABLE;

ALTER TABLE ONLY catalog.control_catalog_node
    ADD CONSTRAINT control_catalog_node_parent_id_fkey FOREIGN KEY (parent_id) REFERENCES catalog.control_catalog_node(id) DEFERRABLE;

ALTER TABLE ONLY catalog.control_catalog_node
    ADD CONSTRAINT control_catalog_node_template_version_id_fkey FOREIGN KEY (template_version_id) REFERENCES catalog.template_version(id) DEFERRABLE;

ALTER TABLE ONLY catalog.control_rule
    ADD CONSTRAINT control_rule_control_node_id_fkey FOREIGN KEY (control_node_id) REFERENCES catalog.control_catalog_node(id) DEFERRABLE;

ALTER TABLE ONLY catalog.lifting_document_item_catalog
    ADD CONSTRAINT lifting_document_item_catalog_template_version_id_fkey FOREIGN KEY (template_version_id) REFERENCES catalog.template_version(id) DEFERRABLE;

ALTER TABLE ONLY catalog.lifting_question_catalog
    ADD CONSTRAINT lifting_question_catalog_template_version_id_fkey FOREIGN KEY (template_version_id) REFERENCES catalog.template_version(id) DEFERRABLE;

ALTER TABLE ONLY catalog.maturity_requirement_catalog
    ADD CONSTRAINT maturity_requirement_catalog_source_control_node_id_fkey FOREIGN KEY (source_control_node_id) REFERENCES catalog.control_catalog_node(id) DEFERRABLE;

ALTER TABLE ONLY catalog.maturity_requirement_catalog
    ADD CONSTRAINT maturity_requirement_catalog_template_version_id_fkey FOREIGN KEY (template_version_id) REFERENCES catalog.template_version(id) DEFERRABLE;

ALTER TABLE ONLY catalog.maturity_requirement_control_map
    ADD CONSTRAINT maturity_requirement_control_map_control_node_id_fkey FOREIGN KEY (control_node_id) REFERENCES catalog.control_catalog_node(id) DEFERRABLE;

ALTER TABLE ONLY catalog.maturity_requirement_control_map
    ADD CONSTRAINT maturity_requirement_control_map_requirement_id_fkey FOREIGN KEY (requirement_id) REFERENCES catalog.maturity_requirement_catalog(id) DEFERRABLE;

ALTER TABLE ONLY catalog.maturity_threshold
    ADD CONSTRAINT maturity_threshold_requirement_id_fkey FOREIGN KEY (requirement_id) REFERENCES catalog.maturity_requirement_catalog(id) DEFERRABLE;

ALTER TABLE ONLY catalog.nist_ciber_item_catalog
    ADD CONSTRAINT nist_ciber_item_catalog_function_id_fkey FOREIGN KEY (function_id) REFERENCES catalog.nist_function(id) DEFERRABLE;

ALTER TABLE ONLY catalog.nist_ciber_item_catalog
    ADD CONSTRAINT nist_ciber_item_catalog_source_control_node_id_fkey FOREIGN KEY (source_control_node_id) REFERENCES catalog.control_catalog_node(id) DEFERRABLE;

ALTER TABLE ONLY catalog.nist_ciber_item_catalog
    ADD CONSTRAINT nist_ciber_item_catalog_subcategory_id_fkey FOREIGN KEY (subcategory_id) REFERENCES catalog.nist_subcategory(id) DEFERRABLE;

ALTER TABLE ONLY catalog.nist_ciber_item_catalog
    ADD CONSTRAINT nist_ciber_item_catalog_template_version_id_fkey FOREIGN KEY (template_version_id) REFERENCES catalog.template_version(id) DEFERRABLE;

ALTER TABLE ONLY catalog.nist_mapping
    ADD CONSTRAINT nist_mapping_control_node_id_fkey FOREIGN KEY (control_node_id) REFERENCES catalog.control_catalog_node(id) DEFERRABLE;

ALTER TABLE ONLY catalog.nist_mapping
    ADD CONSTRAINT nist_mapping_subcategory_id_fkey FOREIGN KEY (subcategory_id) REFERENCES catalog.nist_subcategory(id) DEFERRABLE;

ALTER TABLE ONLY catalog.nist_mapping
    ADD CONSTRAINT nist_mapping_template_version_id_fkey FOREIGN KEY (template_version_id) REFERENCES catalog.template_version(id) DEFERRABLE;

ALTER TABLE ONLY catalog.nist_subcategory
    ADD CONSTRAINT nist_subcategory_function_id_fkey FOREIGN KEY (function_id) REFERENCES catalog.nist_function(id) DEFERRABLE;

ALTER TABLE ONLY catalog.phva_item_catalog
    ADD CONSTRAINT phva_item_catalog_source_control_node_id_fkey FOREIGN KEY (source_control_node_id) REFERENCES catalog.control_catalog_node(id) DEFERRABLE;

ALTER TABLE ONLY catalog.phva_item_catalog
    ADD CONSTRAINT phva_item_catalog_template_version_id_fkey FOREIGN KEY (template_version_id) REFERENCES catalog.template_version(id) DEFERRABLE;

ALTER TABLE ONLY catalog.question_bank_question
    ADD CONSTRAINT question_bank_question_question_bank_id_fkey FOREIGN KEY (question_bank_id) REFERENCES catalog.question_bank(id) DEFERRABLE;

ALTER TABLE ONLY catalog.question_bank_question
    ADD CONSTRAINT question_bank_question_scale_id_fkey FOREIGN KEY (scale_id) REFERENCES catalog.scale(id) DEFERRABLE;

ALTER TABLE ONLY catalog.question_bank
    ADD CONSTRAINT question_bank_scale_id_fkey FOREIGN KEY (scale_id) REFERENCES catalog.scale(id) DEFERRABLE;

ALTER TABLE ONLY catalog.scale_band
    ADD CONSTRAINT scale_band_scale_version_id_fkey FOREIGN KEY (scale_version_id) REFERENCES catalog.scale_version(id) DEFERRABLE;

ALTER TABLE ONLY catalog.scale_level
    ADD CONSTRAINT scale_level_scale_version_id_fkey FOREIGN KEY (scale_version_id) REFERENCES catalog.scale_version(id) DEFERRABLE;

ALTER TABLE ONLY catalog.scale_version
    ADD CONSTRAINT scale_version_scale_id_fkey FOREIGN KEY (scale_id) REFERENCES catalog.scale(id) DEFERRABLE;

ALTER TABLE ONLY catalog.template_version
    ADD CONSTRAINT template_version_scale_version_id_fkey FOREIGN KEY (scale_version_id) REFERENCES catalog.scale_version(id) DEFERRABLE;

ALTER TABLE ONLY catalog.template_version
    ADD CONSTRAINT template_version_template_id_fkey FOREIGN KEY (template_id) REFERENCES catalog.template(id) DEFERRABLE;

ALTER TABLE ONLY evidence.assessment_context
    ADD CONSTRAINT assessment_context_assessment_id_fkey FOREIGN KEY (assessment_id) REFERENCES assessment.assessment(id) DEFERRABLE;

ALTER TABLE ONLY evidence.assessment_context
    ADD CONSTRAINT assessment_context_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES iam."user"(id) DEFERRABLE;

ALTER TABLE ONLY evidence.evidence_file
    ADD CONSTRAINT evidence_file_assessment_id_fkey FOREIGN KEY (assessment_id) REFERENCES assessment.assessment(id) DEFERRABLE;

ALTER TABLE ONLY evidence.evidence_file
    ADD CONSTRAINT evidence_file_uploaded_by_fkey FOREIGN KEY (uploaded_by) REFERENCES iam."user"(id) DEFERRABLE;

ALTER TABLE ONLY evidence.lifting_answer
    ADD CONSTRAINT lifting_answer_assessment_id_fkey FOREIGN KEY (assessment_id) REFERENCES assessment.assessment(id) DEFERRABLE;

ALTER TABLE ONLY evidence.lifting_answer
    ADD CONSTRAINT lifting_answer_question_catalog_id_fkey FOREIGN KEY (question_catalog_id) REFERENCES catalog.lifting_question_catalog(id) DEFERRABLE;

ALTER TABLE ONLY evidence.lifting_answer
    ADD CONSTRAINT lifting_answer_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES iam."user"(id) DEFERRABLE;

ALTER TABLE ONLY evidence.lifting_document_delivery
    ADD CONSTRAINT lifting_document_delivery_assessment_id_fkey FOREIGN KEY (assessment_id) REFERENCES assessment.assessment(id) DEFERRABLE;

ALTER TABLE ONLY evidence.lifting_document_delivery
    ADD CONSTRAINT lifting_document_delivery_document_item_catalog_id_fkey FOREIGN KEY (document_item_catalog_id) REFERENCES catalog.lifting_document_item_catalog(id) DEFERRABLE;

ALTER TABLE ONLY evidence.lifting_document_delivery
    ADD CONSTRAINT lifting_document_delivery_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES iam."user"(id) DEFERRABLE;

ALTER TABLE ONLY evidence.lifting_document_delivery
    ADD CONSTRAINT lifting_document_delivery_validated_by_fkey FOREIGN KEY (validated_by) REFERENCES iam."user"(id) DEFERRABLE;

ALTER TABLE ONLY evidence.process_scope_metric
    ADD CONSTRAINT process_scope_metric_assessment_id_fkey FOREIGN KEY (assessment_id) REFERENCES assessment.assessment(id) DEFERRABLE;

ALTER TABLE ONLY evidence.process_scope_metric
    ADD CONSTRAINT process_scope_metric_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES iam."user"(id) DEFERRABLE;

ALTER TABLE ONLY iam.password_reset_request
    ADD CONSTRAINT password_reset_request_decision_by_fkey FOREIGN KEY (decision_by) REFERENCES iam."user"(id) DEFERRABLE;

ALTER TABLE ONLY iam.password_reset_request
    ADD CONSTRAINT password_reset_request_requested_by_fkey FOREIGN KEY (requested_by) REFERENCES iam."user"(id) DEFERRABLE;

ALTER TABLE ONLY iam.password_reset_request
    ADD CONSTRAINT password_reset_request_target_user_id_fkey FOREIGN KEY (target_user_id) REFERENCES iam."user"(id) DEFERRABLE;

ALTER TABLE ONLY iam."user"
    ADD CONSTRAINT user_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES org.organization(id) DEFERRABLE;

ALTER TABLE ONLY iam.user_role
    ADD CONSTRAINT user_role_role_id_fkey FOREIGN KEY (role_id) REFERENCES iam.role(id) DEFERRABLE;

ALTER TABLE ONLY iam.user_role
    ADD CONSTRAINT user_role_user_id_fkey FOREIGN KEY (user_id) REFERENCES iam."user"(id) DEFERRABLE;

ALTER TABLE ONLY iam.user_totp
    ADD CONSTRAINT user_totp_keycloak_sub_fkey FOREIGN KEY (keycloak_sub) REFERENCES iam."user"(keycloak_sub) DEFERRABLE;

ALTER TABLE ONLY org.organization_area_base
    ADD CONSTRAINT organization_area_base_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES org.organization(id) DEFERRABLE;

ALTER TABLE ONLY org.organization_area_base_topic
    ADD CONSTRAINT organization_area_base_topic_area_base_id_fkey FOREIGN KEY (area_base_id) REFERENCES org.organization_area_base(id) DEFERRABLE;

ALTER TABLE ONLY org.organization_area_base_topic
    ADD CONSTRAINT organization_area_base_topic_default_steward_role_code_fkey FOREIGN KEY (default_steward_role_code) REFERENCES catalog.steward_role(code) DEFERRABLE;

ALTER TABLE ONLY org.organization_contact
    ADD CONSTRAINT organization_contact_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES org.organization(id) DEFERRABLE;

ALTER TABLE ONLY reporting.analytics_cache
    ADD CONSTRAINT analytics_cache_assessment_id_fkey FOREIGN KEY (assessment_id) REFERENCES assessment.assessment(id) DEFERRABLE;

ALTER TABLE ONLY reporting.excel_sheet_mapping
    ADD CONSTRAINT excel_sheet_mapping_workbook_template_id_fkey FOREIGN KEY (workbook_template_id) REFERENCES reporting.excel_workbook_template(id) DEFERRABLE;

ALTER TABLE ONLY reporting.report_generation_job
    ADD CONSTRAINT report_generation_job_assessment_id_fkey FOREIGN KEY (assessment_id) REFERENCES assessment.assessment(id) DEFERRABLE;

ALTER TABLE ONLY reporting.report_generation_job
    ADD CONSTRAINT report_generation_job_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES org.organization(id) DEFERRABLE;

ALTER TABLE ONLY reporting.report_generation_job
    ADD CONSTRAINT report_generation_job_output_file_id_fkey FOREIGN KEY (output_file_id) REFERENCES evidence.evidence_file(id) DEFERRABLE;

ALTER TABLE ONLY reporting.report_generation_job
    ADD CONSTRAINT report_generation_job_requested_by_fkey FOREIGN KEY (requested_by) REFERENCES iam."user"(id) DEFERRABLE;

ALTER TABLE ONLY reporting.report_generation_job
    ADD CONSTRAINT report_generation_job_template_id_fkey FOREIGN KEY (template_id) REFERENCES reporting.report_template(id) DEFERRABLE;

ALTER TABLE ONLY reporting.report_generation_job
    ADD CONSTRAINT report_generation_job_workbook_template_id_fkey FOREIGN KEY (workbook_template_id) REFERENCES reporting.excel_workbook_template(id) DEFERRABLE;

ALTER TABLE ONLY reporting.report_job_assessment
    ADD CONSTRAINT report_job_assessment_assessment_id_fkey FOREIGN KEY (assessment_id) REFERENCES assessment.assessment(id) DEFERRABLE;

ALTER TABLE ONLY reporting.report_job_assessment
    ADD CONSTRAINT report_job_assessment_job_id_fkey FOREIGN KEY (job_id) REFERENCES reporting.report_generation_job(id) DEFERRABLE;
