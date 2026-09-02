# mf_auth — Planificación

**Repositorio:** `MSPI_NVA_CO_MR_FRONT/mf_auth`
**Fecha del documento:** 2026-08-18
**Alcance:** Fase de planificación del microfrontend de autenticación (`mf_auth`), componente del ecosistema **MSPI** (sistema de gestión de seguridad de la información alineado a ISO 27001), construido bajo una arquitectura de microfrontends Angular.

---

## 1. Contexto del proyecto

MSPI es una plataforma web compuesta por un **shell** anfitrión (`mf_shell`, puerto **4200**) y varios microfrontends independientes que se despliegan y ejecutan como aplicaciones Angular separadas:

| Microfrontend | Puerto | Responsabilidad |
|---|---|---|
| `mf_shell` | 4200 | Host / navegación / dashboard |
| **`mf_auth`** | **4201** | **Autenticación, 2FA, cambio de contraseña, gestión de usuarios** |
| `mf_org` | 4202 | Organizaciones |
| `mf_assessment` | 4203 | Evaluaciones |
| `mf_evidence` | 4204 | Evidencias |
| `mf_reports` | 4205 | Reportes |

Esta relación está documentada en `MSPI_NVA_CO_MR_FRONT/docs/README.md`, que sirve de índice general del frontend y enlaza a la documentación propia de cada microfrontend en su carpeta `docs/`.

`mf_auth` es la puerta de entrada de credenciales al sistema: valida usuario/contraseña contra el backend `ms_iam` (puerto 8082), gestiona el segundo factor de autenticación (TOTP/2FA), fuerza el cambio de contraseña en primer acceso, y administra el CRUD de usuarios (incluyendo el catálogo de roles y, cuando aplica, el listado de organizaciones consumido de `ms_org`, puerto 8083).

## 2. Alcance del microfrontend

### 2.1 Incluido en el alcance de `mf_auth`

- Pantalla y flujo de **login** (`/login`) contra `ms_iam` (`POST /auth/login`).
- Pantalla de **bienvenida** post-login (`/welcome`).
- Flujo de **configuración de 2FA / TOTP** (`/setup-2fa`): generación de secreto y QR (librería `qrcode`).
- Flujo de **verificación de 2FA** (`/verify-2fa`): validación de código de 6 dígitos.
- Flujo de **cambio de contraseña** obligatorio o voluntario (`/change-password`).
- **Gestión de usuarios** (CRUD): listado paginado con filtros (`/users`), alta (`/users/new`) y edición (`/users/:id`).
- Persistencia de la sesión (`auth_session`) en `localStorage`/cookie y **propagación de la sesión al shell** vía `postMessage` y navegación (`window.location.href`).
- Aviso de expiración de sesión (`SessionExpiryService`) antes de que el JWT expire.
- Modo **mock** (sin backend) y modo **API real**, seleccionables por configuración de build de Angular.

### 2.2 Fuera del alcance de `mf_auth`

- El **dashboard** post-login y el resto de módulos funcionales (evaluaciones, evidencias, reportes, organizaciones) — son responsabilidad de `mf_shell` y de los demás microfrontends.
- La **administración de organizaciones** propiamente dicha (creación/edición) — `mf_auth` solo consume `GET /organizations` de `ms_org` como catálogo de apoyo para asignar el rol `Lector` a un usuario.
- La lógica de negocio de `ms_iam` (hashing de contraseñas, emisión de JWT, políticas de bloqueo de cuenta) — reside en el backend, `mf_auth` solo la consume.

## 3. Objetivos

### 3.1 Objetivo general

Proveer un microfrontend Angular independiente y desplegable de forma aislada que resuelva la autenticación, el segundo factor de autenticación y la administración de usuarios del sistema MSPI, integrándose con el shell sin acoplamiento de código en tiempo de compilación.

### 3.2 Objetivos específicos

1. Implementar el flujo de login con manejo de los estados de negocio devueltos por `ms_iam`: credenciales inválidas, cuenta bloqueada, usuario inactivo y contraseña por cambiar.
2. Implementar 2FA basado en TOTP (compatible con apps tipo Google/Microsoft Authenticator) reutilizando el estándar `otpauth://` y la librería `qrcode` para el código QR.
3. Persistir la sesión de forma que sea utilizable tanto por `mf_auth` como por `mf_shell`, sin backend de sesión compartido, usando `localStorage`, cookie y `postMessage`.
4. Ofrecer una gestión de usuarios con paginación, búsqueda, filtros por rol/estado y control de acceso por autoridad (`USER_MANAGE`).
5. Aislar la lógica de negocio de la infraestructura HTTP mediante una organización en capas (dominio / aplicación / infraestructura / presentación), de forma que el origen de datos (mock o API real) sea intercambiable sin tocar componentes de UI.
6. Permitir el despliegue en contenedor Docker con Nginx, homogéneo con el resto de microfrontends del ecosistema MSPI.

