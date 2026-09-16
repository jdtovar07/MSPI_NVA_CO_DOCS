# 16 · Glosario del dominio MSPI

| Campo | Valor |
|---|---|
| Fuentes | `02-Modelo-de-Dominio.md`, `14-Flujos-…`, SDLC backend/frontend, código verificado |

Términos usados de forma consistente en la documentación. No sustituye normas ISO/NIST; solo el uso **en este proyecto**.

**Cómo leer diagramas Mermaid** (flowchart, sequence, ER, class): ver sección 0 de [`15-Diagramas-C4-y-Secuencias.md`](15-Diagramas-C4-y-Secuencias.md). Cada diagrama en la wiki lleva título y párrafo de contexto.

| Término | Definición en MSPI |
|---|---|
| **Instrumento** | Instrumento de Identificación de la Línea Base de Seguridad (MinTIC): plantilla Excel de autodiagnóstico cuyas reglas de cálculo reproduce la plataforma. |
| **Plantilla / template_version** | Versión publicada del instrumento en `catalog` (controles, PHVA, madurez, NIST, levantamiento). Al crear una evaluación se toma un *snapshot*. |
| **Evaluación (assessment)** | Instancia de aplicación del instrumento a una organización (`assessment.assessment`). Tiene ciclo de vida, miembros y scores. |
| **Control** | Nodo del árbol ISO Anexo A calificado en la evaluación (`assessment_control_node` / respuesta). |
| **PHVA** | Ciclo Planear–Hacer–Verificar–Actuar. En v2: pesos 56/16/14/14 y jerarquía cláusula → sub-numeral. |
| **Madurez (SGSI)** | Nivel acumulativo de madurez organizacional según requisitos del catálogo y umbrales. |
| **NIST CSF** | Segunda lente de evaluación (Cybersecurity Framework). v2 alinea CSF 2.0. |
| **Escala** | Definición versionada de niveles/bandas de puntuación en `catalog` (admin de instrumento). |
| **Banco de preguntas** | Catálogo administrable de preguntas asociadas a escalas/configuración (`catalog`). |
| **Brecha (gap)** | Hallazgo de no conformidad / oportunidad derivado del diagnóstico (`gap_register` / listados de gaps). |
| **Levantamiento** | Inventario documental de evidencias por ítem de catálogo (`lifting_document_delivery`). |
| **Evidencia** | Archivo o registro de soporte (`evidence_file`) ligado a contexto, levantamiento, control o reporte. |
| **Radicado (`requestNumber`)** | Identificador legible de solicitud: `SOL-ELIM-######`, `SOL-AMPL-######`, `SOL-PWD-######`, `SOL-CAT-######`. |
| **Solicitud aprobable** | Flujo REQUESTED → APPROVED/REJECTED/CANCELLED → (opcional) EXECUTED, con eventos en `ms_audit`. |
| **Borrado lógico** | Marcado con `deleted_at` (u equivalente); **no** se elimina físicamente el registro/archivo en operación normal. |
| **Periodo de gracia** | Días entre aprobación de eliminación y el soft-delete efectivo (`assessmentDeletionGraceDays` / `catalogDeletionGraceDays` en `ms_admin`). |
| **Sweeper** | Job/horario que aplica soft-delete a solicitudes APPROVED cuya `scheduledDeletionAt` ya venció. |
| **Auditoría central** | Bitácora `audit.audit_log` en `ms_audit` (:8088); correlación por `metadata.requestNumber`. |
| **Configuración global** | Parámetros en `admin.system_config` (`ms_admin` :8089): plazos, gracia, etc. |
| **Shell / host** | `mf_shell` (:4200): menú, dashboard, guards; embebe MF hijos en iframe. |
| **Iframe bridge** | Protocolo `postMessage` (`shell-iframe-bridge.ts`): sesión, evaluación activa, navegación cruzada. |
| **Module Federation** | Mecanismo Webpack de composición de MF. En MSPI es **evolución futura**; la composición actual es iframe + postMessage. |
| **JWT / JWK** | Token de acceso emitido por Keycloak; validado por cada MS como Resource Server. |
| **API-key interna** | Header `X-Internal-Api-Key` para rutas `/internal/**` (S2S). |
| **2FA / TOTP** | Segundo factor basado en tiempo; secreto en `iam.user_totp`. |
| **RBAC** | Control de acceso por roles de negocio (`AdminSistema`, `AdminInstrumento`, `Evaluador`, `Revisor`, `EvaluadorRevisor`, `Lector`). |
| **Bounded context** | Partición de dominio con esquema PostgreSQL propio (8 contextos activos). |
| **Hexagonal / Clean Architecture** | Capas `domain` / `usecase` / adaptadores Gradle por microservicio. |
| **Wiki** | GitHub Wiki del repositorio DOCS (`MSPI_NVA_CO_DOCS.wiki`): hub navegable que enlaza a estos documentos. La configuración MkDocs del repo es una alternativa local (`mkdocs serve`). |
| **AUDITCYBER** | Nombre comercial de la plataforma MSPI que ven los usuarios (correos, interfaz). |
| **Keycloak** | Proveedor de identidad (IdP): guarda credenciales, emite los JWT y administra los roles del *realm*. |
| **Brevo** | Proveedor de correo transaccional usado para enviar contraseñas temporales y avisos. |
| **Contraseña temporal** | Contraseña de un solo uso enviada por correo; obliga a cambiarla en el primer ingreso. |
| **Reenvío de contraseña (`SOL-PWD`)** | Solicitud aprobable que genera una contraseña temporal nueva y **reinicia el 2FA** del usuario. |
| **Estado de evaluación** | Borrador → En diligenciamiento → En revisión → Cerrada (con devolución y reapertura), validado por `AssessmentStatuses`. |
| **Ítem heredado / manual** | En PHVA, Madurez y NIST: el heredado se calcula a partir de los controles; el manual lo califica el evaluador. |
| **Instrumento oficial (reporte)** | Libro Excel de 11 hojas o su PDF, diligenciado con los datos de la evaluación y protegido contra edición. |
| **Trabajo de reporte (job)** | Generación asíncrona de un reporte: PENDING → RUNNING → COMPLETED/FAILED. |
| **Datos personales / titular** | Información de personas naturales (usuarios); su tratamiento sigue la Ley 1581 de 2012 y la política de privacidad del proyecto. |
| **Habeas data** | Derecho del titular a conocer, actualizar, rectificar y suprimir sus datos (Ley 1581 de 2012, art. 8). |
