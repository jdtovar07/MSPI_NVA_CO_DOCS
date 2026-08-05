# mf_shell — Desarrollo

**Repositorio:** `MSPI_NVA_CO_MR_FRONT/mf_shell`
**Fecha del documento:** 2026-08-18
**Fuente:** código fuente real (`src/app/**`).

---

## 1. Bootstrap de la aplicación

`src/main.ts` arranca la aplicación Angular standalone con `bootstrapApplication`, usando `AppComponent` y la configuración de `app.config.ts`:

```ts
export const appConfig: ApplicationConfig = {
  providers: [
    provideZoneChangeDetection({ eventCoalescing: true }),
    provideRouter(appRoutes),
    provideHttpClient(withInterceptors([apiInterceptor])),
    { provide: GetDashboardUserPort, useClass: LocalStorageDashboardUserAdapter },
  ],
};
```

No hay `NgModule` en el proyecto: todos los componentes son `standalone: true`, patrón consistente con Angular 19 y con el resto de microfrontends del ecosistema MSPI (según lo descrito en la documentación de `mf_auth`).

## 2. Layout compartido (`ShellLayoutComponent`)

`src/app/presentation/layout/shell-layout.component.ts` es el componente contenedor de toda la experiencia autenticada. Responsabilidades implementadas:

- **Estado reactivo con Signals**: `user`, `mobileMenuOpen`, `notificationsOpen`, `profileOpen` son `signal()`; `displayName`, `navItems`, `authorities`, `authorityLabels`, `extraAuthoritiesCount` son `computed()` derivados del usuario actual.
- **Menú dinámico por autoridad**: `navItems` es un `computed` que reconstruye la lista de ítems de navegación (`NavItem[]`) cada vez que cambia `user`, filtrando por `hasAuthority`/`isSystemAdmin`/rol `Lector`.
- **Escucha de sesión entrante**: `onAuthMessage` (arrow function de clase, para conservar `this` al usarse como *listener*) valida el origen (`localhost:4201`/`127.0.0.1:4201`), persiste `auth_session` en `localStorage` y refresca el usuario ejecutando de nuevo `GetDashboardUserUseCase`.
- **Puente de navegación desde hijos**: en `ngOnInit`, instala `installShellBridgeListener` (de `shell-iframe-bridge.ts`), que traduce mensajes `MSPI_SHELL_NAV` en `router.navigateByUrl(route)`.
- **Limpieza de listeners**: `ngOnDestroy` remueve tanto el listener de `onAuthMessage` como el retornado por `installShellBridgeListener`, evitando fugas de memoria en cambios de ruta/recompilación de componentes standalone.
- **Cierre de sesión duro**: `logout()` limpia ambos almacenamientos y usa `window.location.href = '/login'` — una recarga completa de documento, no navegación SPA — para forzar que los iframes hijos, que mantienen su propio estado en memoria, se destruyan por completo.

El template (`shell-layout.component.html`) consume `navItems()`, `displayName()`, `authorityLabels()` y expone un `<router-outlet>` donde se renderiza el contenido de cada ruta hija (dashboard o iframe del microfrontend correspondiente).

## 3. Manejo de sesión y autenticación global

### 3.1 `AuthSessionService` (dominio)

`src/app/domain/auth/auth-session.service.ts` centraliza la lectura de la sesión con `signal`/`computed`:

- `readFromStorage()` intenta `localStorage`, luego `sessionStorage`, y finalmente una **cookie** `auth_session` (fallback adicional, útil cuando el `localStorage` de origen no está disponible o se quiere compartir sesión vía cookie del mismo host en distinto puerto).
- `isAuthenticated` es un `computed` que valida no solo la presencia de `token`, sino también su expiración (`expiresAt`).
- Es el servicio inyectado por el interceptor HTTP (`apiInterceptor`) para adjuntar el Bearer token.

### 3.2 `LocalStorageDashboardUserAdapter` (infraestructura)

Implementa `GetDashboardUserPort` con la misma clave `auth_session` que usa `mf_auth`, garantizando compatibilidad de formato entre ambos microfrontends. Aplica la misma estrategia de *fallback* a cookie que `AuthSessionService`, valida expiración y exige al menos un rol (`roles.length`) para considerar al usuario autenticado — un usuario sin roles se trata como "sin sesión" a efectos de UI.

