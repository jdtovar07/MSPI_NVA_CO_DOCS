# mf_shell — Análisis

**Repositorio:** `MSPI_NVA_CO_MR_FRONT/mf_shell`
**Fecha del documento:** 2026-08-18
**Fuente:** código fuente (`src/app/**`) y documentación técnica en `docs/` (excluido `ARQUITECTURA-CLEAN-ARCHITECTURE.md`, descartado por inconsistente — ver `01-Planificacion.md`, sección 5).

---

## 1. Actores del sistema

| Actor | Descripción | Evidencia |
|---|---|---|
| **Usuario sin sesión** | Cualquier visitante que accede a una ruta protegida sin `auth_session` válida. | `authGuard`, redirección a `/login` |
| **AdminSistema** | Rol con todas las autoridades (`USER_MANAGE`, `ORG_MANAGE`, `TEMPLATE_MANAGE`, `ASSESSMENT_*`, `REPORT_EXPORT`, `AUDIT_VIEW`) más acceso a Salud del sistema y Configuración. | `authority.ts` (`ROLE_AUTHORITIES.AdminSistema`, `isSystemAdmin`) |
| **AdminInstrumento** | `TEMPLATE_MANAGE`, `ASSESSMENT_VIEW`, `REPORT_EXPORT`. | `authority.ts` |
| **Evaluador** | `ASSESSMENT_EDIT`, `ASSESSMENT_VIEW`, `REPORT_EXPORT`. | `authority.ts` |
| **Revisor** | `ASSESSMENT_REVIEW`, `ASSESSMENT_VIEW`, `REPORT_EXPORT`. | `authority.ts` |
| **EvaluadorRevisor** | Unión de Evaluador + Revisor. | `authority.ts` |
| **Lector** | `ASSESSMENT_VIEW`, `REPORT_EXPORT`; ve "Mi organización" en vez de "Organizaciones". | `authority.ts`, `shell-layout.component.ts` (`navItems`) |
| **Microfrontend hijo** (mf_auth, mf_org, mf_assessment, mf_evidence, mf_reports) | Actor "de sistema": emite y recibe mensajes `postMessage` hacia/desde el shell. | `shell-iframe-bridge.ts` |

## 2. Requerimientos funcionales

