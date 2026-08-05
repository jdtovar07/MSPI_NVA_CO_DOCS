# mf_reports — Pruebas

**Repositorio:** `MSPI_NVA_CO_MR_FRONT/mf_reports`
**Fecha del documento:** 2026-08-18
**Alcance:** Estrategia de pruebas del microfrontend `mf_reports`: frameworks configurados, archivos de prueba existentes, tipos de prueba evidenciados y validación de requerimientos.

---

## 1. Declaración explícita del hallazgo principal

**El repositorio `mf_reports` no contiene pruebas automatizadas.** Esta afirmación se basa en verificación directa y exhaustiva sobre el árbol de archivos del proyecto:

- Búsqueda de archivos `*.spec.ts` en todo el árbol del proyecto (excluyendo `node_modules`): **0 resultados**.
- Búsqueda de archivos relacionados con Karma o Jest (`karma.conf.js`, `jest.config.*`): **0 resultados**.
- `angular.json` **no define un target `test`** dentro de `architect` para el proyecto `mf-reports` (solo existen los targets `build` y `serve`; el generador estándar de Angular CLI habitualmente añade un target `test` con builder `@angular-devkit/build-angular:karma`, ausente aquí).
- `package.json` **no define un script `test`** (los únicos scripts son `ng`, `start`, `start:api`, `build`, `build:docker`, `clean`).
- `package.json` **no incluye ninguna dependencia de testing** (`karma`, `karma-chrome-launcher`, `karma-jasmine`, `jasmine-core`, `@types/jasmine`, `jest`, `@testing-library/*`) ni en `dependencies` ni en `devDependencies`.
- No existe carpeta `e2e/` en la raíz del repositorio.

Esto contrasta con un proyecto Angular CLI estándar, que por defecto incluye Karma + Jasmine y genera un `*.spec.ts` junto a cada componente/servicio generado con `ng generate`. Su ausencia total (ni siquiera el archivo `app.component.spec.ts` por defecto) indica que **la infraestructura de pruebas fue removida o nunca inicializada**, no que sea una omisión parcial. Este mismo patrón se observó también en el microfrontend `mf_auth` del mismo ecosistema, lo que sugiere que es una decisión (o ausencia de decisión) consistente en todo el frontend MSPI, y no un caso aislado de `mf_reports`.

## 2. Estrategia de pruebas actual (según lo evidenciado)

No existe una estrategia de pruebas automatizadas formal para `mf_reports`. La única forma de validación funcional disponible dentro del propio repositorio es:

1. **Modo mock manual**: `environment.useMocks = true` (configuración `development`, por defecto de `ng serve`) permite ejercitar los tres flujos principales — inicio, tablero de diagnóstico y exportación — sin backend, usando el tablero fijo definido en `MockReportingRepository` y su simulación temporizada de progreso de *job* (`PENDING` a los 0 ms, `RUNNING` a los 500 ms, `COMPLETED` a los 2000 ms). Esto funciona como un mecanismo de **prueba manual exploratoria**, no como prueba automatizada.
2. **Modo demo dirigido**: la propia interfaz ofrece un botón "Ver demo (mock-assessment-1)" en `ReportsHomePageComponent` cuando no hay evaluación activa, pensado explícitamente para poder inspeccionar el tablero sin depender de haber diligenciado una evaluación real en `mf_assessment`.

### 2.1 Datos de prueba disponibles en modo mock (`mock-reporting.repository.ts`)

| Elemento | Valor fijo en el mock | Utilidad de prueba |
|---|---|---|
| Dominios ISO | `A.5` (72%, Definido), `A.6` (55%, Gestionado) | Verificar renderizado de tabla y bandas de color |
| PHVA | PLAN 80%, DO 60%, CHECK 60%, ACT 40% (total 60%) | Verificar barras de progreso proporcionales |
| Madurez | Nivel 2, criticidad `INTERMEDIO`, 1 requisito (`M1.1`) | Verificar clase CSS condicional por criticidad (`crit-INTERMEDIO`) |
| NIST | Función `GV` (Gobernanza) al 60% | Verificar lista de funciones |
| Brechas | 1 brecha (`TC.1.2`, Gestión de parches, 40%, responsable Juan Pérez) | Verificar tabla de brechas y caso "sin brechas" (cambiando el umbral) |
| Job de exportación | Progresión temporizada `PENDING → RUNNING (50%) → COMPLETED (100%)` en 2 segundos | Verificar *polling*, barra de progreso y descarga automática |
| Archivo descargado (mock) | Blob de texto plano con encabezado `%PDF-1.4 mock` | Verificar mecánica de descarga sin necesidad de un PDF real |

## 3. Tipos de prueba NO evidenciados en el código

Se declara explícitamente la ausencia de los siguientes tipos de prueba, dado que se buscó evidencia y no se encontró:

- **Pruebas unitarias de los casos de uso** (`GetDiagnosticDashboardUseCase`, `CreateReportJobUseCase`, etc.) — no hay `*.spec.ts` que los instancie con un repositorio falso.
- **Pruebas unitarias de las funciones puras de utilidad**, en particular las de mayor complejidad lógica del proyecto: `reporting-diagnostic.mapper.ts` (normalización de múltiples formas de respuesta del backend) y `report-filename.util.ts` (resolución de nombre/extensión de archivo) — ambas son candidatas naturales a prueba unitaria pura por no depender de Angular ni de HTTP, y actualmente no tienen ninguna cobertura.
- **Pruebas unitarias de componentes** (`TestBed`, `ComponentFixture`) — ninguna de las 3 páginas tiene prueba asociada, incluyendo la lógica de *polling* con temporizadores de `ReportsExportPageComponent`, que sería un caso natural para `fakeAsync`/`tick()`.
- **Pruebas de integración HTTP** (`HttpTestingController`) para verificar `apiInterceptor`, `ApiReportingRepository` o el manejo de descargas binarias en `report-download.helper.ts`.
- **Pruebas end-to-end (E2E)** — no hay Cypress, Playwright ni Protractor configurados; no existe carpeta `e2e/`.
- **Pruebas de accesibilidad** automatizadas (axe-core u otras).
- **Linting configurado como parte del pipeline de calidad** — no se encontró `.eslintrc*` ni script `lint` en `package.json` (Angular CLI 19 no incluye ESLint por defecto salvo instalación explícita de `@angular-eslint/schematics`, ausente en `devDependencies`).

## 4. Validación de requerimientos — estado actual

Dado que no existen pruebas automatizadas, la trazabilidad entre los requerimientos funcionales documentados en `02-Analisis.md` y su verificación es, en el estado actual del repositorio, **exclusivamente manual y no reproducible de forma automática**:

| Requerimiento | Mecanismo de validación disponible | Automatizado |
|---|---|---|
| RF-04–RF-06 Tablero de diagnóstico | Ejecución manual en modo mock o contra `ms_assessment` real | No |
| RF-07–RF-13 Ciclo de vida de job y descarga | Ejecución manual en modo mock (progresión temporizada) o modo API | No |
| RF-14–RF-15 Resolución de nombre/extensión de archivo | Inspección manual del archivo descargado por el navegador | No |
| RF-16 Detección de error JSON disfrazado de blob | Requiere provocar un error real del backend o inspección de código | No |
| RN-02 Cálculo de banda por rango de puntaje | Verificable visualmente en el mock (dominios A.5/A.6 con bandas distintas) | No |
| RN-05/RN-07 Reglas de extensión de archivo Excel | Solo verificable inspeccionando manualmente el archivo tras cada tipo de descarga | No |

## 5. Riesgo asociado

La ausencia de pruebas automatizadas es un riesgo de calidad relevante en dos puntos concretos del microfrontend:

1. **`reporting-diagnostic.mapper.ts`**: al tolerar múltiples formas de respuesta del backend (`domainEffectiveness` como arreglo o como objeto, puntaje bajo 4 nombres de campo distintos, PHVA como arreglo o como campos sueltos), un cambio no probado en esta función podría silenciosamente mostrar puntajes en cero o dominios vacíos sin que ningún error visible lo delate — el tablero simplemente se vería "incompleto".
2. **`report-filename.util.ts`**: al ser la única barrera contra que un archivo Excel se descargue con extensión `.pdf` (o viceversa), un cambio no probado podría degradar silenciosamente la usabilidad de la exportación, un requisito explícito y ya documentado como corrección deliberada (`EXCEL_INSTRUMENT_EXPORT`).

## 6. Recomendación (fuera del alcance del código actual, declarada como brecha)

No se implementa código de prueba como parte de esta documentación (el alcance del presente trabajo es documental), pero se deja registrada como brecha para trabajo futuro (ver `07-Mantenimiento.md`):

1. Reincorporar Karma + Jasmine (`ng generate` estándar) o migrar a un runner moderno (`@angular/build` con Vitest, soportado experimentalmente en Angular 19) y agregar el target `test` a `angular.json`.
2. Priorizar pruebas unitarias puras de `reporting-diagnostic.mapper.ts` y `report-filename.util.ts` — ambas son funciones sin dependencias de Angular, de fácil cobertura y de alto impacto funcional.
3. Priorizar pruebas del `apiInterceptor` con `HttpTestingController`, dado que centraliza autenticación saliente, desempaquetado de respuestas y manejo de errores para todas las llamadas del microfrontend.
4. Cubrir con `fakeAsync`/`tick()` el ciclo de *polling* de `ReportsExportPageComponent`, en particular los tres caminos de salida (`COMPLETED`, `FAILED`/`CANCELLED`, tiempo de espera agotado).
5. Evaluar Playwright para un flujo E2E mínimo del camino crítico: inicio → tablero de diagnóstico → exportación → descarga, en modo mock.
