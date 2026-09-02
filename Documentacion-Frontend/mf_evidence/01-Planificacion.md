# mf_evidence — Planificación

**Repositorio:** `MSPI_NVA_CO_MR_FRONT/mf_evidence`
**Fecha del documento:** 2026-08-18
**Alcance:** Fase de planificación del microfrontend de gestión de evidencias documentales (`mf_evidence`), componente del ecosistema **MSPI** (sistema de gestión de seguridad de la información alineado a ISO 27001), construido bajo una arquitectura de microfrontends Angular.

---

## 1. Contexto del proyecto

MSPI es una plataforma web compuesta por un **shell** anfitrión (`mf_shell`, puerto **4200**) y varios microfrontends independientes que se despliegan y ejecutan como aplicaciones Angular separadas:

| Microfrontend | Puerto | Responsabilidad |
|---|---|---|
| `mf_shell` | 4200 | Host / navegación / dashboard |
| `mf_auth` | 4201 | Autenticación, 2FA, gestión de usuarios |
| `mf_org` | 4202 | Organizaciones |
| `mf_assessment` | 4203 | Evaluaciones |
| **`mf_evidence`** | **4204** | **Contexto de evaluación, archivos adjuntos y levantamiento documental** |
| `mf_reports` | 4205 | Reportes |

Esta relación está documentada en `MSPI_NVA_CO_MR_FRONT/docs/README.md`, índice general del frontend que enlaza a la documentación propia de cada microfrontend en su carpeta `docs/`.

`mf_evidence` es el microfrontend responsable de dos historias de usuario del proceso de evaluación MSPI, según `docs/DESCRIPCION.md`:

1. **Contexto de la evaluación (HU-CFG-03 / HU-CFG-04):** misión, análisis de contexto, mapa de procesos, organigrama y autopercepción (preocupación principal, madurez declarada, componente PHVA débil), con adjuntos documentales.
2. **Levantamiento documental:** un inventario de **43 ítems de entrega** (documentos requeridos), cada uno con estado (`entregado`/`parcial`/`no entregado`), nombre del documento entregado y archivo adjunto; el ítem 43 corresponde específicamente a una **métrica de alcance de procesos** (total de procesos vs. procesos en alcance).

`mf_evidence` **solo se carga en el shell cuando existe una evaluación activa** (clave `active_assessment_id` en `localStorage`, sincronizada desde `mf_assessment`); en su ausencia, la pantalla raíz de `mf_evidence` muestra un aviso y no permite continuar.

## 2. Alcance del microfrontend

### 2.1 Incluido en el alcance de `mf_evidence`

- Pantalla de **inicio** (`/`) que redirige automáticamente al contexto de la evaluación activa, o muestra un aviso si no hay evaluación activa.
- Pantalla de **contexto de evaluación** (`/assessments/:assessmentId/context`): formulario de misión, análisis de contexto, mapa de procesos, organigrama y autopercepción, con `GET`/`PATCH` contra el backend, y subida/listado/descarga de archivos adjuntos de tipo `CONTEXT` (campos `MISSION` y `CONTEXT`).
- Pantalla de **levantamiento documental** (`/assessments/:assessmentId/inventory`): tabla de 43 ítems de entrega con edición de estado y nombre entregado, subida de archivo por fila (`LIFTING_DOC`), y edición de la métrica de alcance de procesos (ítem 43: total de procesos / procesos en alcance / cobertura calculada).
- Componente reutilizable de **navegación de flujo** (`evidence-flow-nav`): indicador de paso (1 de 2 / 2 de 2), botones "Volver"/"Siguiente" y salida hacia el shell (`/evaluations`).
- Componente reutilizable de **carga de archivos** (`file-uploader`): zona de arrastrar-y-soltar y selector de archivo tradicional.
- **Descarga de archivos** vía `FileDownloadService` (blob → enlace temporal `<a download>`).
- Integración con el shell vía **bridge de sesión JWT** (`installAuthParentBridge`, compartido conceptualmente con `mf_auth`) y **bridge de navegación** propio (`openShellRoute`, hacia `/evaluations`).
- Modo **mock** (sin backend, con datos en memoria) y modo **API real** (`ms_evidence`, puerto 8086), seleccionables por configuración de build de Angular.

### 2.2 Fuera del alcance de `mf_evidence`

- La **creación y gestión de evaluaciones** propiamente dicha — es responsabilidad de `mf_assessment`; `mf_evidence` solo lee la evaluación activa (`assessmentId` de la ruta y `active_assessment_id` de `localStorage`).
- La **autenticación y emisión del JWT** — reside en `mf_auth`/`ms_iam`; `mf_evidence` solo consume la sesión ya emitida (lectura de `auth_session` en `localStorage`/cookie y recepción vía `postMessage`).
- La **generación de reportes** a partir de las evidencias recolectadas (`REPORT_OUTPUT` como tipo de relación de archivo aparece en el dominio, pero no hay pantalla ni caso de uso en `mf_evidence` que genere o liste ese tipo de archivo) — es responsabilidad de `mf_reports`, según `docs/DIAGRAMAS.md`.
- La lógica de negocio del backend `ms_evidence` (persistencia, versión optimista, validación de tamaño/tipo de archivo) — reside en el backend; `mf_evidence` solo la consume vía HTTP.

