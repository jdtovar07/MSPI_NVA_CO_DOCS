# mf_org — Desarrollo

**Repositorio:** `MSPI_NVA_CO_MR_FRONT/mf_org`
**Fecha del documento:** 2026-08-18
**Alcance:** Implementación real del microfrontend: manejo de estado, servicios, componentes, patrones aplicados e integración con la API backend (`ms_org`), basado en `docs/API-INTEGRACION.md` y en el código fuente de `src/app`.

---

## 1. Manejo de estado

`mf_org` no usa librería de gestión de estado global (no hay NgRx, Akita ni similares en `package.json`). El estado se maneja con **Angular Signals**:

- **Estado de sesión (leído, no gestionado)** — `AuthSessionService`:
  ```ts
  private readonly sessionSignal = signal<StoredAuthSession | null>(this.readFromStorage());
  readonly session = this.sessionSignal.asReadonly();
  readonly isAuthenticated = computed(() => {
    const s = this.sessionSignal();
    return !!s?.token && (!s.expiresAt || Date.now() < s.expiresAt);
  });
  hasRole(role: string): boolean {
    return (this.sessionSignal()?.roles ?? []).includes(role);
  }
  ```
  A diferencia de `mf_auth`, este servicio **no expone** `mustChangePassword` ni `has2FA` (esos campos no son relevantes para `mf_org`); su tipo `StoredAuthSession` es un subconjunto reducido: `{ token, expiresAt?, roles? }`.

- **Estado local de componente** — cada página usa `signal()` para banderas de UI y datos:
  - `OrganizationListPageComponent`: `organizations`, `totalElements`, `totalPages`, `page`, `loading`, `search`, `typeFilter`.
  - `OrganizationFormPageComponent`: `id`, `loading`, `error` como `signal()`; en cambio, los campos del formulario (`name`, `type`, `identifier`, `email`, `country`, `stateCode`, `city`, `address`, `description`) son **propiedades de clase planas**, enlazadas con `[(ngModel)]` (formulario *template-driven*), no signals.
  - `MyOrganizationPageComponent`: `org`, `loading`, `error`.

- **Estado derivado** — `computed()` se usa para `isEdit` en el formulario (`computed(() => !!this.id())`).

- **Formularios**: `FormsModule` (formularios basados en plantilla), no `ReactiveFormsModule`, igual que en `mf_auth`.

## 2. Servicios

| Servicio/Caso de uso | Capa | Rol |
|---|---|---|
| `AuthSessionService` | domain | Lectura de sesión persistida por `mf_auth`; determina el rol `Lector` |
| `GetOrganizationsPageUseCase` | application | Página de organizaciones con filtros |
| `GetOrganizationByIdUseCase` | application | Detalle de una organización por id |
| `CreateOrganizationUseCase` | application | Alta de organización |
| `UpdateOrganizationUseCase` | application | Edición de organización |
| `GetMyOrganizationUseCase` | application | Organización asociada a la sesión del rol `Lector` |
| `apiInterceptor` | infrastructure | Interceptor funcional: autenticación saliente, normalización de respuesta, manejo de 401 |

Todos los casos de uso siguen el mismo patrón de una sola responsabilidad: reciben `OrganizationRepository` por inyección de constructor y exponen un único método `execute(...)`, delegando completamente en la interfaz de dominio sin conocer si la implementación activa es mock o HTTP real. `GetOrganizationsPageUseCase` es el único que **transforma** ligeramente la respuesta del repositorio, devolviendo solo `{ content, totalElements }` en vez del `PageResponse<Organization>` completo.

## 3. Componentes (páginas)

Las 3 páginas de presentación son **standalone components**; `OrganizationListPageComponent` y `OrganizationFormPageComponent` usan plantilla y estilos en archivos separados (`.html`/`.scss`), mientras que `MyOrganizationPageComponent` usa template y estilos inline (`template:` / `styles:` en el decorador), igual que `WelcomePageComponent` en `mf_auth` por su simplicidad.

Patrón interno común:
1. Inyección de casos de uso / servicios de dominio por constructor.
2. Estado de UI en `signal()`.
3. Método async (`loadPage()`, `submit()`, `load()`) que llama al caso de uso dentro de un bloque `try/catch/finally`, actualizando señales de `loading`/`error`.
4. Navegación imperativa con `Router.navigate()`.

Extracto real representativo — `submit()` de `organization-form-page.component.ts`, mostrando la cadena de validaciones secuenciales antes de invocar el caso de uso:

```ts
if (!name) {
  this.error.set('El nombre de la organización es obligatorio');
  return;
}
// ... validaciones de identifier, email (con emailRegex), country, state, city, address
this.loading.set(true);
try {
  const payload = { name, type: this.type, identifier, email, country, state, city, address, description: this.description || undefined };
  const id = this.id();
  if (id) {
    await this.update.execute(id, payload);
  } else {
    await this.create.execute(payload);
  }
  this.router.navigate(['/organizations']);
} catch (err) {
  this.error.set(err instanceof Error ? err.message : 'Error al guardar');
} finally {
  this.loading.set(false);
}
```

