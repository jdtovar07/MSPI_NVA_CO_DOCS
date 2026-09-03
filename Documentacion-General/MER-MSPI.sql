CREATE SCHEMA "iam";

CREATE SCHEMA "org";

CREATE SCHEMA "catalog";

CREATE SCHEMA "assessment";

CREATE SCHEMA "evidence";

CREATE SCHEMA "reporting";

CREATE TABLE "iam"."user" (
  "id" uuid PRIMARY KEY,
  "full_name" varchar(200) NOT NULL,
  "email" varchar(254) UNIQUE NOT NULL,
  "password_hash" varchar(255),
  "status" varchar(20) NOT NULL DEFAULT 'ACTIVE',
  "failed_attempts" int NOT NULL DEFAULT 0,
  "locked_until" timestamptz,
  "created_at" timestamptz NOT NULL DEFAULT (now()),
  "updated_at" timestamptz NOT NULL DEFAULT (now())
);

CREATE TABLE "iam"."role" (
  "id" uuid PRIMARY KEY,
  "name" varchar(60) UNIQUE NOT NULL,
  "description" varchar(300)
);

CREATE TABLE "iam"."user_role" (
  "user_id" uuid NOT NULL,
  "role_id" uuid NOT NULL,
  "assigned_at" timestamptz NOT NULL DEFAULT (now())
);

CREATE TABLE "iam"."system_config" (
  "key" varchar(120) PRIMARY KEY,
  "value_json" jsonb NOT NULL,
  "version" int NOT NULL DEFAULT 1,
  "updated_by" uuid,
  "updated_at" timestamptz NOT NULL DEFAULT (now())
);

CREATE TABLE "iam"."audit_log" (
  "id" bigserial PRIMARY KEY,
  "event_type" varchar(80) NOT NULL,
  "entity_type" varchar(80) NOT NULL,
  "entity_id" varchar(120) NOT NULL,
  "assessment_id" uuid,
  "actor_user_id" uuid,
  "occurred_at" timestamptz NOT NULL DEFAULT (now()),
  "ip" varchar(64),
  "user_agent" varchar(400),
  "before_json" jsonb,
  "after_json" jsonb,
  "metadata_json" jsonb
);

CREATE TABLE "org"."organization" (
  "id" uuid PRIMARY KEY,
  "name" varchar(220) NOT NULL,
  "identifier" varchar(40),
  "type" varchar(40),
  "status" varchar(20) NOT NULL DEFAULT 'ACTIVE',
  "address" varchar(250),
  "city" varchar(120),
  "department" varchar(120),
  "country" varchar(120),
  "created_at" timestamptz NOT NULL DEFAULT (now()),
  "updated_at" timestamptz NOT NULL DEFAULT (now())
);

CREATE TABLE "org"."organization_contact" (
  "id" uuid PRIMARY KEY,
  "organization_id" uuid NOT NULL,
  "full_name" varchar(200) NOT NULL,
  "role" varchar(120),
  "email" varchar(254),
  "phone" varchar(40),
  "is_primary" boolean NOT NULL DEFAULT false,
  "created_at" timestamptz NOT NULL DEFAULT (now())
);

CREATE TABLE "org"."organization_area_base" (
  "id" uuid PRIMARY KEY,
  "organization_id" uuid NOT NULL,
  "area_name" varchar(160) NOT NULL,
  "description" varchar(300),
  "created_at" timestamptz NOT NULL DEFAULT (now())
);

CREATE TABLE "org"."organization_area_base_topic" (
  "id" uuid PRIMARY KEY,
  "area_base_id" uuid NOT NULL,
  "topic" varchar(220) NOT NULL,
  "staff_name" varchar(200),
  "staff_role" varchar(160),
  "staff_contact" varchar(200),
  "notes" varchar(600)
);

CREATE TABLE "catalog"."scale" (
  "id" uuid PRIMARY KEY,
  "name" varchar(140) UNIQUE NOT NULL,
  "description" varchar(400),
  "created_at" timestamptz NOT NULL DEFAULT (now())
);

CREATE TABLE "catalog"."scale_version" (
  "id" uuid PRIMARY KEY,
  "scale_id" uuid NOT NULL,
  "version" int NOT NULL,
  "status" varchar(20) NOT NULL DEFAULT 'DRAFT',
  "published_at" timestamptz,
  "created_at" timestamptz NOT NULL DEFAULT (now())
);

CREATE TABLE "catalog"."scale_level" (
  "id" uuid PRIMARY KEY,
  "scale_version_id" uuid NOT NULL,
  "label" varchar(80) NOT NULL,
  "value" int,
  "is_na" boolean NOT NULL DEFAULT false,
  "criteria_text" varchar(1200),
  "position" int NOT NULL
);

CREATE TABLE "catalog"."scale_band" (
  "id" uuid PRIMARY KEY,
  "scale_version_id" uuid NOT NULL,
  "min_value" int NOT NULL,
  "max_value" int NOT NULL,
  "label" varchar(60) NOT NULL,
  "position" int NOT NULL
);

CREATE TABLE "catalog"."template" (
  "id" uuid PRIMARY KEY,
  "name" varchar(180) UNIQUE NOT NULL,
  "description" varchar(500),
  "created_at" timestamptz NOT NULL DEFAULT (now())
);

