# Notificaciones in-app y consolidación de roles IAM

| Campo | Valor |
|---|---|
| Fecha | 2026-10-11 |
| Alcance | Campanita mf_shell + `POST /internal/notifications`; normalización de roles sin crear roles nuevos |

---

## 1. Roles existentes (solo estos 6)

`AdminSistema`, `AdminInstrumento`, `Evaluador`, `Revisor`, `EvaluadorRevisor`, `Lector`.

### 1.1 Normalización al asignar/guardar

Aplicada en **front** (`mf_auth` · `normalizeRoles` / `user-form-page`) y de forma **autoritativa** en **ms_iam** (`RoleNormalizer` → `UserManagementService` create/update, sincroniza Keycloak + `iam.user_role`).

| Entrada | Resultado | Mensaje (ES) |
|---|---|---|
| Contiene `AdminSistema` (+ cualquier otro) | Solo `AdminSistema` | «La combinación con AdminSistema se consolidó en AdminSistema (acceso total).» |
| `Evaluador` + `Revisor` | `EvaluadorRevisor` (se quitan los sueltos) | «Evaluador + Revisor se consolidó en EvaluadorRevisor.» |
| `EvaluadorRevisor` + `Evaluador`/`Revisor` | Solo `EvaluadorRevisor` | Idem |

No se inventan roles fuera de los seis. El formulario muestra un aviso cuando hay consolidación.

---

## 2. Notificaciones

### 2.1 Piezas

| Capa | Componente |
|---|---|
| Persistencia | `iam.notification` |
| Casos de uso | `CreateNotificationUseCase`, `ListNotificationsUseCase`, `MarkNotificationReadUseCase`, `MarkAllNotificationsReadUseCase` |
| API usuario (JWT) | `GET /notifications?userId=`, `POST /notifications/{id}/read`, `POST /notifications/read-all` |
| API S2S | `POST /internal/notifications` + header `X-Internal-Api-Key` |
| UI | Campanita en `mf_shell` · `shell-layout` (contador no leídas, lista, marcar una / todas, poll 60 s) |

### 2.2 Contrato interno

```json
{
  "userId": "uuid-opcional",
  "targetRoles": ["AdminSistema", "AdminInstrumento"],
  "excludeUserId": "uuid-opcional",
  "type": "EXTENSION_REQUEST",
  "priority": "MEDIUM",
  "title": "...",
  "message": "...",
  "assessmentId": "uuid-opcional",
  "assessmentName": "...",
  "actionUrl": "/evaluations/extension-requests"
}
```

Se requiere `userId` y/o `targetRoles`. El fan-out por rol usa `iam.user_role` (usuarios ACTIVE). Dedup: no se recrea la misma `(userId, type, assessmentId)` en las últimas 20 h (avisos de vencimiento).

### 2.3 Eventos que disparan notificación

| Evento | Destinatarios | Tipo | `actionUrl` típica |
|---|---|---|---|
| Solicitud de ampliación creada | AdminSistema, AdminInstrumento | `EXTENSION_REQUEST` | `/evaluations/extension-requests` |
| Ampliación aprobada / rechazada | Solicitante | `EXTENSION_APPROVED` / `EXTENSION_REJECTED` | `/evaluations/my-assigned` |
| Solicitud eliminación evaluación | AdminSistema, AdminInstrumento | `DELETION_REQUEST` | `/evaluations/deletion-requests` |
| Eliminación evaluación aprobada / rechazada | Solicitante | `DELETION_APPROVED` / `DELETION_REJECTED` | `/evaluations/my-assigned` |
| Solicitud eliminación catálogo | AdminSistema | `CATALOG_DELETION_REQUEST` | `/catalog/deletion-requests` |
| Eliminación catálogo aprobada / rechazada | Solicitante | `CATALOG_DELETION_*` | catálogo / escalas |
| Miembro agregado a evaluación | Usuario asignado | `MEMBER_ADDED` | `/evaluations/{id}` |
| Fecha límite ≤ 5 días / vencida | Miembros Evaluador o EvaluadorRevisor | `DUE_SOON` / `OVERDUE` | `/evaluations/my-assigned` |

Productores: `ms_assessment` y `ms_catalog` vía `IamNotificationGateway` → `POST /internal/notifications` (best-effort). Job diario 08:00 America/Bogota: `AssessmentDueDateNotificationSweeper`.

### 2.4 Cómo se ven / activan

1. El usuario inicia sesión en el shell.
2. La campanita carga `GET /notifications` y muestra el badge de no leídas.
3. Al abrir: lista ordenada; clic marca leída y navega a `actionUrl` si existe.
4. «Marcar todas» → `POST /notifications/read-all`.
5. El contador se refresca al abrir, al marcar y cada 60 s.

---

*Ver también: eliminación lógica de evaluaciones/catálogo y plazos en la documentación de ms_assessment / ms_catalog.*
