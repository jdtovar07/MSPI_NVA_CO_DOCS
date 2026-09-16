# 08 · Mapa de rutas, permisos y endpoints — `mf_evidence`

Puerto local `:4204` · **3 rutas** · **13 llamadas HTTP distintas** a 3 microservicio(s).

> Generado desde `src/app/app.routes.ts` y las llamadas `HttpClient` del código. La UI oculta lo que el rol no puede hacer, pero la autorización real siempre la valida el backend.

## Rutas y pantallas

| Ruta | Pantalla (componente) | Título visible | Requiere sesión | Permiso |
|---|---|---|---|---|
| `/` | `EvidenceHomePageComponent` | Evidencias | Sí | Ver evaluaciones |
| `/assessments/:assessmentId/context` | `ContextPageComponent` | Contexto de la evaluación | Sí | Ver evaluaciones |
| `/assessments/:assessmentId/inventory` | `InventoryPageComponent` | Levantamiento documental | Sí | Ver evaluaciones |

## Matriz rol × permiso usado en este microfrontend

| Rol | Ver evaluaciones |
|---|---|
| AdminSistema | ✅ |
| AdminInstrumento | ✅ |
| Evaluador | ✅ |
| Revisor | ✅ |
| EvaluadorRevisor | ✅ |
| Lector | ✅ |

Fuente: `ROLE_AUTHORITIES` (`mf_shell/src/app/domain/dashboard/authority.ts`), replicado en cada microfrontend.

## Endpoints de backend consumidos

| Microservicio | Método | Ruta | Archivo(s) |
|---|---|---|---|
| `ms_assessment` | `GET` | `/assessments` | `presentation/pages/evidence-home-page.component.ts` |
| `ms_assessment` | `GET` | `/assessments/{id}` | `presentation/pages/context-page.component.ts`, `presentation/pages/inventory-page.component.ts` |
| `ms_catalog` | `GET` | `/catalog/lifting-document-items` | `presentation/pages/inventory-page.component.ts` |
| `ms_evidence` | `DELETE` | `/files/{id}` | `infrastructure/evidence/api-evidence.repository.ts` |
| `ms_evidence` | `GET` | `/assessments/{id}/context` | `infrastructure/evidence/api-evidence.repository.ts` |
| `ms_evidence` | `GET` | `/assessments/{id}/files` | `infrastructure/evidence/api-evidence.repository.ts` |
| `ms_evidence` | `GET` | `/assessments/{id}/lifting-document-deliveries` | `infrastructure/evidence/api-evidence.repository.ts` |
| `ms_evidence` | `GET` | `/assessments/{id}/process-scope-metric` | `infrastructure/evidence/api-evidence.repository.ts` |
| `ms_evidence` | `GET` | `/files/{id}/download` | `infrastructure/evidence/api-evidence.repository.ts` |
| `ms_evidence` | `PATCH` | `/assessments/{id}/context` | `infrastructure/evidence/api-evidence.repository.ts` |
| `ms_evidence` | `PATCH` | `/assessments/{id}/process-scope-metric` | `infrastructure/evidence/api-evidence.repository.ts` |
| `ms_evidence` | `PATCH` | `/lifting-document-deliveries/{id}` | `infrastructure/evidence/api-evidence.repository.ts` |
| `ms_evidence` | `POST` | `/assessments/{id}/files` | `infrastructure/evidence/api-evidence.repository.ts` |

```mermaid
flowchart LR
  MF["mf_evidence :4204"]
  MF -- "2 llamadas" --> ms_assessment["ms_assessment"]
  MF -- "1 llamadas" --> ms_catalog["ms_catalog"]
  MF -- "10 llamadas" --> ms_evidence["ms_evidence"]
```

**Contexto.** Cada flecha resume cuántas operaciones distintas de ese microservicio usa esta interfaz. Todas viajan con el token JWT de la sesión, que el shell comparte con el iframe por `postMessage`.

---

Ver también: [`03-Diseno.md`](03-Diseno.md) · [Referencia de API](../../Documentacion-General/08-Referencia-API.md)
