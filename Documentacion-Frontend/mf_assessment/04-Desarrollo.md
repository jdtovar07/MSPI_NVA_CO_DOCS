# mf_assessment — Desarrollo

**Repositorio:** `MSPI_NVA_CO_MR_FRONT/mf_assessment`
**Fecha del documento:** 2026-08-18
**Alcance:** Fase de desarrollo/implementación del microfrontend de evaluaciones de madurez (`mf_assessment`), con evidencia directa de código fuente real (`src/app/**`).

---

## 1. Bootstrap de la aplicación

`src/main.ts` arranca un componente standalone (`AppComponent`) con la configuración centralizada en `app.config.ts` (ver `03-Diseno.md`, sección 2). `AppComponent` (`app.component.ts`) es intencionalmente mínimo: solo monta el `<router-outlet>` e instala el puente de autenticación al iniciar:

```typescript
export class AppComponent implements OnInit {
  constructor(private readonly authSession: AuthSessionService) {}

  ngOnInit(): void {
    installAuthParentBridge(() => this.authSession.reload());
  }
}
```

Esto garantiza que, en cuanto el microfrontend se monta dentro del iframe del shell, solicita inmediatamente la sesión (`MSPI_AUTH_REQUEST`) y queda escuchando la respuesta (`MSPI_AUTH_SESSION`) durante todo el ciclo de vida de la aplicación.

## 2. Enrutamiento

`app.routes.ts` define 10 rutas, todas con **lazy loading por componente** (`loadComponent`), sin módulos NgModule. Puntos relevantes verificados en el código:

- La ruta raíz (`''`) redirige a `/evaluations` (`redirectTo`, `pathMatch: 'full'`).
- Las rutas `/controls/admin` y `/controls/tech` cargan el **mismo componente** (`ControlsPageComponent`), diferenciado en tiempo de ejecución por el segmento de la URL (parámetro leído dentro del componente, no por `data` de ruta ni `resolve`).
- Cualquier ruta no reconocida (`**`) redirige a `/evaluations`.
- No se usan *guards* (`CanActivate`/`CanMatch`): el control de acceso por rol no está implementado a nivel de router en este microfrontend.

## 3. Modelo de dominio

`domain/assessment.types.ts` (326 líneas) concentra todo el modelo funcional en tipos e interfaces TypeScript puros, sin dependencias de Angular ni de HTTP. Los tipos discriminados clave son:

```typescript
export type AssessmentStatus = 'BORRADOR' | 'EN_DILIGENCIAMIENTO' | 'PUBLICADO';
export type ControlType = 'ADMIN' | 'TECH';
export type PhvaComponent = 'PLAN' | 'DO' | 'CHECK' | 'ACT';
export type ScoreStatus = 'PENDING' | 'SCORED' | 'NA';
export const RATING_SCALE_VALUES = [0, 20, 40, 60, 80, 100] as const;
```

Interfaces principales: `Assessment`, `ControlScore`, `RollupNode` (árbol recursivo con `children?: RollupNode[]`), `PhvaItem`/`PhvaSummary`, `MaturityRequirement`/`MaturitySummary`/`MaturityMatrixRow`, `NistCiberItem`/`NistSummary`, `AssessmentArea`/`AssessmentAreaTopic`, `ControlSteward`, y los DTO de request (`CreateAssessmentRequest`, `PatchControlScoreRequest`, `PatchControlStewardRequest`, etc.).

## 4. Casos de uso: patrón implementado

Cada caso de uso sigue el mismo patrón mínimo — una clase inyectable con un único método `execute()` que delega en el repositorio de dominio:

```typescript
@Injectable({ providedIn: 'root' })
export class GetRollupUseCase {
  constructor(private readonly repository: AssessmentRepository) {}
  execute(assessmentId: string, controlType: ControlType): Promise<RollupNode[]> {
    return this.repository.getRollup(assessmentId, controlType);
  }
}
```

