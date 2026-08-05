# mf_reports — Planificación

**Repositorio:** `MSPI_NVA_CO_MR_FRONT/mf_reports`
**Fecha del documento:** 2026-08-18
**Alcance:** Fase de planificación del microfrontend de reportes (`mf_reports`), componente del ecosistema **MSPI** (sistema de gestión de seguridad de la información alineado a ISO 27001), construido bajo una arquitectura de microfrontends Angular.

---

## 1. Contexto del proyecto

MSPI es una plataforma web compuesta por un **shell** anfitrión (`mf_shell`, puerto **4200**) y varios microfrontends independientes que se despliegan y ejecutan como aplicaciones Angular separadas:

| Microfrontend | Puerto | Responsabilidad |
|---|---|---|
| `mf_shell` | 4200 | Host / navegación / dashboard |
| `mf_auth` | 4201 | Autenticación, 2FA, gestión de usuarios |
| `mf_org` | 4202 | Organizaciones |
| `mf_assessment` | 4203 | Evaluaciones |
| `mf_evidence` | 4204 | Evidencias |
| **`mf_reports`** | **4205** | **Diagnóstico consolidado y exportación de reportes de cumplimiento** |

Esta relación está documentada en `MSPI_NVA_CO_MR_FRONT/docs/README.md`, índice general del frontend, que enlaza a la documentación propia de cada microfrontend en su carpeta `docs/`.

`mf_reports` es el módulo de **cierre del ciclo de cumplimiento**: consume los resultados de una evaluación ya diligenciada en `mf_assessment` (backend `ms_assessment`, puerto 8084), los presenta como un **tablero de diagnóstico visual** (portada ISO, ciclo PHVA, madurez, NIST CSF, listado de brechas) y permite **generar y descargar** ese diagnóstico como reporte PDF o Excel mediante trabajos asíncronos (*jobs*) creados en el backend `ms_reporting` (puerto 8087).

## 2. Alcance del microfrontend

### 2.1 Incluido en el alcance de `mf_reports`

- Pantalla de **inicio** (`/reports`): detecta si hay una evaluación activa (`active_assessment_id` en `localStorage`) y ofrece abrir su diagnóstico, o un modo demo (`mock-assessment-1`) si no la hay.
- Pantalla de **diagnóstico consolidado** (`/assessments/:id/dashboard`): agrega y visualiza portada ISO (dominios A.5–A.18), ciclo PHVA (Planificar-Hacer-Verificar-Actuar), matriz de madurez, funciones NIST CSF y listado de brechas (*gaps*) por debajo de un umbral.
- Pantalla de **exportación de reportes** (`/assessments/:id/export`): permite solicitar la generación asíncrona de 4 tipos de reporte (PDF diagnóstico, Excel instrumento, PDF de brechas, Excel de brechas), hacer *polling* del estado del *job* y descargar el archivo binario resultante al completarse.
- Tipos de reporte soportados: `FULL_DIAGNOSTIC_PDF`, `EXCEL_INSTRUMENT_EXPORT`, `GAP_LIST_PDF`, `GAP_LIST_XLSX`, y los comparativos `COMPARATIVE_DIAGNOSTIC_PDF` / `COMPARATIVE_DIAGNOSTIC_XLSX` (soportados a nivel de dominio/infraestructura, sin pantalla propia — ver `03-Diseno.md`).
- Sincronización de sesión de autenticación recibida desde el shell vía `postMessage` (`installAuthParentBridge`).
- Modo **mock** (sin backend, con simulación de progreso de *job* por `setTimeout`) y modo **API real**, seleccionables por configuración de build de Angular.

### 2.2 Fuera del alcance de `mf_reports`