## 4. Requerimientos iniciales (alto nivel)

- El microfrontend debe poder ejecutarse **de forma independiente** en el puerto 4201 (`ng serve`), tanto en modo mock como contra `ms_iam`/`ms_org` reales.
- Debe integrarse con `mf_shell` sin que este dependa de artefactos de build de `mf_auth` (no hay *remotes/exposes* de Module Federation — ver hallazgo en la sección 6).
- Debe replicar, en modo mock, las reglas de seguridad reales de `ms_iam` (máximo de intentos fallidos, bloqueo temporal, usuario inactivo) para permitir desarrollo y pruebas manuales sin backend.
- Debe soportar login por usuario/correo, verificación 2FA, y cambio de contraseña con validación de complejidad (mínimo 8 caracteres, mayúscula, minúscula, número y carácter especial — ver `change-password-page.component.ts`).
- Debe restringir la gestión de usuarios a los roles con autoridad `USER_MANAGE` (actualmente solo `AdminSistema`, según `src/app/domain/auth/authority.ts`).

## 5. Stack tecnológico (verificado en `package.json` y `angular.json`)

| Categoría | Tecnología | Versión |
|---|---|---|
| Framework | Angular (`@angular/core`, `@angular/common`, `@angular/forms`, `@angular/router`, `@angular/platform-browser*`) | `^19.0.0` |
| Animaciones | `@angular/animations` | `^19.0.0` |
| Reactividad | `rxjs` | `~7.8.0` |
| Runtime Angular | `zone.js` | `~0.15.0` |
| CLI / build | `@angular/cli`, `@angular-devkit/build-angular` (builder `application`) | `^19.0.0` |
| Compilador | `@angular/compiler-cli`, `typescript` | `~5.6.0` |
| 2FA / QR | `qrcode` (+ `@types/qrcode`) | `^1.5.4` |
| Lenguaje | TypeScript, modo `strict` | `~5.6.0` |
| Contenedor | Node 22-alpine (build) + Nginx 1.27-alpine (runtime) | — |

**Nota importante:** el proyecto **no usa Module Federation de Webpack** (no existe `@angular-architects/module-federation` en `package.json`, ni configuración de `webpack.config.js` o `federation.config.js` en el repositorio). La integración con el shell se realiza por **composición en tiempo de ejecución vía navegador** (iframe, `postMessage`, `localStorage`/cookie compartidos y navegación de página completa), no por federación de módulos JavaScript. Este punto se detalla en `03-Diseno.md` e `INTEGRACION-SHELL.md`.

Adicionalmente, dentro del código fuente conviven artefactos de una plantilla previa (React + Vite, "Clean Architecture Todo App") en `src/features/`, `src/common/presentation/*.tsx`, `src/federated/AppWithProviders.tsx`, `components.json` (shadcn/ui) y `pnpm-workspace.yaml`. Estos archivos **no forman parte del build de Angular real**: `tsconfig.app.json` solo incluye `src/main.ts` y `src/app/**/*.ts`. Se documenta esta situación en detalle en `03-Diseno.md`.

## 6. Restricciones y supuestos

- El backend de autenticación (`ms_iam`) debe estar disponible en `http://localhost:8082` para el modo API; en su ausencia, el proyecto puede ejecutarse con `environment.useMocks = true` (configuración por defecto).
- El backend de organizaciones (`ms_org`) debe estar en `http://localhost:8083` para poblar el selector de organización al crear/editar un usuario con rol `Lector` en modo API.
- El shell (`mf_shell`) se asume corriendo en `http://localhost:4200`/`http://127.0.0.1:4200` — estos orígenes están hardcodeados como destino de `postMessage` (`AuthSessionService`) y como origen permitido para iframes (`Content-Security-Policy: frame-ancestors` en `deployment/nginx.conf`).
- En entorno local, al no compartir dominio, la sesión se propaga por tres mecanismos redundantes: `localStorage` (mismo origen únicamente), cookie `auth_session` (`path=/`, `SameSite=Lax`) y `postMessage`. El propio código documenta que este mecanismo es parcial cuando los puertos difieren (ver comentario en `docs/INTEGRACION-SHELL.md`).
- No se encontró documentación ni configuración de CI/CD dentro del repositorio de `mf_auth` (no hay carpeta `.github/workflows` ni pipeline visible en el microfrontend).