Este patrón se repite de forma consistente en `assessment.use-cases.ts`, `control.use-cases.ts` y `score-modules.use-cases.ts` (17 clases de caso de uso en total contadas en el código), lo que facilita el testeo unitario por mock del repositorio (aunque, como se documenta en `05-Pruebas.md`, no existen pruebas escritas).

La excepción es `AssignEntityOrderTypeUseCase`, que añade manejo de concurrencia:

```typescript
@Injectable({ providedIn: 'root' })
export class AssignEntityOrderTypeUseCase {
  constructor(
    private readonly repository: AssessmentRepository,
    private readonly assessmentState: AssessmentStateService
  ) {}
  execute(id: string, code: string, rowVersion: number) {
    return runWithRowVersionConflict(id, this.repository, this.assessmentState, () =>
      this.repository.assignEntityOrderType(id, code, rowVersion)
    );
  }
}
```

## 5. Manejo de estado con Angular Signals

`AssessmentStateService` es el ejemplo más claro de estado reactivo con signals en el proyecto:

```typescript
@Injectable({ providedIn: 'root' })
export class AssessmentStateService {
  private readonly assessmentSignal = signal<Assessment | null>(null);
  readonly assessment = this.assessmentSignal.asReadonly();
  readonly rowVersion = computed(() => this.assessmentSignal()?.rowVersion ?? 0);

  setAssessment(assessment: Assessment | null): void {
    this.assessmentSignal.set(assessment);
    if (assessment?.id) {
      localStorage.setItem('active_assessment_id', assessment.id);
      syncActiveAssessmentToShell(assessment.id);
    }
  }
  clear(): void { this.assessmentSignal.set(null); }
}
```

Cada vez que se fija una evaluación (creación, recarga tras conflicto de versión, navegación entre pasos), este servicio se encarga tanto de exponer el estado reactivamente (`assessment`, `rowVersion` computado) como de sincronizar el ID activo con `localStorage` y con el shell — una única responsabilidad centralizada evita que cada página tenga que repetir esta lógica.

`CatalogCacheService` combina signals con RxJS para exponer un `Observable` de carga perezosa con caché:

```typescript
ensureLoaded(): Observable<CatalogBundle> {
  const current = this.catalogSignal();
  if (current) return of(current);
  return new Observable<CatalogBundle>((subscriber) => {
    this.catalogRepository.preloadBundle()
      .then((bundle) => {
        this.catalogSignal.set(bundle);
        sessionStorage.setItem(CACHE_KEY, JSON.stringify(bundle));
        subscriber.next(bundle);
        subscriber.complete();
      })
      .catch((err) => subscriber.error(err));
  });
}
```

## 6. Formularios de evaluación

Los formularios usan **Template-driven Forms** (`FormsModule`, `[(ngModel)]`), no Reactive Forms — patrón consistente en todas las páginas del wizard revisadas (`EvaluationCreatePageComponent`, `ControlDetailPanelComponent`).

Ejemplo real, alta de evaluación (`EvaluationCreatePageComponent`):

```typescript
async submit(): Promise<void> {
  this.error.set('');
  if (!this.organizationId || !this.name.trim()) {
    this.error.set('Complete los campos obligatorios');
    return;
  }
  this.loading.set(true);
  try {
    const created = await this.createAssessment.execute({
      organizationId: this.organizationId,
      name: this.name.trim(),
      evaluationDate: this.evaluationDate,
      templateVersionId: this.templateVersionId,
      periodLabel: this.periodLabel || undefined,
      contact: this.contact || undefined,
    });
    this.assessmentState.setAssessment(created);
    this.router.navigate(['/evaluations', created.id, 'entity-order-type']);
  } catch (err) {
    this.error.set(err instanceof Error ? err.message : 'Error al crear');
  } finally {
    this.loading.set(false);
  }
}
```

Este componente además carga en paralelo dos dependencias antes de habilitar el formulario: el listado de organizaciones (`ListOrganizationsUseCase`) y el catálogo (`CatalogCacheService.ensureLoaded()`, del cual toma `templateVersion.id`), acumulando mensajes de error independientes si alguna de las dos cargas falla.

## 7. Calificación de un control: formulario de detalle

