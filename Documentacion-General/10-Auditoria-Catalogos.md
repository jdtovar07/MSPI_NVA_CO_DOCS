# 10 · Auditoría de datos de referencia / catálogos

| | |
|---|---|
| **Proyecto** | MSPI: Sistema de Gestión de Seguridad y Privacidad de la Información |
| **Autores** | Bairon Alexander Suarez Camacho, Juan Diego Tovar Rodriguez |
| **Documento** | Clasificación de los datos de referencia del sistema: qué ya es catálogo, qué está fuera por diseño y qué debería serlo |
| **Fecha** | 2026-10-09 |

> Barrido completo de los datos de referencia (lookup/paramétricos) que usa la plataforma, para responder a la observación de revisión sobre tener los catálogos en tablas y no reutilizar APIs externas.

---

## A) Ya modelado como catálogo (tablas en `ms_catalog`) ✅

Todo el dominio del instrumento MSPI está en catálogo versionado por `template_version`:

- **Plantilla/versiones:** `template`, `template_version`
- **Controles:** `control_catalog_node`, `control_rule`, `iso_domain`
- **Escala:** `scale`, `scale_version`, `scale_level`, `scale_band`
- **PHVA / Madurez / NIST:** `phva_item_catalog`, `maturity_requirement_catalog`, `maturity_threshold`, `nist_function`, `nist_subcategory`, `nist_mapping`, `nist_ciber_item_catalog`
- **Otros paramétricos:** `entity_order_type` (tipos de entidad), `lifting_document_item_catalog`, `steward_role`, `assessment_area_preset`, `question_bank`, `question_bank_question`

→ El dato de negocio del autodiagnóstico **sí** está correctamente en catálogos.

## B) Datos de referencia fuera de `ms_catalog`

### B1. Correcto fuera de catálogo (por diseño) ✅
- **Roles de usuario** → provienen de **Keycloak** (realm `iam`), enriquecidos en `ms_iam`. Correcto: es identidad, no catálogo de negocio.
- **Estados/tipos técnicos como enums:** `UserStatus` (`ms_iam`), `AssessmentStatus`, `ReportType`, `ReportJobStatus`, `AuditResult`. Son valores de estado del propio sistema; estándar mantenerlos como enums en código. No requieren catálogo.

### B2. Candidatos a catálogo ⚠️

| Dato | Hoy | Problema | Prioridad |
|---|---|---|---|
| **Geografía** (países/departamentos/ciudades) | API externa **Country State City** (`https://api.countrystatecity.in/v1`) consumida por `ms_org` (`LocationCatalogAdapter`, `CountryStateCityClientConfig`; API key por Infisical, env `LOCATION_API_KEY`) | No es catálogo local: **depende de un servicio externo** (si cae, no hay geografía), requiere API key y agrega latencia. Es el caso de "reutilizar una API que trae datos que deberían ser catálogo". | **ALTA** — decidido mantener API (ver C.1) |
| **Reglas de workflow** de la evaluación | **Hardcodeadas** en `GetWorkflowRulesUseCase` (`WorkflowRules.builder()...`, sin tabla) | Regla de negocio en código; no configurable ni versionable como catálogo. | MEDIA (discutible) |

## C) Recomendación y decisión

1. **Geografía — DECISIÓN DEL EQUIPO (2026-10-09): se mantiene la API externa Country State City.**
   Justificación: la geografía (países/departamentos/ciudades) es un **dato de referencia universal y estable**, no específico del dominio MSPI; usar la API externa **evita mantener y versionar un catálogo geográfico completo** (que quedaría desactualizado frente a cambios administrativos del país). Ante indisponibilidad del servicio, el sistema **degrada de forma controlada** (`ms_org` devuelve listas vacías, no falla el arranque). Los catálogos del **dominio del instrumento** (controles, escala, PHVA, madurez, NIST, tipos de entidad, etc.) **sí** están modelados como tablas en `ms_catalog`. Si en el futuro se requiere operación 100 % offline o independencia total de terceros, la alternativa sería un **espejo/caché local** de la geografía persistido como catálogo (sin migración disruptiva).
2. **Reglas de workflow → catálogo (MEDIA, opcional).** Si se requiere que las transiciones de estado sean configurables, mover a una tabla `workflow_rule`. Si se consideran regla de negocio pura, pueden quedarse en código. (Sin cambio por ahora.)
3. **Enums de estado → sin cambios.** No aportan valor como catálogo.

**Conclusión:** los catálogos del dominio del instrumento están correctamente en tablas (`ms_catalog`); la identidad va en Keycloak y los estados como enums. El único dato de referencia externo es la **geografía**, que **por decisión del equipo se mantiene vía API externa** con degradación controlada, por las razones de C.1.

## D) Nota operativa — API key de geografía

Mientras la geografía siga consumiendo la API externa, la API key se gestiona así:
- **Proveedor / regenerar la key:** <https://countrystatecity.in/> → iniciar sesión → *My Account / API Keys* → generar/regenerar. Se envía en el header `X-CSCAPI-KEY`.
- **Dónde actualizarla:** en **Infisical** (variable `LOCATION_API_KEY`) y, para Docker local, en `docker-config/docker/env-mspi-docker.env` (`LOCATION_API_KEY=...`). Base URL: `BASE_URL_LOCATION_API=https://api.countrystatecity.in/v1`.
- Si la key no está configurada, `ms_org` devuelve listas vacías de geografía (no rompe el arranque). Migrar la geografía a catálogo local (recomendación C.1) elimina esta dependencia.