CREATE TABLE "catalog"."template_version" (
  "id" uuid PRIMARY KEY,
  "template_id" uuid NOT NULL,
  "scale_version_id" uuid NOT NULL,
  "version" int NOT NULL,
  "status" varchar(20) NOT NULL DEFAULT 'DRAFT',
  "published_at" timestamptz,
  "created_at" timestamptz NOT NULL DEFAULT (now()),
  "maturity_global_rule" varchar(40),
  "maturity_crit_thresholds" jsonb,
  "phva_weights" jsonb,
  "phva_caps" jsonb
);

CREATE TABLE "catalog"."iso_domain" (
  "code" varchar(20) PRIMARY KEY,
  "name" varchar(220),
  "description" varchar(600),
  "active" boolean NOT NULL DEFAULT true
);

CREATE TABLE "catalog"."control_catalog_node" (
  "id" uuid PRIMARY KEY,
  "template_version_id" uuid NOT NULL,
  "parent_id" uuid,
  "position" int NOT NULL,
  "node_type" varchar(10) NOT NULL,
  "control_type" varchar(10),
  "code" varchar(40),
  "title" varchar(300) NOT NULL,
  "description" text,
  "test_guidance" text,
  "iso_domain_code" varchar(20),
  "mspi_tag" varchar(120),
  "ciber_tag" varchar(120),
  "is_scored" boolean NOT NULL DEFAULT false,
  "created_at" timestamptz NOT NULL DEFAULT (now())
);

CREATE TABLE "catalog"."control_rule" (
  "id" uuid PRIMARY KEY,
  "control_node_id" uuid UNIQUE NOT NULL,
  "requires_evidence" boolean NOT NULL DEFAULT false,
  "requires_gap" boolean NOT NULL DEFAULT false,
  "requires_recommendation" boolean NOT NULL DEFAULT false,
  "recommendation_rule_type" varchar(20) NOT NULL DEFAULT 'THRESHOLD',
  "recommendation_threshold_value" int,
  "requires_test_checklist" boolean NOT NULL DEFAULT false,
  "max_files" int,
  "max_text_len" jsonb
);

CREATE TABLE "catalog"."phva_item_catalog" (
  "id" uuid PRIMARY KEY,
  "template_version_id" uuid NOT NULL,
  "code" varchar(40) NOT NULL,
  "component" varchar(10) NOT NULL,
  "title" varchar(280) NOT NULL,
  "description" text,
  "test_guidance" text,
  "source_control_code" varchar(40),
  "source_control_node_id" uuid,
  "position" int NOT NULL
);

CREATE TABLE "catalog"."maturity_requirement_catalog" (
  "id" uuid PRIMARY KEY,
  "template_version_id" uuid NOT NULL,
  "code" varchar(40) NOT NULL,
  "title" varchar(280) NOT NULL,
  "description" text,
  "position" int NOT NULL
);

CREATE TABLE "catalog"."maturity_requirement_control_map" (
  "id" uuid PRIMARY KEY,
  "requirement_id" uuid NOT NULL,
  "control_node_id" uuid NOT NULL
);

CREATE TABLE "catalog"."maturity_threshold" (
  "id" uuid PRIMARY KEY,
  "requirement_id" uuid NOT NULL,
  "level" int NOT NULL,
  "expected_value" int NOT NULL
);

CREATE TABLE "catalog"."nist_function" (
  "id" uuid PRIMARY KEY,
  "code" varchar(20) UNIQUE NOT NULL,
  "name" varchar(120) NOT NULL
);

CREATE TABLE "catalog"."nist_subcategory" (
  "id" uuid PRIMARY KEY,
  "function_id" uuid NOT NULL,
  "code" varchar(40) UNIQUE NOT NULL,
  "description" text,
  "active" boolean NOT NULL DEFAULT true
);

CREATE TABLE "catalog"."nist_mapping" (
  "id" uuid PRIMARY KEY,
  "template_version_id" uuid NOT NULL,
  "subcategory_id" uuid NOT NULL,
  "control_node_id" uuid,
  "iso_control_code" varchar(20)
);

CREATE TABLE "catalog"."lifting_question_catalog" (
  "id" uuid PRIMARY KEY,
  "template_version_id" uuid NOT NULL,
  "code" varchar(40) NOT NULL,
  "section" varchar(120),
  "question_text" text NOT NULL,
  "field_type" varchar(30) NOT NULL,
  "is_required" boolean NOT NULL DEFAULT false,
  "position" int NOT NULL,
  "options_json" jsonb
);

CREATE TABLE "catalog"."lifting_document_item_catalog" (
  "id" uuid PRIMARY KEY,
  "template_version_id" uuid NOT NULL,
  "item_number" int NOT NULL,
  "required_text" text NOT NULL,
  "hints" text,
  "is_required" boolean NOT NULL DEFAULT true,
  "position" int NOT NULL
);

CREATE TABLE "assessment"."assessment" (
  "id" uuid PRIMARY KEY,
  "organization_id" uuid NOT NULL,
  "template_version_id" uuid NOT NULL,
  "name" varchar(220) NOT NULL,
  "status" varchar(30) NOT NULL DEFAULT 'BORRADOR',
  "created_by" uuid NOT NULL,
  "created_at" timestamptz NOT NULL DEFAULT (now()),
  "status_changed_at" timestamptz,
  "status_changed_by" uuid
);

