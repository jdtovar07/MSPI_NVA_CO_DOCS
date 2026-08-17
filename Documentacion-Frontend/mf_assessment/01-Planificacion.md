# mf_assessment — Planificación

**Repositorio:** `MSPI_NVA_CO_MR_FRONT/mf_assessment`
**Fecha del documento:** 2026-08-18
**Alcance:** Fase de planificación del microfrontend de evaluaciones de madurez (`mf_assessment`), componente del ecosistema **MSPI** (sistema de gestión de seguridad de la información alineado a ISO 27001), construido bajo una arquitectura de microfrontends Angular.

---

## 1. Contexto del proyecto

MSPI es una plataforma web compuesta por un **shell** anfitrión (`mf_shell`, puerto **4200**) y varios microfrontends independientes que se despliegan y ejecutan como aplicaciones Angular separadas:

| Microfrontend | Puerto | Responsabilidad |
|---|---|---|
| `mf_shell` | 4200 | Host / navegación / dashboard |
| `mf_auth` | 4201 | Autenticación, 2FA, usuarios |
| `mf_org` | 4202 | Organizaciones |
| **`mf_assessment`** | **4203** | **Instrumento de evaluación de madurez ISO 27001 (wizard completo)** |
| `mf_evidence` | 4204 | Evidencias documentales |
| `mf_reports` | 4205 | Reportes (generación/descarga PDF·Excel) |

Esta relación está documentada en `MSPI_NVA_CO_MR_FRONT/docs/README.md`, índice general del frontend que enlaza a la carpeta `docs/` de cada microfrontend.

`mf_assessment` es el **núcleo funcional del instrumento MSPI**: implementa el diligenciamiento completo de una evaluación de madurez en seguridad de la información, desde la configuración inicial (organización, tipo de entidad, áreas) hasta la calificación de controles ISO 27001 (administrativos y técnicos), el módulo PHVA (Planificar–Hacer–Verificar–Actuar), el cálculo de nivel de madurez, el mapeo a funciones del NIST Cybersecurity Framework (NIST CSF) y el **tablero de diagnóstico consolidado único** del producto. Es el microfrontend que produce los datos que luego consumen `mf_evidence` (evidencias) y `mf_reports` (solo exportación de reportes).

## 2. Alcance del microfrontend

### 2.1 Incluido en el alcance de `mf_assessment`

- **Listado de evaluaciones** (`/evaluations`) con botones Nueva / Continuar, badge de estado (`BORRADOR`, `EN_DILIGENCIAMIENTO`, `PUBLICADO`).
- **Alta de evaluación** (`/evaluations/new`): selección de organización (consumida de `ms_org`), nombre, fecha, periodo, contacto.
- **Wizard de diligenciamiento de 8 pasos**, cada uno con ruta propia bajo `/evaluations/:id/...`:
  1. Tipo de entidad (nacional / territorial)
  2. Áreas y temas (topics) con responsables
  3. Stewardship (responsables por control)
  4. Controles administrativos (árbol + calificación, `controlType=ADMIN`)
  5. Controles técnicos (árbol + calificación, `controlType=TECH`)
  6. PHVA (ítems del ciclo Plan-Do-Check-Act)
  7. Madurez (requisitos y matriz de niveles)
  8. NIST CSF (funciones GV, ID, PR, DE, RS, RC)
- **Calificación de controles** mediante escala fija (0, 20, 40, 60, 80, 100, N/A) con hallazgos, evidencia textual, brechas y recomendaciones.
- **Cálculo de resúmenes** de avance PHVA, nivel de madurez alcanzado y avance por función NIST (obtenidos del backend, no calculados en el cliente).
- **Índice local de evaluaciones** (`AssessmentIndexService`, `localStorage`) como mitigación ante la ausencia de un endpoint de listado paginado en el backend.
- **Puente hacia otros microfrontends del shell**: navegación a Evidencias (`/evidence`) y Reportes (`/reports`) sin recarga completa, propagando la evaluación activa.
- Modo **mock** (sin backend) y modo **API real** (`ms_assessment` 8084, `ms_catalog` 8085, `ms_org` 8083), seleccionables por configuración de build Angular.

### 2.2 Fuera del alcance de `mf_assessment`

