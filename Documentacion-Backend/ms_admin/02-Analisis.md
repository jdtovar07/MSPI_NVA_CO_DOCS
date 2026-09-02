# ms_admin — Análisis

| Campo | Valor |
|---|---|
| Repositorio | `MSPI_NVA_CO_MR_BACK/ms_admin` |
| Fecha del documento | 2026-08-18 |
| Alcance | Requerimientos, actores y reglas de negocio de `ms_admin`, tal como pueden inferirse de la documentación existente (README, ROADMAP, openapi.yaml) |
| Estado del repositorio | Placeholder — sin `domain/model` ni `domain/usecase` implementados |

---

## 1. Advertencia sobre el origen de este análisis

En los microservicios ya implementados del ecosistema (`ms_iam`, `ms_org`) este documento se construye leyendo las clases de `domain/usecase` y las reglas de negocio codificadas en excepciones y validaciones. **En `ms_admin` esas carpetas no existen.** No hay `domain/model`, `domain/usecase`, ni ningún paquete Java. Por lo tanto, todo lo que sigue en este documento es un **análisis de requerimientos aspiracionales/planificados**, extraído literalmente de:

- Los cuatro diagramas Mermaid del `README.md` de `ms_admin`, explícitamente etiquetados por el propio archivo como *"arquitectura objetivo... El código aún no existe; sirven como referencia de diseño"*.
- Las casillas de `docs/ROADMAP.md`.
- El esquema `NotImplemented` de `docs/openapi.yaml`.

No se infiere ninguna regla de negocio de código real porque no hay código real que analizar. Cada elemento se marca como **[PREVISTO]** para distinguirlo de un requerimiento confirmado por implementación.

## 2. Actores

| Actor | Descripción | Fuente |
|---|---|---|
| `AdminSistema` | Rol de Keycloak/`ms_iam` que operaría la consola administrativa. Es el mismo rol que hoy administra usuarios en `ms_iam` | `README.md` diagrama 4 (`A([AdminSistema abre consola])`), `ROADMAP.md` Fase 1 |
| `ms_admin` (sistema) | Componente BFF/MS previsto que agregaría llamadas a otros microservicios | `README.md` diagramas 1, 2 y 4 |
| `ms_iam` | Microservicio proveedor de datos de usuarios/identidad, consumido por `ms_admin` | `README.md` diagramas 1, 2, 4 |
| `ms_org` | Microservicio proveedor de datos de organizaciones, consumido por `ms_admin` | `README.md` diagramas 1, 2, 4 |
| `ms_assessment` | Microservicio proveedor de datos de evaluaciones recientes, consumido por `ms_admin` | `README.md` diagramas 1, 4 |
| `ms_audit` (futuro) | Microservicio de auditoría centralizada que **no existe hoy**; sería consumido por `ms_admin` cuando exista | `README.md` diagrama 1, `ROADMAP.md` Fase 3 |

No hay actores adicionales documentados (por ejemplo, no se menciona un actor "Lector" ni "Evaluador" en relación con `ms_admin`, a diferencia de `ms_iam`).

## 3. Requerimientos funcionales previstos [PREVISTO]

Inferidos de los diagramas de clases y flujo del `README.md` (sección "Diagramas y modelado"), no de código:

| ID | Requerimiento previsto | Evidencia |
|---|---|---|
| RF-1 [PREVISTO] | Exponer una API `AdminDashboardApi` con operaciones `getSystemOverview()`, `listOrganizationsSummary()`, `listActiveAssessments()` | Diagrama de clases del `README.md` |
| RF-2 [PREVISTO] | Exponer una API `SystemConfigApi` para configuración global del sistema | Diagrama "Arquitectura objetivo (hexagonal)" del `README.md` |
| RF-3 [PREVISTO] | Agregar métricas del sistema combinando datos de `ms_iam`, `ms_org` y (potencialmente) `ms_assessment`, mediante un caso de uso `GetSystemMetricsUseCase` | Diagramas 2 y 3 del `README.md` |
| RF-4 [PREVISTO] | Orquestar operaciones administrativas sobre usuarios (creación de usuarios administrativos, deshabilitación masiva) mediante un caso de uso `OrchestrateUserOperationsUseCase`, con métodos `createAdminUser()` y `bulkDisableUsers()` | Diagrama de clases del `README.md` |
| RF-5 [PREVISTO] | Componer una vista única de panel administrativo combinando: métricas de `ms_org`, usuarios de `ms_iam` y evaluaciones recientes de `ms_assessment`, devuelta como `CorrectResponse` (formato de envolvente ya usado por `ms_iam`) | Diagrama 4 (flujo de proceso) del `README.md` |
| RF-6 [PREVISTO] | Autenticar las solicitudes mediante JWT del rol `AdminSistema` emitido por Keycloak | `ROADMAP.md` Fase 1 |
| RF-7 [PREVISTO] | Publicar un endpoint de salud o de agregación como primer entregable de API | `ROADMAP.md` Fase 1 |

No existe ningún endpoint real: `docs/openapi.yaml` declara `paths: {}` de forma explícita, y su único esquema es `NotImplemented`.

## 4. Requerimientos no funcionales previstos [PREVISTO]