CREATE TABLE "assessment"."assessment_member" (
  "assessment_id" uuid NOT NULL,
  "user_id" uuid NOT NULL,
  "member_role" varchar(20) NOT NULL,
  "is_leader" boolean NOT NULL DEFAULT false,
  "assigned_at" timestamptz NOT NULL DEFAULT (now())
);

CREATE TABLE "assessment"."assessment_metadata" (
  "assessment_id" uuid PRIMARY KEY,
  "period" varchar(120),
  "scope" text,
  "prepared_by" varchar(200),
  "approved_by" varchar(200),
  "start_date" date,
  "end_date" date,
  "notes" text,
  "version" int NOT NULL DEFAULT 0
);

CREATE TABLE "assessment"."assessment_status_history" (
  "id" bigserial PRIMARY KEY,
  "assessment_id" uuid NOT NULL,
  "old_status" varchar(30) NOT NULL,
  "new_status" varchar(30) NOT NULL,
  "note" text,
  "changed_by" uuid NOT NULL,
  "changed_at" timestamptz NOT NULL DEFAULT (now())
);

CREATE TABLE "assessment"."assessment_control_node" (
  "id" uuid PRIMARY KEY,
  "assessment_id" uuid NOT NULL,
  "source_catalog_node_id" uuid NOT NULL,
  "parent_id" uuid,
  "position" int NOT NULL,
  "node_type" varchar(10) NOT NULL,
  "control_type" varchar(10),
  "code" varchar(40),
  "title" varchar(300) NOT NULL,
  "description" text,
  "test_guidance" text,
  "iso_domain_code" varchar(20),
  "mspi_tag" varchar(120),
  "ciber_tag" varchar(120),
  "is_scored" boolean NOT NULL DEFAULT false,
  "rules_json" jsonb
);

CREATE TABLE "assessment"."control_response" (
  "id" uuid PRIMARY KEY,
  "assessment_id" uuid NOT NULL,
  "control_node_id" uuid NOT NULL,
  "score_status" varchar(10) NOT NULL DEFAULT 'PENDING',
  "score_value" int,
  "evidence_text" text,
  "gap_text" text,
  "recommendation_text" text,
  "control_status" varchar(30) NOT NULL DEFAULT 'PENDIENTE',
  "updated_by" uuid,
  "updated_at" timestamptz NOT NULL DEFAULT (now()),
  "version" int NOT NULL DEFAULT 0
);

CREATE TABLE "assessment"."control_review" (
  "id" uuid PRIMARY KEY,
  "control_response_id" uuid UNIQUE NOT NULL,
  "review_status" varchar(20) NOT NULL,
  "comment" text,
  "severity" varchar(20),
  "reviewed_by" uuid NOT NULL,
  "reviewed_at" timestamptz NOT NULL DEFAULT (now())
);

CREATE TABLE "assessment"."control_comment_thread" (
  "id" uuid PRIMARY KEY,
  "control_response_id" uuid NOT NULL,
  "created_by" uuid NOT NULL,
  "created_at" timestamptz NOT NULL DEFAULT (now()),
  "is_resolved" boolean NOT NULL DEFAULT false,
  "resolved_by" uuid,
  "resolved_at" timestamptz
);

CREATE TABLE "assessment"."control_comment" (
  "id" uuid PRIMARY KEY,
  "thread_id" uuid NOT NULL,
  "author_user_id" uuid NOT NULL,
  "body" text NOT NULL,
  "created_at" timestamptz NOT NULL DEFAULT (now())
);

CREATE TABLE "assessment"."assessment_area" (
  "id" uuid PRIMARY KEY,
  "assessment_id" uuid NOT NULL,
  "area_name" varchar(160) NOT NULL,
  "description" varchar(400),
  "created_at" timestamptz NOT NULL DEFAULT (now())
);

CREATE TABLE "assessment"."assessment_area_topic" (
  "id" uuid PRIMARY KEY,
  "area_id" uuid NOT NULL,
  "topic" varchar(220) NOT NULL,
  "staff_name" varchar(200),
  "staff_role" varchar(160),
  "staff_contact" varchar(200),
  "notes" varchar(700)
);

CREATE TABLE "assessment"."gap_register" (
  "id" uuid PRIMARY KEY,
  "assessment_id" uuid NOT NULL,
  "control_response_id" uuid,
  "title" varchar(220),
  "gap_text" text NOT NULL,
  "priority" varchar(10) NOT NULL DEFAULT 'MEDIA',
  "owner" varchar(200),
  "due_date" date,
  "status" varchar(20) NOT NULL DEFAULT 'PENDIENTE',
  "created_at" timestamptz NOT NULL DEFAULT (now()),
  "updated_at" timestamptz NOT NULL DEFAULT (now())
);

CREATE TABLE "assessment"."gap_action" (
  "id" uuid PRIMARY KEY,
  "gap_id" uuid NOT NULL,
  "description" text NOT NULL,
  "owner" varchar(200),
  "due_date" date,
  "status" varchar(20) NOT NULL DEFAULT 'PENDIENTE',
  "created_at" timestamptz NOT NULL DEFAULT (now()),
  "updated_at" timestamptz NOT NULL DEFAULT (now())
);