- **Gestión de evidencias documentales** (carga de archivos, versionado) — responsabilidad de `mf_evidence` (4204); `mf_assessment` solo referencia `EvidenceFile[]` en el detalle de un control.
- **Generación de reportes PDF/Excel** — responsabilidad de `mf_reports` (4205); `mf_assessment` únicamente navega hacia allá con la evaluación activa.
- **Administración de organizaciones** (alta/edición) — responsabilidad de `mf_org` (4202); `mf_assessment` solo consume `GET` de organizaciones como catálogo de apoyo al crear una evaluación.
- **Autenticación y emisión de sesión** — responsabilidad de `mf_auth` (4201) / `ms_iam`; `mf_assessment` únicamente consume la sesión propagada por el shell vía `postMessage`.
- **Lógica de cálculo de puntajes agregados (rollup), nivel de madurez y avance PHVA/NIST** — reside en `ms_assessment`; el frontend solo renderiza los resultados que el backend calcula y expone en los endpoints `/scores/rollup`, `/phva/summary`, `/maturity/summary`, `/nist/summary`.

## 3. Objetivos

### 3.1 Objetivo general

Proveer un microfrontend Angular independiente y desplegable de forma aislada que implemente el instrumento de diligenciamiento de evaluaciones de madurez en seguridad de la información del sistema MSPI, alineado a ISO 27001 y NIST CSF, integrado con el shell sin acoplamiento de código en tiempo de compilación.

### 3.2 Objetivos específicos

1. Implementar un wizard de 8 pasos que guíe al evaluador desde la configuración de la evaluación hasta la calificación de controles y módulos complementarios (PHVA, madurez, NIST), respetando el orden funcional definido en `presentation/evaluation-wizard-links.ts`.
2. Modelar el dominio de la evaluación (`Assessment`, `ControlScore`, `RollupNode`, `PhvaItem`, `MaturityRequirement`, `NistCiberItem`) de forma independiente de la infraestructura HTTP, siguiendo una arquitectura por capas (dominio / aplicación / infraestructura / presentación).
3. Consumir los tres microservicios backend involucrados (`ms_assessment` 8084, `ms_catalog` 8085, `ms_org` 8083) a través de repositorios intercambiables (mock/API) sin tocar componentes de presentación.
4. Gestionar el control de concurrencia optimista (`rowVersion`) ante ediciones simultáneas de una misma evaluación, informando al usuario cuando ocurre un conflicto (HTTP 409).
5. Propagar la **evaluación activa** al shell (`mf_shell`) mediante `localStorage` y `postMessage`, para que los menús de Evidencias y Reportes del host puedan operar sobre el mismo contexto.
6. Permitir el despliegue en contenedor Docker con Nginx, homogéneo con el resto de microfrontends del ecosistema MSPI, incluyendo cabecera `Content-Security-Policy: frame-ancestors` restringida al origen del shell.

## 4. Requerimientos iniciales (alto nivel)

- El microfrontend debe poder ejecutarse **de forma independiente** en el puerto 4203 (`ng serve`), tanto en modo mock (`npm start`) como contra `ms_assessment`/`ms_catalog` reales (`npm run start:api`).
- Debe integrarse con `mf_shell` sin que este dependa de artefactos de build de `mf_assessment` (no hay *remotes/exposes* de Module Federation — la integración es por iframe y `postMessage`, ver sección 6 y `03-Diseno.md`).
- Debe respetar el orden funcional del instrumento MSPI: tipo de entidad → áreas → stewardship → controles (admin/técnico) → PHVA → madurez → NIST, con navegación sticky (Volver / Listado / Siguiente) en cada pantalla.
- Debe permitir calificar cada control, ítem PHVA, requisito de madurez o ítem NIST con la escala fija `0, 20, 40, 60, 80, 100` o `N/A` (constante `RATING_SCALE_VALUES`).
- Debe manejar el conflicto de versión (HTTP 409, `AssessmentConflictError`) recargando la evaluación y notificando al usuario.
- Debe mantener un índice local de evaluaciones creadas (`mspi_assessment_index` en `localStorage`) para suplir la ausencia de un endpoint `GET` de listado paginado en `ms_assessment`.

## 5. Stack tecnológico (verificado en `package.json` y `angular.json`)

| Categoría | Tecnología | Versión |
|---|---|---|
| Framework | Angular (`@angular/core`, `@angular/common`, `@angular/forms`, `@angular/router`, `@angular/platform-browser*`) | `^19.0.0` |
| Animaciones | `@angular/animations` | `^19.0.0` |
| Reactividad | `rxjs` | `~7.8.0` |
| Runtime Angular | `zone.js` | `~0.15.0` |
| CLI / build | `@angular/cli`, `@angular-devkit/build-angular` (builder `application`) | `^19.0.0` |
| Compilador | `@angular/compiler-cli`, `typescript` | `~5.6.0` |
| Lenguaje | TypeScript, modo `strict` (+ `noImplicitOverride`, `noPropertyAccessFromIndexSignature`, `noImplicitReturns`, `strictTemplates`) | `~5.6.0` |
| Tipado Node | `@types/node` | `^22.0.0` |
| Contenedor | Node 22-alpine (build) + Nginx 1.27-alpine (runtime) | — |

