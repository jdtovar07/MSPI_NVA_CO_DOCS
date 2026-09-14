# ms_admin — Mantenimiento

| Campo | Valor |
|---|---|
| Repositorio | `MSPI_NVA_CO_MR_BACK/ms_admin` |
| Fecha del documento / Última revisión cruzada con código | **2026-10-19** |
| Estado | Activo |
| Alcance | Operación, historial, monitoreo y deuda técnica de `ms_admin` |

---

## 1. Modelo operativo de datos

### 1.1 Configuración vigente (`admin.system_config`)

- Una fila canónica por clave; la clave de producto es `mspi.system.config`.
- Las actualizaciones **sobrescriben** `value_json` / `version` / `updated_at` de la fila vigente.
- Soft-delete de la config vigente: **no aplica** al diseño actual (no hay `deleted_at`); la fila se mantiene y se actualiza in-place.

### 1.2 Historial (`admin.system_config_history`) — append

- Cada cambio genera una **nueva fila** de historial (append-only).
- No hay borrado lógico/físico de historial en el código de aplicación.
- El crecimiento del historial es monótono: si `limit` del panel es insuficiente para auditoría forense, consultar la tabla directamente o ampliar el parámetro `limit` en la API.
- Soft-delete: **N/A** para history (retención por inserción; purga solo sería operación DBA explícita fuera del MS).

## 2. Operación cotidiana

1. Verificar salud del servicio Compose/`ms-admin` en **8089**.
2. Confirmar que `ms_assessment` y `ms_catalog` resuelven `MS_ADMIN_URL` y comparten `INTERNAL_API_KEY`.
3. Tras cambiar plazos (días), validar impacto en flujos de evaluación/eliminación/catálogo (consumidores leen en caliente vía S2S).
4. Rotar `INTERNAL_API_KEY` de forma coordinada (env/Infisical).
5. Mantener rol Keycloak `AdminSistema` alineado con `SecurityConfig`.

## 3. Esquema y migraciones

- DDL: `patch-admin-schema.sql`.
- Tras migración desde `iam.system_config*`, no reintroducir escritura dual en IAM.
- Nuevos parámetros JSON: preferir extensión del mapa `value_json` + defaults en `GetSystemConfigUseCase` + validación en `UpdateSystemConfigUseCase` (si aplica rango).

## 4. Observabilidad

| Mecanismo | Estado |
|---|---|
| `/actuator/health`, `/actuator/info` | Implementado; HEALTHCHECK Docker |
| `X-Trace-Id` | Filtro + handler de excepciones |
| Métricas Prometheus | No evidenciadas en este MS en la revisión |

## 5. Deuda técnica / mejoras

| Ítem | Notas |
|---|---|
| `updated_by` UUID a menudo null | Limitación documentada en `SystemAdminApi`; el label humano mitiga en summary |
| Tests de API / filtro internos ausentes | Ver `05-Pruebas.md` |
| Historial sin retención automatizada | Operación DBA si el volumen crece |
| Nuevos campos de config | Requiere contrato con consumidores (assessment/catalog/shell) |

## 6. Checklist de mantenimiento

1. Health `ms-admin:8089`.
2. `GET /internal/system/config` responde 200 con defaults o valores persistidos.
3. Un `PUT` de prueba en entorno no productivo deja rastro en `system_config_history`.
4. Front `mf_shell` apunta a `msAdminUrl` correcto.
5. Documentar cualquier nuevo campo de `value_json` en OpenAPI/`README` del microservicio.
