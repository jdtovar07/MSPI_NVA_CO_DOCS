# ms_audit — Pruebas

| Campo | Valor |
|---|---|
| Repositorio | `MSPI_NVA_CO_MR_BACK/ms_audit` |
| Estado | Activo |
| Alcance | Pruebas unitarias existentes y huecos verificados en el árbol `src/test` |

---

## 0. Inventario actualizado de pruebas (desde el código)

**5 clases de prueba · 24 casos (`@Test`/`@ParameterizedTest`).** Este inventario prevalece sobre cualquier conteo anterior de este documento.

| Módulo | Clase de prueba | Casos | Tipo |
|---|---|---|---|
| `domain/usecase` | `ListAuditEventsUseCaseTest` | 1 | Unitaria |
| `domain/usecase` | `RecordAuditEventUseCaseTest` | 8 | Unitaria |
| `infrastructure/entry-points/api-rest` | `CorsConfigTest` | 3 | Unitaria |
| `infrastructure/entry-points/api-rest` | `GlobalExceptionHandlerTest` | 8 | Unitaria |
| `infrastructure/entry-points/api-rest` | `TraceIdFilterTest` | 4 | Unitaria |

Ejecutar: `./gradlew test jacocoTestReport` desde la raíz del microservicio (reporte en `build/reports/jacoco`).

## 1. Frameworks

Heredados de la plantilla Gradle MSPI (`main.gradle` / `build.gradle`):

- JUnit 5 (`useJUnitPlatform()`)
- `spring-boot-starter-test` (Mockito, AssertJ)
- JaCoCo **0.8.14** con verificación de cobertura enlazada a `check` (cuando el módulo tiene tests)

## 2. Estructura real de tests (verificada)

```
domain/usecase/src/test/java/co/com/mspi/usecase/audit/
├── ListAuditEventsUseCaseTest.java
└── RecordAuditEventUseCaseTest.java

infrastructure/entry-points/api-rest/src/test/java/co/com/mspi/api/
├── config/CorsConfigTest.java
├── config/TraceIdFilterTest.java
└── exception/GlobalExceptionHandlerTest.java
```

**Total: 5 clases de prueba** encontradas bajo `ms_audit/**/src/test/**`.

## 3. Cobertura por área

| Área | Estado | Detalle |
|---|---|---|
| `RecordAuditEventUseCase` | Presente | `RecordAuditEventUseCaseTest` |
| `ListAuditEventsUseCase` | Presente | `ListAuditEventsUseCaseTest` |
| `GetRequestAuditTrailUseCase` | **Sin test dedicado** | Verificar en código / TODO de cobertura |
| `AuditApi` / `InternalAuditApi` (MockMvc) | **No encontrado** | Sin pruebas de controlador REST |
| `InternalApiKeyFilter` (constant-time) | **No encontrado** | Sin test unitario del filtro |
| `RequestOwnerGatewayAdapter` (prefijos SOL-*) | **No encontrado** | Sin test del enrutado |
| `AuditEventAdapter` / repositorio JPA | **No encontrado** | Sin `src/test` en `jpa-repository` |
| CORS / TraceId / GlobalExceptionHandler | Presente | 3 tests transversales en `api-rest` |
| Integración `@SpringBootTest` / Testcontainers | **No encontrado** | |

## 4. Qué ejercitan los tests existentes

- **Casos de uso de auditoría**: registro y listado con gateways mockeados (patrón unitario de dominio).
- **Infra HTTP transversal**: construcción de CORS, generación/reutilización de `X-Trace-Id` y mapeo de excepciones a códigos HTTP — mismo patrón que otros MS del monorepo.

## 5. Recomendaciones (deuda de pruebas)

1. Añadir `GetRequestAuditTrailUseCaseTest` con mocks de `RequestOwnerGateway` y del repositorio de eventos.
2. Cubrir `RequestOwnerGatewayAdapter` (prefijos `SOL-CAT-`, `SOL-PWD-`, `SOL-ELIM-`, `SOL-AMPL-` y fallback).
3. Pruebas de `InternalApiKeyFilter` (clave válida/ inválida / ausente / no configurada → 503 si aplica el mismo patrón MSPI).
4. Opcional: MockMvc standalone sobre `AuditApi` y `InternalAuditApi`.

Ejecución local desde la raíz de `ms_audit/`:

```bash
./gradlew test
```


## CI y cobertura (Bitbucket Pipelines)

El paso principal del pipeline ejecuta:

```bash
./gradlew clean test jacocoTestReport assemble
```

- **Pruebas unitarias**: obligatorias (el build de CI falla si hay tests en rojo).
- **Reportes**: se publican `**/build/test-results/**/*.xml` y reportes JaCoCo (`**/build/reports/jacoco*/**`).
- **Empaquetado**: se conserva `assemble` (artefactos en `build/libs/**` / `applications/**/build/libs/**`).
- **Umbral JaCoCo** (`jacocoTestCoverageVerification`, mínimo 0.90 INSTRUCTION sobre clases con tests asociados): **no se bajó**. El pipeline publica el reporte; la verificación local/gate de `check` puede fallar en servicios con deuda (ver abajo).

### Inventario local (este microservicio)

| Métrica | Valor |
|---|---|
| Suites / casos (JUnit XML) | 5 / 24 |
| Cobertura instrucciones (reporte merged / agregado) | 100% (módulos con reporte; conjunto acotado) |
| `jacocoTestCoverageVerification` | OK (≥90% en clases con pruebas unitarias asociadas) |

