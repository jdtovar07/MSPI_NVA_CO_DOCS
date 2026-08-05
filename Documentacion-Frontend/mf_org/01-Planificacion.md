# mf_org — Planificación

**Repositorio:** `MSPI_NVA_CO_MR_FRONT/mf_org`
**Fecha del documento:** 2026-08-18
**Alcance:** Fase de planificación del microfrontend de gestión organizacional (`mf_org`), componente del ecosistema **MSPI** (sistema de gestión de seguridad de la información alineado a ISO 27001), construido bajo una arquitectura de microfrontends Angular.

---

## 1. Contexto del proyecto

MSPI es una plataforma web compuesta por un **shell** anfitrión (`mf_shell`, puerto **4200**) y varios microfrontends independientes que se despliegan y ejecutan como aplicaciones Angular separadas:

| Microfrontend | Puerto | Responsabilidad |
|---|---|---|
| `mf_shell` | 4200 | Host / navegación / dashboard |
| `mf_auth` | 4201 | Autenticación, 2FA, cambio de contraseña, gestión de usuarios |
| **`mf_org`** | **4202** | **Gestión organizacional: organizaciones, "Mi organización"** |
| `mf_assessment` | 4203 | Evaluaciones |
| `mf_evidence` | 4204 | Evidencias |
| `mf_reports` | 4205 | Reportes |

Esta relación está documentada en `MSPI_NVA_CO_MR_FRONT/docs/README.md`, índice general del frontend que enlaza a la documentación propia de cada microfrontend en su carpeta `docs/`.

`mf_org` administra el catálogo de **organizaciones** evaluadas por el sistema MSPI: alta, edición y consulta paginada para roles administrativos, y una vista de solo lectura ("Mi organización") para el rol `Lector`, que solo puede ver los datos de la organización asociada a su cuenta. Consume el backend `ms_org` (puerto **8083**), tanto para el CRUD de organizaciones como para un catálogo geográfico de apoyo (países, departamentos/estados, ciudades) usado en los formularios.

## 2. Alcance del microfrontend

### 2.1 Incluido en el alcance de `mf_org`

- Listado paginado de organizaciones (`/organizations`) con búsqueda por nombre y filtro por tipo (`PUBLICA` / `PRIVADA`).
- Alta de organización (`/organizations/new`): nombre, tipo, identificador, correo, ubicación (país/departamento/ciudad en cascada) y dirección.
- Edición de organización (`/organizations/:id`), precargando los datos existentes.
- Vista **"Mi organización"** (`/my-organization`): pantalla de solo lectura para el rol `Lector`, que consulta la organización asociada al usuario autenticado vía `GET /organizations/my-organization`.
- Redirección automática del rol `Lector` desde el listado (`/organizations`) hacia `/my-organization`, evitando que este rol acceda al CRUD administrativo.
- Catálogo geográfico en cascada (país → departamento/estado → ciudad) para los formularios de alta/edición, con modo mock (datos estáticos en `src/data/locations.ts`) y modo API real (`GET /location/...` de `ms_org`).
- Modo **mock** (sin backend) y modo **API real**, seleccionables por configuración de build de Angular (`ng serve --configuration=api`).

### 2.2 Fuera del alcance de `mf_org`

- La **autenticación y emisión de sesión** (login, 2FA, JWT) — responsabilidad de `mf_auth`; `mf_org` únicamente **lee** la sesión (`auth_session`) ya emitida para determinar el token JWT a enviar en las llamadas HTTP y el rol del usuario (`AuthSessionService.hasRole('Lector')`).
- La **gestión de usuarios** — CRUD de usuarios y roles pertenece a `mf_auth`.
- El **borrado (eliminación)** de organizaciones: el dominio (`OrganizationRepository`) solo define `getPage`, `getById`, `create`, `update` y `getMyOrganization`; no existe operación de borrado en el código ni en la documentación preexistente.
- La lógica de negocio de `ms_org` (validaciones de identificador, unicidad, persistencia en base de datos) — reside en el backend; `mf_org` solo la consume.

## 3. Objetivos

### 3.1 Objetivo general

Proveer un microfrontend Angular independiente y desplegable de forma aislada que resuelva la gestión del catálogo de organizaciones del sistema MSPI (alta, edición, consulta paginada y vista de solo lectura para el rol `Lector`), integrándose con el shell sin acoplamiento de código en tiempo de compilación.

### 3.2 Objetivos específicos