- El **diligenciamiento de la evaluación** (preguntas, evidencias, puntajes por control) — responsabilidad de `mf_assessment`; `mf_reports` únicamente **lee** los resultados ya calculados vía `GET /assessments/{id}/diagnostic/dashboard` y `GET /assessments/{id}/gaps` de `ms_assessment`.
- La **generación del archivo binario** (renderizado del PDF/Excel) — ocurre en el backend `ms_reporting`; el microfrontend solo crea el *job*, hace *polling* de su estado y descarga el resultado.
- El **archivado de evidencias** — el campo `outputFileId` del *job* indica que `ms_reporting` archiva una copia en `ms_evidence` de forma servidor-a-servidor; esto es puramente informativo para el usuario del microfrontend, que no lo usa para descargar.
- La **autenticación** propiamente dicha (login, 2FA, emisión de token) — responsabilidad de `mf_auth`; `mf_reports` solo consume la sesión ya emitida.

## 3. Objetivos

### 3.1 Objetivo general

Proveer un microfrontend Angular independiente y desplegable de forma aislada que consolide visualmente el resultado de una evaluación de cumplimiento MSPI y permita exportarlo en formatos PDF y Excel mediante generación asíncrona, integrándose con el shell sin acoplamiento de código en tiempo de compilación.

### 3.2 Objetivos específicos

1. Agregar en un único tablero información proveniente de dos fuentes del backend `ms_assessment` (`diagnostic/dashboard` y `gaps`) más metadatos de la evaluación, normalizando las variantes de forma de respuesta observadas en el API mediante un mapeador dedicado (`reporting-diagnostic.mapper.ts`).
2. Implementar el flujo de exportación asíncrona (crear *job* → *polling* de estado → descarga) tolerando los estados `PENDING`, `RUNNING`, `COMPLETED`, `FAILED` y `CANCELLED`, con un tiempo máximo de espera de 5 minutos.
3. Garantizar que el nombre y la extensión del archivo descargado sean correctos incluso cuando el backend no informe `Content-Disposition`, mediante un resolutor de nombre de archivo con reglas explícitas por tipo de reporte (`report-filename.util.ts`).
4. Aislar la lógica de negocio de la infraestructura HTTP mediante una organización en capas (dominio / aplicación / infraestructura / presentación), de forma que el origen de datos (mock o API real) sea intercambiable sin tocar componentes de UI.
5. Sincronizar la sesión de autenticación emitida por `mf_auth`/`mf_shell` sin backend de sesión compartido, mediante `postMessage` y `localStorage`.
6. Permitir el despliegue en contenedor Docker con Nginx, homogéneo con el resto de microfrontends del ecosistema MSPI.

## 4. Requerimientos iniciales (alto nivel)

- El microfrontend debe poder ejecutarse **de forma independiente** en el puerto 4205 (`ng serve`), tanto en modo mock (`useMocks: true`, configuración `development`, por defecto) como contra `ms_reporting`/`ms_assessment` reales (`ng serve --configuration=api`).
- Debe integrarse con `mf_shell` mediante **iframe**: la ruta `/reports` del shell embebe `http://localhost:4205/assessments/{id}/dashboard` (ver `docs/INTEGRACION-SHELL.md` del propio repositorio).
- Debe funcionar correctamente aun cuando el usuario no tenga una evaluación activa (pantalla de inicio con mensaje informativo y acceso a modo demo).
- Debe reflejar en la interfaz el progreso de generación del reporte (`progressPct`) y manejar el error documentado de backend en el que un *job* fallido puede llegar envuelto en la estructura `CorrectResponse` (Jackson en `ms_reporting`) en lugar de un error plano.
- Debe forzar la extensión de archivo correcta para `EXCEL_INSTRUMENT_EXPORT` (`.xlsx`), dado que su nombre de tipo no termina en `_XLSX` como los demás tipos Excel.

## 5. Stack tecnológico (verificado en `package.json` y `angular.json`)

| Categoría | Tecnología | Versión |
|---|---|---|
| Framework | Angular (`@angular/core`, `@angular/common`, `@angular/forms`, `@angular/router`, `@angular/platform-browser*`) | `^19.0.0` |
| Animaciones | `@angular/animations` | `^19.0.0` |
| Reactividad | `rxjs` | `~7.8.0` |
| Runtime Angular | `zone.js` | `~0.15.0` |
| CLI / build | `@angular/cli`, `@angular-devkit/build-angular` (builder `application`) | `^19.0.0` |
| Compilador | `@angular/compiler-cli`, `typescript` | `~5.6.0` |
| Lenguaje | TypeScript, modo `strict` (`noImplicitOverride`, `noPropertyAccessFromIndexSignature`, `noImplicitReturns`, `noFallthroughCasesInSwitch`) | `~5.6.0` |
| Contenedor | Node 22-alpine (build) + Nginx 1.27-alpine (runtime) | — |

