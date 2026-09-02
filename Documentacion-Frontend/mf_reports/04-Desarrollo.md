# mf_reports — Desarrollo

**Repositorio:** `MSPI_NVA_CO_MR_FRONT/mf_reports`
**Fecha del documento:** 2026-08-18
**Alcance:** Implementación real del microfrontend: manejo de estado, servicios, componentes, integración con APIs backend y funcionalidades desarrolladas, con referencias directas a archivos y fragmentos de código fuente.

---

## 1. Bootstrap y configuración de la aplicación

`mf_reports` arranca como aplicación **standalone** de Angular 19 (sin `NgModule` raíz):

```typescript
// src/main.ts
bootstrapApplication(AppComponent, appConfig).catch((err) => console.error(err));
```

`app.config.ts` registra tres grupos de *providers*:

1. `provideZoneChangeDetection({ eventCoalescing: true })` — optimización de detección de cambios.
2. `provideRouter(appRoutes)` y `provideHttpClient(withInterceptors([apiInterceptor]))`.
3. La **selección de implementación de repositorio** en tiempo de *build*:

```typescript
{
  provide: ReportingRepository,
  useClass: environment.useMocks ? MockReportingRepository : ApiReportingRepository,
}
```

Esta línea es el punto exacto donde el modo mock/API se decide; no hay lógica adicional de *feature flag* en tiempo de ejecución — el modo se fija en el `environment` importado en tiempo de compilación (ver sección 6).

`AppComponent` (raíz) no renderiza UI propia — solo un `<router-outlet>` — y en `ngOnInit` instala el puente de sesión con el shell:

```typescript
// app.component.ts
ngOnInit(): void {
  installAuthParentBridge(() => this.authSession.reload());
}
```

## 2. Manejo de estado

El manejo de estado de `mf_reports` es **local por componente**, usando **Angular Signals**, sin librería de gestión de estado global (no hay NgRx, Akita ni servicios de estado compartido entre pantallas más allá de `AuthSessionService`).

- **`AuthSessionService`** (único estado verdaderamente compartido/singleton): usa `signal<StoredSession | null>` y expone `token`/`isAuthenticated` como `computed()`. Se recarga (`reload()`) tanto al recibir un mensaje del shell como en cada solicitud HTTP saliente (`api.interceptor.ts` llama `authSession.reload()` antes de leer el token), garantizando que un cambio de sesión detectado por cualquier vía se refleje inmediatamente.
- **`DiagnosticDashboardPageComponent`**: 3 signals — `loading`, `error`, `data` — que gobiernan de forma exhaustiva los 3 estados de UI posibles (cargando / error / datos), usando el bloque `@if/@else if` del template.
- **`ReportsExportPageComponent`**: 4 signals — `busy`, `message`, `isError`, `job` — más dos variables de instancia no reactivas (`pollTimer`, `pollStartedAt`, `autoDownloaded`) que controlan el temporizador de *polling* y evitan doble descarga automática.
- **`ReportsHomePageComponent`**: 1 signal — `assessmentId` — leída de `localStorage` en `ngOnInit`.

No se usa RxJS para el estado de UI (solo internamente en el interceptor y en `ApiReportingRepository.downloadReport`, donde se combinan operadores `switchMap`/`catchError`/`from` para adaptar la llamada HTTP basada en `Observable` a una función que interopera con `async/await` vía `firstValueFrom`).

## 3. Servicios y casos de uso

### 3.1 Casos de uso (`application/reporting/reporting.use-cases.ts`)

Cinco clases `@Injectable({ providedIn: 'root' })`, cada una envolviendo un único método del repositorio:

```typescript
@Injectable({ providedIn: 'root' })
export class CreateReportJobUseCase {
  constructor(private readonly repository: ReportingRepository) {}
  execute(assessmentId: string, req: CreateReportJobRequest) {
    return this.repository.createReportJob(assessmentId, req);
  }
}
```