CREATE TABLE "evidence"."evidence_file" (
  "id" uuid PRIMARY KEY,
  "assessment_id" uuid NOT NULL,
  "relation_type" varchar(20) NOT NULL,
  "relation_id" uuid,
  "filename" varchar(260) NOT NULL,
  "content_type" varchar(120) NOT NULL,
  "size_bytes" bigint NOT NULL,
  "sha256" varchar(80) NOT NULL,
  "bucket" varchar(120) NOT NULL,
  "object_key" varchar(500) NOT NULL,
  "uploaded_by" uuid NOT NULL,
  "uploaded_at" timestamptz NOT NULL DEFAULT (now()),
  "deleted_at" timestamptz
);

CREATE TABLE "evidence"."lifting_answer" (
  "id" uuid PRIMARY KEY,
  "assessment_id" uuid NOT NULL,
  "question_catalog_id" uuid NOT NULL,
  "answer_json" jsonb NOT NULL,
  "updated_by" uuid,
  "updated_at" timestamptz NOT NULL DEFAULT (now()),
  "version" int NOT NULL DEFAULT 0
);

CREATE TABLE "evidence"."lifting_document_delivery" (
  "id" uuid PRIMARY KEY,
  "assessment_id" uuid NOT NULL,
  "document_item_catalog_id" uuid NOT NULL,
  "status" varchar(20) NOT NULL DEFAULT 'SOLICITADO',
  "delivered_name" varchar(260),
  "notes" text,
  "validated_by" uuid,
  "validated_at" timestamptz,
  "updated_at" timestamptz NOT NULL DEFAULT (now())
);

CREATE TABLE "evidence"."process_scope_metric" (
  "assessment_id" uuid PRIMARY KEY,
  "total_processes" int NOT NULL,
  "in_scope_processes" int NOT NULL,
  "coverage" numeric(6,4) NOT NULL,
  "updated_at" timestamptz NOT NULL DEFAULT (now())
);

CREATE TABLE "reporting"."report_template" (
  "id" uuid PRIMARY KEY,
  "name" varchar(60) NOT NULL,
  "version" int NOT NULL DEFAULT 1,
  "jrxml_path" varchar(300) NOT NULL,
  "active" boolean NOT NULL DEFAULT true,
  "created_at" timestamptz NOT NULL DEFAULT (now())
);

CREATE TABLE "reporting"."report_generation_job" (
  "id" uuid PRIMARY KEY,
  "assessment_id" uuid NOT NULL,
  "report_type" varchar(40) NOT NULL,
  "status" varchar(20) NOT NULL DEFAULT 'PENDING',
  "requested_by" uuid NOT NULL,
  "requested_at" timestamptz NOT NULL DEFAULT (now()),
  "started_at" timestamptz,
  "finished_at" timestamptz,
  "output_file_id" uuid,
  "error_message" text
);

CREATE TABLE "reporting"."analytics_cache" (
  "id" uuid PRIMARY KEY,
  "assessment_id" uuid NOT NULL,
  "kind" varchar(30) NOT NULL,
  "payload_json" jsonb NOT NULL,
  "source_hash" varchar(80) NOT NULL,
  "computed_at" timestamptz NOT NULL DEFAULT (now())
);

CREATE UNIQUE INDEX ON "iam"."user_role" ("user_id", "role_id");

CREATE INDEX ON "iam"."user_role" ("role_id");

CREATE INDEX ON "iam"."audit_log" ("assessment_id", "occurred_at");

CREATE INDEX ON "iam"."audit_log" ("actor_user_id", "occurred_at");

CREATE INDEX ON "iam"."audit_log" ("event_type", "occurred_at");

CREATE INDEX ON "org"."organization" ("name");

CREATE INDEX ON "org"."organization" ("identifier");

CREATE UNIQUE INDEX ON "org"."organization" ("name", "identifier");

CREATE INDEX ON "org"."organization_contact" ("organization_id");

CREATE INDEX ON "org"."organization_contact" ("organization_id", "is_primary");

CREATE INDEX ON "org"."organization_area_base" ("organization_id");

CREATE UNIQUE INDEX ON "org"."organization_area_base" ("organization_id", "area_name");

CREATE INDEX ON "org"."organization_area_base_topic" ("area_base_id");

CREATE UNIQUE INDEX ON "catalog"."scale_version" ("scale_id", "version");

CREATE INDEX ON "catalog"."scale_version" ("status");

CREATE INDEX ON "catalog"."scale_level" ("scale_version_id");

CREATE INDEX ON "catalog"."scale_level" ("scale_version_id", "position");

CREATE UNIQUE INDEX ON "catalog"."scale_level" ("scale_version_id", "value");

CREATE INDEX ON "catalog"."scale_band" ("scale_version_id");

CREATE INDEX ON "catalog"."scale_band" ("scale_version_id", "position");

CREATE UNIQUE INDEX ON "catalog"."template_version" ("template_id", "version");

CREATE INDEX ON "catalog"."template_version" ("status");

CREATE INDEX ON "catalog"."control_catalog_node" ("template_version_id");

CREATE INDEX ON "catalog"."control_catalog_node" ("template_version_id", "parent_id", "position");

CREATE UNIQUE INDEX ON "catalog"."control_catalog_node" ("template_version_id", "code");

CREATE INDEX ON "catalog"."control_catalog_node" ("template_version_id", "iso_domain_code");

CREATE UNIQUE INDEX ON "catalog"."phva_item_catalog" ("template_version_id", "code");

CREATE INDEX ON "catalog"."phva_item_catalog" ("template_version_id", "component");