`ControlDetailPanelComponent` es el formulario más complejo del microfrontend. Construye el `PatchControlScoreRequest` según si la calificación es un valor numérico o `N/A`:

```typescript
save(): void {
  const rating = this.rating();
  if (rating === null) {
    this.error.set('Seleccione una calificación o N/A');
    return;
  }
  const req: PatchControlScoreRequest =
    rating === 'NA'
      ? { scoreStatus: 'NA', evidenceText: this.evidenceText, gapText: this.gapText,
          recommendationText: this.recommendationText, controlStatus: this.controlStatus }
      : { scoreStatus: 'SCORED', scoreValue: rating, evidenceText: this.evidenceText,
          gapText: this.gapText, recommendationText: this.recommendationText,
          controlStatus: this.controlStatus };
  this.saved.emit(req);
}
```

El panel es un componente de presentación puro (no invoca el repositorio directamente): emite `saved` con el request armado y delega en el componente padre (`ControlsPageComponent`) la ejecución de `PatchControlScoreUseCase` y el refresco del árbol. También expone un botón **"Gestionar evidencias en mf_evidence →"** que invoca `openShellRoute('/evidence', assessmentId)`, cruzando hacia otro microfrontend sin salir del shell.

## 8. Árbol de controles (rollup) recursivo

`ControlTreeComponent` se renderiza a sí mismo para reflejar la jerarquía dominio → objetivo → control, usando `forwardRef` para permitir la autorreferencia en un componente standalone:

```typescript
@Component({
  selector: 'app-control-tree',
  standalone: true,
  imports: [forwardRef(() => ControlTreeComponent)],
  ...
})
export class ControlTreeComponent {
  @Input({ required: true }) nodes!: RollupNode[];
  @Input() depth = 0;
  @Input() selectedId: string | null = null;
  @Output() nodeSelect = new EventEmitter<RollupNode>();
  readonly isLeaf = isRollupLeaf;
  readonly displayName = displayNodeName;

  onSelect(node: RollupNode): void {
    if (isRollupLeaf(node)) this.nodeSelect.emit(node);
  }
}
```

Solo los nodos hoja (sin `children`) son seleccionables y emiten `nodeSelect`; los nodos intermedios (dominio, objetivo) solo agregan visualmente el promedio (`averageValue`/`averageScore`) y la banda de madurez (`bandLabel`) calculados por el backend.

## 9. Navegación del wizard

`EvaluationWizardNavComponent` es el componente compartido de mayor complejidad de UI: calcula el paso actual (`stepNumber`/`totalSteps`) a partir de `WIZARD_STEPS` (`evaluation-wizard-links.ts`), soporta un *trail* opcional de pasos clicables (`showStepTrail`) donde los pasos anteriores al actual son enlaces de navegación directa y los posteriores se muestran deshabilitados como texto:

```typescript
@if (stepIndex(step.id) < currentIndex) {
  <a [routerLink]="step.route(assessmentId)" class="step-link">{{ step.label }}</a>
} @else if (step.id === currentStepId) {
  <span class="step-current" aria-current="step">{{ step.label }}</span>
} @else {
  <span class="step-upcoming">{{ step.label }}</span>
}
```

También expone un slot de "acción extra" (`extraActionLabel`/`extraAction`), usado por ejemplo en la pantalla NIST para el botón **Reportes** hacia el shell.

## 10. Integración con las APIs backend

### 10.1 Interceptor HTTP

`apiInterceptor` (funcional, `HttpInterceptorFn`) se ejecuta en cada petición saliente:

```typescript
export const apiInterceptor: HttpInterceptorFn = (req, next) => {
  const authSession = inject(AuthSessionService);
  authSession.reload();
  const token = authSession.token();
  const authReq = token ? req.clone({ setHeaders: { Authorization: `Bearer ${token}` } }) : req;

  return next(authReq).pipe(
    map((event) => {
      if (!(event instanceof HttpResponse)) return event;
      if (event.body instanceof Blob) return event;
      const body = event.body as { data?: unknown; meta?: unknown } | null;
      if (body && body.data !== undefined && body.meta) return event.clone({ body: body.data });
      return event;
    }),
    catchError((err: HttpErrorResponse) => {
      const apiError = new ApiError(err.status, err.error?.error ?? [{ code: 'UNKNOWN', message: err.message }], err.error?.meta?.traceId);
      return throwError(() => apiError);
    })
  );
};
```

