# 04 · Decisiones técnicas complementarias

Complementa la sección 9 ("Decisiones arquitectónicas clave") de [`01-Arquitectura-General-del-Sistema.md`](01-Arquitectura-General-del-Sistema.md). Primero el **registro de decisiones (ADR)** con su contexto, alternativa descartada y consecuencia; después el detalle de las decisiones puntuales de implementación.

## Registro de decisiones de arquitectura (ADR)

| ADR | Decisión | Contexto | Alternativa descartada | Consecuencia |
|---|---|---|---|---|
| ADR-01 | Microservicios por dominio (8) con arquitectura hexagonal | El instrumento tiene dominios con reglas propias (identidad, catálogo, evaluación, evidencias, reportes) | Monolito modular | Despliegue y prueba independientes por dominio; más infraestructura que operar |
| ADR-02 | Una instancia PostgreSQL con un esquema por microservicio | Proyecto académico con recursos limitados | Una base de datos por servicio | Cada servicio escribe solo en su esquema; existen FK físicas entre esquemas (58), que acoplan el modelo |
| ADR-03 | Identidad delegada a Keycloak (JWT validado por JWK en cada servicio) | No reinventar el manejo de credenciales | Autenticación propia con contraseñas en BD | Sin contraseñas en la base; dependencia operativa de Keycloak |
| ADR-04 | 2FA TOTP obligatorio, gestionado en `ms_iam` | La plataforma evalúa controles de seguridad y debe cumplirlos | 2FA opcional o delegado a Keycloak | Todo usuario configura 2FA en el primer ingreso; el reinicio requiere solicitud aprobada |
| ADR-05 | Composición de microfrontends con iframe + `postMessage` | Seis aplicaciones Angular independientes con despliegue propio | Module Federation | Aislamiento fuerte y despliegue independiente; cada iframe carga su propio runtime (evolución futura: Module Federation) |
| ADR-06 | Catálogo versionado separado de la ejecución (`template_version` congelada) | MinTIC actualiza el instrumento (2013 → 2022) | Evaluaciones apuntando al catálogo vivo | Cambios del catálogo no alteran evaluaciones históricas |
| ADR-07 | Borrado solo lógico (`deleted_at`) con periodo de gracia | Trazabilidad exigida por la propia auditoría | Borrado físico | Nada se elimina; se puede recuperar durante la gracia; los listados filtran eliminados |
| ADR-08 | Solicitudes aprobables con radicado legible (`SOL-*`) | Acciones sensibles necesitan doble control y auditoría | Acción directa del usuario | Separación entre quien solicita y quien decide; línea de tiempo por radicado |
| ADR-09 | Auditoría centralizada en `ms_audit`, sin FK a otros esquemas | La bitácora vivía en `ms_iam` y mezclaba dominios | Mantenerla en `ms_iam` | Cada servicio produce eventos por `/internal`; la bitácora sobrevive a cambios del resto del modelo |
| ADR-10 | Configuración global en `ms_admin` | Plazos y gracia estaban fijos en código | Variables de entorno por servicio | Parámetros versionados con historial y editables desde la UI |
| ADR-11 | Comunicación servidor-a-servidor con `X-Internal-Api-Key` en `/internal/**` | Llamadas entre servicios sin usuario | Reenviar el JWT del usuario | Rutas internas nunca expuestas al navegador; la clave debe rotarse en todos los servicios a la vez |
| ADR-12 | Reportes generando el Excel oficial y convirtiéndolo a PDF con LibreOffice | Fidelidad a la plantilla oficial (gráficos, fórmulas) | Dibujar el PDF con una librería | PDF idéntico al Excel; dependencia de LibreOffice en la imagen de `ms_reporting` |
| ADR-13 | Reportes asíncronos (job PENDING → RUNNING → COMPLETED/FAILED) | La generación tarda varios segundos | Respuesta síncrona | La UI consulta el estado; el archivo se guarda como evidencia |
| ADR-14 | Validación del contenido real de los archivos (*magic bytes*) | La extensión se puede falsificar | Validar solo extensión/MIME declarado | Se rechazan archivos disfrazados |