**Nota importante:** el proyecto **no usa Module Federation de Webpack** (no existe `@angular-architects/module-federation` en `package.json`, ni `webpack.config.js`/`federation.config.js` en el repositorio). La integración con el shell se realiza por **composición en tiempo de ejecución vía navegador**: el shell carga `mf_assessment` en un `<iframe>` apuntando a `http://localhost:4203/evaluations`, y la comunicación ocurre por `postMessage` (`MSPI_AUTH_REQUEST`/`MSPI_AUTH_SESSION`, `MSPI_ACTIVE_ASSESSMENT`, `MSPI_SHELL_NAV`) y `localStorage`. Este punto se detalla en `03-Diseno.md` e `INTEGRACION-SHELL.md`.

A diferencia de otros microfrontends del ecosistema (p. ej. `mf_auth`, que arrastra artefactos de una plantilla React/Vite previa), en `mf_assessment` **no se encontró código residual ajeno a Angular**: la carpeta `src/` contiene exclusivamente `app/`, `environments/`, `index.html`, `main.ts` y `styles.scss`, coherente con `tsconfig.app.json`.

## 6. Restricciones y supuestos

- El backend de evaluaciones (`ms_assessment`) debe estar disponible en `http://localhost:8084`, el de catálogo (`ms_catalog`) en `http://localhost:8085` y el de organizaciones (`ms_org`) en `http://localhost:8083` para el modo API; en su ausencia, el proyecto puede ejecutarse con `environment.useMocks = true` (configuración por defecto de `environment.ts`).
- El shell (`mf_shell`) se asume corriendo en `http://localhost:4200`/`http://127.0.0.1:4200` — estos orígenes están hardcodeados como destino de `postMessage` (`shell-bridge.ts`, `auth-parent-bridge.ts`) y como origen permitido para iframes (`Content-Security-Policy: frame-ancestors` en `deployment/nginx.conf`).
- La recomendación explícita del propio equipo, documentada en `docs/INTEGRACION-SHELL.md`, es **no abrir `localhost:4203` directamente** en el flujo normal de uso, sino acceder siempre vía shell (`http://localhost:4200/evaluations`), porque solo así se comparte el JWT y la evaluación activa.
- El listado de evaluaciones **no dispone de un endpoint `GET` de listado en el backend** (limitación documentada en `docs/DESCRIPCION.md`); el frontend suple esto con un índice local en `localStorage` (`AssessmentIndexService`), lo que implica que el listado visible depende del navegador/dispositivo donde se crearon las evaluaciones.
- No se encontró documentación ni configuración de CI/CD dentro del repositorio de `mf_assessment` (no hay carpeta `.github/workflows` ni pipeline visible en el microfrontend).
- La referencia a la guía de integración backend (`docker-config/docs/backend/GUIA_INTEGRACION_FRONTEND.md`), citada en `docs/API-INTEGRACION.md`, se encuentra fuera del repositorio `MSPI_NVA_CO_MR_FRONT` analizado; no se verificó su contenido.

## 7. Recursos y planificación

### 7.1 Recursos identificados en el repositorio

- Código fuente Angular real: `src/app/**` organizado en `domain/`, `application/`, `infrastructure/`, `presentation/` (arquitectura por capas explícita).
- Documentación técnica preexistente en `mf_assessment/docs/` (7 documentos Markdown: `DESCRIPCION.md`, `ARQUITECTURA.md`, `RUTAS-Y-PANTALLAS.md`, `FLUJOS.md`, `API-INTEGRACION.md`, `INTEGRACION-SHELL.md`, `DIAGRAMAS.md`), tomada como fuente primaria para esta documentación de tesis.
- Carpeta `public/` presente pero **vacía** (sin logo ni assets propios detectados).
- Infraestructura de despliegue propia: `deployment/Dockerfile`, `deployment/nginx.conf`.
- Infraestructura de despliegue compartida a nivel de repositorio frontend: `MSPI_NVA_CO_MR_FRONT/deployment/docker/Dockerfile.angular` (plantilla genérica) y `MSPI_NVA_CO_MR_FRONT/deployment/nginx/spa.conf`.

