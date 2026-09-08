# 04 · Decisiones técnicas complementarias

Complementa la sección 9 ("Decisiones arquitectónicas clave") de [`01-Arquitectura-General-del-Sistema.md`](01-Arquitectura-General-del-Sistema.md) con decisiones tomadas durante la implementación de RBAC fino, el catálogo de escalas/bancos de preguntas y las funcionalidades administrativas de `ms_iam`.

## RBAC de dos niveles en `ms_assessment`

La autorización de negocio no depende solo del rol global de Keycloak (`Evaluador`, `Revisor`, etc.), sino también del **rol del usuario como miembro de la evaluación específica** (tabla `assessment.assessment_member`). Un componente de infraestructura (`AssessmentAccessGuard`) se invoca al inicio de cada caso de uso de mutación en los controladores de evaluación, combinando ambas fuentes:

- `AdminSistema` tiene bypass total.
- `EVALUADOR`/`EVALUADOR_REVISOR` pueden editar, solo si la evaluación está en un estado que lo permite.
- `REVISOR`/`EVALUADOR_REVISOR` pueden revisar, solo en el estado correspondiente.

Este patrón (RBAC de UI + RBAC de dominio verificado en el backend) es el que se sigue en toda la plataforma: la UI oculta acciones no permitidas por comodidad, pero la autorización real y no evadible vive en el servidor.

## `auditorId` como identificador de texto libre

El campo `auditor_id` en `assessment.assessment` se modela como texto libre, no como una relación a un catálogo formal de "auditores" — el dominio del instrumento MSPI no define esa entidad como un concepto propio con ciclo de vida (a diferencia de `assessment_member`, que sí es una relación real usuario↔evaluación). Se prefirió mantener el modelo de datos fiel al dominio real en vez de introducir una entidad nueva sin un caso de uso que la sustente.

## Manejo de errores uniforme

Todos los microservicios de negocio (`ms_assessment`, `ms_catalog`, `ms_org`, `ms_evidence`, `ms_reporting`) devuelven cualquier error — incluidos errores de deserialización de body y excepciones no mapeadas explícitamente — dentro del mismo *envelope* JSON (`{ meta, error: [{ code, message }] }`) que usa el resto de la API, vía un `GlobalExceptionHandler` común por servicio. Esto permite que el frontend muestre siempre un mensaje específico en vez de un estado de error genérico.

## Bloqueo de cuenta por intentos fallidos

`ms_iam` registra cada intento de login en `iam.login_attempt` y bloquea la cuenta 3 intentos fallidos seguidos por 15 minutos, como capa adicional a nivel de aplicación, complementaria a cualquier política configurada directamente en Keycloak.

## Búsqueda de preguntas del banco de preguntas vía SQL nativo

El filtro de `catalog.question_bank_question` (por texto, dominio, tipo de evaluación) se implementó con SQL nativo y `CAST(:param AS text)` explícito en cada comparación, en lugar de JPQL con `LOWER(CONCAT(...))`. PostgreSQL no puede inferir el tipo de un parámetro `NULL` dentro de esas funciones sin un *type hint* explícito cuando el parámetro llega sin contexto de tipo desde Hibernate, así que el `CAST` explícito evita la ambigüedad.

## `outputHashing` y `Cache-Control` diferenciado por tipo de recurso

Los 6 microfrontends generan sus bundles JS/CSS con nombre de archivo hasheado (`outputHashing: "all"`) en la configuración de build usada por despliegue, y el `index.html` de cada uno se sirve con `Cache-Control: no-cache` en nginx, mientras que los assets hasheados mantienen caché agresiva (`public, immutable; expires 7d`). Esto asegura que cada build produzca una URL de entrada distinta, y el navegador nunca sirva una versión obsoleta del punto de entrada.

## Integración entre microfrontends: `<iframe>` + sesión compartida por cookies

`mf_shell` embebe cada microfrontend hijo como `<iframe>` apuntando a su propio puerto/origen; la sesión de Keycloak se comparte porque las cookies son de dominio `localhost` (cross-port en desarrollo). No hay *token passing* explícito para autenticación entre shell e hijo — el navegador ya trae la cookie de sesión al navegar al origen del iframe. Es una integración más simple que Module Federation, a costa de que cada microfrontend hijo carga su propio runtime de Angular.
