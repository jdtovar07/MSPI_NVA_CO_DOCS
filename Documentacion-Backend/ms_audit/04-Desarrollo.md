# ms_audit — Desarrollo

| Campo | Valor |
|---|---|
| Repositorio | `MSPI_NVA_CO_MR_BACK/ms_audit` |
| Fecha del documento | 2026-08-18 |
| Alcance | Estado real de desarrollo del repositorio `ms_audit` y de la funcionalidad de auditoría que implementa (en `ms_iam`) el comportamiento que este microservicio deberá asumir |

---

## 1. Declaración de alcance de este documento

No existe implementación de código en `ms_audit` (ver `01-Planificacion.md` y `03-Diseno.md`). En consecuencia, no hay librerías, patrones de código, controladores, casos de uso ni adaptadores propios de `ms_audit` que describir. Este documento tiene dos partes:

1. El "desarrollo" real y verificable de `ms_audit`: la redacción y versionado de su documentación (`README.md`, `docs/`).
2. La implementación funcional **existente en `ms_iam` y `ms_assessment`** que constituye, en la práctica, el código que hoy cumple el rol de auditoría en el sistema, y que serviría de base/referencia si se decide desarrollar `ms_audit` reutilizando patrones ya probados.

## 2. Desarrollo real de `ms_audit`

### 2.1 Historial de commits del monorepo relevante al repositorio

El repositorio `ms_audit` no tiene historial de commits propio identificable como microservicio independiente porque vive dentro del monorepo `MSPI_NVA_CO_MR_BACK`. Los commits relevantes a nivel de monorepo son:

```
9691df5 Agregar docker-config, SQL/seeds y documentacion para levantar MSPI.
d57d88e Migrar microservicios backend MSPI al monorepo back.
d60a709 Initial commit
```

No hay commits dedicados a "implementar ms_audit"; el contenido actual (`README.md`, `docs/MIGRATION-NOTES.md`, `docs/openapi.yaml`) llegó como parte de la migración general de microservicios al monorepo (commit `d57d88e`) y/o del commit de documentación (`9691df5`).

### 2.2 Contenido desarrollado

| Artefacto | Tipo de "desarrollo" | Extensión |
|---|---|---|
| `README.md` | Documentación con 6 diagramas Mermaid (flowchart, sequenceDiagram, classDiagram) describiendo el estado actual y el objetivo | 200 líneas |
| `docs/MIGRATION-NOTES.md` | Documentación de integración operativa (contrato HTTP, configuración, comportamiento ante fallos, pasos de migración) | 123 líneas |
| `docs/openapi.yaml` | Contrato OpenAPI 3.1.0, con un único path deprecado que reenvía al contrato real de `ms_iam` | 153 líneas |
| `.gitignore` | Plantilla genérica sin adaptar al proyecto (mismas reglas Node/Java/Python/Maven/IDE que se ven en otros repos, sin reglas específicas de Gradle wrapper como sí tiene, por ejemplo, `ms_iam`) | 34 líneas |

No hay ningún archivo de código fuente (`.java`, `.kt`, `.ts`, `.py`, etc.), ni configuración de build, ni configuración de aplicación (`application.yaml`), ni scripts SQL propios del esquema `audit`.

## 3. Implementación real de referencia (en `ms_iam` y `ms_assessment`)

Dado que esta funcionalidad es la que `ms_audit` deberá asumir, se documentan aquí sus patrones de implementación concretos, útiles como línea base de diseño para el desarrollo futuro del microservicio.

### 3.1 Capa de entrada — `InternalAuditApi` (ms_iam)