Este patrón (caso de uso = adaptador delgado sobre el repositorio) es idéntico en los 5 casos (`GetDiagnosticDashboardUseCase`, `GetGapsUseCase`, `CreateReportJobUseCase`, `GetReportJobUseCase`, `DownloadReportUseCase`). Su valor es de **punto de extensión** y de **frontera de test unitario** (aunque, como se documenta en `05-Pruebas.md`, no existen pruebas actualmente).

### 3.2 `ReportDownloadService` (`application/reporting/report-download.service.ts`)

Responsable del efecto secundario de "guardar archivo": crea una URL de objeto temporal (`URL.createObjectURL`), la asigna a un `<a download>` generado en memoria (nunca insertado en el DOM), simula un clic y libera la URL:

```typescript
saveBlob(blob: Blob, filename: string): void {
  const url = URL.createObjectURL(blob);
  const anchor = document.createElement('a');
  anchor.href = url;
  anchor.download = filename;
  anchor.click();
  URL.revokeObjectURL(url);
}
```

El comentario del propio archivo aclara la limitación real: *"El navegador/OS decide la carpeta según configuración del usuario (diálogo 'Guardar como')"* — el microfrontend no controla la ubicación final del archivo, solo dispara el mecanismo nativo del navegador.

## 4. Integración con las APIs backend

### 4.1 `ApiReportingRepository` — `ms_reporting` (8087) y `ms_assessment` (8084)

| Método | Verbo y ruta | Backend |
|---|---|---|
| `getDiagnosticDashboard` | `GET /assessments/{id}/diagnostic/dashboard`, `GET /assessments/{id}/gaps?threshold=60`, `GET /assessments/{id}` (en paralelo) | `ms_assessment` |
| `getGaps` | Reutiliza `getDiagnosticDashboard` si `threshold === 60`; si no, `GET /assessments/{id}/gaps?threshold={n}` | `ms_assessment` |
| `createReportJob` | `POST /reports/jobs` (con posible `GET /assessments/{id}` previo si falta `organizationId`) | `ms_reporting` (+ `ms_assessment`) |
| `createComparativeReportJob` | `POST /reports/comparative/jobs` | `ms_reporting` |
| `getReportJob` | `GET /reports/jobs/{jobId}` | `ms_reporting` |
| `downloadReport` | `GET /reports/jobs/{jobId}/download` (`responseType: 'blob'`, `observe: 'response'`) | `ms_reporting` |

Ejemplo representativo — obtención del tablero con tolerancia a fallo parcial:

```typescript
override async getDiagnosticDashboard(assessmentId: string): Promise<DiagnosticDashboard> {
  const [diagnostic, gaps, assessment] = await Promise.all([
    firstValueFrom(this.http.get(`${this.assessmentBase}/assessments/${assessmentId}/diagnostic/dashboard`)),
    firstValueFrom(this.http.get(`${this.assessmentBase}/assessments/${assessmentId}/gaps`, { params: { threshold: '60' } })),
    firstValueFrom(this.http.get<AssessmentMeta>(`${this.assessmentBase}/assessments/${assessmentId}`))
      .catch(() => ({ id: assessmentId, organizationId: '', name: 'Evaluación MSPI' })),
  ]);
  return mapToReportsDashboard(assessmentId, diagnostic, gaps, assessment);
}
```

El `.catch()` sobre la tercera promesa es deliberado: si `ms_assessment` no puede resolver los metadatos de cabecera (por ejemplo, la evaluación demo `mock-assessment-1` no existe realmente en el backend), el tablero se sigue construyendo con un nombre de reserva en lugar de fallar por completo.

### 4.2 Descarga binaria y manejo de error disfrazado (`report-download.helper.ts`)

El *endpoint* de descarga puede responder de dos formas bajo el mismo `responseType: 'blob'`: el archivo real, o un JSON de error (por ejemplo si el `jobId` no existe o el archivo fue purgado). El código distingue por `Content-Type`:

```typescript
const contentType = res.headers.get('Content-Type') ?? blob.type ?? '';
if (contentType.includes('application/json') || contentType.includes('json')) {
  return parseJsonBlobError(blob);
}
```

