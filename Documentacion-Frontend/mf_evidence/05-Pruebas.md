# mf_evidence — Pruebas

**Repositorio:** `MSPI_NVA_CO_MR_FRONT/mf_evidence`
**Fecha del documento:** 2026-08-18
**Alcance:** Estrategia de pruebas del microfrontend `mf_evidence`: frameworks configurados, archivos de prueba existentes, tipos de prueba evidenciados y validación de requerimientos.

---

## 1. Declaración explícita del hallazgo principal

**El repositorio `mf_evidence` no contiene pruebas automatizadas.** Esta afirmación se basa en verificación directa y exhaustiva:

- Búsqueda de archivos `*.spec.ts` en todo el árbol del proyecto (excluyendo `node_modules`): **0 resultados**.
- Búsqueda de archivos relacionados con Karma o Jest (`karma.conf.js`, `jest.config.*`): **0 resultados**.
- `angular.json` **no define un target `test`** dentro de `architect` para el proyecto `mf-evidence` (solo existen los targets `build` y `serve`; el generador estándar de Angular CLI habitualmente añade un target `test` con builder `@angular-devkit/build-angular:karma`, ausente aquí).
- `package.json` **no define un script `test`** (los únicos scripts son `ng`, `start`, `start:api`, `build`, `build:docker`, `clean`).
- `package.json` **no incluye ninguna dependencia de testing** (`karma`, `karma-chrome-launcher`, `karma-jasmine`, `jasmine-core`, `@types/jasmine`, `jest`, `@angular/testing`, `@testing-library/*`) ni en `dependencies` ni en `devDependencies`.

Este hallazgo es idéntico en naturaleza al documentado para `mf_auth`: la infraestructura de pruebas estándar de Angular CLI fue removida o nunca inicializada en este microfrontend, de forma consistente en todo el ecosistema MSPI (al menos en los dos repositorios auditados hasta ahora).

## 2. Estrategia de pruebas actual (según lo evidenciado)

No existe una estrategia de pruebas automatizadas formal para `mf_evidence`. La única forma de validación funcional disponible dentro del propio repositorio es:

1. **Modo mock manual**: `environment.useMocks = true` (configuración por defecto de `ng serve`) permite ejercitar los flujos de contexto, levantamiento y métrica de alcance sin backend, usando `MockEvidenceRepository`. Este mock:
   - Genera automáticamente **43 entregas simuladas** al primer acceso a una evaluación (`buildMockDeliveries()`), con 5 marcadas como `DELIVERED`, 3 como `PARTIAL` y las 35 restantes como `NOT_DELIVERED` — permite probar visualmente los tres estados y la mezcla de completitud sin configuración adicional.
   - Simula una métrica de alcance por defecto (`totalProcesses: 100, inScopeProcesses: 75, coverage: 75`) hasta que el usuario la edite explícitamente.
   - Simula la subida/descarga de archivos en memoria (`this.files: EvidenceFileMetadata[]`), generando contenido de archivo ficticio (`Mock content: {filename}`) para la descarga, ya que no hay almacenamiento binario real.
2. **Precondición manual de evaluación activa**: dado que `mf_evidence` depende de `active_assessment_id` en `localStorage`, ejercitar el flujo en modo standalone (fuera del shell) requiere establecer manualmente esa clave desde la consola del navegador (`localStorage.setItem('active_assessment_id', '<cualquier-id>')`) antes de navegar a `/`, o navegar directamente a `/assessments/<id>/context`.

### 2.1 Datos de prueba disponibles en modo mock (`mock-evidence.repository.ts`)

| Elemento | Valor de prueba | Notas |
|---|---|---|
| Contexto inicial | Todos los campos vacíos (`''`) hasta el primer `PATCH` | Permite verificar el estado "sin diligenciar" |
| Métrica inicial | `totalProcesses: 100`, `inScopeProcesses: 75`, `coverage: 75` | Cobertura ya calculada por defecto |
| Entregas 1–5 | `DELIVERED`, con `deliveredName: "Documento DOC-00N.pdf"` | Permite probar el estado "entregado" sin edición previa |
| Entregas 6–8 | `PARTIAL`, sin `deliveredName` | Permite probar el estado "parcial" |
| Entregas 9–43 | `NOT_DELIVERED` | Estado por defecto, mayoría de los ítems |
| Nombres de documento | 5 nombres cíclicos (`DOC_NAMES`): política de seguridad, plan de tratamiento de riesgos, inventario de activos, matriz de roles, procedimiento de gestión de incidentes | Se repiten cada 5 ítems, sufijados con el código `DOC-0NN` |