CREATE UNIQUE INDEX ON "catalog"."maturity_requirement_catalog" ("template_version_id", "code");

CREATE INDEX ON "catalog"."maturity_requirement_control_map" ("requirement_id");

CREATE UNIQUE INDEX ON "catalog"."maturity_requirement_control_map" ("requirement_id", "control_node_id");

CREATE UNIQUE INDEX ON "catalog"."maturity_threshold" ("requirement_id", "level");

CREATE INDEX ON "catalog"."nist_subcategory" ("function_id");

CREATE INDEX ON "catalog"."nist_mapping" ("template_version_id");

CREATE INDEX ON "catalog"."nist_mapping" ("template_version_id", "subcategory_id");

CREATE UNIQUE INDEX ON "catalog"."nist_mapping" ("template_version_id", "subcategory_id", "control_node_id");

CREATE UNIQUE INDEX ON "catalog"."lifting_question_catalog" ("template_version_id", "code");

CREATE INDEX ON "catalog"."lifting_question_catalog" ("template_version_id", "section");

CREATE UNIQUE INDEX ON "catalog"."lifting_document_item_catalog" ("template_version_id", "item_number");

CREATE INDEX ON "assessment"."assessment" ("organization_id");

CREATE INDEX ON "assessment"."assessment" ("template_version_id");

CREATE INDEX ON "assessment"."assessment" ("status");

CREATE INDEX ON "assessment"."assessment" ("created_at");

CREATE UNIQUE INDEX ON "assessment"."assessment_member" ("assessment_id", "user_id");

CREATE INDEX ON "assessment"."assessment_member" ("assessment_id", "member_role");

CREATE INDEX ON "assessment"."assessment_member" ("user_id");

CREATE INDEX ON "assessment"."assessment_status_history" ("assessment_id", "changed_at");

CREATE INDEX ON "assessment"."assessment_control_node" ("assessment_id");

CREATE INDEX ON "assessment"."assessment_control_node" ("assessment_id", "parent_id", "position");

CREATE UNIQUE INDEX ON "assessment"."assessment_control_node" ("assessment_id", "code");

CREATE INDEX ON "assessment"."assessment_control_node" ("assessment_id", "iso_domain_code");

CREATE INDEX ON "assessment"."assessment_control_node" ("assessment_id", "control_type");

CREATE INDEX ON "assessment"."control_response" ("assessment_id");

CREATE UNIQUE INDEX ON "assessment"."control_response" ("assessment_id", "control_node_id");

CREATE INDEX ON "assessment"."control_response" ("assessment_id", "control_status");

CREATE INDEX ON "assessment"."control_response" ("assessment_id", "score_status");

CREATE INDEX ON "assessment"."control_comment_thread" ("control_response_id");

CREATE INDEX ON "assessment"."control_comment_thread" ("is_resolved");

CREATE INDEX ON "assessment"."control_comment" ("thread_id", "created_at");

CREATE INDEX ON "assessment"."assessment_area" ("assessment_id");

CREATE UNIQUE INDEX ON "assessment"."assessment_area" ("assessment_id", "area_name");

CREATE INDEX ON "assessment"."assessment_area_topic" ("area_id");

CREATE INDEX ON "assessment"."gap_register" ("assessment_id");

CREATE INDEX ON "assessment"."gap_register" ("assessment_id", "priority");

CREATE INDEX ON "assessment"."gap_register" ("assessment_id", "status");

CREATE INDEX ON "assessment"."gap_action" ("gap_id");

CREATE INDEX ON "assessment"."gap_action" ("gap_id", "status");

CREATE INDEX ON "evidence"."evidence_file" ("assessment_id");

CREATE INDEX ON "evidence"."evidence_file" ("assessment_id", "relation_type");

CREATE INDEX ON "evidence"."evidence_file" ("relation_type", "relation_id");

CREATE INDEX ON "evidence"."evidence_file" ("sha256");

CREATE INDEX ON "evidence"."lifting_answer" ("assessment_id");

CREATE UNIQUE INDEX ON "evidence"."lifting_answer" ("assessment_id", "question_catalog_id");

CREATE INDEX ON "evidence"."lifting_document_delivery" ("assessment_id");

CREATE UNIQUE INDEX ON "evidence"."lifting_document_delivery" ("assessment_id", "document_item_catalog_id");

CREATE INDEX ON "evidence"."lifting_document_delivery" ("assessment_id", "status");

CREATE UNIQUE INDEX ON "reporting"."report_template" ("name", "version");

CREATE INDEX ON "reporting"."report_template" ("active");

CREATE INDEX ON "reporting"."report_generation_job" ("assessment_id", "requested_at");

CREATE INDEX ON "reporting"."report_generation_job" ("status");

CREATE UNIQUE INDEX ON "reporting"."analytics_cache" ("assessment_id", "kind");

CREATE INDEX ON "reporting"."analytics_cache" ("computed_at");

COMMENT ON COLUMN "iam"."user"."password_hash" IS 'Only if auth is internal. If Keycloak, omit this field.';

COMMENT ON COLUMN "iam"."user"."status" IS 'ACTIVE|INACTIVE';

COMMENT ON COLUMN "iam"."user"."locked_until" IS 'If not null and > now => locked';

COMMENT ON COLUMN "iam"."role"."name" IS 'AdminSistema|AdminInstrumento|Evaluador|Revisor|Lector';