**Nota importante:** el proyecto **no usa Module Federation de Webpack** (no existe `@angular-architects/module-federation` en `package.json`, ni `webpack.config.js` ni `federation.config.js` en el repositorio). La integración con el shell se realiza por **composición en tiempo de ejecución vía navegador** (iframe embebido desde `mf_shell`, `postMessage` para la sesión, `localStorage` para `active_assessment_id`), no por federación de módulos JavaScript. A diferencia de otros MF del ecosistema (p. ej. `mf_auth`), `mf_reports` **no** tiene dependencias de librerías de UI adicionales (no usa `qrcode` ni ninguna librería de gráficos/tablas de terceros): las barras de progreso, tablas y tarjetas del tablero están implementadas con HTML/CSS puro dentro de cada componente standalone.

`package.json` no define script `test`, ni dependencias de testing (`karma`, `jasmine`, `jest`), ver detalle en `05-Pruebas.md`.

## 6. Restricciones y supuestos

- El backend de reportes (`ms_reporting`) debe estar disponible en `http://localhost:8087` para el modo API; en su ausencia, el proyecto puede ejecutarse con `environment.useMocks = true` (configuración `development`, por defecto de `ng serve`).
- El backend de evaluaciones (`ms_assessment`) debe estar en `http://localhost:8084` para obtener el tablero de diagnóstico, las brechas y los metadatos de la evaluación (nombre, organización) en modo API.
- El shell (`mf_shell`) se asume corriendo en `http://localhost:4200`/`http://127.0.0.1:4200` — estos orígenes están hardcodeados como lista blanca de `postMessage` (`installAuthParentBridge`) y como origen permitido para iframes (`Content-Security-Policy: frame-ancestors` en `deployment/nginx.conf`).
- La sesión de autenticación se lee de `localStorage`/`sessionStorage`/cookie bajo la clave `auth_session`, y se actualiza cuando el shell la reenvía por `postMessage` — el propio microfrontend no gestiona login ni renovación de token, delega en `mf_auth`.
- No se encontró documentación ni configuración de CI/CD dentro del repositorio de `mf_reports` (no hay carpeta `.github/workflows` ni pipeline visible en el microfrontend).
- El único activo estático en `public/` es un archivo `.gitkeep`; no hay logo, favicon personalizado ni imágenes propias del microfrontend.

## 7. Recursos y planificación

### 7.1 Recursos identificados en el repositorio

- Código fuente Angular real: `src/app/**` (dominio, aplicación, infraestructura, presentación) — 17 archivos TypeScript en total.
- Documentación técnica preexistente en `mf_reports/docs/` (8 documentos Markdown, de extensión breve — entre 4 y 36 líneas cada uno), tomada como fuente primaria de esta documentación de tesis y ampliada aquí con verificación directa del código fuente.
- Infraestructura de despliegue propia: `deployment/Dockerfile`, `deployment/nginx.conf`.
- Infraestructura de despliegue compartida a nivel de repositorio frontend: `MSPI_NVA_CO_MR_FRONT/deployment/docker/Dockerfile.angular` (plantilla genérica parametrizable por `MF_NAME`/`DIST_FOLDER`) y `MSPI_NVA_CO_MR_FRONT/deployment/nginx/spa.conf` (equivalente genérico al `nginx.conf` propio del MF).
- `README.md` de la raíz del repositorio: contiene el texto genérico de plantilla de Bitbucket ("Edit a file, create a new file, and clone from Bitbucket…"), sin contenido específico de `mf_reports` — se declara explícitamente como hallazgo, no se inventa contenido que no existe.

### 7.2 Plan de trabajo inferido (por evidencia de código, no por bitácora explícita)