| ID | Requerimiento | Evidencia en código |
|---|---|---|
| RF-01 | El sistema debe redirigir a `/login` a cualquier usuario sin sesión que intente acceder a una ruta protegida, conservando la ruta de destino (`from`). | `auth.guard.ts` |
| RF-02 | El sistema debe permitir navegación libre a `/` y `/login` sin sesión. | `auth.guard.ts` (`isPublicPath`) |
| RF-03 | El sistema debe mostrar/ocultar cada ítem de menú según la autoridad calculada a partir de los roles del usuario. | `shell-layout.component.ts` (`navItems`) |
| RF-04 | El sistema debe bloquear el acceso directo por URL a una ruta sin la autoridad requerida, redirigiendo a `/dashboard?accessDenied=1`. | `role.guard.ts` (`roleGuard`, `systemAdminGuard`) |
| RF-05 | El sistema debe mostrar en el dashboard tarjetas de acceso rápido filtradas por autoridad, con contador numérico o `—` si la API falla. | `dashboard-page.component.ts`, `dashboard-stats.service.ts` |
| RF-06 | El sistema debe calcular en paralelo los contadores de organizaciones, usuarios, evaluaciones, evidencias y reportes, aislando el fallo de una fuente sin afectar a las demás. | `DashboardStatsService.load()` (`Promise.all` + `safeCount`) |
| RF-07 | El sistema debe embeber cada microfrontend hijo en un `<iframe>` dentro del layout del shell al navegar a su ruta correspondiente. | `users-redirect.component.ts`, `organizations-redirect.component.ts`, `evaluations-redirect.component.ts`, `evidence-redirect.component.ts`, `reports-redirect.component.ts`, `my-organization-redirect.component.ts` |
| RF-08 | El sistema debe reenviar la sesión (`auth_session`) al iframe hijo tras su carga (`load`) y en respuesta a una solicitud explícita del hijo (`MSPI_AUTH_REQUEST`). | `shell-iframe-bridge.ts` (`installIframeAuthRelay`, `postAuthSessionToIframe`) |
| RF-09 | El sistema debe recibir la sesión emitida por `mf_auth` tras el login (`MSPI_AUTH_SESSION`) y persistirla en `localStorage`, refrescando el usuario mostrado en el layout. | `shell-layout.component.ts` (`onAuthMessage`) |
| RF-10 | El sistema debe recibir y persistir el identificador de "evaluación activa" (`MSPI_ACTIVE_ASSESSMENT`) emitido por `mf_assessment`. | `shell-iframe-bridge.ts` (`installShellBridgeListener`) |
| RF-11 | El sistema debe permitir que un microfrontend hijo solicite al shell una navegación (`MSPI_SHELL_NAV`) especificando ruta y evaluación activa. | `shell-iframe-bridge.ts`, `shell-layout.component.ts` (`installShellBridgeListener` → `router.navigateByUrl`) |
| RF-12 | El sistema debe mostrar la vista de Evidencias/Reportes solo si existe una evaluación activa (`active_assessment_id`); en caso contrario debe mostrar un mensaje de "Sin evaluación activa". | `evidence-redirect.component.ts`, `reports-redirect.component.ts` |
| RF-13 | El sistema debe cerrar sesión eliminando `auth_session` de `localStorage`/`sessionStorage` y redirigiendo a `/login`. | `shell-layout.component.ts` (`logout`) |
| RF-14 | El sistema debe validar el origen (`event.origin`) de todo mensaje `postMessage` recibido, aceptando únicamente `localhost`/`127.0.0.1` en los puertos 4201–4205. | `shell-iframe-bridge.ts` (`isShellChildOrigin`), `shell-layout.component.ts` (`onAuthMessage`, lista explícita 4201) |
| RF-15 | El sistema debe presentar páginas *placeholder* informativas para módulos aún no implementados (Escalas, Banco de preguntas, Auditoría, Salud del sistema, Configuración), indicando una acción alternativa cuando aplica. | `feature-placeholder-page.component.ts`, `app.routes.ts` (bloque `data`) |
| RF-16 | El sistema debe adjuntar el header `Authorization: Bearer {token}` a las peticiones HTTP salientes del shell y desenvolver la respuesta `{ data, meta }`. | `api.interceptor.ts` |

## 3. Requerimientos no funcionales

| ID | Requerimiento | Evidencia |
|---|---|---|
| RNF-01 | **Aislamiento de despliegue**: el shell debe poder compilarse y desplegarse en un contenedor Docker independiente de los demás microfrontends. | `deployment/Dockerfile`, `deployment/nginx.conf` |
| RNF-02 | **Resiliencia de UI ante fallos de backend**: el dashboard no debe romperse si una fuente de datos falla; debe degradar a `—`. | `DashboardStatsService.safeCount` |
| RNF-03 | **Seguridad por origen**: los mensajes `postMessage` entrantes deben validarse por origen antes de procesarse. | `isShellChildOrigin`, listas de orígenes en `shell-layout.component.ts` |
| RNF-04 | **Carga perezosa (lazy loading)** de cada ruta hija mediante `loadComponent`, evitando cargar todos los componentes de redirección en el bundle inicial. | `app.routes.ts` |
| RNF-05 | **Mantenibilidad por capas**: separación en `domain`, `application`, `infrastructure`, `presentation` dentro de `src/app`. | Estructura de `src/app/**`, `docs/ARQUITECTURA.md` |
| RNF-06 | **Consistencia visual**: el layout (menú, cabecera) del shell se mantiene visible mientras se navega a un microfrontend hijo (no hay salto de dominio ni recarga completa de página). | `docs/FLUJOS.md` ("El usuario no cambia de dominio") |
| RNF-07 | **Cacheo de assets estáticos** con expiración de 7 días e inmutabilidad en producción. | `deployment/nginx.conf` |

No se encontraron requerimientos no funcionales explícitos de rendimiento (tiempos de respuesta), accesibilidad (WCAG) ni internacionalización en el código o la documentación del repositorio; se declara esta ausencia en vez de asumirlos.