`parseJsonBlobError` convierte el `Blob` a texto, lo parsea como JSON con la forma `{ error: [{ message }], meta: { traceId } }` (mismo contrato `CorrectResponse` que el resto del API MSPI) y lanza un `Error` con ese mensaje, adjuntando el `traceId` cuando existe.

### 4.3 Resolución de nombre de archivo (`report-filename.util.ts`)

```typescript
export function resolveReportFilename(
  fromHeader: string | null,
  reportType: ReportType,
  assessmentId: string,
  jobId: string
): string {
  const fallback = fallbackReportFilename(reportType, assessmentId, jobId);
  const dot = fallback.lastIndexOf('.');
  const expectedExt = dot >= 0 ? fallback.slice(dot + 1) : 'pdf';
  const base = fromHeader && fromHeader.includes('.')
    ? fromHeader.slice(0, fromHeader.lastIndexOf('.'))
    : fallback.slice(0, dot >= 0 ? dot : fallback.length);
  return `${base}.${expectedExt}`;
}
```

Nótese que el **nombre base** puede tomarse del header (`fromHeader`) si está presente, pero la **extensión** siempre se recalcula a partir del `reportType` — regla de negocio RN-07 documentada en `02-Analisis.md`.

### 4.4 Normalización del tablero (`reporting-diagnostic.mapper.ts`)

Función pura `mapToReportsDashboard(assessmentId, diagnostic, gaps, assessmentMeta)` que compone 5 sub-mapeadores (`mapDomains`, `mapPhva`, `mapMaturity`, `mapNist`, `mapGaps`), cada uno con múltiples `??` en cascada para tolerar nombres de campo alternativos del backend real. Ejemplo — resolución de puntaje de un dominio ISO, que puede llegar bajo 4 nombres distintos según el punto del ciclo de vida de la evaluación:

```typescript
const score = d.currentScore ?? d.combinedScore ?? d.adminScore ?? d.techScore ?? 0;
```

## 5. Componentes de presentación — funcionalidades desarrolladas

### 5.1 `ReportsHomePageComponent` (`/reports`)

Pantalla mínima de enrutamiento condicional. No llama a ningún backend: solo lee `localStorage.getItem('active_assessment_id')` y decide entre dos botones de acción (`openDashboard()` navega con el id real; `openDemo()` navega con `mock-assessment-1` fijo).

### 5.2 `DiagnosticDashboardPageComponent` (`/assessments/:id/dashboard`)

Funcionalidad de **visualización de reportes**: al iniciar, toma el `id` de la ruta y ejecuta `GetDiagnosticDashboardUseCase.execute(assessmentId)`. Renderiza:

- 4 tarjetas resumen (Portada ISO %, PHVA total %, Nivel de madurez + criticidad, NIST CSF %).
- Tabla de dominios ISO A.5–A.18 con puntaje, etiqueta de banda y conteo de controles.
- Barras de progreso horizontales por componente PHVA (`[style.width.%]="c.cappedL"`), con etiquetas en español (`PHVA_LABELS`: Planificación/Implementación/Evaluación/Mejora).
- Tabla de requisitos de madurez y lista de funciones NIST, en diseño de dos columnas responsivo (colapsa a una columna bajo 720px).
- Tabla de brechas bajo el umbral configurado, con mensaje explícito si no hay brechas.
- Enlace a la pantalla de exportación, propagando `organizationId` como query param.

### 5.3 `ReportsExportPageComponent` (`/assessments/:id/export`)

Funcionalidad de **generación y descarga de reportes**, la más compleja del microfrontend en términos de manejo de estado asíncrono:

- 4 botones de generación (uno por tipo de reporte soportado en UI), deshabilitados mientras `busy()` es verdadero.
- `generate(type)`: crea el *job*, inicia el mensaje de estado y arranca el *polling*.
- `startPoll(jobId)`: usa `setInterval` (2500 ms) más una llamada inmediata (`pollOnce`) para no esperar el primer intervalo.
- `pollOnce(jobId)`: en cada tick, si excede `POLL_TIMEOUT_MS` (5 minutos) corta el *polling* con mensaje de tiempo agotado; si no, consulta el estado y reacciona según el valor (`COMPLETED` dispara descarga automática una única vez vía la bandera `autoDownloaded`; `FAILED`/`CANCELLED` detiene y muestra error; `RUNNING` actualiza el porcentaje).
- Barra de progreso visual (`progress-fill` con `[style.width.%]`) mostrada solo si `busy()` y el *job* reporta `progressPct`.
- `download()`: reutilizable tanto por el flujo automático como por el botón manual "Descargar archivo"; delega en `ReportDownloadService`.