COMMENT ON COLUMN "iam"."system_config"."key" IS 'e.g. file.maxSizeBytes, assessment.minCompletionForReview, etc.';

COMMENT ON COLUMN "org"."organization"."identifier" IS 'NIT or internal identifier';

COMMENT ON COLUMN "org"."organization"."type" IS 'e.g. PUBLIC|PRIVATE|EDU|OTHER';

COMMENT ON COLUMN "catalog"."scale_version"."status" IS 'DRAFT|PUBLISHED';

COMMENT ON COLUMN "catalog"."scale_level"."value" IS '0..100; null if is_na=true';

COMMENT ON COLUMN "catalog"."scale_band"."label" IS 'INEXISTENTE|INICIAL|REPETIBLE|EFECTIVO|GESTIONADO|OPTIMIZADO';

COMMENT ON COLUMN "catalog"."template_version"."status" IS 'DRAFT|PUBLISHED';

COMMENT ON COLUMN "catalog"."template_version"."maturity_global_rule" IS 'MIN|AVG|MAJORITY';

COMMENT ON COLUMN "catalog"."template_version"."maturity_crit_thresholds" IS 'thresholds for SUFICIENTE/INTERMEDIO/CRITICO, per Excel';

COMMENT ON COLUMN "catalog"."template_version"."phva_weights" IS 'optional: {PLAN:0.25,DO:0.25,CHECK:0.25,ACT:0.25}';

COMMENT ON COLUMN "catalog"."template_version"."phva_caps" IS 'optional: caps/topes like Excel if any';

COMMENT ON COLUMN "catalog"."iso_domain"."code" IS 'A.5..A.18';

COMMENT ON COLUMN "catalog"."control_catalog_node"."node_type" IS 'SECTION|CONTROL';

COMMENT ON COLUMN "catalog"."control_catalog_node"."control_type" IS 'ADMIN|TECH; only for CONTROL nodes';

COMMENT ON COLUMN "catalog"."control_catalog_node"."code" IS 'AD.1, AD.2.1, T.1... only for CONTROL nodes';

COMMENT ON COLUMN "catalog"."control_catalog_node"."is_scored" IS 'true only for CONTROL nodes';

COMMENT ON COLUMN "catalog"."control_rule"."recommendation_rule_type" IS 'ALWAYS|THRESHOLD|NEVER';

COMMENT ON COLUMN "catalog"."control_rule"."recommendation_threshold_value" IS 'e.g. 60';

COMMENT ON COLUMN "catalog"."control_rule"."max_files" IS 'override global config';

COMMENT ON COLUMN "catalog"."control_rule"."max_text_len" IS 'optional per field: {evidence:5000,gap:3000,recommendation:3000}';

COMMENT ON COLUMN "catalog"."phva_item_catalog"."component" IS 'PLAN|DO|CHECK|ACT';

COMMENT ON COLUMN "catalog"."phva_item_catalog"."source_control_code" IS 'for 1:1 derivation like Excel (VLOOKUP/cell refs)';

COMMENT ON COLUMN "catalog"."maturity_threshold"."level" IS '1..5';

COMMENT ON COLUMN "catalog"."maturity_threshold"."expected_value" IS 'e.g. 40/60/80/100';

COMMENT ON COLUMN "catalog"."nist_function"."code" IS 'ID|PR|DE|RS|RC';

COMMENT ON COLUMN "catalog"."nist_subcategory"."code" IS 'DE.AE-1, RC.IM-1, ...';

COMMENT ON COLUMN "catalog"."nist_mapping"."iso_control_code" IS 'fallback mapping like Excel uses ''CONTROL ISO''';

COMMENT ON COLUMN "catalog"."lifting_question_catalog"."field_type" IS 'TEXT|TEXTAREA|NUMBER|SELECT|MULTISELECT|DATE';

COMMENT ON COLUMN "catalog"."lifting_question_catalog"."options_json" IS 'for SELECT/MULTISELECT';

COMMENT ON COLUMN "assessment"."assessment"."status" IS 'BORRADOR|EN_DILIGENCIAMIENTO|EN_REVISION|CERRADA';

COMMENT ON COLUMN "assessment"."assessment_member"."member_role" IS 'EVALUATOR|REVIEWER|READER';

COMMENT ON COLUMN "assessment"."assessment_control_node"."node_type" IS 'SECTION|CONTROL';

COMMENT ON COLUMN "assessment"."assessment_control_node"."control_type" IS 'ADMIN|TECH';

COMMENT ON COLUMN "assessment"."assessment_control_node"."rules_json" IS 'control_rule snapshot for 1:1 behavior';

COMMENT ON COLUMN "assessment"."control_response"."score_status" IS 'PENDING|SCORED|NA';

COMMENT ON COLUMN "assessment"."control_response"."score_value" IS 'null if NA/PENDING';

COMMENT ON COLUMN "assessment"."control_response"."control_status" IS 'PENDIENTE|EN_PROGRESO|COMPLETO|VALIDADO|REQUIERE_AJUSTES';

COMMENT ON COLUMN "assessment"."control_review"."review_status" IS 'VALIDATED|NEEDS_CHANGES';

COMMENT ON COLUMN "assessment"."control_review"."severity" IS 'LOW|MEDIUM|HIGH optional';

COMMENT ON COLUMN "assessment"."gap_register"."priority" IS 'ALTA|MEDIA|BAJA';