## 4. Reglas de negocio

### 4.1 Enrutamiento global y control de acceso

1. Toda ruta bajo `ShellLayoutComponent` (todas excepto `/login`) requiere sesión activa (`authGuard`).
2. Las rutas `/users`, `/organizations`, `/evaluations`, `/evidence`, `/reports`, `/scales`, `/security-baseline`, `/audit` requieren, además, una autoridad específica vía `roleGuard(authority)`.
3. Las rutas `/system-health` y `/system-settings` requieren el rol `AdminSistema` exclusivamente (`systemAdminGuard`), no una autoridad derivada.
4. La ruta `/my-organization` no exige autoridad adicional (solo sesión), pero solo se muestra en el menú a usuarios con rol `Lector` que no tengan `ORG_MANAGE`.
5. Cualquier ruta no reconocida (`**`) redirige a `/dashboard`.
6. El fallo de autorización en una ruta hija redirige siempre a `/dashboard?accessDenied=1` (no a una página de error genérica).

### 4.2 Sesión compartida entre microfrontends

1. La sesión se persiste bajo la clave única `auth_session` en `localStorage` (y opcionalmente `sessionStorage`), como JSON con `token`, `roles`, `user`, `expiresAt`.
2. El shell reenvía la sesión a cada iframe hijo automáticamente al detectar el evento `load` del iframe, y también cuando el hijo la solicita explícitamente (`MSPI_AUTH_REQUEST`).
3. El shell solo acepta actualizaciones de sesión (`MSPI_AUTH_SESSION`) provenientes del origen de `mf_auth` (`localhost:4201` / `127.0.0.1:4201`).
4. Al recibir una sesión válida, el shell la persiste en `localStorage` y refresca inmediatamente el usuario mostrado en el layout (nombre, roles, menú).
5. El cierre de sesión (`logout`) elimina la clave `auth_session` de ambos almacenamientos y fuerza una recarga completa hacia `/login` (`window.location.href`), no una navegación interna del router.

### 4.3 Evaluación activa (contexto compartido Evaluaciones → Evidencias/Reportes)

1. `mf_assessment`, al seleccionar o crear una evaluación, notifica al shell mediante `MSPI_ACTIVE_ASSESSMENT`, que la persiste en `localStorage` bajo `active_assessment_id`.
2. Las vistas de Evidencias y Reportes leen `active_assessment_id` al inicializarse; si no existe, no renderizan el iframe y muestran un mensaje de "Sin evaluación activa" con instrucción de crear/abrir una evaluación primero.
3. Un microfrontend hijo puede solicitar al shell una navegación con evaluación asociada mediante `MSPI_SHELL_NAV` (incluye `route` y `assessmentId`); el shell persiste el id y navega internamente con `router.navigateByUrl`.

### 4.4 Cálculo de autoridades por rol

1. Las autoridades (`Authority`) se derivan de los roles del usuario mediante una tabla estática `ROLE_AUTHORITIES` (no se consultan permisos individuales del backend).
2. Un usuario puede tener múltiples roles; sus autoridades son la unión (`Set`) de las autoridades de todos sus roles.
3. `AdminSistema` es tratado como caso especial adicional para el acceso a Salud del sistema y Configuración del sistema, independientemente de la lista de autoridades.

### 4.5 Contadores del dashboard

1. Cada tarjeta del dashboard obtiene su contador de una fuente distinta: organizaciones y usuarios vía API paginada (`totalElements`), evaluaciones vía índice local (`mspi_assessment_index`) o evaluación activa, evidencias y reportes vía API de `ms_evidence` filtrando por `deliveryStatus`/`relationType`, y auditoría sin fuente disponible (siempre `—`).
2. El fallo individual de cualquier fuente no debe impedir el cálculo de las demás (`Promise.all` + `safeCount` con captura de error por tarea).

## 5. Casos de uso

### CU-01 — Iniciar sesión y llegar al dashboard