1. Implementar un listado paginado de organizaciones con búsqueda por nombre y filtro por tipo, consumiendo `GET /organizations` de `ms_org`.
2. Implementar el alta y edición de organizaciones con un formulario que valide campos obligatorios (nombre, identificador, correo, país, departamento, ciudad, dirección) y un selector geográfico en cascada.
3. Ofrecer una vista de solo lectura ("Mi organización") restringida funcionalmente al rol `Lector`, reutilizando el mismo caso de uso de dominio (`OrganizationRepository.getMyOrganization`).
4. Aislar la lógica de negocio de la infraestructura HTTP mediante una organización en capas (dominio / aplicación / infraestructura / presentación), de forma que el origen de datos (mock o API real) sea intercambiable sin tocar componentes de UI.
5. Mapear correctamente el contrato de tipo de organización entre la UI (`PUBLICA`/`PRIVADA`, en español) y el contrato real de `ms_org` (`PUBLIC`/`PRIVATE`, en inglés), mediante un mapeador dedicado (`organization-api.mapper.ts`).
6. Permitir el despliegue en contenedor Docker con Nginx, homogéneo con el resto de microfrontends del ecosistema MSPI.

## 4. Requerimientos iniciales (alto nivel)

- El microfrontend debe poder ejecutarse **de forma independiente** en el puerto 4202 (`ng serve`), tanto en modo mock como contra `ms_org` real.
- Debe integrarse con `mf_shell` sin que este dependa de artefactos de build de `mf_org` (no hay *remotes/exposes* de Module Federation — ver hallazgo en `03-Diseno.md`).
- Debe restringir el acceso al CRUD de organizaciones cuando el usuario tenga el rol `Lector`, redirigiéndolo a la vista de solo lectura.
- Debe leer la sesión (`auth_session`) generada por `mf_auth` (`localStorage`/cookie) para determinar el rol del usuario y adjuntar el JWT a las peticiones HTTP.
- Debe soportar un catálogo geográfico en cascada (país/departamento/ciudad) tanto en modo mock (datos estáticos locales) como en modo API real (`ms_org` `/location/...`).

## 5. Stack tecnológico (verificado en `package.json` y `angular.json`)

| Categoría | Tecnología | Versión |
|---|---|---|
| Framework | Angular (`@angular/core`, `@angular/common`, `@angular/forms`, `@angular/router`, `@angular/platform-browser*`) | `^19.0.0` |
| Animaciones | `@angular/animations` | `^19.0.0` |
| Reactividad | `rxjs` | `~7.8.0` |
| Runtime Angular | `zone.js` | `~0.15.0` |
| CLI / build | `@angular/cli`, `@angular-devkit/build-angular` (builder `application`) | `^19.0.0` |
| Compilador | `@angular/compiler-cli`, `typescript` | `~5.6.0` |
| Lenguaje | TypeScript, modo `strict` | `~5.6.0` |
| Contenedor | Node 22-alpine (build) + Nginx 1.27-alpine (runtime) | — |

**Nota importante:** el proyecto **no usa Module Federation de Webpack** (no existe `@angular-architects/module-federation` en `package.json`, ni `webpack.config.js` ni sección `exposes`/`remotes` en el repositorio). La integración con el shell se realiza por **composición en el navegador** (`iframe` embebiendo `http://localhost:4202/organizations` y `.../my-organization`, con lectura de sesión compartida), no por federación de módulos JavaScript. Este punto se detalla en `03-Diseno.md` e `INTEGRACION-SHELL.md`.

A diferencia de `mf_auth` (donde ninguna dependencia de React/Vite fue reutilizable), en `mf_org` uno de los artefactos de la plantilla previa — `src/data/locations.ts` — **sí es consumido por el árbol Angular real**: `MockLocationRepository` (`src/app/infrastructure/mock-location.repository.ts`) importa directamente `countries`, `states` y `cities` desde `../../data/locations`. El resto de artefactos de la plantilla (`src/features/`, `src/components/ui/*.tsx`, `src/common/domain/errors/Result.ts` no referenciado desde `src/app`, `src/federated/OrganizationsApp.tsx`, `src/config/env.ts`, `index.html`/`README.md` de la raíz) **no forma parte del build de Angular real**: `tsconfig.app.json` solo incluye `src/main.ts` y `src/app/**/*.ts` como raíces de compilación. Este hallazgo se detalla en `03-Diseno.md`.

## 6. Restricciones y supuestos

- El backend de organizaciones (`ms_org`) debe estar disponible en `http://localhost:8083` para el modo API; en su ausencia, el proyecto puede ejecutarse con `environment.useMocks = true` (configuración por defecto).
- El shell (`mf_shell`) se asume corriendo en `http://localhost:4200`; la política `Content-Security-Policy: frame-ancestors` de `deployment/nginx.conf` autoriza explícitamente `http://localhost:4200` y `http://127.0.0.1:4200` como orígenes que pueden embeber `mf_org` en un `iframe`.
- La lectura del rol `Lector` depende de que la sesión (`auth_session`) generada por `mf_auth` esté disponible en `localStorage`, `sessionStorage` o cookie del mismo origen/navegador — `docs/INTEGRACION-SHELL.md` recomienda "entrar por 4200" (a través del shell) para garantizar esta condición.
- No se encontró documentación ni configuración de CI/CD dentro del repositorio de `mf_org` (no hay carpeta `.github/workflows` ni pipeline visible en el microfrontend).
- No existe archivo `.env` ni `.env.example` en la raíz de `mf_org` (a diferencia de `mf_auth`), aunque persiste el archivo `src/config/env.ts`, que depende de `import.meta.env` (sintaxis Vite) y no se importa desde ningún módulo de `src/app`.