```java
@RestController
@RequestMapping("/internal/audit")
@RequiredArgsConstructor
public class InternalAuditApi {

    private final RecordAuditEventUseCase recordAuditEventUseCase;

    @PostMapping(value = "/events", consumes = MediaType.APPLICATION_JSON_VALUE,
            produces = MediaType.APPLICATION_JSON_VALUE)
    public ResponseEntity<CorrectResponse> record(@Valid @RequestBody AuditEventRequest body) {
        AuditEvent event = AuditEvent.builder()
                .eventType(body.getEventType())
                .entityType(body.getEntityType())
                .entityId(body.getEntityId())
                .assessmentId(body.getAssessmentId())
                .actorUserId(body.getActorUserId())
                .occurredAt(body.getOccurredAt())
                .ip(body.getIp())
                .userAgent(body.getUserAgent())
                .beforeJson(body.getBeforeJson())
                .afterJson(body.getAfterJson())
                .metadataJson(body.getMetadataJson())
                .build();
        recordAuditEventUseCase.execute(event);
        return ResponseEntity.status(HttpStatus.ACCEPTED).body(
                ApiResponseMapper.success(UUID.randomUUID().toString(), "recorded"));
    }
}
```

Patrones observados: separación estricta DTO de entrada (`AuditEventRequest`) → modelo de dominio (`AuditEvent`, vía `builder()`), delegación inmediata al caso de uso, envoltura de respuesta consistente vía `ApiResponseMapper.success()` (mismo patrón de respuesta usado en el resto de APIs de `ms_iam`, `meta` + `data`).

### 3.2 Capa de dominio — `RecordAuditEventUseCase`

```java
@RequiredArgsConstructor
public class RecordAuditEventUseCase {

    private final AuditEventGateway auditEventGateway;

    public void execute(AuditEvent event) {
        if (event.getEventType() == null || event.getEventType().isBlank()) {
            throw new IllegalArgumentException("eventType es obligatorio");
        }
        if (event.getEntityType() == null || event.getEntityType().isBlank()) {
            throw new IllegalArgumentException("entityType es obligatorio");
        }
        if (event.getEntityId() == null || event.getEntityId().isBlank()) {
            throw new IllegalArgumentException("entityId es obligatorio");
        }
        if (event.getOccurredAt() == null) {
            event.setOccurredAt(Instant.now());
        }
        auditEventGateway.record(event);
    }
}
```

Este caso de uso es **agnóstico de framework** (no importa nada de Spring, JPA ni HTTP), consistente con la arquitectura hexagonal manual que sigue `ms_iam` en el resto de sus módulos (`domain/usecase` solo depende de `domain/model`). Las validaciones de negocio (campos obligatorios) viven aquí, no en el DTO ni en el controlador, y el enriquecimiento por defecto (`occurredAt`) también se resuelve en esta capa, no en la base de datos (aunque la columna sí tiene `DEFAULT CURRENT_TIMESTAMP` como red de seguridad adicional).

### 3.3 Capa de persistencia — `AuditLogEntity`

Mapea 1:1 la tabla `iam.audit_log`, usando `@JdbcTypeCode(SqlTypes.JSON)` de Hibernate 6+ para las tres columnas `JSONB` (`before_json`, `after_json`, `metadata_json`), permitiendo persistir `Map<String, Object>` sin serialización manual.

### 3.4 Consumidor — `IamAuditGatewayAdapter` (ms_assessment)

```java
@Slf4j
@Component
public class IamAuditGatewayAdapter implements IamAuditGateway {

    private static final String ENTITY_TYPE = "ASSESSMENT";
    private final RestClient restClient;

    public IamAuditGatewayAdapter(@Qualifier("msIamRestClient") RestClient restClient) {
        this.restClient = restClient;
    }

    @Override
    public void recordAssessmentEvent(String eventType, UUID assessmentId, UUID actorUserId,
                                      Map<String, Object> before, Map<String, Object> after,
                                      Map<String, Object> metadata) {
        Map<String, Object> body = new HashMap<>();
        body.put("eventType", eventType);
        body.put("entityType", ENTITY_TYPE);
        body.put("entityId", String.valueOf(assessmentId));
        body.put("assessmentId", assessmentId);
        body.put("actorUserId", actorUserId);
        body.put("occurredAt", Instant.now().toString());
        if (before != null) body.put("beforeJson", before);
        if (after != null) body.put("afterJson", after);
        if (metadata != null) body.put("metadataJson", metadata);
        try {
            restClient.post()
                    .uri("/internal/audit/events")
                    .body(body)
                    .retrieve()
                    .toBodilessEntity();
        } catch (Exception ex) {
            log.warn("[AUDIT][IAM] no se pudo registrar evento {} para assessment {}: {}",
                    eventType, assessmentId, ex.getMessage());
        }
    }
}
```

