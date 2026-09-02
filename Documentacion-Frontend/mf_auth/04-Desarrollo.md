# mf_auth — Desarrollo

**Repositorio:** `MSPI_NVA_CO_MR_FRONT/mf_auth`
**Fecha del documento:** 2026-08-18
**Alcance:** Implementación real del microfrontend: manejo de estado, servicios, componentes, patrones aplicados e integración con las APIs backend (`ms_iam`, `ms_org`), basado en `docs/API-INTEGRACION.md` y en el código fuente de `src/app`.

---

## 1. Manejo de estado

`mf_auth` no usa una librería de gestión de estado global (no hay NgRx, Akita ni similares en `package.json`). El estado se maneja con **Angular Signals**, introducidos como API estable en Angular 17+ y usados aquí de forma consistente:

- **Estado de sesión** — `AuthSessionService`:
  ```ts
  private readonly sessionSignal = signal<AuthSession | null>(this.readFromStorage());
  session = this.sessionSignal.asReadonly();
  isAuthenticated = computed(() => { ... });
  roles = computed(() => this.sessionSignal()?.roles ?? []);
  mustChangePassword = computed(() => this.sessionSignal()?.mustChangePassword ?? false);
  has2FA = computed(() => this.sessionSignal()?.has2FA ?? false);
  ```
  El servicio se inicializa leyendo `localStorage`/cookie de forma síncrona en el constructor implícito del signal, de modo que la sesión está disponible inmediatamente al arrancar la aplicación (sin parpadeo de "no autenticado").

- **Estado local de componente** — cada página usa `signal()` para banderas de UI (`loading`, `error`, `showPassword`, `copied`, etc.), en vez de propiedades de clase mutables planas, aprovechando la reactividad automática en las plantillas (`login-page.component.html`, etc. usan `signal()` con la sintaxis de invocación `error()` en el template).

- **Estado derivado** — `computed()` se usa para valores calculados a partir de otras señales: `canManage` (autorización), `isEdit`, `requiresOrganization`, `passwordValidation`/`passwordsMatch` (aunque estos últimos están implementados como *getters* de clase, no `computed()`, ya que dependen de campos de formulario que no son signals sino propiedades planas enlazadas con `ngModel`).

- **Formularios**: se usa `FormsModule` (formularios basados en plantilla / *template-driven*) en todas las páginas con entrada de usuario, no `ReactiveFormsModule`. Esto se evidencia en los `imports: [FormsModule]` de cada componente y en el uso de `[(ngModel)]` esperado en los `.html` asociados.

## 2. Servicios

| Servicio | Capa | Rol |
|---|---|---|
| `AuthSessionService` | domain | Fuente única de verdad del estado de sesión; persistencia y notificación al shell |
| `SessionExpiryService` | domain | Temporizador que agenda un aviso antes de expirar el JWT |
| `LoginUseCase` | application | Orquesta el login delegando en `AuthRepository` |
| `GetUsersPageUseCase`, `CreateUserUseCase`, `UpdateUserUseCase`, `UpdateUserStatusUseCase`, `GetUserByIdUseCase` | application | Casos de uso CRUD de usuarios, cada uno una clase `@Injectable({providedIn:'root'})` de responsabilidad única |
| `ListOrganizationsUseCase` | application | Obtiene el catálogo de organizaciones para el formulario de usuario |
| `apiInterceptor` | infrastructure | Interceptor funcional: autenticación saliente, normalización de respuesta, manejo de 401 |

Todos los casos de uso siguen el mismo patrón: reciben el repositorio abstracto por inyección de constructor y exponen un único método `execute(...)`, delegando completamente en la interfaz de dominio sin conocer si la implementación activa es mock o HTTP real.

## 3. Componentes (páginas)

Las 7 páginas de presentación son **standalone components** con plantilla y estilos en archivos separados (`.html` / `.scss`), salvo `WelcomePageComponent` que usa template y estilos inline por su simplicidad. Todas siguen el mismo patrón interno:

1. Inyección de casos de uso / servicios de dominio por constructor.
2. Estado de UI en `signal()`.
3. Método `onSubmit()`/`submit()` async que llama al caso de uso, interpreta el `Result<T, E>` (`{ok: true, value}` / `{ok: false, error}`) y actualiza señales de error/loading.
4. Navegación imperativa con `Router.navigate()` o, en los puntos de salida hacia el shell, `window.location.href`.

Ejemplo representativo — extracto real de `setup-2fa-page.component.ts` mostrando el patrón `async/await` + `Result`:

```ts
const result = await this.authRepository.totpVerify(this.verificationCode().trim());
this.loading.set(false);
if (!result.ok) {
  this.error.set(result.error.message || 'Código inválido o expirado.');
  return;
}
```

## 4. Patrones aplicados

- **Result / Either** (`{ ok: true, value } | { ok: false, error }`) para todas las operaciones de dominio que pueden fallar, evitando `throw` como control de flujo salvo en casos específicos (p. ej. `LoginUseCase` no relanza; `login-page.component.ts` sí captura `throw` para el caso especial `REQUIRED_CHANGE_PASSWORD` lanzado en algunos flujos).
- **Repository Pattern / Ports & Adapters**: cada entidad de dominio (`Auth`, `User`, `Roles`, `OrganizationList`) tiene un puerto abstracto y (al menos) dos adaptadores: `Api*Repository` y `Mock*Repository`.
- **Strategy vía DI**: la elección de adaptador (mock/API) es una decisión de configuración centralizada en `app.config.ts`, no dispersa en los componentes.
- **Interceptor / Middleware HTTP**: `apiInterceptor` centraliza autenticación saliente y manejo de errores entrantes, evitando repetir lógica de headers/try-catch en cada repositorio API.
- **Adapter de formato de API**: funciones puras `toUser()` (en `api-user.repository.ts`) y `mapRoles()` (en `api-auth.repository.ts`) traducen el DTO crudo del backend al tipo de dominio (`User`, `AuthSession`), aislando a la UI del contrato exacto de `ms_iam`.
- **Composición de UI condicionada por autorización**: `hasAuthority(roles, 'USER_MANAGE')` se reutiliza igual en `UserListPageComponent` y `UserFormPageComponent`, centralizando la regla en `authority.ts` (función pura, sin estado).

## 5. Integración con APIs backend

Basado en `docs/API-INTEGRACION.md` y verificado directamente en los repositorios de infraestructura.

### 5.1 `ms_iam` (puerto 8082) — vía `environment.apiBaseUrl`

| Endpoint | Método | Usado por | Notas |
|---|---|---|---|
| `/auth/login` | `POST` | `ApiAuthRepository.login()` | Body: `{usernameOrEmail, password}`. Respuesta esperada: `{accessToken, expiresIn, user, roles}` |
| `/auth/totp/status` | `GET` | `ApiAuthRepository.login()` (tras login, para poblar `has2FA`) y `getTotpStatus()` | Con `Authorization: Bearer` inyectado por el interceptor |
| `/auth/totp/setup` | `POST` | `ApiAuthRepository.totpSetup()` | Respuesta: `{secretBase32, qrCodeUrl}` |
| `/auth/totp/verify` | `POST` | `ApiAuthRepository.totpVerify()` | Body: `{code}`; respuesta `{success, message}` |
| `/auth/change-password` | `POST` | `ApiAuthRepository.changePassword()` | Body: `{usernameOrEmail, currentPassword, newPassword}`; no requiere JWT (cambio forzado sin sesión) |
| `/users` | `GET` | `ApiUserRepository.getPage()` | Query params: `page`, `size`, `q`, `role`, `status` |
| `/users/:id` | `GET` | `ApiUserRepository.getById()` | 404 se traduce a `null` (no error) |
| `/users` | `POST` | `ApiUserRepository.create()` | Puede devolver `temporaryPassword` en el DTO de respuesta |
| `/users/:id` | `PUT` | `ApiUserRepository.update()` | Body parcial: `name`, `email`, `roles`, `status` |
| `/users/:id/status` | `PATCH` | `ApiUserRepository.updateStatus()` | Body: `{status}` |
| `/roles` | `GET` | `ApiRolesRepository.getRoles()` | Catálogo de roles para el formulario; ante error retorna `[]` silenciosamente |

### 5.2 `ms_org` (puerto 8083)

| Endpoint | Método | Usado por | Notas |
|---|---|---|---|
| `/organizations` | `GET` | `ApiOrganizationListRepository` | Consumido solo en modo API real, para el selector de organización en el formulario de usuario (`ListOrganizationsUseCase`) |

### 5.3 Contrato de sobre de respuesta

`ms_iam` responde bajo un formato envolvente `{meta, data}` en éxito y `{meta, error}` en fallo (visto en `api-response.model.ts` y desenvuelto por `apiInterceptor`):

```ts
export interface ApiMeta { traceId: string; timestamp: string; }
export interface CorrectResponse<T> { meta: ApiMeta; data: T; }
export interface ErrorResponse { meta: ApiMeta; error: ErrorDetail[]; }
```

