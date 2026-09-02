# mf_evidence — Mantenimiento

**Repositorio:** `MSPI_NVA_CO_MR_FRONT/mf_evidence`
**Fecha del documento:** 2026-08-18
**Alcance:** Lineamientos de mantenimiento correctivo, preventivo y evolutivo, gestión de versiones, monitoreo, manejo de errores en frontend y mejoras futuras evidenciadas para el microfrontend `mf_evidence`.

---

## 1. Gestión de versiones — estado actual

- `package.json` fija `"version": "1.0.0"` de forma estática; no hay evidencia de versionado semántico automatizado (no hay `standard-version`, `semantic-release`, ni scripts de *bump* de versión).
- No existe `CHANGELOG.md` en el repositorio.
- No existe carpeta `.github/workflows` ni ningún otro archivo de integración continua (CI) dentro de `mf_evidence`; no se pudo determinar si el pipeline de CI/CD vive centralizado fuera de este repositorio (`docker-config` u otro), ya que está fuera del alcance analizado.
- El control de versiones del propio repositorio no fue inspeccionado (fuera del alcance de esta tarea: el análisis se limitó al árbol de archivos de `mf_evidence`, sin ejecutar comandos de historial `git log`).

**Recomendación de mantenimiento:** adoptar versionado semántico (`MAJOR.MINOR.PATCH`) ligado a los cambios de contrato con `ms_evidence` (un cambio de forma de DTO como `LiftingDelivery` o `EvidenceFileMetadata` debería ser al menos `MINOR`), y mantener un `CHANGELOG.md` mínimo, dado que este microfrontend depende de un backend propio (`ms_evidence`) y de dos sistemas pares (`mf_shell`, `mf_assessment`) cuya evolución debe coordinarse.

## 2. Mantenimiento correctivo

Lineamientos derivados de los hallazgos de código documentados en `03-Diseno.md` y `04-Desarrollo.md`:

| Hallazgo | Tipo de corrección recomendada | Prioridad sugerida |
|---|---|---|
| `deleteFile()` implementado en dominio e infraestructura pero sin uso en ninguna página | Exponer un botón "Eliminar" en `ContextPageComponent`/`InventoryPageComponent`, o retirar el método si no forma parte del alcance funcional previsto | Media |
| `AssessmentContext.version`/`LiftingDelivery.version` recibidos pero nunca reenviados ni usados para detectar conflictos de edición concurrente | Implementar verificación de versión (optimistic locking) en los `PATCH`, o documentar explícitamente que la app no soporta edición concurrente | Media-Alta (riesgo de pérdida silenciosa de cambios en evaluaciones colaborativas) |
| `FileUploaderComponent.uploading`/`error` (signals) declaradas pero no conectadas al flujo real de subida | Conectar las señales del componente al ciclo real de `UploadEvidenceFileUseCase.execute()` (marcar `uploading` antes/después de la llamada, capturar error localmente) en vez de depender únicamente del signal `message` de la página contenedora | Baja-Media (mejora de cohesión, sin impacto funcional actual) |
| Recarga completa (`await this.load()`) tras cada cambio de estado/nombre entregado en `InventoryPageComponent` | Evaluar actualización optimista local del array `deliveries()` para reducir peticiones HTTP redundantes, especialmente en evaluaciones con edición frecuente | Baja (optimización, no corrección funcional) |
| Sin validación de tipo/tamaño de archivo en `FileUploaderComponent` | Añadir validación en cliente (tamaño máximo, extensiones permitidas) antes de invocar el caso de uso de subida, complementaria a la validación del backend | Media (mejora de experiencia y reduce cargas fallidas tardías) |
| `apiBaseUrl` declarado en `environment.*.ts` sin uso real en el código (solo se usa `msEvidenceUrl`) | Eliminar la variable no usada o documentar su propósito si se reserva para uso futuro | Baja (deuda de claridad) |

## 3. Mantenimiento preventivo