## RBAC de dos niveles en `ms_assessment`

La autorización de negocio no depende solo del rol global de Keycloak (`Evaluador`, `Revisor`, etc.), sino también del **rol del usuario como miembro de la evaluación específica** (tabla `assessment.assessment_member`). Un componente de infraestructura (`AssessmentAccessGuard`) se invoca al inicio de cada caso de uso de mutación en los controladores de evaluación, combinando ambas fuentes:

- `AdminSistema` tiene bypass total.
- `EVALUADOR`/`EVALUADOR_REVISOR` pueden editar, solo si la evaluación está en un estado que lo permite.
- `REVISOR`/`EVALUADOR_REVISOR` pueden revisar, solo en el estado correspondiente.

Este patrón (RBAC de UI + RBAC de dominio verificado en el backend) es el que se sigue en toda la plataforma: la UI oculta acciones no permitidas por comodidad, pero la autorización real y no evadible vive en el servidor.

## `auditorId` como UUID opcional (sin FK a catálogo de auditores)

El campo `auditor_id` en `assessment.assessment` es **UUID nullable** (misma tipología que el resto de `*_id` de la fila), no texto libre. En el API el request sigue aceptando `auditorId` como *string* JSON (o `null`/omitido); la capa de entrada lo convierte a `UUID` o `null`. No hay FK ni entidad “Auditor” con ciclo de vida propio (a diferencia de `assessment_member`); el UUID suele apuntar a un usuario de IAM cuando se informa, y `auditor_display_name` permanece como etiqueta de presentación (`String`).

## Manejo de errores uniforme

Todos los microservicios de negocio (`ms_assessment`, `ms_catalog`, `ms_org`, `ms_evidence`, `ms_reporting`) devuelven cualquier error — incluidos errores de deserialización de body y excepciones no mapeadas explícitamente — dentro del mismo *envelope* JSON (`{ meta, error: [{ code, message }] }`) que usa el resto de la API, vía un `GlobalExceptionHandler` común por servicio. Esto permite que el frontend muestre siempre un mensaje específico en vez de un estado de error genérico.

## Bloqueo de cuenta por intentos fallidos

`ms_iam` registra cada intento de login en `iam.login_attempt` y bloquea la cuenta 3 intentos fallidos seguidos por 15 minutos, como capa adicional a nivel de aplicación, complementaria a cualquier política configurada directamente en Keycloak.

## Búsqueda de preguntas del banco de preguntas vía SQL nativo

El filtro de `catalog.question_bank_question` (por texto, dominio, tipo de evaluación) se implementó con SQL nativo y `CAST(:param AS text)` explícito en cada comparación, en lugar de JPQL con `LOWER(CONCAT(...))`. PostgreSQL no puede inferir el tipo de un parámetro `NULL` dentro de esas funciones sin un *type hint* explícito cuando el parámetro llega sin contexto de tipo desde Hibernate, así que el `CAST` explícito evita la ambigüedad.

## `outputHashing` y `Cache-Control` diferenciado por tipo de recurso

Los 6 microfrontends generan sus bundles JS/CSS con nombre de archivo hasheado (`outputHashing: "all"`) en la configuración de build usada por despliegue, y el `index.html` de cada uno se sirve con `Cache-Control: no-cache` en nginx, mientras que los assets hasheados mantienen caché agresiva (`public, immutable; expires 7d`). Esto asegura que cada build produzca una URL de entrada distinta, y el navegador nunca sirva una versión obsoleta del punto de entrada.

## Integración entre microfrontends: `<iframe>` + sesión compartida por cookies

`mf_shell` embebe cada microfrontend hijo como `<iframe>` apuntando a su propio puerto/origen; la sincronización de sesión/navegación usa `shell-iframe-bridge.ts` (`postMessage`). Es la composición **actual** de los 6 MF; Module Federation queda como **evolución futura**. Cada hijo carga su propio runtime de Angular.