El interceptor desenvuelve automáticamente `event.body.data` cuando detecta `{data, meta}`, de modo que los repositorios (`ApiAuthRepository`, `ApiUserRepository`, etc.) reciben directamente el payload útil sin tener que desestructurar el sobre en cada llamada. Los `traceId` se registran con `console.debug('[API]', url, 'traceId:', meta.traceId)` — único mecanismo de trazabilidad/observabilidad encontrado en el cliente.

### 5.4 Manejo de errores HTTP

`apiInterceptor` convierte cualquier `HttpErrorResponse` en un `ApiError` tipado:

```ts
catchError((err: HttpErrorResponse) => {
  if (err.status === 401) authSession.clearSession();
  const apiError = new ApiError(
    err.status,
    err.error?.error ?? [{ code: 'UNKNOWN', message: err.message }],
    err.error?.meta?.traceId
  );
  return throwError(() => apiError);
})
```

Los repositorios de infraestructura capturan `ApiError` y lo traducen a mensajes de negocio (`apiErrorToMessage()` en `api-auth.repository.ts` y `getErrorMessage()` en `api-user.repository.ts`), priorizando el campo `code` sobre `message` cuando está disponible — esto es lo que permite a `login-page.component.ts` mapear códigos de negocio (`ACCOUNT_LOCKED`, `USER_INACTIVE`, etc.) a mensajes en español.

## 6. Funcionalidades desarrolladas (resumen funcional)

1. **Login con usuario/correo + contraseña**, con manejo diferenciado de 4 códigos de error de negocio.
2. **Segundo factor de autenticación (TOTP)**: generación de secreto Base32, URL `otpauth://` compatible con apps de autenticación estándar, renderizado de QR client-side con la librería `qrcode`, copia de secreto al portapapeles (`navigator.clipboard`).
3. **Verificación de 2FA** en logins subsecuentes, con contador de intentos restantes (`attemptsLeft`, inicializado en 3 pero **sin lógica visible que lo decremente** en el componente — posible funcionalidad incompleta, ver `07-Mantenimiento.md`).
4. **Cambio de contraseña** con validación de complejidad en tiempo real (getters reactivos a cada tecla) y doble modalidad (forzado sin sesión / voluntario con sesión).
5. **Gestión de sesión** persistente entre recargas, con expiración basada en `expiresAt` (timestamp calculado en el cliente a partir de `expiresIn`) y aviso previo configurable.
6. **CRUD de usuarios** con paginación server-side (`PageRequest`/`PageResponse`), búsqueda por texto, filtros combinables por rol y estado, y confirmación explícita antes de cambiar el estado de un usuario.
7. **Autorización basada en autoridades derivadas de roles** (RBAC ligero), reutilizada de forma consistente entre listado y formulario de usuarios.
8. **Modo mock funcionalmente equivalente al modo API** para los cuatro dominios (auth, users, roles, organizations), permitiendo desarrollo y demostración sin backend, incluyendo réplica de reglas de bloqueo de cuenta.

## 7. Convenciones de código observadas

- Nomenclatura de archivos en `kebab-case` con sufijo por rol arquitectónico: `*.repository.ts`, `*.use-case.ts`, `*.service.ts`, `*-page.component.ts`.
- Clases de dominio en `PascalCase`, interfaces/tipos también en `PascalCase` (`AuthSession`, `PageRequest`).
- Uso extensivo de `readonly` en propiedades inyectadas por constructor (`private readonly authRepository: AuthRepository`).
- Comentarios en español explicando reglas de negocio directamente en el código (p. ej. el bloque de comentarios sobre el flujo de 2FA/cambio de contraseña en `login-page.component.ts`), lo que facilita la trazabilidad entre requerimiento y código sin necesidad de documentación externa adicional.
- TypeScript en modo `strict` real (no solo declarado): se observan anotaciones de tipo explícitas incluso en callbacks (`(u): u is AuthRole =>`, type guards) y ausencia de `any` en el código inspeccionado.

## 8. Limitaciones de implementación observadas

- `attemptsLeft` en `Verify2FAPageComponent` se inicializa pero no se decrementa ni se usa para bloquear el intento tras agotarse — la limitación de intentos de 2FA parece delegada completamente al backend (`ms_iam`), sin reflejo en la UI mock.
- `PlanPolicy.ts` (raíz del proyecto) está vacío; las reglas de complejidad de contraseña están hardcodeadas dentro del componente de UI en vez de centralizadas en un módulo de dominio reutilizable.
- No se encontró manejo de *retry* o *debounce* en la búsqueda de usuarios (`onSearch`): cada tecla dispara inmediatamente `loadPage()`, lo que en un entorno con backend real generaría una petición HTTP por carácter escrito.