COMMENT ON COLUMN "assessment"."gap_register"."status" IS 'PENDIENTE|EN_PROGRESO|COMPLETADA';

COMMENT ON COLUMN "evidence"."evidence_file"."relation_type" IS 'CONTROL|LIFTING_DOC|GLOBAL|GAP_ACTION';

COMMENT ON COLUMN "evidence"."evidence_file"."relation_id" IS 'control_node_id OR lifting_document_delivery_id OR gap_action_id (depending on relation_type)';

COMMENT ON COLUMN "evidence"."lifting_answer"."answer_json" IS 'supports different field types; store plain text as {value:''...''}';

COMMENT ON COLUMN "evidence"."lifting_document_delivery"."status" IS 'SOLICITADO|RECIBIDO|VALIDADO|INCOMPLETO';

COMMENT ON COLUMN "evidence"."process_scope_metric"."coverage" IS 'computed: in_scope/total';

COMMENT ON COLUMN "reporting"."report_template"."name" IS 'EXECUTIVE|TECHNICAL';

COMMENT ON COLUMN "reporting"."report_template"."jrxml_path" IS 'classpath path to jrxml/jasper';

COMMENT ON COLUMN "reporting"."report_generation_job"."report_type" IS 'PDF_EXECUTIVE|PDF_TECHNICAL|XLSX_EXACT';

COMMENT ON COLUMN "reporting"."report_generation_job"."status" IS 'PENDING|RUNNING|DONE|FAILED';

COMMENT ON COLUMN "reporting"."report_generation_job"."output_file_id" IS 'Stored PDF/XLSX in evidence service for download';

COMMENT ON COLUMN "reporting"."analytics_cache"."kind" IS 'ISO|PHVA|MATURITY|NIST|ROLLUP';

COMMENT ON COLUMN "reporting"."analytics_cache"."source_hash" IS 'hash of inputs: responses + mappings + scale to invalidate';