Dos responsabilidades combinadas: (1) inyecta el `Authorization: Bearer <token>` leído de la sesión sincronizada con el shell, y (2) **desenvuelve el sobre de respuesta** `{ data, meta }` usado por el backend, de forma que el resto de la aplicación trabaja directamente con el payload (`data`) sin conocer el formato de envoltura. Los errores HTTP se normalizan a `ApiError` con código, mensaje y `traceId` de diagnóstico.

### 10.2 Repositorio API real

`ApiAssessmentRepository` implementa el puerto `AssessmentRepository` contra `ms_assessment` (8084), delegando el mapeo DTO↔dominio en `assessment-api.mapper.ts` (ver `03-Diseno.md`, sección 6). El interceptor ya se encarga de autenticación y desenvoltura de la respuesta, por lo que este repositorio se concentra en construir las URLs y mapear los cuerpos de petición/respuesta.

### 10.3 Repositorio mock

`MockAssessmentRepository` (676 líneas) reproduce en memoria el comportamiento del backend, incluyendo la construcción sintética del árbol de rollup (`buildMockRollup`) con dos niveles de profundidad (dominio → objetivo → 2 controles hoja) y datos de ejemplo realistas para PHVA (p. ej. ítem `phva-p1`, "Política de seguridad de la información documentada", ya calificado con `score: 80`). Este repositorio permite desarrollar y demostrar el wizard completo sin levantar ningún backend.

## 11. Funcionalidades desarrolladas — resumen

| Funcionalidad | Implementación |
|---|---|
| Alta y listado de evaluaciones | `EvaluationCreatePageComponent`, `EvaluationListPageComponent`, `AssessmentIndexService` |
| Configuración de tipo de entidad territorial | `EntityOrderTypePageComponent`, `AssignEntityOrderTypeUseCase` (con manejo de conflicto) |
| Gestión de áreas y temas con responsables | `AreasPageComponent`, `ReplaceAreaTopicsUseCase` |
| Asignación de responsables por control (heredado/personalizado) | `StewardshipPageComponent`, `PatchControlStewardUseCase` |
| Árbol de controles ISO con calificación (ADMIN/TECH) | `ControlsPageComponent`, `ControlTreeComponent`, `ControlDetailPanelComponent` |
| Ciclo PHVA con resumen de avance por componente | `PhvaPageComponent`, casos de uso de `score-modules.use-cases.ts` |
| Requisitos de madurez, matriz por nivel y bloqueantes | `MaturityPageComponent` |
| Ítems NIST CSF, resumen por función y avance global | `NistPageComponent` |
| Navegación guiada de 8 pasos con indicador de progreso | `EvaluationWizardNavComponent`, `evaluation-wizard-links.ts` |
| Puente de sesión y navegación cruzada con el shell | `auth-parent-bridge.ts`, `shell-bridge.ts` |
| Manejo de concurrencia optimista | `assessment-conflict.handler.ts` |

## 12. Convenciones de código observadas

- **100% standalone components** (`standalone: true`), sin `NgModule` alguno en el proyecto.
- **Control flow moderno de Angular** (`@if`, `@for`) en todos los templates, no las directivas estructurales clásicas (`*ngIf`, `*ngFor`).
- **Estilos en línea por componente** (`styles: \`...\`` dentro del decorador `@Component`), sin hojas SCSS separadas por componente; solo existe un `styles.scss` global.
- **Imports de tipo explícitos** (`import type { ... }`) para los tipos de dominio, separados de los imports de valor — coherente con la configuración estricta de TypeScript.
- **Rutas relativas de importación por profundidad de carpeta** (`../../domain/...`), sin *path aliases* configurados en `tsconfig.json`.