## 3. Objetivos

### 3.1 Objetivo general

Proveer un microfrontend Angular independiente y desplegable de forma aislada que resuelva la captura del contexto de una evaluación MSPI y el levantamiento de las evidencias documentales asociadas, integrándose con el shell y con la sesión de autenticación sin acoplamiento de código en tiempo de compilación.

### 3.2 Objetivos específicos

1. Implementar el formulario de contexto de evaluación (misión, análisis de contexto, mapa de procesos, organigrama, autopercepción) con persistencia incremental vía `PATCH`.
2. Implementar el inventario de 43 ítems de levantamiento documental con edición de estado de entrega, nombre del documento y adjunto por ítem.
3. Implementar la métrica de alcance de procesos (ítem 43) con cálculo de cobertura y alerta cuando los procesos en alcance superan el total declarado.
4. Proveer una experiencia de carga de archivos uniforme (arrastrar-y-soltar o selección) reutilizable entre contexto y levantamiento.
5. Aislar la lógica de acceso a datos de la UI mediante una organización en capas (dominio / aplicación / infraestructura / presentación), de forma que el origen de datos (mock o API real) sea intercambiable sin tocar componentes de presentación.
6. Integrar el microfrontend con el shell mediante composición en navegador (iframe, `postMessage`, `localStorage`), reutilizando la sesión emitida por `mf_auth` y comunicando la evaluación activa a `mf_shell`.
7. Permitir el despliegue en contenedor Docker con Nginx, homogéneo con el resto de microfrontends del ecosistema MSPI.

## 4. Requerimientos iniciales (alto nivel)

- El microfrontend debe poder ejecutarse **de forma independiente** en el puerto 4204 (`ng serve`), tanto en modo mock como contra `ms_evidence` real.
- Debe integrarse con `mf_shell` sin que este dependa de artefactos de build de `mf_evidence` (no hay *remotes/exposes* de Module Federation — ver hallazgo detallado en `03-Diseno.md`).
- Debe funcionar únicamente en el contexto de una evaluación activa: sin `assessmentId` en la ruta o sin `active_assessment_id` en `localStorage`, la pantalla de inicio debe informar la ausencia de evaluación en vez de fallar silenciosamente.
- Debe soportar el flujo secuencial de dos pasos (contexto → levantamiento) con navegación bidireccional y salida hacia el listado de evaluaciones del shell.
- Debe reutilizar la sesión JWT establecida por `mf_auth` (mismo mecanismo de clave `auth_session` en `localStorage`/cookie) para autenticar las llamadas a `ms_evidence`.

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

**Observaciones:**

- No existen dependencias de terceros más allá del framework Angular y RxJS: no hay librería de gestión de estado (NgRx/Akita), ni componentes de UI de terceros (Material, PrimeNG), ni librerías de manejo de formularios distintas a `@angular/forms`. Toda la interfaz (formularios, tabla, dropzone) está implementada con HTML/CSS y Angular puro.
- No se encontró configuración de **Module Federation de Webpack** (`@angular-architects/module-federation`, `webpack.config.js`, `federation.config.js` ausentes en el repositorio). La integración con el shell se realiza por **composición en tiempo de ejecución vía navegador** (iframe, `postMessage`, `localStorage` compartido), no por federación de módulos JavaScript — detallado en `03-Diseno.md`.
- A diferencia de `mf_auth`, el repositorio de `mf_evidence` **no contiene artefactos de una plantilla previa** (React/Vite u otra); el árbol `src/` corresponde en su totalidad a la aplicación Angular real.

## 6. Restricciones y supuestos

- El backend de evidencias (`ms_evidence`) debe estar disponible en `http://localhost:8086` para el modo API; en su ausencia, el proyecto puede ejecutarse con `environment.useMocks = true` (configuración por defecto).
- El shell (`mf_shell`) se asume corriendo en `http://localhost:4200`/`http://127.0.0.1:4200` — estos orígenes están hardcodeados como destino de `postMessage` (`installAuthParentBridge`, `openShellRoute`) y como origen permitido para iframes (`Content-Security-Policy: frame-ancestors` en `deployment/nginx.conf`).
- `mf_evidence` depende de que exista una evaluación activa gestionada por `mf_assessment` (`active_assessment_id` en `localStorage`); no crea ni selecciona evaluaciones por sí mismo.
- La sesión de autenticación (`auth_session`) se asume ya emitida por `mf_auth`; `mf_evidence` no tiene pantalla de login propia, solo lee y reenvía la solicitud de sesión al padre (`window.parent`) cuando está embebido en iframe.
- No se encontró documentación ni configuración de CI/CD dentro del repositorio de `mf_evidence` (no hay carpeta `.github/workflows` ni pipeline visible en el microfrontend).