### 3.3 Interceptor HTTP (`apiInterceptor`)

Función de interceptor (`HttpInterceptorFn`, API funcional de Angular 19) que:

1. Inyecta `AuthSessionService` y adjunta `Authorization: Bearer {token}` si existe token.
2. Desenvuelve automáticamente respuestas con forma `{ data, meta }` (patrón de paginación/envelope de las APIs backend MSPI), exponiendo solo `data` al código consumidor — excepto si el cuerpo es un `Blob` (descargas de archivo).
3. Ante un `401`, limpia la sesión (`authSession.clearSession()`) y relanza un `ApiError` tipado con código, mensaje y `traceId` si el backend lo provee.

### 3.4 Puente de sesión entre iframes (`shell-iframe-bridge.ts`)

Módulo de infraestructura puro (sin dependencias de Angular) que expone funciones reutilizables por los componentes de presentación:

| Función | Uso |
|---|---|
| `readAuthSessionRaw()` | Lee la sesión cruda de `localStorage`/`sessionStorage`, sin parsear. |
| `postAuthSessionToIframe(iframe, childOrigin, sessionRaw?)` | Envía `{ type: MSPI_AUTH_SESSION, payload }` al `contentWindow` del iframe, con `targetOrigin` explícito. |
| `isShellChildOrigin(origin)` | Valida por regex que el origen del mensaje entrante pertenece a un puerto 4201–4205 de `localhost`/`127.0.0.1`. |
| `installShellBridgeListener(onNavigate)` | Instala un listener global de `message` que procesa `MSPI_ACTIVE_ASSESSMENT` (persiste `active_assessment_id`) y `MSPI_SHELL_NAV` (persiste y llama `onNavigate(route, assessmentId)`). Devuelve función de limpieza. |
| `installIframeAuthRelay(iframe, childOrigin, onAuthRequest)` | Instala, sobre un iframe concreto, el reenvío automático de sesión al evento `load` y la escucha de `MSPI_AUTH_REQUEST` proveniente de ese hijo. Devuelve función de limpieza. |

Cada componente `*-redirect` que necesita retransmitir sesión (por ejemplo `EvidenceRedirectComponent`, `ReportsRedirectComponent`) importa estas funciones directamente en vez de depender de un servicio Angular inyectable, manteniendo el módulo agnóstico del framework.

## 4. Componentes de redirección iframe (patrón repetido)

Los seis componentes `*-redirect.component.ts` siguen un patrón consistente:

```ts
@Component({
  selector: 'app-x-redirect',
  standalone: true,
  template: `<div class="remote-container"><iframe [src]="..." class="remote-frame"></iframe></div>`,
})
export class XRedirectComponent { /* ... */ }
```

Variantes observadas:

- **Simples** (`UsersRedirectComponent`, `OrganizationsRedirectComponent`, `MyOrganizationRedirectComponent`): `src` fijo en el template (string literal), sin lógica de ciclo de vida.
- **Con evaluación activa** (`EvidenceRedirectComponent`, `ReportsRedirectComponent`): implementan `OnInit`/`AfterViewInit`/`OnDestroy`, leen `active_assessment_id` de `localStorage`, construyen la URL dinámicamente, la sanitizan con `DomSanitizer.bypassSecurityTrustResourceUrl` (obligatorio en Angular para asignar URLs dinámicas a `[src]` de iframe) y activan `installIframeAuthRelay` sobre la referencia real del `<iframe>` (`@ViewChild`).
- **Con feature-flag de contenido** (`EvaluationsRedirectComponent`): siempre visible, apunta directamente a `4203/evaluations` sin condición de evaluación activa (es el punto de entrada para *crear* la evaluación).

## 5. Guards de enrutamiento

### 5.1 `authGuard`

Función `CanActivateFn` que resuelve `GetDashboardUserUseCase.execute()` como observable, toma el primer valor (`take(1)`) y decide:

- Si la ruta es pública (`/` o prefijo `/login`), permite el acceso sin verificar sesión.
- Si hay usuario, permite el acceso.
- Si no hay usuario, construye un `UrlTree` hacia `/login` con `queryParams: { from: path }`, preservando la intención de navegación original.

