# ms_audit — Mantenimiento

| Campo | Valor |
|---|---|
| Repositorio | `MSPI_NVA_CO_MR_BACK/ms_audit` |
| Fecha del documento / Última revisión cruzada con código | **2026-10-19** |
| Estado | Activo |
| Alcance | Operación, retención, monitoreo y deuda técnica de `ms_audit` |

---

## 1. Modelo operativo: append-only

`audit.audit_log` es una bitácora **solo inserción**:

- **Soft-delete: N/A.** No existe columna `deleted_at` ni caso de uso de borrado lógico/físico en el microservicio.
- No hay UPDATE de negocio sobre eventos históricos en el flujo de ingestión documentado; el diseño asume inmutabilidad de filas.
- El crecimiento de la tabla es monótono: planificar retención/archivado a nivel DBA (particionado, export frío) fuera del código de aplicación si el volumen lo exige — **no hay job de purga en el repositorio**.

## 2. Correlación y consistencia

- La correlación de solicitudes depende de que los productores escriban `metadata_json.requestNumber` de forma coherente.
- El timeline `GET /audit/requests/{requestNumber}` depende además de la disponibilidad de `ms_assessment` / `ms_catalog` / `ms_iam` vía `RequestOwnerGatewayAdapter`. Un 404 del dueño deja la cabecera vacía/ausente según el caso de uso; los eventos locales siguen siendo consultables por filtro.
- Rotación de `INTERNAL_API_KEY`: debe coordinarse en todos los productores y en `ms_audit` (comentario en `InternalApiKeyFilter`: rotar periódicamente vía env/Infisical).

## 3. Esquema y migraciones

- Fuente de verdad DDL: `docker-config/docker/postgres/init/patch-audit-schema.sql`.
- Cambios de columnas requieren patch SQL idempotente coordinado; la app no ejecuta Flyway/Liquibase.
- Tras la migración inicial desde `iam.audit_log`, esa tabla origen se elimina: no reintroducir escritura dual en `iam`.

## 4. Observabilidad

| Mecanismo | Estado |
|---|---|
| `/actuator/health`, `/actuator/info` | Implementado; usado por HEALTHCHECK Docker |
| `X-Trace-Id` | `TraceIdFilter` + errores en `GlobalExceptionHandler` |
| Métricas Prometheus | No evidenciadas en este microservicio en la revisión |

## 5. Deuda técnica / mejoras

| Ítem | Notas |
|---|---|
| Tests incompletos en trail / adaptadores | Ver `05-Pruebas.md` (`GetRequestAuditTrailUseCase`, `RequestOwnerGatewayAdapter`, filtro API key) |
| Crecimiento sin retención automatizada | Operación DBA |
| Dependencia runtime de dueños de solicitud | Degradación parcial del timeline si assessment/catalog/iam caen |
| Catálogo abierto de `event_type` | Convenir convenciones de naming entre productores para filtros admin útiles |

## 6. Checklist de mantenimiento rutinario

1. Verificar salud del contenedor/servicio `ms-audit` (`8088`).
2. Confirmar que productores siguen publicando a `MS_AUDIT_URL` con API key válida.
3. Monitorear tamaño de `audit.audit_log` e índices.
4. Tras cambios de prefijos `SOL-*`, actualizar `RequestOwnerGatewayAdapter` y documentar.
5. Mantener alineados JWT issuer (Keycloak) y rol `AdminSistema` para el panel de consulta.