## 7. Recursos y planificación

### 7.1 Recursos identificados en el repositorio

- Código fuente Angular real: `src/app/**` (dominio, aplicación, infraestructura, presentación) — 21 archivos TypeScript en `src/app`.
- Documentación técnica preexistente en `mf_evidence/docs/` (8 documentos Markdown, muy concisos), tomada como fuente primaria para esta documentación de tesis.
- Infraestructura de despliegue propia: `deployment/Dockerfile`, `deployment/nginx.conf`.
- Infraestructura de despliegue compartida a nivel de repositorio frontend: `MSPI_NVA_CO_MR_FRONT/deployment/docker/Dockerfile.angular` (plantilla genérica parametrizable) y `MSPI_NVA_CO_MR_FRONT/deployment/nginx/spa.conf`.
- Carpeta `public/` prácticamente vacía (solo `.gitkeep`): no hay logo ni activos gráficos propios del microfrontend.

### 7.2 Plan de trabajo inferido (por evidencia de código, no por bitácora explícita)

No existe en el repositorio un backlog, roadmap o bitácora de sprints formal para `mf_evidence`. La planificación documentada aquí se reconstruye a partir de la evidencia funcional del código y de la documentación en `docs/`, siguiendo el orden natural de dependencia funcional:

1. **Base del microfrontend**: bootstrap Angular standalone (`main.ts`, `app.config.ts`, `app.routes.ts`), configuración de entornos (mock/API).
2. **Dominio de evidencias**: `EvidenceRepository` (contrato abstracto), tipos (`AssessmentContext`, `LiftingDelivery`, `ProcessScopeMetric`, `EvidenceFileMetadata`).
3. **Casos de uso**: `GetContextUseCase`, `PatchContextUseCase`, `GetLiftingDeliveriesUseCase`, `PatchLiftingDeliveryUseCase`, `GetProcessScopeMetricUseCase`, `PatchProcessScopeMetricUseCase`, `UploadEvidenceFileUseCase`, `ListEvidenceFilesUseCase`, y el servicio `FileDownloadService`.
4. **Infraestructura**: `ApiEvidenceRepository` (HTTP contra `ms_evidence`), `MockEvidenceRepository` (datos en memoria, incluida la generación de 43 entregas simuladas), `apiInterceptor`, bridges de sesión y de navegación al shell.
5. **Presentación**: `EvidenceHomePageComponent`, `ContextPageComponent`, `InventoryPageComponent`, y los componentes reutilizables `EvidenceFlowNavComponent` y `FileUploaderComponent`.
6. **Empaquetado y despliegue**: Dockerfile propio + Nginx.
7. **Documentación técnica** (`docs/*.md`), generada como parte del proyecto.

Declaración explícita de limitación: **no hay evidencia en el repositorio de control de versiones semántico por hitos, ni de un archivo `CHANGELOG.md`, ni de tickets/historias de usuario formales fuera de las referencias HU-CFG-03/04 embebidas en el código**; el archivo `package.json` fija `"version": "1.0.0"` de forma estática.

## 8. Riesgos identificados

| Riesgo | Evidencia | Impacto |
|---|---|---|
| Ausencia total de pruebas automatizadas | No existen archivos `*.spec.ts` ni configuración Karma/Jest (ver `05-Pruebas.md`) | Riesgo de regresiones no detectadas, especialmente en flujos de carga/descarga de archivos |
| Dependencia estricta de `active_assessment_id` en `localStorage` sin validación de pertenencia/permisos en el propio microfrontend | `EvidenceHomePageComponent.ngOnInit()` navega directamente con el valor leído, sin verificar que la evaluación exista o sea accesible para el usuario actual | Posible navegación a una evaluación inexistente o no autorizada si el valor queda desincronizado |
| Hardcodeo de URLs del shell (`localhost:4200`) en código de producción | `auth-parent-bridge.ts`, `shell-bridge.ts`, `deployment/nginx.conf` | Rigidez para despliegues en otros dominios/ambientes |
| Ítem 43 (métrica de procesos) modelado como caso especial dentro del mismo flujo tabular de levantamiento | `InventoryPageComponent` combina la tarjeta de métrica y la tabla de 43 entregas en una sola pantalla, sin una relación explícita en el modelo de datos entre el ítem 43 y `ProcessScopeMetric` | Posible confusión de mantenimiento si se requiere desacoplar la métrica del listado de entregas |
| Sin manejo de control de concurrencia visible en UI pese a que el dominio expone `version` | `AssessmentContext.version` y `LiftingDelivery.version` existen en los tipos pero no se usan en las páginas para detectar ediciones concurrentes | Posible pérdida de cambios si dos usuarios editan la misma evaluación simultáneamente |

Estos hallazgos se retoman con mayor detalle en `03-Diseno.md`, `04-Desarrollo.md` y `07-Mantenimiento.md`.
