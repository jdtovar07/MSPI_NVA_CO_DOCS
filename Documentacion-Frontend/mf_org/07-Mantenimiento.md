# mf_org — Mantenimiento

**Repositorio:** `MSPI_NVA_CO_MR_FRONT/mf_org`
**Fecha del documento:** 2026-08-18
**Alcance:** Lineamientos de mantenimiento correctivo, preventivo y evolutivo, gestión de versiones, monitoreo, manejo de errores en frontend y mejoras futuras evidenciadas para el microfrontend `mf_org`.

---

## 1. Gestión de versiones — estado actual

- `package.json` fija `"version": "1.0.0"` de forma estática; no hay evidencia de versionado semántico automatizado.
- No existe `CHANGELOG.md` en el repositorio.
- No existe carpeta `.github/workflows` ni ningún otro archivo de integración continua (CI) dentro de `mf_org`; no se pudo determinar si el pipeline de CI/CD vive centralizado fuera de este repositorio (`docker-config` u otro), ya que está fuera del alcance analizado.
- El control de versiones del propio repositorio no fue inspeccionado (fuera del alcance de esta tarea: el análisis se limitó al árbol de archivos de `mf_org`, sin ejecutar comandos de historial `git log`).

**Recomendación de mantenimiento:** adoptar versionado semántico (`MAJOR.MINOR.PATCH`) ligado a los cambios de contrato con `ms_org` — un cambio en el DTO de organización (p. ej. renombrar `department` u `organizationEmail`) debería ser al menos `MINOR` y coordinarse con el equipo de `mf_auth` (que también consume `GET /organizations` de `ms_org` como catálogo de apoyo, según `docs/API-INTEGRACION.md` de `mf_auth`).

## 2. Mantenimiento correctivo

Lineamientos derivados de los hallazgos de código documentados en `03-Diseno.md` y `04-Desarrollo.md`:

| Hallazgo | Tipo de corrección recomendada | Prioridad sugerida |
|---|---|---|
| No existe verificación de autoridad (`ORG_MANAGE`) dentro de `mf_org`; el control descrito en `docs/INTEGRACION-SHELL.md` solo se aplica en el shell | Añadir una verificación equivalente a `canManage`/`hasAuthority('ORG_MANAGE')` dentro de `mf_org` (como existe `USER_MANAGE` en `mf_auth`), para que la app no dependa exclusivamente de que el shell la embeba correctamente | Alta (defensa en profundidad: si `mf_org` se accede directamente en `localhost:4202` sin pasar por el shell, no hay control de autorización alguno más allá de la redirección del rol `Lector`) |
| `.env.example`/`src/config/env.ts` con sintaxis Vite sin efecto real (aunque sin `.env.example` presente en la raíz, a diferencia de `mf_auth`) | Eliminar `src/config/env.ts` para no inducir a error a nuevos desarrolladores | Media |
| Árbol de código muerto (`src/features`, `src/components/ui/*.tsx`, `src/federated`, `src/common/domain/errors/Result.ts`, `README.md`/`index.html` de plantilla) | Eliminar del repositorio o migrar a una rama histórica; **verificar primero** que `src/data/locations.ts` (única dependencia real detectada) se traslade o preserve antes de cualquier borrado masivo del árbol heredado | Alta |
| Ausencia de *route guards* (`CanActivateFn`) | Migrar el control de acceso del rol `Lector` de la redirección imperativa en `ngOnInit()` a un guard declarativo de Angular Router | Media |
| `onSearch()` en `OrganizationListPageComponent` dispara una petición por cada tecla | Introducir *debounce* (p. ej. con RxJS `debounceTime`) antes de llamar a `loadPage()` | Media |
| Traducción de campos `state`→`department`, `email`→`organizationEmail` hecha inline en `ApiOrganizationRepository` en vez de en `organization-api.mapper.ts` | Centralizar todo el mapeo UI↔API (incluyendo estos campos) en el mapper dedicado, junto al mapeo de `type` | Baja (deuda de organización del código) |
| `GetOrganizationsPageUseCase` descarta `totalPages`/`page`/`size` de la respuesta real del backend; el componente recalcula `totalPages` de forma independiente | Propagar los valores de paginación ya calculados por `ms_org` en vez de duplicar el cálculo en la capa de presentación | Baja |

