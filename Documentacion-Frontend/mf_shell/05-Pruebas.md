# mf_shell — Pruebas

**Repositorio:** `MSPI_NVA_CO_MR_FRONT/mf_shell`
**Fecha del documento:** 2026-08-18

---

## 1. Frameworks de pruebas configurados

Se revisó `package.json` (dependencias y `devDependencies`), `angular.json` (targets del proyecto `shell`) y la totalidad de `src/` en busca de infraestructura de pruebas.

**Hallazgo: no hay ningún framework de pruebas configurado.**

- `package.json` no declara `karma`, `karma-jasmine`, `jasmine-core`, `@angular/testing`, `jest`, `@testing-library/*`, `cypress`, `playwright` ni ninguna dependencia relacionada con pruebas.
- `angular.json` solo define los *targets* `build` y `serve` en `projects.shell.architect`; **no existe un target `test`** (a diferencia de un proyecto Angular CLI estándar, que por defecto incluye `test` con Karma).
- No existen archivos `karma.conf.js`, `jest.config.js`/`.ts`, `cypress.config.ts` ni carpetas `e2e/`, `cypress/` o `playwright/`.
- No existen archivos `*.spec.ts` en ninguna carpeta de `src/` (búsqueda exhaustiva por patrón `*.spec.ts`, sin resultados).

## 2. Pruebas unitarias

**Estado: inexistentes.** Ningún componente, guard, servicio, adaptador o caso de uso del shell cuenta con prueba unitaria. Esto incluye piezas con lógica de negocio no trivial y alto valor de cobertura potencial:

| Unidad | Lógica relevante no cubierta |
|---|---|
| `authority.ts` | `hasAuthority`, `isSystemAdmin`, `getUserAuthorities` — mapeo rol → autoridad, base de todo el control de acceso del menú y las rutas. |
| `auth.guard.ts` | Determinación de rutas públicas, redirección con `queryParams.from`. |
| `role.guard.ts` | `roleGuard`/`systemAdminGuard` — redirección con `accessDenied=1`. |
| `shell-iframe-bridge.ts` | `isShellChildOrigin` (validación de origen por regex), `installShellBridgeListener`, `installIframeAuthRelay` — superficie de seguridad de mensajería entre orígenes. |
| `DashboardStatsService` | `safeCount`, `fetchPageTotal`, `readAssessmentCount`, `fetchEvidenceMetric`, `fetchReportsMetric` — parseo de distintas formas de respuesta API y degradación a `—`. |
| `LocalStorageDashboardUserAdapter` / `AuthSessionService` | Parseo de sesión, expiración, *fallback* a cookie. |
| `api.interceptor.ts` | Adjunción de Bearer token, desenvolvimiento de `{ data, meta }`, manejo de `401`. |

## 3. Pruebas de integración

**Estado: inexistentes.** No hay evidencia de pruebas que verifiquen la interacción entre el shell y un microfrontend hijo (por ejemplo, simular un `postMessage` `MSPI_AUTH_SESSION` y comprobar que el layout actualiza el usuario), ni pruebas de los guards en el contexto real del `Router` de Angular.

## 4. Pruebas end-to-end (E2E)

**Estado: inexistentes.** No hay configuración de Cypress, Playwright, ni ninguna otra herramienta E2E. No se encontró evidencia de pruebas manuales documentadas más allá de las instrucciones de arranque manual descritas en `docs/README.md` y `docs/FLUJOS.md` ("Entrar siempre por 4200", orden recomendado de arranque de los 5 microfrontends).

## 5. Verificación manual documentada

Aunque no hay pruebas automatizadas, `docs/FLUJOS.md` y `docs/INTEGRACION-SHELL.md` documentan de forma indirecta un procedimiento de verificación manual que actúa como sustituto informal de un plan de pruebas:

1. Levantar los microservicios backend (`ms_iam` 8082, `ms_org` 8083, `ms_assessment` 8084, `ms_evidence` 8086, `ms_reporting` 8087).
2. Levantar los 5 microfrontends hijos en sus puertos fijos (4201–4205).
3. Levantar `mf_shell` en el puerto 4200 y entrar siempre por esa URL.
4. Verificar login → propagación de sesión al dashboard.
5. Verificar navegación a cada módulo embebido y correcto filtrado de menú por rol.
6. Verificar el flujo "sin evaluación activa" en Evidencias/Reportes y su resolución al activar una evaluación desde `mf_assessment`.

Este procedimiento no está automatizado ni versionado como script o *checklist* ejecutable; se documenta en prosa dentro de los archivos Markdown citados.

## 6. Linting y análisis estático

- No se encontró configuración de ESLint (`.eslintrc*`, `eslint.config.*`) ni de Prettier en el repositorio de `mf_shell`.
- El único control de calidad de tipos disponible es el compilador de TypeScript en modo `strict` (`tsconfig.json`: `strict: true`, `noImplicitOverride`, `noPropertyAccessFromIndexSignature`, `noImplicitReturns`, `noFallthroughCasesInSwitch`) y las opciones estrictas del compilador Angular (`strictInjectionParameters`, `strictInputAccessModifiers`, `strictTemplates` en `angularCompilerOptions`), que se ejecutan como parte del `ng build`.

## 7. Conclusión y recomendación

El microfrontend `mf_shell` **no cuenta con ninguna estrategia de pruebas automatizadas** (unitarias, de integración ni E2E). Dado que concentra el control de acceso global del sistema MSPI (guards de autenticación/autorización) y el protocolo de sincronización de sesión entre 5 microfrontends vía `postMessage`, esta ausencia representa el riesgo técnico más relevante identificado en el análisis de este microfrontend (ver también `01-Planificacion.md`, sección 8, y `07-Mantenimiento.md`). Se recomienda, como mínimo, priorizar pruebas unitarias con Jasmine/Karma (herramienta nativa del Angular CLI, ausente pero fácil de añadir con `ng generate config karma` en un CLI moderno o instalación manual) para `authority.ts`, los guards y `shell-iframe-bridge.ts`, dado que son las piezas de mayor impacto en seguridad y menor complejidad de prueba (funciones puras o casi puras).