### 5.2 `roleGuard(authority)` y `systemAdminGuard()`

Ambas son *factories* de `CanActivateFn` (funciones que devuelven una función guard), parametrizadas por la autoridad requerida o, en el segundo caso, fijas al rol `AdminSistema`. Comparten la misma forma: resolver el usuario, evaluar `hasAuthority`/`isSystemAdmin`, y redirigir a `/dashboard?accessDenied=1` en caso negativo.

## 6. Dashboard y contadores reales

`DashboardPageComponent` combina:

- `GetDashboardUserUseCase` para obtener el usuario y derivar `cards` (computed) filtradas por autoridad.
- `DashboardStatsService.load()` (infraestructura), que dispara 5 peticiones en paralelo con `Promise.all`, cada una envuelta en `safeCount` para que un fallo individual no rompa el resto (retorna `'—'` en ese caso).
- Lectura de `accessDenied` desde el `queryParamMap` de la ruta activa (`ActivatedRoute.snapshot`), reflejando la redirección hecha por `roleGuard`/`systemAdminGuard`.

`DashboardStatsService` no usa un puerto de dominio (no está detrás de una interfaz `GetDashboardStatsPort`); se inyecta y consume directamente como servicio de infraestructura desde el componente de presentación — una excepción al patrón estricto de puertos aplicado al usuario del dashboard.

## 7. Módulos placeholder

`FeaturePlaceholderPageComponent` es un componente genérico y reutilizable, parametrizado vía `ActivatedRoute.snapshot.data` (tipado como `FeaturePlaceholderData`: `title`, `description`, `hint?`, `actionLink?`, `actionLabel?`). Cada ruta placeholder (`/scales`, `/security-baseline`, `/audit`, `/system-health`, `/system-settings`) define su propio contenido informativo directamente en `app.routes.ts`, evitando crear un componente Angular distinto por cada módulo pendiente. Es un patrón de diseño de UI pragmático para comunicar alcance futuro sin duplicar código.

## 8. Patrones aplicados (resumen)

| Patrón | Dónde |
|---|---|
| Standalone components (sin `NgModule`) | Todo `src/app/**` |
| Signals + computed para estado reactivo de UI | `ShellLayoutComponent`, `DashboardPageComponent`, `AuthSessionService` |
| Puerto/adaptador (Clean Architecture) | `GetDashboardUserPort` ↔ `LocalStorageDashboardUserAdapter` |
| Caso de uso explícito | `GetDashboardUserUseCase` |
| Guard como función pura inyectable (`CanActivateFn`) | `auth.guard.ts`, `role.guard.ts` |
| Guard factory (función que retorna guard parametrizado) | `roleGuard(authority)`, `systemAdminGuard()` |
| Interceptor funcional (`HttpInterceptorFn`) | `api.interceptor.ts` |
| Módulo de infraestructura agnóstico de framework | `shell-iframe-bridge.ts` |
| Componente genérico parametrizado por datos de ruta | `FeaturePlaceholderPageComponent` |
| Lazy loading por ruta (`loadComponent`) | `app.routes.ts` |
| Degradación controlada ante fallos de API (`safeCount`) | `DashboardStatsService` |

## 9. Convenciones de código observadas

- Nomenclatura de archivos en `kebab-case` con sufijo de tipo (`*.component.ts`, `*.guard.ts`, `*.service.ts`, `*.adapter.ts`, `*.use-case.ts`, `*.port.ts`), consistente en toda la capa `presentation`/`infrastructure`/`application`/`domain`.
- Uso de `@if`/`@for` (sintaxis de control flow nativa de Angular 17+) en vez de `*ngIf`/`*ngFor`, visible en `EvidenceRedirectComponent` y `FeaturePlaceholderPageComponent`.
- Componentes con `styles` inline (array o string) para vistas pequeñas y `styleUrls` con archivo `.scss` separado para vistas más grandes (`ShellLayoutComponent`, `DashboardPageComponent`).
- Tipado estricto de mensajes `postMessage` mediante *type assertions* sobre `event.data as { type?: string; ... }`, sin librería de validación de esquemas (no hay `zod` ni similar en `package.json`).
