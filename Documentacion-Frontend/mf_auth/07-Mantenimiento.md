# mf_auth — Mantenimiento

**Repositorio:** `MSPI_NVA_CO_MR_FRONT/mf_auth`
**Fecha del documento:** 2026-08-18
**Alcance:** Lineamientos de mantenimiento correctivo, preventivo y evolutivo, gestión de versiones, monitoreo, manejo de errores en frontend y mejoras futuras evidenciadas para el microfrontend `mf_auth`.

---

## 1. Gestión de versiones — estado actual

- `package.json` fija `"version": "1.0.0"` de forma estática; no hay evidencia de versionado semántico automatizado (no hay `standard-version`, `semantic-release`, ni scripts de *bump* de versión).
- No existe `CHANGELOG.md` en el repositorio.
- No existe carpeta `.github/workflows` ni ningún otro archivo de integración continua (CI) dentro de `mf_auth`; no se pudo determinar si el pipeline de CI/CD vive centralizado fuera de este repositorio (`docker-config` u otro), ya que está fuera del alcance analizado.
- El control de versiones del propio repositorio no fue inspeccionado (fuera del alcance de esta tarea: el análisis se limitó al árbol de archivos de `mf_auth`, sin ejecutar comandos de historial `git log`).

**Recomendación de mantenimiento:** adoptar versionado semántico (`MAJOR.MINOR.PATCH`) ligado a los cambios de contrato con `ms_iam`/`ms_org` (un cambio de forma de DTO como `ApiUserDto` debería ser al menos `MINOR`), y mantener un `CHANGELOG.md` mínimo, dado que este microfrontend es consumido/depende de otros tres servicios (`ms_iam`, `ms_org`, `mf_shell`) cuya evolución debe coordinarse.

## 2. Mantenimiento correctivo

Lineamientos derivados de los hallazgos de código documentados en `03-Diseno.md` y `04-Desarrollo.md`:

| Hallazgo | Tipo de corrección recomendada | Prioridad sugerida |
|---|---|---|
| `attemptsLeft` en `Verify2FAPageComponent` se declara pero nunca se decrementa | Completar la lógica de bloqueo de intentos en cliente, o eliminar el estado muerto si el control es 100% del backend | Media |
| `PlanPolicy.ts` vacío en la raíz | Implementar la política de contraseñas centralizada que el nombre del archivo sugiere, o eliminarlo si fue abandonado | Baja (deuda de claridad) |
| `.env.example` con `VITE_USE_MOCKS` sin efecto real | Corregir o eliminar el archivo para no inducir a error a nuevos desarrolladores; documentar el mecanismo real (`--configuration=api`) | Alta (afecta onboarding y puede causar despliegues incorrectos si alguien asume que basta con `.env`) |
| Árbol de código muerto (`src/features`, `src/common/presentation/*.tsx`, `src/federated`, `components.json`, `pnpm-workspace.yaml`, `README.md` de plantilla React) | Eliminar del repositorio o migrar a una rama/branch histórica, ya que no aporta valor y aumenta la superficie de auditoría (incluida la de seguridad) | Alta |
| Ausencia de *route guards* (`CanActivateFn`) para `/users/new` y `/users/:id` | Migrar el control de acceso imperativo dentro de `ngOnInit()` a guards declarativos de Angular Router, reduciendo el riesgo de que una nueva página con la misma necesidad olvide replicar la verificación | Media |
| `onSearch()` en `UserListPageComponent` dispara una petición por cada tecla | Introducir *debounce* (p. ej. con RxJS `debounceTime`) antes de llamar a `loadPage()` | Media |

## 3. Mantenimiento preventivo

- **Actualizaciones de Angular**: el proyecto fija dependencias con caret (`^19.0.0`), por lo que recibirá automáticamente parches y *minors* de Angular 19 en instalaciones limpias de `npm install`; se recomienda revisar periódicamente las notas de versión de Angular (especialmente cambios en `HttpInterceptorFn`, Signals y el builder `application`, todos usados activamente) y ejecutar `ng update` de forma controlada.
- **Auditoría de dependencias**: no se encontró evidencia de `npm audit` automatizado ni de Dependabot/Renovate configurado en el repositorio; dado que `mf_auth` maneja credenciales y tokens, se recomienda incorporar auditoría de dependencias como parte del mantenimiento preventivo.
- **Revisión de URLs hardcodeadas**: como se documenta en `06-Implementacion-Despliegue.md`, las URLs del shell (`http://localhost:4200`) y de los backends están embebidas en múltiples archivos (`AuthSessionService`, `SessionExpiryService`, páginas de login/2FA/cambio de contraseña, `environment.api.ts`). Cualquier cambio de dominio en un ambiente distinto a local obliga a una revisión coordinada de todos estos puntos; se recomienda centralizarlas en `environment.*.ts` únicamente (hoy `SessionExpiryService` y varias páginas usan el literal `'http://localhost:4200/dashboard'` directamente en vez de leer `environment`).
- **Revisión de la política de expiración de sesión**: el valor `expiresIn` por defecto (300s reales / 3600s en mock) y el aviso de 60s están hardcodeados en `SessionExpiryService`; si `ms_iam` cambia su TTL de token, este valor debe revisarse manualmente ya que no se deriva dinámicamente salvo por el propio `expiresIn` recibido en la respuesta de login (que sí se usa correctamente para calcular `expiresAt`).

## 4. Mantenimiento evolutivo — mejoras futuras evidenciadas en la documentación del repositorio

`docs/` no contiene una sección explícita de "roadmap" o "trabajo futuro", por lo que las siguientes mejoras se infieren de brechas y comentarios encontrados directamente en el código y en la documentación existente, sin inventar alcance no sustentado:

1. **Guards de ruta declarativos** — actualmente ausentes según `docs/RUTAS-Y-PANTALLAS.md` ("Sin guards en rutas"); es una mejora natural para reforzar la autorización a nivel de enrutamiento.
2. **Configuración runtime de URLs** (en vez de compilación estática) — necesaria si el ecosistema MSPI se despliega alguna vez fuera de `localhost` con dominios reales por microfrontend, dado que hoy el shell y los backends están hardcodeados.
3. **Cobertura de pruebas automatizadas** — brecha crítica documentada en `05-Pruebas.md`; es la mejora evolutiva de mayor impacto identificada, dado que `mf_auth` concentra la autenticación de todo el sistema.
4. **Limpieza del árbol de código heredado** (React/Vite) — mejora de mantenibilidad pura, sin impacto funcional, pero que reduce significativamente la carga cognitiva para nuevos integrantes del equipo y el ruido en revisiones de seguridad de dependencias.
5. **Centralización de la política de contraseñas** — sugerida por la existencia (vacía) de `PlanPolicy.ts`, que indicaría una intención de diseño no concretada.
6. **Fortalecimiento de la propagación de sesión entre orígenes** — `docs/INTEGRACION-SHELL.md` reconoce que la cookie compartida "ayuda parcialmente" en local con puertos distintos; en un despliegue real con subdominios (p. ej. `auth.mspi.example.com` y `app.mspi.example.com`), convendría evaluar un mecanismo más robusto (p. ej. cookies `Domain` compartidas a nivel de dominio raíz, o un *backend for frontend* de sesión).

## 5. Monitoreo y logs

No se encontró integración con ninguna herramienta de observabilidad (no hay Sentry, DataDog, Application Insights, ni similares en `package.json`). Los únicos mecanismos de trazabilidad presentes son:

- **`console.debug('[API]', url, 'traceId:', meta.traceId)`** en `apiInterceptor` — registra en la consola del navegador el `traceId` devuelto por `ms_iam` en cada respuesta exitosa, útil para correlacionar logs de cliente con logs de backend, pero **solo visible en la consola del desarrollador**, sin envío a ningún sistema centralizado.
- **`console.error`** en `main.ts` como manejador global de error de arranque (`bootstrapApplication(...).catch((err) => console.error(err))`) — cualquier fallo de bootstrap de Angular solo se refleja en la consola del navegador.
- **`HEALTHCHECK` de Docker** (`curl -f http://127.0.0.1/`) — único mecanismo de monitoreo de disponibilidad, a nivel de infraestructura (verifica que Nginx responde, no verifica la salud funcional de la aplicación ni su conectividad con `ms_iam`/`ms_org`).

**Recomendación:** para un sistema de gestión de seguridad de la información (contexto ISO 27001 de MSPI), la ausencia de registro centralizado de eventos de autenticación en el frontend (intentos fallidos, bloqueos, cambios de contraseña, altas/bajas de usuario) es una brecha relevante de cara a auditoría — actualmente esta trazabilidad, si existe, depende enteramente del backend `ms_iam` (fuera del alcance de este repositorio).

## 6. Manejo de errores en frontend

Mecanismo centralizado observado (ver también `04-Desarrollo.md`):

1. **Nivel HTTP** — `apiInterceptor` normaliza cualquier error de red/HTTP a `ApiError(status, errors[], traceId)`.
2. **Nivel repositorio** — cada `Api*Repository` captura `ApiError`/`HttpErrorResponse` y lo traduce a un `Error` de dominio con un `message` que representa un **código de negocio** (`INVALID_CREDENTIALS`, `ACCOUNT_LOCKED`, `USER_INACTIVE`, `REQUIRED_CHANGE_PASSWORD`, `UNKNOWN`) en vez de un mensaje humano.
3. **Nivel presentación** — cada página traduce el código de negocio a un mensaje en español mostrado en un `signal('')` de error (p. ej. `errorMessage(code)` en `login-page.component.ts`).
4. **Sesión inválida (401)** — se limpia automáticamente en el interceptor (`authSession.clearSession()`), garantizando que un token expirado o revocado no quede persistido localmente tras el primer fallo de autorización.

No se identificó un **error boundary global** de Angular (`ErrorHandler` personalizado) que capture excepciones no controladas de la aplicación (por ejemplo, errores de renderizado) y las reporte de forma centralizada; los `try/catch` están distribuidos método a método dentro de cada componente.

## 7. Checklist de mantenimiento recomendado (síntesis)

- [ ] Retirar o corregir `.env.example`/`src/config/env.ts` para evitar confusión sobre el mecanismo real de conmutación mock/API.
- [ ] Eliminar el árbol de código heredado de la plantilla React/Vite (`src/features`, `src/common/presentation/*.tsx`, `src/federated`, `components.json`, `pnpm-workspace.yaml`) y actualizar el `README.md` raíz.
- [ ] Incorporar framework de pruebas (Karma/Jasmine o alternativa) y cobertura mínima sobre `authority.ts`, casos de uso y `apiInterceptor`.
- [ ] Añadir *route guards* declarativos para `/users/new` y `/users/:id`.
- [ ] Externalizar URLs de shell/backend a configuración centralizada en `environment.*.ts` (eliminar literales duplicados).
- [ ] Completar o retirar `attemptsLeft` en `Verify2FAPageComponent`.
- [ ] Decidir el destino de `PlanPolicy.ts` (implementar o eliminar).
- [ ] Evaluar debounce en la búsqueda de usuarios.
- [ ] Definir estrategia de versionado semántico y `CHANGELOG.md`.
- [ ] Evaluar instrumentación de logs/observabilidad centralizada acorde al contexto ISO 27001 de MSPI.