Patrones observados: uso de `RestClient` (Spring 6+, no `RestTemplate` ni `WebClient`) con un *bean* nombrado (`@Qualifier("msIamRestClient")`) configurado externamente para inyectar el header `X-Internal-Api-Key` automáticamente; construcción de body como `Map<String, Object>` en lugar de un DTO tipado, lo que evita duplicar la clase `AuditEventRequest` en el consumidor a costa de perder chequeo de tipos en compilación; manejo de error mediante *logging* con prefijo de componente `[AUDIT][IAM]`, siguiendo la misma convención de logging estructurado que el resto de `ms_iam` (`[API][auth]`, `[ADAPTER][LoginService]`, etc.).

## 4. Funcionalidades concretas versus documentadas

| Funcionalidad | ¿Tiene código real? | Ubicación |
|---|---|---|
| Ingesta de eventos vía HTTP interno | Sí | `ms_iam` (`InternalAuditApi`, `RecordAuditEventUseCase`, `AuditEventAdapter`) |
| Registro de eventos de login | Sí | `ms_iam` (`AuthAuditAdapter`) |
| Envío de eventos desde ms_assessment | Sí | `ms_assessment` (`IamAuditGatewayAdapter`) |
| Consulta de bitácora (`GET /audit/events`) | No | Ni en `ms_iam` ni en `ms_audit` |
| Exportación (`GET /audit/export`) | No | Ni en `ms_iam` ni en `ms_audit` |
| Persistencia en esquema `audit` propio | No | Solo existe `iam.audit_log` |
| Cualquier lógica dentro de `ms_audit/` | No | El repositorio no contiene código |

## 5. Librerías y versiones (de la implementación de referencia en ms_iam)

Puesto que no hay `build.gradle` en `ms_audit`, no se pueden citar versiones propias. Las librerías relevantes al subdominio de auditoría, verificadas en `ms_iam`, son:

| Librería | Uso en el flujo de auditoría |
|---|---|
| Spring MVC (`spring-boot-starter-webmvc`) | Controlador `InternalAuditApi` |
| Spring Data JPA + Hibernate | `AuditEventAdapter`, `AuditLogEntity`, mapeo `JSONB` vía `@JdbcTypeCode(SqlTypes.JSON)` |
| Lombok | `@RequiredArgsConstructor`, `@Builder`, `@Getter` en `AuditEvent`/`AuditLogEntity` |
| Spring 6 `RestClient` | Cliente HTTP en `IamAuditGatewayAdapter` (`ms_assessment`) |
| SLF4J (`@Slf4j`) | Logging de advertencia ante fallos de auditoría |

## 6. Conclusión de la fase de desarrollo

En términos estrictos de "desarrollo de software", `ms_audit` se encuentra en **fase 0** (documentación de intención, sin una sola línea de código de aplicación). El trabajo de desarrollo real relacionado con auditoría en el proyecto de grado está contenido íntegramente en `ms_iam` (productor propio + servidor de ingesta) y en `ms_assessment` (cliente/consumidor). Cualquier desarrollo futuro de `ms_audit` puede apoyarse directamente en los tres artefactos de código citados en la sección 3 como punto de partida, dado que el propio equipo ya dejó ese contrato "congelado" como referencia en `ms_audit/docs/openapi.yaml`.