## 7. Recursos y planificación

### 7.1 Recursos identificados en el repositorio

- Código fuente Angular real: `src/app/**` (dominio, aplicación, infraestructura, presentación).
- Documentación técnica preexistente en `mf_org/docs/` (7 documentos Markdown), tomada como fuente primaria para esta documentación de tesis.
- Catálogo geográfico estático reutilizado por el modo mock: `src/data/locations.ts` (países, departamentos, ciudades de referencia, principalmente de Colombia).
- Infraestructura de despliegue propia: `deployment/Dockerfile`, `deployment/nginx.conf`.
- Infraestructura de despliegue compartida a nivel de repositorio frontend: `MSPI_NVA_CO_MR_FRONT/deployment/docker/Dockerfile.angular` (plantilla genérica parametrizable) y `MSPI_NVA_CO_MR_FRONT/deployment/nginx/spa.conf`.

### 7.2 Plan de trabajo inferido (por evidencia de código, no por bitácora explícita)

No existe en el repositorio un backlog, roadmap o bitácora de sprints formal para `mf_org`. La planificación documentada aquí se reconstruye a partir de la evidencia funcional del código y de la documentación en `docs/`, siguiendo el orden natural de dependencia funcional:

1. **Base del microfrontend**: bootstrap Angular standalone (`main.ts`, `app.config.ts`, `app.routes.ts`), configuración de entornos (mock/API).
2. **Dominio de organizaciones**: `OrganizationRepository` (puerto abstracto), tipos (`Organization`, `PageRequest`, `PageResponse`, payloads de creación/edición).
3. **Casos de uso**: `GetOrganizationsPageUseCase`, `GetOrganizationByIdUseCase`, `CreateOrganizationUseCase`, `UpdateOrganizationUseCase`, `GetMyOrganizationUseCase`.
4. **Infraestructura**: `MockOrganizationRepository` y `ApiOrganizationRepository` (con `organization-api.mapper.ts` para traducir `PUBLICA/PRIVADA` ↔ `PUBLIC/PRIVATE`), interceptor HTTP (`apiInterceptor`).
5. **Catálogo geográfico**: `LocationRepository`, `MockLocationRepository` (datos estáticos) y `ApiLocationRepository` (`ms_org` `/location/...`), integrados como selects en cascada del formulario.
6. **Presentación**: `OrganizationListPageComponent`, `OrganizationFormPageComponent`, `MyOrganizationPageComponent`, con lectura de rol vía `AuthSessionService`.
7. **Empaquetado y despliegue**: Dockerfile propio + Nginx.
8. **Documentación técnica** (`docs/*.md`), generada como parte del proyecto.

Declaración explícita de limitación: **no hay evidencia en el repositorio de control de versiones semántico por hitos, ni de un archivo `CHANGELOG.md`, ni de tickets/historias de usuario formales**; el archivo `package.json` fija `"version": "1.0.0"` de forma estática.

## 8. Riesgos identificados

| Riesgo | Evidencia | Impacto |
|---|---|---|
| Ausencia total de pruebas automatizadas | No existen archivos `*.spec.ts` ni configuración Karma/Jest (ver `05-Pruebas.md`) | Riesgo de regresiones no detectadas, especialmente en el mapeo de tipos `PUBLICA/PRIVADA` ↔ `PUBLIC/PRIVATE` |
| Código muerto de plantilla (React/Vite) conviviendo con el código Angular real | `src/features/*`, `src/components/ui/*.tsx`, `src/federated/OrganizationsApp.tsx`, `README.md` e `index.html` de la raíz (plantilla Vite/React) | Confusión para nuevos desarrolladores, aumento de superficie de auditoría sin valor funcional |
| Acoplamiento parcial con la plantilla previa: `src/data/locations.ts` es importado por código Angular real | `mock-location.repository.ts` | Cualquier limpieza total del árbol "muerto" sin revisar dependencias reales rompería el modo mock del catálogo geográfico |
| Sin operación de borrado de organizaciones en el dominio | `OrganizationRepository` no declara `delete` | Puede ser una limitación de alcance intencional del backend, o una funcionalidad pendiente; no hay evidencia para decidir cuál |
| Hardcodeo de URLs de shell/backend (`localhost:8083`, `localhost:4200`) en código de producción | `environment.ts`, `environment.api.ts`, `deployment/nginx.conf` | Rigidez para despliegues en otros dominios/ambientes |

Estos hallazgos se retoman con mayor detalle en `03-Diseno.md`, `04-Desarrollo.md` y `07-Mantenimiento.md`.
