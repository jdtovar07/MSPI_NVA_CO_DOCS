# mf_auth — Pruebas

**Repositorio:** `MSPI_NVA_CO_MR_FRONT/mf_auth`
**Fecha del documento:** 2026-08-18
**Alcance:** Estrategia de pruebas del microfrontend `mf_auth`: frameworks configurados, archivos de prueba existentes, tipos de prueba evidenciados y validación de requerimientos.

---

## 1. Declaración explícita del hallazgo principal

**El repositorio `mf_auth` no contiene pruebas automatizadas.** Esta afirmación se basa en verificación directa y exhaustiva:

- Búsqueda de archivos `*.spec.ts` en todo el árbol del proyecto (excluyendo `node_modules`): **0 resultados**.
- Búsqueda de archivos relacionados con Karma o Jest (`karma.conf.js`, `jest.config.*`, `karma-jasmine`, etc.): **0 resultados**.
- `angular.json` **no define un target `test`** dentro de `architect` para el proyecto `mf-auth` (solo existen los targets `build` y `serve`; el generador estándar de Angular CLI habitualmente añade un target `test` con builder `@angular-devkit/build-angular:karma`, que aquí está ausente).
- `package.json` **no define un script `test`** (los únicos scripts son `ng`, `start`, `start:api`, `start:force`, `build`, `build:docker`, `clean`).
- `package.json` **no incluye ninguna dependencia de testing** (`karma`, `karma-chrome-launcher`, `karma-jasmine`, `jasmine-core`, `@types/jasmine`, `jest`, `@angular/testing`, `@testing-library/*`) ni en `dependencies` ni en `devDependencies`.

Esto contrasta con un proyecto Angular CLI estándar, que por defecto incluye Karma + Jasmine y genera un `*.spec.ts` junto a cada componente/servicio generado con `ng generate`. Su ausencia total (ni siquiera el archivo `app.component.spec.ts` por defecto) indica que **la infraestructura de pruebas fue removida o nunca inicializada**, no que sea una omisión parcial.

## 2. Estrategia de pruebas actual (según lo evidenciado)

No existe una estrategia de pruebas automatizadas formal para `mf_auth`. La única forma de validación funcional disponible dentro del propio repositorio es:

1. **Modo mock manual**: `environment.useMocks = true` (configuración por defecto de `ng serve`) permite ejercitar los flujos de login, 2FA, cambio de contraseña y CRUD de usuarios sin backend, usando el catálogo de usuarios de prueba definido en `mock-auth.repository.ts` y `mock-user.repository.ts`. Esto funciona como un mecanismo de **prueba manual exploratoria**, no como prueba automatizada.
2. **Login de referencia documentado** para pruebas contra el backend real (`ms_iam`) en modo Docker: `admin@mspi.local` / `Admin123!`, referenciado en `docs/README.md` hacia `docker-config/docs/local/USUARIO-PRINCIPAL.md` (fuera del alcance de este repositorio).

### 2.1 Usuarios de prueba disponibles en modo mock (`mock-auth.repository.ts`)

| Email | Rol | Estado | Notas de prueba |
|---|---|---|---|
| `admin@sistema.com` | `AdminSistema` | ACTIVE | Único con autoridad `USER_MANAGE`; permite probar CU-06/07/08 |
| `maria@empresa.com` | `Evaluador` | ACTIVE | — |
| `juan@empresa.com` | `Revisor` | ACTIVE | — |
| `ana@empresa.com` | `EvaluadorRevisor` | **INACTIVE** | Permite probar el error `USER_INACTIVE` |
| `carlos@empresa.com` | `AdminInstrumento` | ACTIVE | — |
| `pedro@empresa.com` | `Lector` | ACTIVE | — |
| `laura@empresa.com` | `Evaluador` | ACTIVE | `mustChangePassword: true`, `has2FA: false` — único usuario que fuerza el flujo completo `/setup-2fa` → `/change-password` |

Contraseña fija para todos en modo mock: `password123`. Tras 3 intentos fallidos con cualquier usuario, se activa el bloqueo simulado de 15 minutos — permite probar manualmente el error `ACCOUNT_LOCKED`.

## 3. Tipos de prueba NO evidenciados en el código

Se declara explícitamente la ausencia de los siguientes tipos de prueba, dado que se buscó evidencia y no se encontró:

- **Pruebas unitarias** de casos de uso (`LoginUseCase`, `CreateUserUseCase`, etc.) — no hay `*.spec.ts` que instancie estos casos de uso con un repositorio falso.
- **Pruebas unitarias de componentes** (`TestBed`, `ComponentFixture`) — ninguna de las 7 páginas tiene prueba asociada.
- **Pruebas de integración HTTP** (`HttpTestingController`) para verificar el comportamiento de `apiInterceptor` o de los repositorios `Api*Repository`.
- **Pruebas end-to-end (E2E)** — no hay Cypress, Playwright ni Protractor configurados; no existe carpeta `e2e/`.
- **Pruebas de accesibilidad** automatizadas (axe-core u otras).
- **Linting configurado como parte del pipeline de calidad** — no se encontró `.eslintrc*` ni script `lint` en `package.json` (Angular CLI 19 no incluye ESLint por defecto salvo instalación explícita de `@angular-eslint/schematics`, ausente en `devDependencies`).

## 4. Validación de requerimientos — estado actual

Dado que no existen pruebas automatizadas, la trazabilidad entre los requerimientos funcionales documentados en `02-Analisis.md` y su verificación es, en el estado actual del repositorio, **exclusivamente manual y no reproducible de forma automática**:

| Requerimiento | Mecanismo de validación disponible | Automatizado |
|---|---|---|
| RF-01 Login | Ejecución manual en modo mock/API | No |
| RF-04–RF-06 2FA | Ejecución manual, requiere app TOTP externa para generar el código de 6 dígitos | No |
| RF-08 Complejidad de contraseña | Validación visible en UI en tiempo real (getters), verificable manualmente | No |
| RF-11–RF-16 CRUD usuarios | Ejecución manual contra `MockUserRepository` | No |
| RNF-05 Limpieza de sesión en 401 | Requiere provocar un 401 real (backend) o inspección de código | No |

## 5. Riesgo asociado

La ausencia de pruebas automatizadas es un riesgo de calidad significativo dado que `mf_auth` es el componente que gestiona credenciales, tokens JWT y control de acceso (`USER_MANAGE`) de todo el ecosistema MSPI: un cambio no probado en `authority.ts`, en `apiInterceptor`, o en la lógica de redirección de `login-page.component.ts` podría degradar silenciosamente la seguridad de acceso de todos los microfrontends que dependen de la sesión emitida aquí.

## 6. Recomendación (fuera del alcance del código actual, declarada como brecha)

No se implementa código de prueba como parte de esta documentación (el alcance del presente trabajo es documental), pero se deja registrada como brecha para trabajo futuro (ver `07-Mantenimiento.md`):

1. Reincorporar Karma + Jasmine (`ng generate` estándar) o migrar a un runner moderno (`@angular/build` con Vitest, soportado experimentalmente en Angular 19) y agregar el target `test` a `angular.json`.
2. Priorizar pruebas unitarias de `authority.ts` (función pura, alto impacto en seguridad, fácil de cubrir) y de los casos de uso (`LoginUseCase`, `CreateUserUseCase`) usando repositorios mock inyectados.
3. Priorizar pruebas del `apiInterceptor` con `HttpTestingController` dado que centraliza autenticación saliente y manejo de 401 para todas las llamadas del microfrontend.
4. Evaluar Playwright para un flujo E2E mínimo del camino crítico: login → setup 2FA → dashboard, en modo mock.