**Actor:** Usuario sin sesión.
**Flujo principal:**
1. El usuario navega a `http://localhost:4200/`.
2. `authGuard` detecta ausencia de sesión y redirige a `/login`.
3. `LoginPlaceholderComponent` reenvía al usuario a `http://localhost:4201/login` (mf_auth).
4. El usuario se autentica en `mf_auth`, que persiste `auth_session` y redirige de vuelta a `http://localhost:4200/dashboard`, emitiendo `postMessage` `MSPI_AUTH_SESSION`.
5. El shell recibe el mensaje, valida el origen, persiste la sesión y renderiza el dashboard con el menú filtrado por rol.

### CU-02 — Navegar a un módulo embebido (ejemplo: Evaluaciones)

**Actor:** Usuario autenticado con autoridad `ASSESSMENT_VIEW` o `ASSESSMENT_EDIT`.
**Flujo principal:**
1. El usuario hace clic en "Evaluaciones" en el menú lateral.
2. El router activa la ruta `/evaluations`, protegida por `roleGuard('ASSESSMENT_VIEW')`.
3. Se carga perezosamente `EvaluationsRedirectComponent`, que renderiza un `<iframe>` apuntando a `http://localhost:4203/evaluations`.
4. Al cargar el iframe, el shell le retransmite la sesión (`postAuthSessionToIframe`).
5. El usuario interactúa con `mf_assessment` dentro del layout del shell, sin cambiar de dominio visible.

**Flujo alterno:** si el usuario no tiene la autoridad requerida, `roleGuard` redirige a `/dashboard?accessDenied=1`.

### CU-03 — Continuar a Evidencias con evaluación activa

**Actor:** Usuario con autoridad `ASSESSMENT_EDIT`.
**Precondición:** el usuario seleccionó/creó previamente una evaluación en `mf_assessment`, que notificó `MSPI_ACTIVE_ASSESSMENT` al shell.
**Flujo principal:**
1. El usuario navega a "Evidencias".
2. `EvidenceRedirectComponent` lee `active_assessment_id` de `localStorage`.
3. Si existe, construye la URL `http://localhost:4204/assessments/{id}/context` y la renderiza en un iframe sanitizado (`DomSanitizer.bypassSecurityTrustResourceUrl`).
4. El shell instala un relevo de autenticación (`installIframeAuthRelay`) para reenviar la sesión si `mf_evidence` la solicita.

**Flujo alterno:** sin `active_assessment_id`, se muestra el mensaje "Sin evaluación activa".

### CU-04 — Acceso denegado por falta de autoridad

**Actor:** Usuario autenticado sin la autoridad requerida por una ruta.
**Flujo principal:**
1. El usuario navega (por menú oculto o URL directa) a una ruta protegida por una autoridad que no posee.
2. El guard correspondiente (`roleGuard` o `systemAdminGuard`) evalúa `hasAuthority`/`isSystemAdmin` y falla.
3. El router redirige a `/dashboard?accessDenied=1`.
4. `DashboardPageComponent` lee el query param `accessDenied` para, potencialmente, mostrar una notificación (según implementación de la plantilla HTML).

### CU-05 — Cerrar sesión

**Actor:** Usuario autenticado.
**Flujo principal:**
1. El usuario hace clic en "Cerrar sesión" en el menú de perfil.
2. `ShellLayoutComponent.logout()` elimina `auth_session` de `localStorage` y `sessionStorage`.
3. Se fuerza una recarga completa (`window.location.href = '/login'`), no una navegación SPA, garantizando que el estado en memoria del shell y de los iframes se reinicie.

## 6. Flujos principales (resumen)

Los flujos detallados con diagramas de secuencia se documentan en `docs/FLUJOS.md` del repositorio (reutilizado como fuente primaria) y se amplían en `03-Diseno.md` de este documento con el diagrama de integración completo con los 5 microfrontends hijos.

## 7. Alcance no cubierto por análisis funcional

Las siguientes áreas están fuera del alcance funcional de `mf_shell` y no se modelan en este análisis: lógica de negocio de autenticación (2FA, cambio de contraseña — ver documentación de `mf_auth`), CRUD de organizaciones, motor de evaluación MSPI, gestión de evidencias y generación de reportes. El shell únicamente orquesta el acceso a esos módulos.
