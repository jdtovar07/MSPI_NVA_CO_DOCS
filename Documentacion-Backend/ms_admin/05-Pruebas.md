# ms_admin — Pruebas

| Campo | Valor |
|---|---|
| Repositorio | `MSPI_NVA_CO_MR_BACK/ms_admin` |
| Estado | Activo |
| Alcance | Pruebas unitarias existentes y huecos en `src/test` |

---

## 0. Inventario actualizado de pruebas (desde el código)

**6 clases de prueba · 20 casos (`@Test`/`@ParameterizedTest`).** Este inventario prevalece sobre cualquier conteo anterior de este documento.

| Módulo | Clase de prueba | Casos | Tipo |
|---|---|---|---|
| `domain/usecase` | `GetSystemConfigHistoryUseCaseTest` | 1 | Unitaria |
| `domain/usecase` | `GetSystemConfigUseCaseTest` | 2 | Unitaria |
| `domain/usecase` | `UpdateSystemConfigUseCaseTest` | 2 | Unitaria |
| `infrastructure/entry-points/api-rest` | `CorsConfigTest` | 3 | Unitaria |
| `infrastructure/entry-points/api-rest` | `GlobalExceptionHandlerTest` | 8 | Unitaria |
| `infrastructure/entry-points/api-rest` | `TraceIdFilterTest` | 4 | Unitaria |

Ejecutar: `./gradlew test jacocoTestReport` desde la raíz del microservicio (reporte en `build/reports/jacoco`).

## 1. Frameworks

Plantilla Gradle MSPI: JUnit 5, `spring-boot-starter-test` (Mockito), JaCoCo enlazado a `check` cuando hay tests en el módulo.

## 2. Estructura real de tests (verificada)

```
domain/usecase/src/test/java/co/com/mspi/usecase/systemconfig/
├── GetSystemConfigUseCaseTest.java
├── UpdateSystemConfigUseCaseTest.java
└── GetSystemConfigHistoryUseCaseTest.java

infrastructure/entry-points/api-rest/src/test/java/co/com/mspi/api/
├── config/CorsConfigTest.java
├── config/TraceIdFilterTest.java
└── exception/GlobalExceptionHandlerTest.java
```

**Total: 6 clases de prueba** bajo `ms_admin/**/src/test/**`.

## 3. Cobertura por área

| Área | Estado | Detalle |
|---|---|---|
| `GetSystemConfigUseCase` | Presente | Defaults 30/15/5/5 y merge con valores existentes |
| `UpdateSystemConfigUseCase` | Presente | Incluye rechazo de días fuera de rango (p. ej. 0) |
| `GetSystemConfigHistoryUseCase` | Presente | `GetSystemConfigHistoryUseCaseTest` |
| `SystemAdminApi` / `InternalSystemConfigApi` | **No encontrado** | Sin MockMvc de controladores |
| `InternalApiKeyFilter` | **No encontrado** | TODO / verificar si se añade |
| Adaptador JPA `SystemConfig*` | **No encontrado** | Sin `src/test` en `jpa-repository` |
| CORS / TraceId / GlobalExceptionHandler | Presente | 3 tests transversales |
| Integración `@SpringBootTest` | **No encontrado** | |

## 4. Qué ejercitan los tests de dominio

- Aplicación de defaults cuando no hay fila o faltan claves.
- Persistencia mockeada en update con valores válidos.
- Validación de negocio: días fuera de **1–365** lanzan `BusinessRulesOnFieldsException`.
- Lectura de historial con gateway mockeado.

## 5. Recomendaciones

1. MockMvc de `PUT /system/config` (401/403 sin rol, 400 por validación, 200 feliz).
2. Test del filtro interno (clave válida/ inválida).
3. Mantener tests de usecase como quality gate mínimo en CI (`./gradlew test` / `check`).

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
| Suites / casos (JUnit XML) | 6 / 20 |
| Cobertura instrucciones (reporte merged / agregado) | 69.3% |
| `jacocoTestCoverageVerification` | FALLA — usecase INSTRUCTION 0.69 < 0.90 |
| Deuda de cobertura | jacocoTestCoverageVerification en `:usecase` (0.69). Umbral 0.90 sin bajar; ampliar pruebas de casos de uso admin. |