No existe en el repositorio un backlog, roadmap o bitácora de sprints formal para `mf_reports`. La planificación documentada aquí se reconstruye a partir de la evidencia funcional del código y de la documentación en `docs/`, siguiendo el orden natural de dependencia funcional:

1. **Base del microfrontend**: bootstrap Angular standalone (`main.ts`, `app.config.ts`, `app.routes.ts`), configuración de entornos (`environment.ts` mock / `environment.api.ts` real).
2. **Dominio de reportes**: contrato `ReportingRepository` y tipos (`reporting.types.ts`) alineados con el OpenAPI de `ms_reporting` y el tablero de `ms_assessment`.
3. **Casos de uso**: `GetDiagnosticDashboardUseCase`, `GetGapsUseCase`, `CreateReportJobUseCase`, `GetReportJobUseCase`, `DownloadReportUseCase` (`reporting.use-cases.ts`), y el servicio de descarga de archivo (`ReportDownloadService`).
4. **Infraestructura mock**: `MockReportingRepository`, con tablero de ejemplo fijo y simulación de progreso de *job* (`PENDING` → `RUNNING` a los 500 ms → `COMPLETED` a los 2000 ms).
5. **Infraestructura real**: `ApiReportingRepository` (llamadas HTTP a `ms_reporting`/`ms_assessment`), mapeador de tablero (`reporting-diagnostic.mapper.ts`), utilidades de nombre de archivo y manejo de errores de descarga binaria (`report-filename.util.ts`, `report-download.helper.ts`).
6. **Presentación**: `ReportsHomePageComponent`, `DiagnosticDashboardPageComponent`, `ReportsExportPageComponent`.
7. **Integración shell**: puente de sesión (`auth-parent-bridge.ts`), interceptor HTTP (`api.interceptor.ts`).
8. **Empaquetado y despliegue**: Dockerfile propio + Nginx con cabecera CSP para embeberse en el shell.
9. **Documentación técnica** (`docs/*.md`), generada como parte del proyecto, con el contenido mínimo de referencia rápida.

Declaración explícita de limitación: **no hay evidencia en el repositorio de control de versiones semántico por hitos, ni de un archivo `CHANGELOG.md`, ni de tickets/historias de usuario formales**; el archivo `package.json` fija `"version": "1.0.0"` de forma estática.

## 8. Riesgos identificados

| Riesgo | Evidencia | Impacto |
|---|---|---|
| Error conocido de backend documentado por el propio equipo | `docs/FLUJOS.md`: "Si el job falla con `CorrectResponse` (Jackson en ms_reporting), el front muestra `job.errorMessage` — requiere fix en backend" | El mensaje de error mostrado al usuario puede ser incorrecto o incompleto mientras no se corrija en `ms_reporting` |
| Ausencia total de pruebas automatizadas | No existen archivos `*.spec.ts` ni configuración Karma/Jest (ver `05-Pruebas.md`) | Riesgo de regresiones no detectadas, especialmente en la lógica de resolución de nombre de archivo y en el mapeador de tablero, que manejan múltiples variantes de forma de respuesta del backend |
| Hardcodeo de URLs de shell y backends (`localhost:4200`, `:8084`, `:8087`) en código de producción | `environment.api.ts`, `auth-parent-bridge.ts`, `nginx.conf` | Rigidez para despliegues en otros dominios/ambientes; requiere reemplazo manual por variables de entorno o `fileReplacements` adicionales |
| Dependencia de `ms_assessment` para tres llamadas por carga de tablero (`diagnostic/dashboard`, `gaps`, metadatos de evaluación) sin *caching* | `api-reporting.repository.ts`, método `getDiagnosticDashboard` | Latencia acumulada en la carga del tablero; posible inconsistencia si los datos cambian entre llamadas |
| `README.md` raíz sin contenido específico del proyecto | Texto de plantilla Bitbucket genérica | Onboarding deficiente para nuevos desarrolladores que solo consulten el README raíz en lugar de `docs/` |

Estos hallazgos se retoman con mayor detalle en `03-Diseno.md`, `04-Desarrollo.md` y `07-Mantenimiento.md`.