- **Actualizaciones de Angular**: el proyecto fija dependencias con caret (`^19.0.0`), por lo que recibirá automáticamente parches y *minors* de Angular 19 en instalaciones limpias de `npm install`; se recomienda revisar periódicamente las notas de versión de Angular (especialmente cambios en `HttpInterceptorFn`, Signals y el builder `application`, todos usados activamente) y ejecutar `ng update` de forma controlada.
- **Auditoría de dependencias**: no se encontró evidencia de `npm audit` automatizado ni de Dependabot/Renovate configurado en el repositorio; dado que `mf_evidence` maneja carga y descarga de archivos (superficie de ataque sensible: tipos MIME, tamaño, contenido), se recomienda incorporar auditoría de dependencias como parte del mantenimiento preventivo.
- **Revisión de URLs hardcodeadas**: como se documenta en `06-Implementacion-Despliegue.md`, las URLs del shell (`http://localhost:4200`/`http://127.0.0.1:4200`) están embebidas en múltiples archivos (`auth-parent-bridge.ts`, `shell-bridge.ts`, `deployment/nginx.conf`) además de en `environment.shellOrigin`. Cualquier cambio de dominio en un ambiente distinto a local obliga a una revisión coordinada de todos estos puntos; se recomienda que `ALLOWED_PARENTS`/`SHELL_ORIGINS` deriven exclusivamente de `environment.shellOrigin` en vez de mantener literales duplicados junto al valor de configuración.
- **Duplicación de la lógica de sesión entre microfrontends**: `AuthSessionService` y el mecanismo de `postMessage`/`localStorage` están reimplementados de forma equivalente (pero no idéntica) en `mf_auth` y `mf_evidence`. Un cambio en el contrato de sesión (por ejemplo, el nombre de la clave `auth_session` o la forma del payload) debe propagarse manualmente a ambos repositorios; se recomienda evaluar la extracción de una librería compartida (`@mspi/session-bridge` o similar) si el número de microfrontends que consumen sesión sigue creciendo.
- **Revisión del contrato de 43 ítems fijos**: el número de entregas de levantamiento (43) está hardcodeado tanto en el mock (`Array.from({length: 43}, ...)`) como implícitamente asumido por la UI (título "43 ítems + métrica de alcance"); si el catálogo de documentos requeridos cambia en `ms_evidence`, el mock debe actualizarse manualmente para seguir siendo representativo.

## 4. Mantenimiento evolutivo — mejoras futuras evidenciadas en la documentación del repositorio

`docs/` no contiene una sección explícita de "roadmap" o "trabajo futuro", por lo que las siguientes mejoras se infieren de brechas y comentarios encontrados directamente en el código y en la documentación existente, sin inventar alcance no sustentado:

1. **Guards de ruta declarativos** — actualmente ausentes; sería una mejora natural validar la existencia de la evaluación (`assessmentId`) antes de renderizar `ContextPageComponent`/`InventoryPageComponent`, en vez de dejar que cada página falle o muestre datos vacíos ante un id inválido.
2. **Exposición de la eliminación de archivos en la UI** — la capacidad ya existe en dominio e infraestructura (`deleteFile()`), pero no está conectada a ninguna interacción de usuario; es la mejora de menor esfuerzo con mayor cierre de brecha funcional identificada.
3. **Control de concurrencia optimista visible en UI** — aprovechar los campos `version` ya presentes en el dominio para detectar y advertir sobre ediciones concurrentes del mismo contexto o ítem de levantamiento, relevante en un flujo de evaluación potencialmente colaborativo.
4. **Configuración runtime de URLs** (en vez de compilación estática) — necesaria si el ecosistema MSPI se despliega alguna vez fuera de `localhost` con dominios reales por microfrontend, dado que hoy el shell y el backend están hardcodeados tanto en `environment.*.ts` como en los bridges de infraestructura.
5. **Cobertura de pruebas automatizadas** — brecha crítica documentada en `05-Pruebas.md`; de particular importancia en `mf_evidence` por tratarse del módulo que centraliza la evidencia documental de cumplimiento (contexto ISO 27001 de MSPI).
6. **Validación de archivos en cliente** (tipo, tamaño) — actualmente delegada completamente al backend; añadirla en `FileUploaderComponent` mejoraría la experiencia de usuario al fallar más rápido y con mensajes más claros.
7. **Extracción de una librería compartida de integración con el shell** — para eliminar la duplicación de `AuthSessionService`/bridges entre `mf_auth` y `mf_evidence` señalada en la sección 3.

## 5. Monitoreo y logs

No se encontró integración con ninguna herramienta de observabilidad (no hay Sentry, DataDog, Application Insights, ni similares en `package.json`). Los únicos mecanismos de trazabilidad presentes son:

- **`console.error`** en `main.ts` como manejador global de error de arranque (`bootstrapApplication(...).catch((err) => console.error(err))`) — cualquier fallo de bootstrap de Angular solo se refleja en la consola del navegador.
- **`HEALTHCHECK` de Docker** (`curl -f http://127.0.0.1/`) — único mecanismo de monitoreo de disponibilidad, a nivel de infraestructura (verifica que Nginx responde, no verifica la salud funcional de la aplicación ni su conectividad con `ms_evidence`).

**Diferencia frente a `mf_auth`:** a diferencia del interceptor de `mf_auth`, el `apiInterceptor` de `mf_evidence` **no registra** el `traceId` de las respuestas exitosas (`console.debug('[API]', ...)` no está presente en `api.interceptor.ts` de este repositorio); en consecuencia, `mf_evidence` tiene **menos** trazabilidad de cliente que `mf_auth`, incluso careciendo de este único mecanismo básico de correlación con logs de backend.

**Recomendación:** para un módulo que gestiona evidencias documentales de auditoría, la ausencia de registro (ni siquiera en consola) de operaciones sensibles — carga de archivo, cambio de estado de entrega, edición de la métrica de alcance — es una brecha relevante de cara a trazabilidad; actualmente esta trazabilidad, si existe, depende enteramente del backend `ms_evidence` (fuera del alcance de este repositorio).

## 6. Manejo de errores en frontend

Mecanismo observado (ver también `04-Desarrollo.md`):

1. **Nivel HTTP** — `apiInterceptor` normaliza cualquier error de red/HTTP a `ApiError(status, errors[], traceId)`.
2. **Nivel repositorio** — `ApiEvidenceRepository` captura el error de cada llamada `HttpClient` y lo relanza como `ApiError` mediante la función `toApiError()`, reutilizada en los 10 métodos del repositorio vía `.catch(toApiError)`.
3. **Nivel presentación** — cada página captura la excepción en un bloque `try/catch` y muestra `err instanceof Error ? err.message : 'Error al guardar...'` en el signal `message`; **a diferencia de `mf_auth`, no hay traducción de códigos de negocio a mensajes en español** (no existe un equivalente a `errorMessage(code)`) — se muestra el mensaje crudo devuelto por el backend o el mensaje genérico de `ApiError` (`errors[0]?.message ?? 'Error desconocido'`).
4. **Sesión inválida (401)** — se **recarga** (no se limpia) automáticamente en el interceptor (`inject(AuthSessionService).reload()`), dado que `AuthSessionService` de este microfrontend es de solo lectura y no expone un método de limpieza de sesión (ver `04-Desarrollo.md`, sección 1).

No se identificó un **error boundary global** de Angular (`ErrorHandler` personalizado) que capture excepciones no controladas de la aplicación; los `try/catch` están distribuidos método a método dentro de cada página, igual que en `mf_auth`.

## 7. Checklist de mantenimiento recomendado (síntesis)

- [ ] Exponer la eliminación de archivos (`deleteFile()`) en la UI de contexto y levantamiento, o retirar el método si no está en alcance.
- [ ] Definir e implementar una estrategia de control de concurrencia (optimistic locking) aprovechando los campos `version` ya presentes en el dominio.
- [ ] Conectar las señales `uploading`/`error` de `FileUploaderComponent` al flujo real de subida en vez de dejarlas sin uso.
- [ ] Añadir *route guards* que validen la existencia/pertenencia de `assessmentId` antes de renderizar contexto o levantamiento.
- [ ] Externalizar URLs de shell/backend a configuración centralizada, eliminando literales duplicados en `auth-parent-bridge.ts`/`shell-bridge.ts`.
- [ ] Incorporar framework de pruebas (Karma/Jasmine o alternativa) y cobertura mínima sobre el cálculo de cobertura de procesos, `MockEvidenceRepository` y `apiInterceptor`.
- [ ] Añadir validación de tipo/tamaño de archivo en `FileUploaderComponent`.
- [ ] Evaluar extracción de una librería compartida de sesión/bridge entre microfrontends para eliminar duplicación con `mf_auth`.
- [ ] Retirar o documentar el uso previsto de la variable `apiBaseUrl` no utilizada en `environment.*.ts`.
- [ ] Definir estrategia de versionado semántico y `CHANGELOG.md`.
- [ ] Evaluar instrumentación de logs/observabilidad centralizada acorde al contexto ISO 27001 de MSPI, especialmente para operaciones de carga/descarga y cambio de estado de evidencias.