| ID | Requerimiento | Evidencia / justificación |
|---|---|---|
| RNF-1 [PREVISTO] | Arquitectura hexagonal / Clean Architecture, alineada con `ms_iam` y `ms_org` | `ROADMAP.md` Fase 2 ("Estructura Clean Architecture (alineada con `ms_iam` / `ms_org`)"), diagrama 2 del `README.md` que ya separa Entry Points / Use Cases / Gateways |
| RNF-2 [PREVISTO] | Desacoplamiento de infraestructura mediante interfaces de puerto (`IamAdminGateway`, `OrgAdminGateway`, `AssessmentReadGateway`) | Diagramas 2 y 3 del `README.md` |
| RNF-3 [PREVISTO] | Seguridad basada en JWT/OAuth2 Resource Server, consistente con el resto del ecosistema | `ROADMAP.md` Fase 1 |
| RNF-4 [PREVISTO] | Gestión de secretos mediante Infisical | `ROADMAP.md` Fase 2 |
| RNF-5 [PREVISTO] | Contrato de API versionado y publicado en OpenAPI **antes** de implementar el primer endpoint | `README.md` §"Próximos pasos" punto 3, `ROADMAP.md` Fase 1 |
| RNF-6 [PREVISTO] | Gobernanza de cambios: todo cambio de alcance se refleja primero en el MER y en los contratos OpenAPI de los MS afectados | `ROADMAP.md` §"Notas" |

No hay requerimientos no funcionales verificables sobre rendimiento, disponibilidad, escalabilidad o límites de tasa, porque no existe implementación ni configuración de infraestructura (no hay `application.yaml`, no hay Dockerfile, no hay definición de recursos).

## 5. Reglas de negocio

**No existen reglas de negocio implementadas.** No hay `domain/usecase` con validaciones, ni excepciones de dominio, ni value objects. Las únicas "reglas" documentadas son de proceso/gobernanza, no de dominio:

- **RN-1 [PREVISTO/Gobernanza]** — No se debe implementar código en `ms_admin` sin antes actualizar el MER y los contratos OpenAPI de los microservicios afectados (`ROADMAP.md`, §"Notas").
- **RN-2 [PREVISTO/Gobernanza]** — El contrato `docs/openapi.yaml` debe publicarse con al menos un endpoint antes del primer endpoint implementado (`README.md`, §"Próximos pasos").
- **RN-3 [PREVISTO, no confirmado]** — Solo el rol `AdminSistema` operaría la consola (se infiere del actor único en el diagrama de flujo 4 del `README.md`; no hay lista de roles permitidos ni matriz de permisos documentada).

No hay reglas sobre validación de campos, formatos, límites de longitud, estados permitidos, ni ningún otro tipo de regla de negocio verificable en código, dado que no hay código.

## 6. Casos de uso previstos [PREVISTO]

Basados en el diagrama de clases del `README.md` (etiquetado explícitamente como "diseño previsto"):

| Caso de uso | Actor | Descripción prevista |
|---|---|---|
| Consultar panel administrativo | `AdminSistema` | El actor abre la consola; `ms_admin` agrega en paralelo datos de `ms_org` (métricas), `ms_iam` (usuarios) y `ms_assessment` (evaluaciones recientes) y compone una vista única de tipo `CorrectResponse` |
| Obtener resumen del sistema | `AdminSistema` | `AdminDashboardApi.getSystemOverview()` — sin detalle adicional de payload en la documentación disponible |
| Listar resumen de organizaciones | `AdminSistema` | `AdminDashboardApi.listOrganizationsSummary()` |
| Listar evaluaciones activas | `AdminSistema` | `AdminDashboardApi.listActiveAssessments()` |
| Crear usuario administrativo | `AdminSistema` | `OrchestrateUserOperationsUseCase.createAdminUser()`, delegando en `IamAdminGateway` hacia `ms_iam` |
| Deshabilitar usuarios en lote | `AdminSistema` | `OrchestrateUserOperationsUseCase.bulkDisableUsers()`, delegando en `IamAdminGateway` |

Ninguno de estos casos de uso tiene una firma de método, tipo de retorno, validación de entrada o manejo de error definido más allá del nombre de la operación en el diagrama; no puede documentarse contrato de entrada/salida real porque no existe.

## 7. Matriz de trazabilidad requerimiento → fuente documental

| Requerimiento | ROADMAP.md | README.md (diagramas) | openapi.yaml |
|---|:---:|:---:|:---:|
| RF-1 a RF-5 (funcionales) | — | Sí | No (stub) |
| RF-6, RF-7, RNF-1 a RNF-6 | Sí | Parcial | No |
| Reglas de gobernanza (RN-1, RN-2) | Sí | Sí (Próximos pasos) | — |

## 8. Conclusión del análisis

El análisis funcional de `ms_admin` está en un estado de **intención de diseño documentada, sin especificación formal ni implementación**. No existen historias de usuario propias de `ms_admin` en `docs/proyecto/Historias_Usuario_MSPI_v2.md` del monorepo (se verificó por búsqueda y no se encontraron coincidencias), lo que confirma que el proceso de ingeniería de requerimientos para este microservicio aún no se ha ejecutado formalmente dentro de la metodología del proyecto. La recomendación operativa, coherente con la gobernanza declarada en `ROADMAP.md`, es completar la Fase 1 (definición de alcance) —incluyendo la redacción de historias de usuario formales— antes de avanzar a análisis funcional detallado o diseño de datos.
