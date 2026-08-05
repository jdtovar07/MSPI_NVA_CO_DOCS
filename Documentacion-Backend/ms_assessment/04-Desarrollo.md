# ms_assessment — Desarrollo

| Campo | Valor |
|---|---|
| Repositorio | `MSPI_NVA_CO_MR_BACK/ms_assessment` |
| Fecha del documento | 2026-08-19 |
| Alcance | Descripción de la implementación real: tecnologías, estructura de código por capa, patrones aplicados y funcionalidades desarrolladas |

---

## 1. Tecnologías y librerías (consolidado de todos los `build.gradle`)

| Categoría | Librería | Versión | Módulo(s) |
|---|---|---|---|
| Runtime | Java (toolchain) | 21 | todos |
| Framework | Spring Boot | 4.0.2 (BOM `spring-boot-dependencies`) | todos |
| Web (servidor) | `spring-boot-starter-web`, `spring-boot-starter-webmvc` | gestionada por BOM | `app-service`, `api-rest` |
| Web (cliente saliente) | `spring-boot-starter-webmvc` (`RestClient`) | gestionada por BOM | `rest-consumer` |
| Seguridad | `spring-boot-starter-security`, `spring-security-oauth2-resource-server`, `spring-security-oauth2-jose` | gestionada por BOM | `app-service`, `api-rest`, `rest-consumer` (resource-server) |
| Persistencia | `spring-boot-starter-data-jpa` | gestionada por BOM | `jpa-repository` |
| Base de datos | `org.postgresql:postgresql` | gestionada por BOM (`runtimeOnly`) | `jpa-repository`, `app-service` |
| Observabilidad | `spring-boot-starter-actuator` | gestionada por BOM | `api-rest` |
| Validación | `spring-boot-starter-validation` | gestionada por BOM | `api-rest` |
| Serialización | `com.fasterxml.jackson.core:jackson-databind` | gestionada por BOM | `app-service`, `rest-consumer` |
| Secretos | `com.infisical:sdk` | 3.0.2 | `app-service` |
| Boilerplate | `org.projectlombok:lombok` | 1.18.42 | todos (`compileOnly`/`annotationProcessor`) |
| Devtools | `spring-boot-devtools` | gestionada por BOM (`runtimeOnly`) | `app-service` |
| Pruebas | `spring-boot-starter-test` (JUnit 5, Mockito, AssertJ) | gestionada por BOM | todos |
| Pruebas (seguridad) | `spring-security-test` | gestionada por BOM | `app-service`, `api-rest` |
| Pruebas (arquitectura, declarada) | `com.tngtech.archunit:archunit` | 1.4.1 | `app-service` (`testImplementation`, sin clase de prueba asociada) |
| Pruebas (mapeo, declarada) | `org.reactivecommons.utils:object-mapper` | 0.1.0 | `jpa-repository` (`testImplementation`) |
| Cobertura / calidad | JaCoCo, Pitest, plugin SonarQube | 0.8.14 / plugin 1.19.0-rc.3 (motor 1.22.0) / 7.2.2.6593 | build raíz |

No hay dependencia de mensajería (Kafka/RabbitMQ), caché (Redis), motor reactivo (WebFlux/R2DBC) ni motor de plantillas/correo (a diferencia de `ms_iam`, que integra Brevo): `ms_assessment` es puramente HTTP síncrono + PostgreSQL.

## 2. Estructura del código por capa

### 2.1 `domain/model` (`:model`) — núcleo de dominio

El módulo más grande del proyecto en número de clases: **58 POJOs** repartidos en `assessment/` (41 clases — entidades de dominio, comandos y resultados de cálculo) y `external/` (17 clases — representaciones de lo que se consume de `ms_catalog`/`ms_org`/`ms_evidence`), más 6 interfaces de puerto en `gateway/`. `build.gradle` está vacío (sin dependencias declaradas propias). Ejemplo representativo — el agregado raíz `Assessment`:

```java
@Data
@Builder(toBuilder = true)
public class Assessment {
    private UUID id;
    private UUID organizationId;
    private UUID templateVersionId;
    private String name;
    private String status;              // BORRADOR / CERRADA
    private String entityOrderTypeCode;
    private BigDecimal phvaExpectedAdvanceSnapshot;
    private UUID clonedFromAssessmentId;
    private Integer rowVersion;
    // ... más campos snapshot/auditoría
}
```

Un rasgo distintivo frente a `ms_iam` es la **densidad de tipos de resultado de cálculo** (`RollupResult`/`RollupNode`, `MaturitySummaryResult`/`MaturityMatrixRow`/`MaturityMatrixCell`/`MaturityBlockingRequirement`, `NistSummaryResult`/`NistFunctionSummary`, `DomainEffectivenessResult`/`DomainEffectivenessRow`, `DiagnosticDashboardResult`, `SelfPerceptionComparison`, `GapListResult`/`GapItem`, `ReportExportBundle`): cada agregación on-read tiene su propio árbol de tipos inmutables construidos con Lombok `@Builder`, sin anotaciones JPA/Jackson (el mapeo a entidad y a DTO ocurre en capas externas).

### 2.2 `domain/usecase` (`:usecase`) — casos de uso y resolvers

31 clases: **28 casos de uso** de una responsabilidad cada una, y **3 "resolvers"** (`PhvaScoreResolver`, `MaturityScoreResolver`, `NistCiberScoreResolver`) que son clases `final` con constructor privado y métodos **estáticos** — no son casos de uso inyectables, sino funciones de dominio puras reutilizadas por varios casos de uso (p. ej. `MaturityScoreResolver` invoca internamente a `PhvaScoreResolver.resolveEffectiveScore(...)` para resolver la regla `PHVA_ITEM_SCORE`).

Ejemplo de la lógica de resolución de valor efectivo (`F_n`) de un requisito de madurez, tomada de `MaturityScoreResolver.resolveEffectiveScore`:

```java
static Integer resolveEffectiveScore(MaturityRequirementSnapshot req, ...) {
    if (SCORING_MANUAL.equalsIgnoreCase(req.getScoringMode())) {
        return scoreFromMaturityResponse(manualResponse);
    }
    if (!SCORING_INHERITED.equalsIgnoreCase(req.getScoringMode())) {
        return null;
    }
    return switch (req.getInheritRule()) {
        case INHERIT_CONTROL_SCORE -> scoreFromControlNode(req.getSourceAssessmentControlNodeId(), controlResponses);
        case INHERIT_CONTROL_ROLLUP -> rollupByControlNodeId.get(req.getSourceAssessmentControlNodeId());
        case INHERIT_PHVA_ITEM -> resolvePhvaCode(req.getSourcePhvaItemCode(), ...);
        case INHERIT_PHVA_COMPOSITE -> resolvePhvaComposite(req.getCompositePhvaCodes(), ...);
        default -> null;
    };
}
```

Los resolvers usan un **caché local por código PHVA** (`Map<String, Integer> phvaEffectiveByCode`, pasado por referencia entre llamadas) para evitar recalcular el valor efectivo de un mismo ítem PHVA cuando varios requisitos de madurez lo referencian, dentro de una sola ejecución de `ComputeMaturitySummaryUseCase`.

Los casos de uso "orquestadores" encadenan otros casos de uso en lugar de repetir lógica: `ComputeDiagnosticDashboardUseCase` depende de `ComputeDomainEffectivenessUseCase`, `ComputePhvaAdvanceUseCase`, `ComputeMaturitySummaryUseCase` y `ComputeNistSummaryUseCase`; `BuildReportExportBundleUseCase` depende de siete casos de uso de lectura (incluyendo `ComputeDiagnosticDashboardUseCase`). Esta composición se resuelve por inyección de constructor vía `@RequiredArgsConstructor` de Lombok, ensamblada en `UseCaseConfig` (`:app-service`).

### 2.3 `infrastructure/driven-adapters/jpa-repository` (`:jpa-repository`)

Implementa el único puerto de persistencia (`AssessmentPersistenceGateway`, 39 métodos) en una **sola clase adaptadora**, `AssessmentJpaAdapter`, apoyada en 13 entidades `@Entity` (una por tabla) y 13 interfaces `JpaRepository`. Responsabilidades observadas en el adaptador:

- Mapeo bidireccional entidad↔dominio (métodos `toDomain`/`toEntity` por tipo).
- **Materialización de snapshots**: `snapshotControlTree`, `snapshotPhvaItems`, `snapshotMaturityRequirements`, `snapshotNistCiberItems` reciben listas de DTOs de catálogo (`external.*CatalogInfo`) y las traducen a filas `assessment_*`, resolviendo referencias cruzadas (p. ej. `Map<UUID, UUID> catalogControlToAssessmentNode` para traducir el id de control del catálogo al id del nodo ya materializado en la evaluación).
- **Clonación de snapshot completo**: `cloneAssessmentAreas`, `cloneAssessmentControlSnapshot`, `clonePhvaSnapshot`, `cloneMaturitySnapshot`, `cloneNistCiberSnapshot`, invocados en cadena por `CloneAssessmentUseCase` para duplicar íntegramente el árbol de una evaluación `CERRADA` hacia una nueva `BORRADOR`.
- **Resolución de stewardship**: `findControlStewardshipByAssessmentId` construye la vista `ControlStewardshipRow` combinando el `default_steward_role_code` heredado del área/tema con el override `CUSTOM` capturado en `control_response`.

### 2.4 `infrastructure/driven-adapters/rest-consumer` (`:rest-consumer`)

5 adaptadores sobre `RestClient` de Spring (no `WebClient`), configurados con 4 *beans* `RestClient` nombrados en `RestConsumerConfig` (`msOrgRestClient`, `msCatalogRestClient`, `msEvidenceRestClient`, `msIamRestClient`). Un interceptor común (`jwtBearerForwardingInterceptor`) reenvía el JWT del usuario autenticado (leído de `SecurityContextHolder`) hacia `ms_org`, `ms_catalog` e `ms_iam`; las llamadas a `ms_evidence` y las internas de `ms_catalog`/`ms_iam` añaden además `X-Internal-Api-Key` cuando está configurada. `ApiDataExtractor` (paquete `support`) centraliza la deserialización del envoltorio `CorrectResponse{data}` que devuelven los microservicios remotos, evitando repetir ese *unwrapping* en cada adaptador.

`CatalogGatewayAdapter` es el adaptador más extenso: expone ~15 operaciones GET distintas contra `ms_catalog` (plantilla activa, árbol de controles, hojas, reglas por nodo, escala/bandas publicadas, PHVA, madurez, NIST, presets de áreas, dominios ISO, tipos de orden territorial).

### 2.5 `infrastructure/entry-points/api-rest` (`:api-rest`)

9 controladores `@RestController` delgados (patrón idéntico al de `ms_iam`: DTO validado → mapper estático → caso de uso → DTO de respuesta). Incluye dos clases de soporte propias de este microservicio sin equivalente en `ms_iam`:

- **`CurrentUserResolver`**: resuelve el `userId` interno (UUID de `iam.user`) a partir del `sub` (y opcionalmente `email`) del JWT, delegando en `IamUserGateway.resolveInternalUserId(...)`. Si el usuario autenticado no existe como espejo en `ms_iam`, lanza `IamServiceException` con un mensaje operativo explícito: *"Usuario no registrado en iam.user. Ejecuta seed-usuario-principal.ps1 o crea el usuario en ms_iam."* — mensaje de error auto-explicativo con el remedio, mismo patrón de diseño observado en `ms_iam` para el error 403 de Keycloak Admin API.
- **`JwtSupport`**: utilidades de extracción de claims compartidas entre controladores.

### 2.6 `infrastructure/helpers/common` (`:common`)

Módulo compartido con la misma estructura que en `ms_iam` (`CorrectResponse`/`ErrorResponse`/`Meta`/`ErrorDetail`, `ApiResponseMapper`, `CommonErrorConstants`), pero con **solo 5 excepciones de dominio** (`DomainException`, `BusinessRulesOnFieldsException`, `ResourceNotFoundException`, `IamServiceException`, `UserAlreadyExistsException`) frente a las 8 de `ms_iam`. Las dos últimas (`IamServiceException`, `UserAlreadyExistsException`) son vestigios reutilizados del módulo `common` compartido en el ecosistema MSPI: `IamServiceException` sí se usa (en `CurrentUserResolver`), pero **no se encontró ningún punto del código de `ms_assessment` que lance `UserAlreadyExistsException`** — su manejador en `GlobalExceptionHandler` existe por herencia del contrato compartido, no por una funcionalidad propia de creación de usuarios (que no aplica a este microservicio).

