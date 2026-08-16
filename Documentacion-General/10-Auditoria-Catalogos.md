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
| **Geografía** (países/departamentos/ciudades) | API externa **Country State City** (`https://api.countrystatecity.in/v1`) consumida por `ms_org` (`LocationCatalogAdapter`, `CountryStateCityClientConfig`; API key por Infisical, env `LOCATION_API_KEY`) | No es catálogo local: **depende de un servicio externo** (si cae, no hay geografía), requiere API key y agrega latencia. Es el caso de "reutilizar una API que trae datos que deberían ser catálogo". | **ALTA** |
| **Reglas de workflow** de la evaluación | **Hardcodeadas** en `GetWorkflowRulesUseCase` (`WorkflowRules.builder()...`, sin tabla) | Regla de negocio en código; no configurable ni versionable como catálogo. | MEDIA (discutible) |

## C) Recomendación

1. **Geografía → catálogo local (ALTA).** Crear tablas (p. ej. `org.country` / `org.state` / `org.city`, o un esquema `location`) sembradas con los datos de Colombia (fuente DANE) y migrar `ms_org /location/**` a leer de BD. Elimina la dependencia externa y la API key. Alternativa intermedia: mantener la API externa pero con **caché/espejo local** persistido como catálogo.
2. **Reglas de workflow → catálogo (MEDIA, opcional).** Si se requiere que las transiciones de estado sean configurables, mover a una tabla `workflow_rule`. Si se consideran regla de negocio pura, pueden quedarse en código.
3. **Enums de estado → sin cambios.** No aportan valor como catálogo.

**Conclusión:** el único dato de referencia que claramente *debería ser catálogo y hoy se reutiliza de una API externa* es la **geografía**. El resto está correcto (catálogos de negocio en `ms_catalog`, identidad en Keycloak, estados como enums).

## D) Nota operativa — API key de geografía

Mientras la geografía siga consumiendo la API externa, la API key se gestiona así:
- **Proveedor / regenerar la key:** <https://countrystatecity.in/> → iniciar sesión → *My Account / API Keys* → generar/regenerar. Se envía en el header `X-CSCAPI-KEY`.
- **Dónde actualizarla:** en **Infisical** (variable `LOCATION_API_KEY`) y, para Docker local, en `docker-config/docker/env-mspi-docker.env` (`LOCATION_API_KEY=...`). Base URL: `BASE_URL_LOCATION_API=https://api.countrystatecity.in/v1`.
- Si la key no está configurada, `ms_org` devuelve listas vacías de geografía (no rompe el arranque). Migrar la geografía a catálogo local (recomendación C.1) elimina esta dependencia.