No hay usuarios ni credenciales de prueba propios de `mf_evidence` (a diferencia de `mf_auth`), dado que este microfrontend no gestiona autenticación; la sesión debe provenir de `mf_auth` o simularse manualmente vía `localStorage['auth_session']`.

## 3. Tipos de prueba NO evidenciados en el código

Se declara explícitamente la ausencia de los siguientes tipos de prueba, dado que se buscó evidencia y no se encontró:

- **Pruebas unitarias** de casos de uso (`GetContextUseCase`, `PatchLiftingDeliveryUseCase`, etc.) — no hay `*.spec.ts` que los instancie con un repositorio falso.
- **Pruebas unitarias de componentes** (`TestBed`, `ComponentFixture`) — ninguna de las 3 páginas ni de los 2 componentes reutilizables tiene prueba asociada.
- **Pruebas de integración HTTP** (`HttpTestingController`) para verificar el comportamiento de `apiInterceptor` o de `ApiEvidenceRepository`, en particular el manejo especial de `Blob` en la descarga.
- **Pruebas end-to-end (E2E)** — no hay Cypress, Playwright ni Protractor configurados; no existe carpeta `e2e/`.
- **Pruebas de accesibilidad** automatizadas (axe-core u otras).
- **Linting configurado como parte del pipeline de calidad** — no se encontró `.eslintrc*` ni script `lint` en `package.json`.
- **Pruebas de carga/subida de archivos** (tamaño máximo, tipos permitidos) — tampoco existe la validación correspondiente en el código de producción (`FileUploaderComponent` acepta cualquier archivo sin restricción de tipo o tamaño).

## 4. Validación de requerimientos — estado actual

Dado que no existen pruebas automatizadas, la trazabilidad entre los requerimientos funcionales documentados en `02-Analisis.md` y su verificación es, en el estado actual del repositorio, **exclusivamente manual y no reproducible de forma automática**:

| Requerimiento | Mecanismo de validación disponible | Automatizado |
|---|---|---|
| RF-01–RF-02 Redirección/aviso de evaluación activa | Ejecución manual con/sin `active_assessment_id` en `localStorage` | No |
| RF-03–RF-06 Contexto de evaluación | Ejecución manual en modo mock/API | No |
| RF-08–RF-12 Levantamiento documental | Ejecución manual contra `MockEvidenceRepository` (43 ítems ya poblados) | No |
| RF-13–RF-15 Métrica de alcance de procesos | Edición manual de "Total procesos"/"En alcance" y verificación visual de cobertura y advertencia | No |
| RF-19 Carga por arrastrar-y-soltar | Requiere interacción manual real del navegador (drag-and-drop no es trivialmente simulable sin un runner E2E) | No |
| RNF-05 Recarga de sesión en 401 | Requiere provocar un 401 real (backend) o inspección de código | No |

## 5. Riesgo asociado

La ausencia de pruebas automatizadas es un riesgo de calidad relevante porque `mf_evidence` gestiona **evidencias documentales de auditoría** dentro de un sistema alineado a ISO 27001: un cambio no probado en el cálculo de cobertura (`coverage`), en la lógica de asociación de archivos por `relationId`, o en el interceptor que desenvuelve `{data, meta}` podría corromper silenciosamente el estado de cumplimiento mostrado al usuario sin que exista una red de seguridad automatizada que lo detecte antes de producción.

## 6. Recomendación (fuera del alcance del código actual, declarada como brecha)

No se implementa código de prueba como parte de esta documentación (el alcance del presente trabajo es documental), pero se deja registrada como brecha para trabajo futuro (ver `07-Mantenimiento.md`):

1. Reincorporar Karma + Jasmine (`ng generate` estándar) o migrar a un runner moderno (Vitest, soportado experimentalmente en Angular 19) y agregar el target `test` a `angular.json`.
2. Priorizar pruebas unitarias de `MockEvidenceRepository.buildMockDeliveries()` y del cálculo de `coverage`/`inScopeExceedsTotal` en `patchProcessScopeMetric()` (funciones puras de alto valor y fácil cobertura).
3. Priorizar pruebas del `apiInterceptor` con `HttpTestingController`, en particular el caso de exclusión de `Blob` del desenvolvimiento de respuesta, dado que es una rama de código fácil de romper accidentalmente y crítica para la descarga de archivos.
4. Evaluar Playwright para un flujo E2E mínimo del camino crítico: home con evaluación activa → contexto → guardar → levantamiento → cambiar estado de un ítem → subir archivo → descargar archivo.
5. Añadir pruebas de componente para `FileUploaderComponent`, incluyendo el evento `dragover`/`drop`, dado que es el único componente con lógica de interacción del navegador (`DragEvent`) más allá de formularios estándar.