ALTER TABLE "iam"."user_role" ADD FOREIGN KEY ("user_id") REFERENCES "iam"."user" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "iam"."user_role" ADD FOREIGN KEY ("role_id") REFERENCES "iam"."role" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "iam"."system_config" ADD FOREIGN KEY ("updated_by") REFERENCES "iam"."user" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "iam"."audit_log" ADD FOREIGN KEY ("assessment_id") REFERENCES "assessment"."assessment" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "iam"."audit_log" ADD FOREIGN KEY ("actor_user_id") REFERENCES "iam"."user" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "org"."organization_contact" ADD FOREIGN KEY ("organization_id") REFERENCES "org"."organization" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "org"."organization_area_base" ADD FOREIGN KEY ("organization_id") REFERENCES "org"."organization" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "org"."organization_area_base_topic" ADD FOREIGN KEY ("area_base_id") REFERENCES "org"."organization_area_base" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "catalog"."scale_version" ADD FOREIGN KEY ("scale_id") REFERENCES "catalog"."scale" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "catalog"."scale_level" ADD FOREIGN KEY ("scale_version_id") REFERENCES "catalog"."scale_version" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "catalog"."scale_band" ADD FOREIGN KEY ("scale_version_id") REFERENCES "catalog"."scale_version" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "catalog"."template_version" ADD FOREIGN KEY ("template_id") REFERENCES "catalog"."template" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "catalog"."template_version" ADD FOREIGN KEY ("scale_version_id") REFERENCES "catalog"."scale_version" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "catalog"."control_catalog_node" ADD FOREIGN KEY ("template_version_id") REFERENCES "catalog"."template_version" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "catalog"."control_catalog_node" ADD FOREIGN KEY ("parent_id") REFERENCES "catalog"."control_catalog_node" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "catalog"."control_catalog_node" ADD FOREIGN KEY ("iso_domain_code") REFERENCES "catalog"."iso_domain" ("code") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "catalog"."control_rule" ADD FOREIGN KEY ("control_node_id") REFERENCES "catalog"."control_catalog_node" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "catalog"."phva_item_catalog" ADD FOREIGN KEY ("template_version_id") REFERENCES "catalog"."template_version" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "catalog"."phva_item_catalog" ADD FOREIGN KEY ("source_control_node_id") REFERENCES "catalog"."control_catalog_node" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "catalog"."maturity_requirement_catalog" ADD FOREIGN KEY ("template_version_id") REFERENCES "catalog"."template_version" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "catalog"."maturity_requirement_control_map" ADD FOREIGN KEY ("requirement_id") REFERENCES "catalog"."maturity_requirement_catalog" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "catalog"."maturity_requirement_control_map" ADD FOREIGN KEY ("control_node_id") REFERENCES "catalog"."control_catalog_node" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "catalog"."maturity_threshold" ADD FOREIGN KEY ("requirement_id") REFERENCES "catalog"."maturity_requirement_catalog" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "catalog"."nist_subcategory" ADD FOREIGN KEY ("function_id") REFERENCES "catalog"."nist_function" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "catalog"."nist_mapping" ADD FOREIGN KEY ("template_version_id") REFERENCES "catalog"."template_version" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "catalog"."nist_mapping" ADD FOREIGN KEY ("subcategory_id") REFERENCES "catalog"."nist_subcategory" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "catalog"."nist_mapping" ADD FOREIGN KEY ("control_node_id") REFERENCES "catalog"."control_catalog_node" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "catalog"."lifting_question_catalog" ADD FOREIGN KEY ("template_version_id") REFERENCES "catalog"."template_version" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "catalog"."lifting_document_item_catalog" ADD FOREIGN KEY ("template_version_id") REFERENCES "catalog"."template_version" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "assessment"."assessment" ADD FOREIGN KEY ("organization_id") REFERENCES "org"."organization" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "assessment"."assessment" ADD FOREIGN KEY ("template_version_id") REFERENCES "catalog"."template_version" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "assessment"."assessment" ADD FOREIGN KEY ("created_by") REFERENCES "iam"."user" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "assessment"."assessment" ADD FOREIGN KEY ("status_changed_by") REFERENCES "iam"."user" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "assessment"."assessment_member" ADD FOREIGN KEY ("assessment_id") REFERENCES "assessment"."assessment" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "assessment"."assessment_member" ADD FOREIGN KEY ("user_id") REFERENCES "iam"."user" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "assessment"."assessment_metadata" ADD FOREIGN KEY ("assessment_id") REFERENCES "assessment"."assessment" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "assessment"."assessment_status_history" ADD FOREIGN KEY ("assessment_id") REFERENCES "assessment"."assessment" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "assessment"."assessment_status_history" ADD FOREIGN KEY ("changed_by") REFERENCES "iam"."user" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "assessment"."assessment_control_node" ADD FOREIGN KEY ("assessment_id") REFERENCES "assessment"."assessment" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "assessment"."assessment_control_node" ADD FOREIGN KEY ("source_catalog_node_id") REFERENCES "catalog"."control_catalog_node" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "assessment"."assessment_control_node" ADD FOREIGN KEY ("parent_id") REFERENCES "assessment"."assessment_control_node" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "assessment"."assessment_control_node" ADD FOREIGN KEY ("iso_domain_code") REFERENCES "catalog"."iso_domain" ("code") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "assessment"."control_response" ADD FOREIGN KEY ("assessment_id") REFERENCES "assessment"."assessment" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "assessment"."control_response" ADD FOREIGN KEY ("control_node_id") REFERENCES "assessment"."assessment_control_node" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "assessment"."control_response" ADD FOREIGN KEY ("updated_by") REFERENCES "iam"."user" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "assessment"."control_review" ADD FOREIGN KEY ("control_response_id") REFERENCES "assessment"."control_response" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "assessment"."control_review" ADD FOREIGN KEY ("reviewed_by") REFERENCES "iam"."user" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "assessment"."control_comment_thread" ADD FOREIGN KEY ("control_response_id") REFERENCES "assessment"."control_response" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "assessment"."control_comment_thread" ADD FOREIGN KEY ("created_by") REFERENCES "iam"."user" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "assessment"."control_comment_thread" ADD FOREIGN KEY ("resolved_by") REFERENCES "iam"."user" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "assessment"."control_comment" ADD FOREIGN KEY ("thread_id") REFERENCES "assessment"."control_comment_thread" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "assessment"."control_comment" ADD FOREIGN KEY ("author_user_id") REFERENCES "iam"."user" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "assessment"."assessment_area" ADD FOREIGN KEY ("assessment_id") REFERENCES "assessment"."assessment" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "assessment"."assessment_area_topic" ADD FOREIGN KEY ("area_id") REFERENCES "assessment"."assessment_area" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "assessment"."gap_register" ADD FOREIGN KEY ("assessment_id") REFERENCES "assessment"."assessment" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "assessment"."gap_register" ADD FOREIGN KEY ("control_response_id") REFERENCES "assessment"."control_response" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "assessment"."gap_action" ADD FOREIGN KEY ("gap_id") REFERENCES "assessment"."gap_register" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "evidence"."evidence_file" ADD FOREIGN KEY ("assessment_id") REFERENCES "assessment"."assessment" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "evidence"."evidence_file" ADD FOREIGN KEY ("uploaded_by") REFERENCES "iam"."user" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "evidence"."lifting_answer" ADD FOREIGN KEY ("assessment_id") REFERENCES "assessment"."assessment" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "evidence"."lifting_answer" ADD FOREIGN KEY ("question_catalog_id") REFERENCES "catalog"."lifting_question_catalog" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "evidence"."lifting_answer" ADD FOREIGN KEY ("updated_by") REFERENCES "iam"."user" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "evidence"."lifting_document_delivery" ADD FOREIGN KEY ("assessment_id") REFERENCES "assessment"."assessment" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "evidence"."lifting_document_delivery" ADD FOREIGN KEY ("document_item_catalog_id") REFERENCES "catalog"."lifting_document_item_catalog" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "evidence"."lifting_document_delivery" ADD FOREIGN KEY ("validated_by") REFERENCES "iam"."user" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "evidence"."process_scope_metric" ADD FOREIGN KEY ("assessment_id") REFERENCES "assessment"."assessment" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "reporting"."report_generation_job" ADD FOREIGN KEY ("assessment_id") REFERENCES "assessment"."assessment" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "reporting"."report_generation_job" ADD FOREIGN KEY ("requested_by") REFERENCES "iam"."user" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "reporting"."report_generation_job" ADD FOREIGN KEY ("output_file_id") REFERENCES "evidence"."evidence_file" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "reporting"."analytics_cache" ADD FOREIGN KEY ("assessment_id") REFERENCES "assessment"."assessment" ("id") DEFERRABLE INITIALLY IMMEDIATE;