### 7.2 Plan de trabajo inferido (por evidencia de código, no por bitácora explícita)

No existe en el repositorio un backlog, roadmap o bitácora de sprints formal para `mf_assessment`. La planificación documentada aquí se reconstruye a partir de la evidencia funcional del código y de la documentación en `docs/`, siguiendo el orden natural de dependencia funcional del instrumento:

1. **Base del microfrontend**: bootstrap Angular standalone (`main.ts`, `app.config.ts`, `app.routes.ts`), configuración de entornos (mock/API), interceptor HTTP de autenticación (`apiInterceptor`).
2. **Ciclo de vida de la evaluación**: dominio (`AssessmentRepository`, `Assessment`), casos de uso (`ListAssessmentsUseCase`, `CreateAssessmentUseCase`, `GetAssessmentUseCase`, `AssignEntityOrderTypeUseCase`), infraestructura (`MockAssessmentRepository`, `ApiAssessmentRepository`), presentación (`EvaluationListPageComponent`, `EvaluationCreatePageComponent`).
3. **Configuración inicial**: tipo de entidad territorial, áreas y temas (`AreasPageComponent`, `ReplaceAreaTopicsUseCase`), stewardship por control (`StewardshipPageComponent`, `PatchControlStewardUseCase`).
4. **Calificación de controles ISO**: árbol de rollup (`ControlTreeComponent`), panel de detalle (`ControlDetailPanelComponent`), casos de uso (`GetRollupUseCase`, `GetControlDetailUseCase`, `PatchControlScoreUseCase`), manejo de conflicto de versión (`assessment-conflict.handler.ts`).
5. **Módulos complementarios**: PHVA (`PhvaPageComponent`, `score-modules.use-cases.ts`), Madurez (`MaturityPageComponent`), NIST CSF (`NistPageComponent`).
6. **Puente con el shell y otros MF**: `AssessmentIndexService`, `shell-bridge.ts` (`openShellRoute` hacia `/evidence` y `/reports`), `auth-parent-bridge.ts`.
7. **Empaquetado y despliegue**: Dockerfile propio + Nginx con `Content-Security-Policy: frame-ancestors`.
8. **Documentación técnica** (`docs/*.md`), generada como parte del proyecto.

Declaración explícita de limitación: **no hay evidencia en el repositorio de control de versiones semántico por hitos, ni de un archivo `CHANGELOG.md`, ni de tickets/historias de usuario formales**; el archivo `package.json` fija `"version": "1.0.0"` de forma estática.

## 8. Riesgos identificados

| Riesgo | Evidencia | Impacto |
|---|---|---|
| Ausencia de endpoint `GET` de listado de evaluaciones en el backend | `docs/DESCRIPCION.md`: "AssessmentIndexService guarda IDs en localStorage... (limitación actual)" | El listado de evaluaciones depende del navegador local; no es un listado centralizado ni multiusuario real |
| Ausencia total de pruebas automatizadas | No existen archivos `*.spec.ts` ni configuración Karma/Jest en el repositorio (ver `05-Pruebas.md`) | Riesgo de regresiones no detectadas, especialmente en mapeos DTO↔dominio y en el manejo de conflicto de versión |
| Hardcodeo de orígenes del shell (`localhost:4200`) en código de producción | `shell-bridge.ts`, `auth-parent-bridge.ts`, `deployment/nginx.conf` (`frame-ancestors`) | Rigidez para desplegar en otros dominios/ambientes sin recompilar o reconfigurar Nginx |
| Doble representación de campos en el dominio (`score`/`scoreValue`, `evidenceText`/`findingText`, `recommendationText`/`improvementText`) | `assessment.types.ts`, `assessment-api.mapper.ts` | Superficie de mantenimiento mayor y riesgo de inconsistencia entre alias equivalentes |
| Conflictos de edición concurrente sobre la misma evaluación | `assessment-conflict.handler.ts` maneja HTTP 409 recargando datos | Pérdida de cambios locales no guardados del usuario que perdió la carrera de escritura |
| Falta de guía de integración backend accesible dentro del repositorio analizado | `docs/API-INTEGRACION.md` referencia `docker-config/docs/backend/GUIA_INTEGRACION_FRONTEND.md`, fuera del alcance de este análisis | Documentación de contrato API dependiente de un repositorio externo no verificado |

Estos hallazgos se retoman con mayor detalle en `03-Diseno.md`, `04-Desarrollo.md` y `07-Mantenimiento.md`.
