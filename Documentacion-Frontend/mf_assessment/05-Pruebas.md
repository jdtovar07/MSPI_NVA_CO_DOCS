# mf_assessment — Pruebas

**Repositorio:** `MSPI_NVA_CO_MR_FRONT/mf_assessment`
**Fecha del documento:** 2026-08-18
**Alcance:** Estado real de pruebas automatizadas del microfrontend de evaluaciones de madurez (`mf_assessment`), verificado sobre el repositorio.

---

## 1. Declaración explícita de estado

**No se encontró ninguna prueba automatizada en el repositorio `mf_assessment`.** Verificación realizada:

- Búsqueda de archivos `*.spec.ts` en `src/` y en la raíz del proyecto: **0 resultados**.
- Búsqueda de archivos `*.test.ts`: **0 resultados**.
- Búsqueda de configuración Karma (`karma.conf.js`) o Jest (`jest.config.*`): **no existe**.
- Búsqueda de configuración de pruebas end-to-end (Cypress, Playwright, Protractor): **no existe**.
- `package.json` no define ningún script `test`, `test:unit`, `test:e2e` ni equivalente — solo existen `ng`, `start`, `start:api`, `start:force`, `build`, `build:docker`, `clean`.
- `angular.json` no define un *target* `test` en `architect` (solo `build` y `serve`).

Esta situación es consistente con lo observado en el microfrontend piloto `mf_auth` del mismo ecosistema, donde tampoco se detectó infraestructura de pruebas.

## 2. Framework de pruebas configurado

Ninguno. El proyecto fue generado con Angular CLI 19 pero **no conserva ni el builder de pruebas por defecto** (`@angular-devkit/build-angular:karma`) ni un archivo `tsconfig.spec.json`, que suelen incluirse en el esqueleto estándar de `ng new`. Esto sugiere una remoción deliberada de la infraestructura de pruebas generada automáticamente, o bien un proyecto iniciado a partir de una plantilla reducida.

`devDependencies` en `package.json` (verificado):

```json
"devDependencies": {
  "@angular-devkit/build-angular": "^19.0.0",
  "@angular/cli": "^19.0.0",
  "@angular/compiler-cli": "^19.0.0",
  "@types/node": "^22.0.0",
  "typescript": "~5.6.0"
}
```

No aparecen `karma`, `karma-chrome-launcher`, `jasmine-core`, `@types/jasmine`, `jest`, `@testing-library/angular`, `cypress` ni `@playwright/test`.

## 3. Specs existentes

No aplica — no hay ningún archivo de prueba en el repositorio.

## 4. Superficie de riesgo sin cobertura

A partir del análisis de código (`03-Diseno.md`, `04-Desarrollo.md`), las áreas con mayor lógica no trivial y por tanto mayor beneficio potencial de pruebas automatizadas son:

| Área | Archivo | Motivo |
|---|---|---|
| Mapeo API↔dominio | `infrastructure/assessment/assessment-api.mapper.ts` | 366 líneas con múltiples reconciliaciones de alias (`??` en cascada), parsing de texto libre (`nivelAlcanzado` → número), recursión en `mapRollupNodeFromApi` |
| Manejo de conflicto de versión | `application/assessment/assessment-conflict.handler.ts` | Lógica crítica de negocio: distingue HTTP 409 de otros errores, recarga estado, lanza `AssessmentConflictError` |
| Puente de sesión con el shell | `infrastructure/auth/auth-parent-bridge.ts` | Validación de origen (`ALLOWED_PARENTS`), expiración de sesión, parsing de JSON potencialmente malformado |
| Puente de navegación con el shell | `infrastructure/shell/shell-bridge.ts` | Comportamiento condicional según `window.parent === window` (iframe vs. standalone) |
| Índice local de evaluaciones | `infrastructure/assessment/assessment-index.service.ts` | Deduplicación de IDs, límite de 100 registros, manejo de cuota de `localStorage` |
| Formulario de calificación de control | `presentation/components/control-detail-panel.component.ts` | Construcción condicional del `PatchControlScoreRequest` según `rating` sea numérico o `'NA'` |

## 5. Verificación manual disponible (mocks)

Ante la ausencia de pruebas automatizadas, el proyecto ofrece un mecanismo de **verificación manual mediante datos mock**:

- `npm start` (configuración `development`, `useMocks: true` en `environment.ts`) permite recorrer todo el wizard de 8 pasos sin backend, usando `MockAssessmentRepository`, `MockCatalogRepository` y `MockOrganizationListRepository`.
- Los datos mock incluyen una evaluación de ejemplo (`mock-assessment-1`, "Diagnóstico SI 2026", estado `BORRADOR`) y un árbol de rollup sintético con dominios, objetivos y controles hoja para los tipos `ADMIN` y `TECH`.
- `npm run start:api` permite la verificación manual contra los backends reales (`ms_assessment`, `ms_catalog`, `ms_org`), útil para validar el contrato real antes de un despliegue.

Esto sustituye parcialmente la necesidad de pruebas unitarias durante el desarrollo, pero no ofrece ninguna garantía de regresión automatizada ni de cobertura medible.

## 6. Recomendaciones (fuera del alcance implementado, a título de trabajo futuro)

1. Reincorporar el builder de pruebas de Angular (`ng generate config karma` o migrar a Jest con `@angular-builders/jest`) y cubrir, como mínimo, los mappers de `assessment-api.mapper.ts` con pruebas de tabla (casos con y sin campos opcionales).
2. Añadir pruebas unitarias al manejador de conflicto de versión (`assessment-conflict.handler.ts`), simulando un `ApiError` con `status: 409` y verificando que se recarga la evaluación y se lanza `AssessmentConflictError`.
3. Añadir pruebas de componente (`TestBed`) para `ControlDetailPanelComponent`, validando que `save()` arma correctamente el `PatchControlScoreRequest` en ambos casos (`SCORED` y `NA`).
4. Considerar pruebas end-to-end (Playwright/Cypress) que recorran el wizard completo en modo mock, dado que es el modo de ejecución que no depende de infraestructura externa.

Esta sección documenta una **ausencia real y verificada**, no una recomendación ya implementada.