### 2.7 `applications/app-service` (`:app-service`) — módulo ejecutable

Punto de ensamblaje final:

- `MainApplication` — `@SpringBootApplication`, sin lógica adicional (excluida de Sonar vía `sonar.exclusions`).
- `UseCaseConfig` — *composition root* con **27 `@Bean`**, uno por caso de uso (más de los que declara `ms_iam`, reflejando el mayor número de casos de uso de este microservicio).
- `SecurityConfig` — cadena de filtros, `NimbusJwtDecoder`, conversión de `realm_access.roles` a `ROLE_<nombre>` + `ROLE_USER` por defecto.
- `InternalApiKeyFilter` / `InternalApiProperties` — protección de `/internal/**`, idéntico a `ms_iam` (503 si no configurada, 401 si inválida).
- `InfisicalConfig` — mismo patrón `BeanFactoryPostProcessor` fail-open que `ms_iam`.
- `AdapterProperties` — *binding* tipado de las 4 URLs + claves de los microservicios consumidos (`adapter.ms-org.url`, `adapter.ms-catalog.url`, etc.), en lugar de `@Value` sueltos.
- `JacksonConfig` — configuración de serialización compartida (fechas ISO, etc.).
- `DBCredential` / `DBCredentialConfig` — parseo de `DB_CREDENTIAL` (JSON), igual que `ms_iam`.

## 3. Patrones y estándares aplicados

| Patrón | Dónde se aplica |
|---|---|
| **Puertos y adaptadores (Hexagonal)** | Todo el proyecto; 6 interfaces en `:model/gateway`, implementaciones en `driven-adapters/*` |
| **Inyección de dependencias por constructor** | Todas las clases de infraestructura y casos de uso (`@RequiredArgsConstructor` de Lombok) |
| **Composition Root explícito** | `UseCaseConfig` (27 `@Bean`) en `:app-service` |
| **DTO ↔ Dominio con mapeadores estáticos dedicados** | 9 clases `*ApiMapper` en `api-rest` |
| **Composición de casos de uso** (un caso de uso depende de otros ya construidos, no solo de gateways) | `ComputeDiagnosticDashboardUseCase`, `BuildReportExportBundleUseCase`, `ListPhvaItemsUseCase`/`ListMaturityRequirementsUseCase` (dependen de `ComputeAssessmentRollupUseCase`) |
| **Funciones de dominio puras, sin estado (resolvers estáticos)** | `PhvaScoreResolver`, `MaturityScoreResolver`, `NistCiberScoreResolver` — constructor privado, métodos `static` |
| **Snapshot inmutable + respuesta mutable separada** | Patrón repetido en controles, PHVA, madurez y NIST tanto en modelo de datos (§5.2 de `03-Diseno.md`) como en modelo de dominio (`*Snapshot` vs. `*Response`) |
| **Cálculo on-read sin tablas de resultados persistidos** | Todos los `Compute*UseCase` — recalculan desde cero en cada petición a partir de snapshots + respuestas |
| **Caché local de memorización dentro de una ejecución** | `Map<String, Integer> phvaEffectiveByCode` en `MaturityScoreResolver`, evita recalcular el mismo ítem PHVA para múltiples requisitos de madurez |
| **Excepciones de dominio tipadas y centralizadas** | `:common/exception` + `GlobalExceptionHandler` (6 manejadores específicos) |
| **Filtro Servlet para autenticación alterna (API key)** | `InternalApiKeyFilter` (`OncePerRequestFilter`), insertado antes del filtro Bearer |
| **Interceptor de propagación de credenciales salientes** | `jwtBearerForwardingInterceptor` en `RestConsumerConfig` — reenvía el JWT del usuario a microservicios aguas abajo |
| **BeanFactoryPostProcessor para inyección temprana de configuración** | `InfisicalConfig` |
| **Multi-módulo Gradle como *build-time enforcement*** | `settings.gradle` + reglas de dependencia por `build.gradle` |
| **Mensajes de error operativos auto-explicativos** | `CurrentUserResolver` (usuario no espejado en `ms_iam`) |

