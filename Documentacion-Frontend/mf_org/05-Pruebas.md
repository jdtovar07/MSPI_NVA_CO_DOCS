# mf_org — Pruebas

**Repositorio:** `MSPI_NVA_CO_MR_FRONT/mf_org`
**Fecha del documento:** 2026-08-18
**Alcance:** Estrategia de pruebas del microfrontend `mf_org`: frameworks configurados, archivos de prueba existentes, tipos de prueba evidenciados y validación de requerimientos.

---

## 1. Declaración explícita del hallazgo principal

**El repositorio `mf_org` no contiene pruebas automatizadas.** Esta afirmación se basa en verificación directa y exhaustiva, replicando la misma metodología usada para `mf_auth`:

- Búsqueda de archivos `*.spec.ts` en todo el árbol del proyecto (excluyendo `node_modules`): **0 resultados**.
- Búsqueda de archivos relacionados con Karma o Jest (`karma.conf.js`, `jest.config.*`): **0 resultados**.
- `angular.json` **no define un target `test`** dentro de `architect` para el proyecto `mf-org` (solo existen los targets `build` y `serve`).
- `package.json` **no define un script `test`** (los únicos scripts son `ng`, `start`, `start:api`, `build`, `build:docker`).
- `package.json` **no incluye ninguna dependencia de testing** (`karma`, `karma-jasmine`, `jasmine-core`, `@types/jasmine`, `jest`, `@testing-library/*`) ni en `dependencies` ni en `devDependencies`.
- No existe `.eslintrc*` ni script `lint`.
- No existe carpeta `e2e/` ni configuración de Cypress/Playwright/Protractor.

Esto contrasta con un proyecto Angular CLI estándar, que por defecto incluye Karma + Jasmine y genera un `*.spec.ts` junto a cada componente/servicio generado con `ng generate`. Su ausencia total indica que **la infraestructura de pruebas fue removida o nunca inicializada**, patrón idéntico al observado en `mf_auth` y consistente con la hipótesis de que todos los microfrontends del ecosistema MSPI comparten el mismo punto de partida de plantilla.

## 2. Estrategia de pruebas actual (según lo evidenciado)

No existe una estrategia de pruebas automatizadas formal para `mf_org`. La única forma de validación funcional disponible dentro del propio repositorio es:

1. **Modo mock manual**: `environment.useMocks = true` (configuración por defecto de `ng serve`) permite ejercitar el listado, la búsqueda, el filtro por tipo, el alta, la edición y la vista "Mi organización" sin backend, usando el catálogo de dos organizaciones de prueba definido en `MockOrganizationRepository` y el catálogo geográfico estático de `src/data/locations.ts` (vía `MockLocationRepository`). Esto funciona como un mecanismo de **prueba manual exploratoria**, no como prueba automatizada.
2. **Datos de organización de prueba disponibles en modo mock** (`mock-organization.repository.ts`):

| id | Nombre | Tipo | Identificador | Correo |
|---|---|---|---|---|
| `1` | Entidad Demo Pública | `PUBLICA` | `900123456` | `contacto@demo.gov.co` |
| `2` | Empresa Demo Privada | `PRIVADA` | `800654321` | `info@demo.com` |

`MockOrganizationRepository.getMyOrganization()` siempre retorna la primera organización del arreglo (`this.mockOrgs[0]`, id `1`), independientemente de la sesión activa — útil para probar CU-04 (vista "Mi organización") sin backend, pero sin variabilidad entre usuarios simulados.

3. **Catálogo geográfico mock** (`src/data/locations.ts`): incluye 9 países (Colombia, México, Argentina, Chile, Perú, Ecuador, Brasil, España, Estados Unidos) y un listado extenso de departamentos de Colombia (códigos `CO-DC`, `CO-ANT`, `CO-ATL`, `CO-BOL`, `CO-BOY`, `CO-CAL`, `CO-CAU`, entre otros), permitiendo ejercitar la cascada geográfica completa en modo mock sin backend.

## 3. Tipos de prueba NO evidenciados en el código

Se declara explícitamente la ausencia de los siguientes tipos de prueba, dado que se buscó evidencia y no se encontró:

- **Pruebas unitarias** de casos de uso (`GetOrganizationsPageUseCase`, `CreateOrganizationUseCase`, etc.) — no hay `*.spec.ts` que instancie estos casos de uso con un repositorio falso.
- **Pruebas unitarias de componentes** (`TestBed`, `ComponentFixture`) — ninguna de las 3 páginas tiene prueba asociada.
- **Pruebas del mapeador de vocabulario** (`organization-api.mapper.ts`) — pese a ser una función pura de bajo costo de prueba y alto impacto (una regresión aquí desalinearía silenciosamente el filtro de tipo y el guardado de organizaciones con `ms_org`), no tiene cobertura.
- **Pruebas de integración HTTP** (`HttpTestingController`) para verificar el comportamiento de `apiInterceptor`, `ApiOrganizationRepository` o `ApiLocationRepository`.
- **Pruebas end-to-end (E2E)** — no hay Cypress, Playwright ni Protractor configurados; no existe carpeta `e2e/`.
- **Pruebas de accesibilidad** automatizadas (axe-core u otras).
- **Linting configurado como parte del pipeline de calidad** — no se encontró `.eslintrc*` ni script `lint` en `package.json`.

## 4. Validación de requerimientos — estado actual

Dado que no existen pruebas automatizadas, la trazabilidad entre los requerimientos funcionales documentados en `02-Analisis.md` y su verificación es, en el estado actual del repositorio, **exclusivamente manual y no reproducible de forma automática**:

| Requerimiento | Mecanismo de validación disponible | Automatizado |
|---|---|---|
| RF-01–RF-03 Listado, búsqueda y filtro | Ejecución manual en modo mock/API con las 2 organizaciones de prueba | No |
| RF-04 Redirección del rol `Lector` | Requiere simular manualmente una sesión con `roles: ['Lector']` en `localStorage`/cookie, dado que el mock de organizaciones no depende del rol para el listado | No |
| RF-05–RF-09 Alta/edición y validaciones de formulario | Ejecución manual, visible en UI en tiempo real (bloqueo de envío) | No |
| RF-10 Vista "Mi organización" | Ejecución manual; en modo mock siempre retorna la organización id `1`, sin variar por usuario | No |
| RF-13 Mapeo de tipo `PUBLICA/PRIVADA` ↔ `PUBLIC/PRIVATE` | Solo verificable inspeccionando el código o las peticiones de red en modo API real | No |

## 5. Riesgo asociado

La ausencia de pruebas automatizadas es un riesgo de calidad relevante, particularmente sobre `organization-api.mapper.ts` y las traducciones inline de campos (`state`→`department`, `email`→`organizationEmail` en `ApiOrganizationRepository`): un cambio de contrato en `ms_org` o un error de tipeo en estos mapeos podría persistir organizaciones con datos incorrectos (tipo invertido, ubicación vacía) sin que ninguna prueba lo detecte antes de producción — un defecto especialmente sensible en un sistema de gestión documental ISO 27001, donde la organización es la entidad raíz de todo el modelo de evaluación.

## 6. Recomendación (fuera del alcance del código actual, declarada como brecha)

No se implementa código de prueba como parte de esta documentación (el alcance del presente trabajo es documental), pero se deja registrada como brecha para trabajo futuro (ver `07-Mantenimiento.md`):

1. Reincorporar Karma + Jasmine (`ng generate` estándar) o migrar a un runner moderno, y agregar el target `test` a `angular.json`.
2. Priorizar pruebas unitarias de `organization-api.mapper.ts` (función pura, alto impacto, trivial de cubrir con casos límite: valores no reconocidos, mayúsculas/minúsculas mixtas).
3. Priorizar pruebas de los casos de uso (`CreateOrganizationUseCase`, `UpdateOrganizationUseCase`) usando `MockOrganizationRepository` o un doble de prueba inyectado.
4. Priorizar pruebas del `apiInterceptor` con `HttpTestingController`, dado que es prácticamente idéntico al de `mf_auth` y centraliza autenticación saliente y manejo de 401.
5. Evaluar un flujo E2E mínimo del camino crítico: listar → crear organización con selección geográfica completa → verificar aparición en el listado, en modo mock.