## 6. Configuración de entornos

Dos archivos de entorno, intercambiados por `fileReplacements` en `angular.json`:

```typescript
// src/environments/environment.ts (desarrollo, mock por defecto)
export const environment = {
  useMocks: true,
  msReportingUrl: 'http://localhost:8087',
  msAssessmentUrl: 'http://localhost:8084',
  apiBaseUrl: 'http://localhost:8087',
};
```

```typescript
// src/environments/environment.api.ts (configuración "api", API real)
export const environment = {
  useMocks: false,
  msReportingUrl: 'http://localhost:8087',
  msAssessmentUrl: 'http://localhost:8084',
  shellOrigin: 'http://localhost:4200',
  apiBaseUrl: 'http://localhost:8087',
};
```

Nótese que `shellOrigin` solo está definido en `environment.api.ts` — en modo mock (`environment.ts`) el campo no existe, por lo que `auth-parent-bridge.ts` (que referencia `environment.shellOrigin`) recibe `undefined` en ese modo; el `Set` de orígenes permitidos lo filtra (`.filter(Boolean)`) y continúa funcionando solo con los orígenes `localhost:4200`/`127.0.0.1:4200` fijos en el propio código. Es un detalle de implementación consistente pero no documentado explícitamente en el código.

## 7. Interceptor HTTP — comportamiento exacto

```typescript
export const apiInterceptor: HttpInterceptorFn = (req, next) => {
  const authSession = inject(AuthSessionService);
  authSession.reload();
  const token = authSession.token();
  const authReq = token ? req.clone({ setHeaders: { Authorization: `Bearer ${token}` } }) : req;

  return next(authReq).pipe(
    map((event) => {
      if (!(event instanceof HttpResponse)) return event;
      if (event.body instanceof Blob) return event;                 // no desempaqueta binarios
      const body = event.body as { data?: unknown; meta?: unknown } | null;
      if (body && body.data !== undefined && body.meta) {
        return event.clone({ body: body.data });                    // desempaqueta CorrectResponse
      }
      return event;
    }),
    catchError((err: HttpErrorResponse) => {
      if (err.status === 401) authSession.reload();
      if (err.error instanceof Blob) return throwError(() => err);   // delega a report-download.helper
      const apiError = new ApiError(
        err.status,
        err.error?.error ?? [{ code: 'UNKNOWN', message: err.message }],
        err.error?.meta?.traceId
      );
      return throwError(() => apiError);
    })
  );
};
```

Puntos de diseño verificados en el código:

- El token se relee (`authSession.reload()`) en **cada** solicitud, no una sola vez al arrancar — asegura que un cambio de sesión reciente (por ejemplo, recién notificado por el shell) se aplique de inmediato.
- El desempaquetado de `CorrectResponse` (`{ data, meta }` → `data`) es genérico para toda la aplicación: ningún repositorio necesita desempaquetar manualmente la respuesta.
- Un `401` fuerza una recarga de la sesión (para reflejar una posible expiración detectada por el backend), pero el interceptor **no redirige** ni cierra sesión activamente — esa reacción, si existe, queda fuera del alcance de `mf_reports`.

## 8. Conclusión de la fase de desarrollo

El código fuente implementa íntegramente las 3 pantallas y el flujo de exportación asíncrona descritos en el análisis, con separación de capas consistente y manejo explícito de los casos borde documentados por el propio equipo (`docs/FLUJOS.md`): extensión forzada para Excel, y el error conocido de `CorrectResponse` en fallos de `ms_reporting`. No se identificó código muerto, archivos de plantilla residuales ni dependencias no utilizadas en `package.json`.