## 4. Principales funcionalidades desarrolladas

1. **Ciclo de vida de evaluación con materialización de snapshot en 4 dimensiones**: al crear (`CreateAssessmentUseCase`), el microservicio consulta `ms_org` (validación) y `ms_catalog` (plantilla activa + árbol completo de controles, PHVA, madurez, NIST y presets de áreas) y persiste una copia congelada de todo eso en el esquema `assessment`, más una llamada a `ms_evidence` para inicializar el levantamiento documental asociado.
2. **Publicación con concurrencia optimista y auditoría best-effort**: `PublishAssessmentUseCase` valida `entityOrderTypeCode` asignado y `rowVersion` coincidente antes de transicionar `BORRADOR → CERRADA`, registra el cambio en `assessment_status_history` y notifica a `ms_iam` sin bloquear la operación si la auditoría falla.
3. **Clonación de evaluación cerrada**: `CloneAssessmentUseCase` duplica atómicamente áreas, snapshot de controles, PHVA, madurez y NIST hacia una nueva evaluación `BORRADOR`, y solicita a `ms_evidence` clonar el levantamiento documental.
4. **Calificación uniforme con reglas de completitud dependientes del catálogo**: `PatchControlScoreUseCase` valida el valor contra la escala publicada, y al marcar `COMPLETADO` aplica las reglas `ControlRuleInfo` (evidencia/brecha/recomendación condicionada por umbral) resueltas dinámicamente desde `ms_catalog`.
5. **Motor de rollup jerárquico recursivo** (`ComputeAssessmentRollupUseCase`): recorre el árbol snapshot de hojas a raíz con promedio *half-up*, herencia directa en nodos de un solo hijo calculable, y resolución de banda de madurez por rango — reutilizado como base de 4 cálculos derivados distintos (efectividad por dominio, avance PHVA, resumen de madurez, resumen NIST).
6. **Resolución de valor efectivo (`F_n`) con hasta 5 estrategias de herencia** para PHVA/madurez/NIST (`MANUAL`, `CONTROL_SCORE`, `CONTROL_ROLLUP`, `ANEXO_A_OVERALL`, `INHERIT_PHVA_ITEM_SCORE`, `INHERIT_PHVA_COMPOSITE_AVG`), implementada como funciones puras memoizadas por código dentro de una misma ejecución.
7. **Matriz de cumplimiento y nivel de madurez tipo CMMI**: `ComputeMaturitySummaryUseCase`/`MaturityScoreResolver` comparan cada requisito contra 5 umbrales (uno por nivel), determinan el primer nivel bloqueado y clasifican SUFICIENTE/INTERMEDIO/CRÍTICO según umbrales configurables por plantilla (`maturity_crit_thresholds`).
8. **Tablero diagnóstico agregado con auto-percepción**: `ComputeDiagnosticDashboardUseCase` combina 4 cálculos internos con datos de auto-percepción obtenidos de `ms_evidence` en una sola respuesta consolidada.
9. **Listado de brechas priorizadas con *fallback* de recomendación**: `ListGapsUseCase` filtra por umbral/dominio/rol, calcula prioridad (`ALTA`/`MEDIA`/`BAJA`) y usa `test_guidance` del catálogo cuando no hay recomendación capturada por el evaluador.
10. **API interna S2S para `ms_reporting`**: `BuildReportExportBundleUseCase` agrega en una sola respuesta el resultado de 7 casos de uso de lectura, protegida por `X-Internal-Api-Key` sin requerir JWT.
11. **Resolución de identidad interna desde JWT**: `CurrentUserResolver`/`IamUserGatewayAdapter` traducen el `sub` del token de Keycloak al `userId` (UUID) espejado en `ms_iam`, con mensaje de error operativo si el usuario no existe.