## 7. Recursos y planificación

### 7.1 Recursos identificados en el repositorio

- Código fuente Angular real: `src/app/**` (dominio, aplicación, infraestructura, presentación).
- Documentación técnica preexistente en `mf_auth/docs/` (8 documentos Markdown), tomada como fuente primaria para esta documentación de tesis.
- Assets estáticos: `public/auditcyber-logo.png` (logo del producto "AuditCyber", usado también como issuer del TOTP mock), `public/vite.svg` (residual, no referenciado en el HTML final).
- Infraestructura de despliegue propia: `deployment/Dockerfile`, `deployment/nginx.conf`.
- Infraestructura de despliegue compartida a nivel de repositorio frontend: `MSPI_NVA_CO_MR_FRONT/deployment/docker/Dockerfile.angular` (plantilla genérica parametrizable) y `MSPI_NVA_CO_MR_FRONT/deployment/nginx/spa.conf`.

### 7.2 Plan de trabajo inferido (por evidencia de código, no por bitácora explícita)

No existe en el repositorio un backlog, roadmap o bitácora de sprints formal para `mf_auth`. La planificación documentada aquí se reconstruye a partir de la evidencia funcional del código y de la documentación en `docs/`, siguiendo el orden natural de dependencia funcional:

1. **Base del microfrontend**: bootstrap Angular standalone (`main.ts`, `app.config.ts`, `app.routes.ts`), configuración de entornos (mock/API).
2. **Login**: dominio (`AuthRepository`, `AuthSession`), caso de uso (`LoginUseCase`), infraestructura (`MockAuthRepository`, `ApiAuthRepository`), presentación (`LoginPageComponent`).
3. **Gestión de sesión**: `AuthSessionService` (persistencia + notificación al shell) y `SessionExpiryService` (aviso de expiración).
4. **Seguridad reforzada**: 2FA/TOTP (`setup-2fa`, `verify-2fa`) y cambio de contraseña obligatorio (`change-password`).
5. **Gestión de usuarios**: dominio (`UserRepository`, `RolesRepository`, `OrganizationListRepository`), casos de uso CRUD, infraestructura mock/API, presentación (`UserListPageComponent`, `UserFormPageComponent`).
6. **Empaquetado y despliegue**: Dockerfile propio + Nginx.
7. **Documentación técnica** (`docs/*.md`), generada como parte del proyecto.

Declaración explícita de limitación: **no hay evidencia en el repositorio de control de versiones semántico por hitos, ni de un archivo `CHANGELOG.md`, ni de tickets/historias de usuario formales**; el archivo `package.json` fija `"version": "1.0.0"` de forma estática.

## 8. Riesgos identificados

| Riesgo | Evidencia | Impacto |
|---|---|---|
| Sesión no verdaderamente compartida entre orígenes distintos en local (4200 vs 4201) | Comentario explícito en `docs/INTEGRACION-SHELL.md`: "cookie ayuda parcialmente" | Posible pérdida de sesión al navegar entre MFs en desarrollo |
| Ausencia total de pruebas automatizadas | No existen archivos `*.spec.ts` ni configuración Karma/Jest (ver `05-Pruebas.md`) | Riesgo de regresiones no detectadas |
| Código muerto de plantilla (React/Vite) conviviendo con el código Angular real | `src/features/*`, `src/common/presentation/*.tsx`, `.env.example` con `VITE_USE_MOCKS` | Confusión para nuevos desarrolladores, aumento de superficie de auditoría sin valor funcional |
| `PlanPolicy.ts` vacío en la raíz del proyecto | Archivo de 0 bytes | Posible funcionalidad planeada y no implementada (política de contraseñas centralizada) |
| Hardcodeo de URLs de shell (`localhost:4200`) en código de producción | `AuthSessionService`, `SessionExpiryService`, páginas de login/2FA/cambio de contraseña | Rigidez para despliegues en otros dominios/ambientes |

Estos hallazgos se retoman con mayor detalle en `03-Diseno.md`, `04-Desarrollo.md` y `07-Mantenimiento.md`.