## 4. Patrones aplicados

- **Repository Pattern / Ports & Adapters**: `OrganizationRepository` y `LocationRepository` son puertos abstractos, cada uno con dos adaptadores (`Api*Repository` / `Mock*Repository`).
- **Strategy vía DI**: la elección de adaptador (mock/API) se centraliza en `app.config.ts`, no dispersa en los componentes.
- **Interceptor / Middleware HTTP**: `apiInterceptor` centraliza autenticación saliente y manejo de errores entrantes.
- **Adapter de formato de API + vocabulario**: además de traducir la forma del DTO (`toOrganization()` en `api-organization.repository.ts`, que mapea `department` → `state`), `organization-api.mapper.ts` traduce el **vocabulario** del tipo de organización entre la UI en español y el contrato en inglés de `ms_org`.
- **Result implícito vía `try/catch`**: a diferencia de `mf_auth` (que usa un tipo `Result<T,E>` explícito `{ok, value|error}` en varios flujos), `mf_org` **no define** un tipo `Result` propio dentro de `src/app` — el manejo de fallos se resuelve con `throw`/`try-catch` estándar de TypeScript en los casos de uso y componentes. (El tipo `Result<T,E>` sí existe en `src/common/domain/errors/Result.ts`, pero pertenece al árbol de la plantilla React/Vite no compilado — ver `03-Diseno.md`).
- **Degradación silenciosa en catálogos de apoyo**: `ApiLocationRepository` retorna `[]` ante cualquier error HTTP en sus tres métodos (`getCountries`, `getStates`, `getCities`), priorizando que el formulario siga siendo usable (aunque sin opciones) frente a interrumpir el flujo con un error.

## 5. Integración con la API backend

Basado en `docs/API-INTEGRACION.md` y verificado directamente en `api-organization.repository.ts` y `api-location.repository.ts`. **Nota de precisión respecto a la documentación preexistente:** `docs/API-INTEGRACION.md` describe el tipo de organización como `PUBLIC` en el filtro de listado; el código confirma que el **contrato de `ms_org`** usa efectivamente `PUBLIC`/`PRIVATE` (inglés), mientras la UI interna trabaja en español (`PUBLICA`/`PRIVADA`) y el mapeador hace la conversión en cada llamada saliente/entrante.

### 5.1 `ms_org` (puerto 8083) — vía `environment.apiBaseUrl`

| Endpoint | Método | Usado por | Notas |
|---|---|---|---|
| `/organizations` | `GET` | `ApiOrganizationRepository.getPage()` | Query params: `page`, `size`, `name` (desde `params.q`), `type` (mapeado a `PUBLIC`/`PRIVATE`). Tolera dos formas de respuesta: página (`{content, totalElements, totalPages, number, size}`) o arreglo plano (fallback, se calcula `totalPages: 1`) |
| `/organizations/{id}` | `GET` | `ApiOrganizationRepository.getById()` | 404 se traduce a `null` (no error) |
| `/organizations` | `POST` | `ApiOrganizationRepository.create()` | Body: `{name, type, identifier, address, city, department, country, organizationEmail}`. Respuesta esperada: `{id}`; tras crear, se hace un segundo `GET /organizations/{id}` para devolver la entidad completa |
| `/organizations/{id}` | `PUT` | `ApiOrganizationRepository.update()` | Mismo body que `create`; respuesta: DTO completo de la organización actualizada |
| `/organizations/my-organization` | `GET` | `ApiOrganizationRepository.getMyOrganization()` | Sin parámetros; el backend resuelve la organización a partir del JWT del rol `Lector` |
| `/location/countries` | `GET` | `ApiLocationRepository.getCountries()` | DTO `{iso2, name}` → `{code, name}` |
| `/location/countries/{iso2}/states` | `GET` | `ApiLocationRepository.getStates()` | DTO `{iso2, name}` → `{code, name, countryCode}` |
| `/location/countries/{iso2}/states/{iso2}/cities` | `GET` | `ApiLocationRepository.getCities()` | DTO `{name}` → `{name, stateCode}` |

**Nota sobre el DTO de creación/edición:** el body enviado usa **claves distintas** a las del tipo de dominio `Organization`/`CreateOrganizationPayload` en dos campos: `state` (dominio) se envía como `department` (API), y `email` (dominio) se envía como `organizationEmail` (API) — traducción explícita realizada inline en `create()`/`update()` de `ApiOrganizationRepository`, sin pasar por `organization-api.mapper.ts` (que solo traduce el campo `type`).

### 5.2 Contrato de sobre de respuesta