## 3. Mantenimiento preventivo

- **Actualizaciones de Angular**: el proyecto fija dependencias con caret (`^19.0.0`), por lo que recibirá automáticamente parches y *minors* de Angular 19 en instalaciones limpias de `npm install`; se recomienda revisar periódicamente las notas de versión de Angular (especialmente cambios en `HttpInterceptorFn`, Signals y el builder `application`) y ejecutar `ng update` de forma controlada, coordinado con el resto de microfrontends del ecosistema (todos fijan la misma versión mayor).
- **Auditoría de dependencias**: no se encontró evidencia de `npm audit` automatizado ni de Dependabot/Renovate configurado en el repositorio.
- **Revisión de URLs hardcodeadas**: como se documenta en `06-Implementacion-Despliegue.md`, `apiBaseUrl` (backend) y la política `frame-ancestors` hacia el shell (`http://localhost:4200`) están embebidas en `environment.*.ts` y `deployment/nginx.conf`. Cualquier cambio de dominio en un ambiente distinto a local obliga a una revisión coordinada de ambos puntos.
- **Coordinación de contrato con `ms_org` y con `mf_auth`**: dado que tanto `mf_org` como `mf_auth` consumen `GET /organizations` de `ms_org` (este último como catálogo de apoyo para el formulario de usuarios, según su propia documentación), un cambio de forma en el DTO de organización impacta a ambos microfrontends simultáneamente y debe versionarse/comunicarse en conjunto.
- **Revisión del campo `msIamUrl` no utilizado**: `environment.ts`/`environment.api.ts` declaran `msIamUrl` sin que ningún módulo de `src/app` lo referencie; se recomienda eliminarlo o documentar explícitamente por qué se conserva, para evitar que futuros desarrolladores asuman una integración con `ms_iam` que no existe en `mf_org`.

## 4. Mantenimiento evolutivo — mejoras futuras evidenciadas en la documentación del repositorio

`docs/` no contiene una sección explícita de "roadmap" o "trabajo futuro", por lo que las siguientes mejoras se infieren de brechas y comentarios encontrados directamente en el código y en la documentación existente, sin inventar alcance no sustentado:

1. **Verificación de autoridad `ORG_MANAGE` dentro de `mf_org`** — actualmente delegada por completo al shell según `docs/INTEGRACION-SHELL.md`; añadirla dentro del propio microfrontend reforzaría la seguridad ante accesos directos fuera del iframe del shell.
2. **Operación de eliminación de organizaciones** — no existe en el dominio actual (`OrganizationRepository`); si el negocio lo requiere, deberá añadirse tanto en `ms_org` como en el puerto/adaptadores/UI de `mf_org`.
3. **Guards de ruta declarativos** — reemplazar la redirección imperativa del rol `Lector` dentro de `ngOnInit()` por un `CanActivateFn`, mejora natural análoga a la recomendada para `mf_auth`.
4. **Configuración runtime de URLs** (en vez de compilación estática) — necesaria si el ecosistema MSPI se despliega alguna vez fuera de `localhost` con dominios reales por microfrontend.
5. **Cobertura de pruebas automatizadas** — brecha crítica documentada en `05-Pruebas.md`, con prioridad especial sobre `organization-api.mapper.ts` por su impacto directo en la integridad de los datos de organización.
6. **Limpieza del árbol de código heredado** (React/Vite con intención de Module Federation) — mejora de mantenibilidad pura, con la salvedad de preservar `src/data/locations.ts` (dependencia real, ver `03-Diseno.md`).
7. **Centralización completa del mapeo UI↔API** en `organization-api.mapper.ts` (hoy parcialmente disperso entre el mapper y `ApiOrganizationRepository`).

## 5. Monitoreo y logs

No se encontró integración con ninguna herramienta de observabilidad (no hay Sentry, DataDog, Application Insights, ni similares en `package.json`). Los mecanismos de trazabilidad presentes son incluso más limitados que en `mf_auth`:

- **`console.error` implícito en `main.ts`**: `bootstrapApplication(AppComponent, appConfig).catch((err) => console.error(err));` — cualquier fallo de bootstrap de Angular solo se refleja en la consola del navegador.
- **`HEALTHCHECK` de Docker** (`curl -f http://127.0.0.1/`) — único mecanismo de monitoreo de disponibilidad, a nivel de infraestructura (verifica que Nginx responde, no verifica la salud funcional de la aplicación ni su conectividad con `ms_org`).
- **Sin registro de `traceId`**: a diferencia de `mf_auth` (que registra `console.debug('[API]', url, 'traceId:', meta.traceId)` en su interceptor), el `apiInterceptor` de `mf_org` **no** registra el `traceId` de las respuestas exitosas en consola — reduce aún más la capacidad de correlacionar logs de cliente con logs de `ms_org` durante un incidente.

**Recomendación:** para un sistema de gestión de seguridad de la información (contexto ISO 27001 de MSPI), donde la organización es la entidad raíz de todo el modelo de evaluación, la ausencia de registro de eventos de creación/edición de organizaciones en el frontend es una brecha relevante de cara a auditoría; se recomienda como mínimo replicar el patrón de `console.debug` con `traceId` que ya existe en `mf_auth`, y evaluar una herramienta de observabilidad centralizada compartida entre microfrontends.

## 6. Manejo de errores en frontend

Mecanismo centralizado observado (ver también `04-Desarrollo.md`):

1. **Nivel HTTP** — `apiInterceptor` normaliza cualquier error de red/HTTP a `ApiError(status, errors[], traceId)`.
2. **Nivel repositorio** — `ApiOrganizationRepository.getErrorMessage()` traduce `ApiError`/`HttpErrorResponse` a un mensaje priorizando `message` sobre `code`, con un caso de negocio específico (`USER_ALREADY_EXISTS` → mensaje en español); `ApiLocationRepository` opta por **no** propagar el error, retornando listas vacías.
3. **Nivel presentación** — cada página muestra el mensaje resultante en un `signal('')` de error (`OrganizationFormPageComponent.error`, `MyOrganizationPageComponent.error`).
4. **Sesión inválida (401)** — se limpia automáticamente en el interceptor (`authSession.clearSession()`).

No se identificó un **error boundary global** de Angular (`ErrorHandler` personalizado) que capture excepciones no controladas de la aplicación y las reporte de forma centralizada; los `try/catch` están distribuidos método a método dentro de cada componente, igual que en `mf_auth`.

## 7. Checklist de mantenimiento recomendado (síntesis)

- [ ] Añadir verificación de autoridad `ORG_MANAGE` dentro de `mf_org` (defensa en profundidad, no solo en el shell).
- [ ] Eliminar `src/config/env.ts` (sintaxis Vite sin efecto real).
- [ ] Eliminar el árbol de código heredado de la plantilla React/Vite, preservando `src/data/locations.ts`.
- [ ] Incorporar framework de pruebas (Karma/Jasmine o alternativa) y cobertura mínima sobre `organization-api.mapper.ts`, casos de uso y `apiInterceptor`.
- [ ] Añadir *route guard* declarativo para la redirección del rol `Lector`.
- [ ] Centralizar el mapeo `state`→`department`/`email`→`organizationEmail` en `organization-api.mapper.ts`.
- [ ] Evaluar debounce en la búsqueda de organizaciones.
- [ ] Definir la necesidad (o no) de una operación de eliminación de organizaciones.
- [ ] Externalizar `apiBaseUrl` y la política CSP del shell a configuración centralizada.
- [ ] Eliminar el campo `msIamUrl` no utilizado de `environment.*.ts`, o documentar su propósito.
- [ ] Replicar el registro de `traceId` en consola que ya existe en el interceptor de `mf_auth`.
- [ ] Definir estrategia de versionado semántico y `CHANGELOG.md`, coordinada con `ms_org` y `mf_auth`.