Igual que en `mf_auth`, `ms_org` responde bajo un formato envolvente `{meta, data}` en éxito y `{meta, error}` en fallo (`api-response.model.ts`), desenvuelto automáticamente por `apiInterceptor`:

```ts
export interface ApiMeta { traceId: string; timestamp: string; }
export interface ErrorDetail { code: string; message: string; }
export class ApiError extends Error {
  constructor(public status: number, public errors: ErrorDetail[], public traceId?: string) { ... }
}
```

El interceptor desenvuelve `event.body.data` cuando detecta `{data, meta}` (y `body.data !== undefined`), de modo que los repositorios reciben directamente el payload útil. A diferencia de `mf_auth`, **no se encontró** un `console.debug('[API]', ...)` de trazabilidad de `traceId` dentro del interceptor de `mf_org` — el interceptor de `mf_org` es funcionalmente más reducido: no registra el `traceId` de las respuestas exitosas en consola.

### 5.3 Manejo de errores HTTP

`apiInterceptor` convierte cualquier `HttpErrorResponse` en un `ApiError` tipado, limpiando la sesión local si el estado es `401`:

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

`ApiOrganizationRepository` centraliza la traducción a mensaje legible en `getErrorMessage()`, priorizando `err.errors[0]?.message`, luego `err.errors[0]?.code`, luego `err.message` — y añade un caso de negocio específico: si el error contiene el código `USER_ALREADY_EXISTS`, se sustituye por el mensaje "El correo de la organización ya está registrado como usuario." (ver `02-Analisis.md`, regla de negocio 8).

## 6. Funcionalidades desarrolladas (resumen funcional)

1. **Listado paginado de organizaciones** con búsqueda por nombre y filtro por tipo (`PUBLICA`/`PRIVADA`/`Todos`), con insignias de color diferenciadas por tipo.
2. **Alta de organización** con formulario validado (campos obligatorios secuenciales, formato de correo) y selector geográfico en cascada.
3. **Edición de organización** con precarga de datos, incluyendo recuperación tolerante de la selección geográfica (por código o por nombre).
4. **Vista "Mi organización"** de solo lectura, exclusiva para el rol `Lector`, con redirección automática desde el listado administrativo.
5. **Catálogo geográfico en cascada** (país → departamento/estado → ciudad), funcionalmente equivalente en modo mock (datos estáticos) y modo API real (`ms_org` `/location/...`), con degradación silenciosa a lista vacía ante fallo.
6. **Traducción de vocabulario UI↔API** para el tipo de organización, evitando que el idioma del contrato de `ms_org` (inglés) se filtre a la interfaz (español).
7. **Modo mock funcionalmente equivalente al modo API** para organizaciones y ubicaciones, permitiendo desarrollo y demostración sin backend.

## 7. Convenciones de código observadas

- Nomenclatura de archivos en `kebab-case` con sufijo por rol arquitectónico: `*.repository.ts`, `*.use-case.ts`, `*.mapper.ts`, `*-page.component.ts`.
- Clases de dominio en `PascalCase`; tipos también en `PascalCase` (`Organization`, `PageRequest`, `LocationCountry`).
- Uso de `readonly` en propiedades inyectadas por constructor (`private readonly repository: OrganizationRepository`).
- Comentarios en español explicando el propósito de puertos y mapeos directamente en el código (p. ej. `/** Puerto de persistencia de organizaciones (Clean Architecture). */`, `/** Mapeo UI ↔ API ms_org (OpenAPI: type PUBLIC | PRIVATE). */`).
- TypeScript en modo `strict` real: se observan anotaciones de tipo explícitas en las interfaces DTO (`ApiOrganizationDto`, `ApiPage<T>`) y ausencia de `any` en el código de `src/app` inspeccionado (los únicos `$any(...)` aparecen en las plantillas HTML, para leer `event.target.value` sin fricción del *strict template checking* de Angular).

## 8. Limitaciones de implementación observadas

- El DTO de creación/edición traduce `state`→`department` y `email`→`organizationEmail` de forma manual e inline dentro de `ApiOrganizationRepository`, en vez de centralizarse en `organization-api.mapper.ts` junto al mapeo de `type` — inconsistencia menor de organización del código, no de comportamiento.
- No hay *debounce* en la búsqueda del listado (`onSearch()` dispara `loadPage()` en cada evento `input`), igual que la limitación equivalente documentada para `mf_auth`.
- `GetOrganizationsPageUseCase` descarta `totalPages`, `page` y `size` de la respuesta del repositorio, devolviendo solo `{content, totalElements}`; el componente de presentación **recalcula** `totalPages` de forma independiente (`Math.ceil(res.totalElements / PAGE_SIZE) || 1`) en vez de usar el valor ya calculado por el backend — duplica la lógica de paginación en dos capas.
- No se encontró un mecanismo de eliminación de organizaciones ni en el dominio ni en la API integrada (ver `02-Analisis.md`, regla de negocio 10).
