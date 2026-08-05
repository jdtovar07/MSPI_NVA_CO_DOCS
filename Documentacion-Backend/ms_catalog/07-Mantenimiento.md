# ms_catalog — Mantenimiento

| Campo | Valor |
|---|---|
| Repositorio | `MSPI_NVA_CO_MR_BACK/ms_catalog` |
| Fecha del documento | 2026-08-19 |
| Alcance | Mantenimiento, versionado, monitoreo y mejoras futuras del microservicio `ms_catalog`, basado en evidencia real del repositorio |

---

## 1. Versionado

- **Versión de API**: `docs/openapi.yaml` declara `info.version: 1.0.0`. No se encontró un historial de versiones anteriores ni un `CHANGELOG.md` propio de `ms_catalog`.
- **Versionado de contenido del instrumento**: el modelo de datos sí soporta versionado explícito vía `template.id` → `template_version.version` (entero incremental) y `status` (`DRAFT`/`PUBLISHED`), análogamente para `scale`/`scale_version`. Sin embargo, la API solo expone la resolución de la versión `PUBLISHED` más reciente (`findFirstByStatusOrderByPublishedAtDesc`); no hay endpoint para listar o comparar versiones históricas.
- **Versionado de dependencias**: fijado centralmente en `build.gradle` raíz (`springBootVersion = '4.0.2'`, `lombokVersion = '1.18.42'`, `jacocoVersion = '0.8.14'`, `pitestVersion = '1.19.0-rc.3'`, `sonarVersion = '7.2.2.6593'`) y heredado por todos los subproyectos vía `main.gradle`, evitando desalineación de versiones entre módulos.
- **Gradle wrapper**: fijado a `9.3.0` (`tasks.named('wrapper') { gradleVersion = '9.3.0' }`), asegurando reproducibilidad de build entre entornos.

## 2. Gestión del contenido del catálogo (proceso de mantenimiento real)

Dado que no hay API de escritura, cualquier cambio al contenido del instrumento (nuevo control, ajuste de pesos PHVA, nuevo requisito de madurez, actualización de metas NIST) requiere:

1. Editar directamente `schema.sql` (si hay cambio estructural) y/o los seeds `data.sql` / `nist_ciber_data.sql` / `maturity_data.sql`.
2. Aplicar el script SQL manualmente contra la base de datos del entorno correspondiente (no hay Flyway/Liquibase ni ninguna herramienta de migración versionada evidenciada; `spring.jpa.hibernate.ddl-auto: none` y `spring.sql.init.mode: never` confirman que Spring Boot no participa de este proceso).
3. Publicar una nueva `template_version` (`status = PUBLISHED`, `published_at` actual) para que `GetActiveTemplateVersionUseCase` la resuelva como activa; no hay endpoint ni script documentado para automatizar este paso — se infiere que se realiza por `UPDATE`/`INSERT` SQL directo.

Existe un script auxiliar `applications/app-service/src/main/resources/gen_maturity_seeds.py` (Python) para generar los `INSERT` de `maturity_data.sql`, evidencia de que al menos parte de la carga de datos de madurez se generó programáticamente a partir de una fuente externa (probablemente la hoja de cálculo/Excel de línea base ISO 27001 del proyecto), en lugar de escribirse el SQL a mano.

Este proceso manual concentra un **riesgo operativo real**: un error en el script SQL aplicado directamente en producción no pasa por ninguna validación de aplicación (no hay pruebas de `CatalogJpaAdapter` que detecten un `JSONB` mal formado antes de llegar a producción, ver `05-Pruebas.md`).

## 3. Monitoreo y observabilidad

| Elemento | Detalle | Evidencia |
|---|---|---|
| Health check | `GET /actuator/health`, público, usado por `Dockerfile HEALTHCHECK` (cada 30s, timeout 5s, gracia de arranque 90s, 3 reintentos) | `Dockerfile`, `SecurityConfig` |
| Info | `GET /actuator/info`, público | `SecurityConfig.permitAll()` |
| Trazabilidad HTTP | Cabecera `X-Trace-Id` generada o propagada por `TraceIdFilter`, registrada en MDC y en logs de inicio/fin de cada petición (método, ruta, estado, duración) | `TraceIdFilter.java` |
| Logs | Configuración estándar de Spring Boot vía `logback.xml` (`applications/app-service/src/main/resources/logback.xml`) | Presente en el repositorio |
| Métricas | No se encontró `micrometer-registry-prometheus` ni ningún endpoint `/actuator/metrics` o `/actuator/prometheus` habilitado explícitamente en `api-rest/build.gradle` (solo `spring-boot-starter-actuator`, sin registro Prometheus) | Ausencia confirmada por inspección de dependencias |
| Alertas | No se encontró configuración de alertas (ni en el repositorio ni referenciada en `docker-config/docs/`) | Ausencia declarada explícitamente |

**Nota comparativa**: a diferencia del piloto `ms_iam`, cuyo stack tecnológico documentado incluye Micrometer + Prometheus registry, `ms_catalog` **no declara esta dependencia** en ninguno de sus `build.gradle`; su observabilidad se limita a `/actuator/health`, `/actuator/info` y logging estructurado con `X-Trace-Id`.

## 4. Errores y resiliencia

- **Manejo de errores centralizado** vía `GlobalExceptionHandler`, con `traceId` de correlación reutilizado del `MDC` de `TraceIdFilter` (ver `04-Desarrollo.md` §4 para la discrepancia entre este `traceId` y el `meta.traceId` generado ad-hoc en el camino de éxito).
- **Sin mecanismos de resiliencia** (no hay Resilience4j, *circuit breaker*, *retry* ni *timeout* configurado explícitamente para las consultas JPA) — coherente con que `ms_catalog` no realiza llamadas salientes a otros servicios; su única dependencia externa síncrona es PostgreSQL.
- **Timeouts explícitos solo en la resolución del JWK set** de Keycloak (`SimpleClientHttpRequestFactory`: conexión 15s, lectura 30s en `SecurityConfig.jwtDecoder()`), no en las consultas a base de datos.

## 5. Deuda técnica identificada (para mantenimiento futuro)

Consolidado de los hallazgos documentados en los capítulos anteriores, priorizado por impacto:

1. **Cobertura de pruebas prácticamente nula fuera de `:api-rest`** (`05-Pruebas.md`): los 17 casos de uso y el adaptador de persistencia (parsers JSON manuales incluidos) no tienen ninguna prueba. Es el ítem de mayor riesgo dado que concentra toda la lógica de negocio real del microservicio.
2. **Parser JSON manual en `CatalogJpaAdapter`** (`extractJsonInt`, `parseStringListJson`, etc.) en lugar de `ObjectMapper`: funcional pero frágil ante cambios de formato de las columnas `JSONB`; reemplazarlo por deserialización tipada reduciría el riesgo de fallos silenciosos.
3. **Discrepancia README vs. código sobre `InternalApiKeyFilter`** (`02-Analisis.md` §5): el README afirma que no hay API interna/API key, pero el filtro existe y está activo en la cadena de seguridad. Debe resolverse documentando la intención real o removiendo el filtro si es código muerto/obsoleto.
4. **Pipeline de CI sin `test`/`check`**: el build de Bitbucket Pipelines solo ejecuta `assemble`, por lo que errores de compilación de pruebas o regresiones de cobertura no bloquean el despliegue.
5. **Excepciones y DTOs de dominio no relacionados con catálogo** (`IamServiceException`, `UserAlreadyExistsException` en `:common`) sin uso real en este microservicio: limpieza de código heredado de la plantilla compartida entre microservicios MSPI.
6. **Ausencia de proceso versionado de publicación de plantilla** (no hay endpoint ni migración automatizada para promover una `template_version` de `DRAFT` a `PUBLISHED`): todo el ciclo de vida del contenido depende de SQL manual sin trazabilidad de quién/cuándo lo aplicó más allá de los propios `created_at`/`published_at` de las tablas.
7. **Sin métricas Prometheus**: a diferencia de otros microservicios del sistema, no hay superficie de métricas más allá de `/actuator/health`/`/actuator/info`.

## 6. Mejoras futuras razonables (no implementadas, inferidas del análisis)

- Automatizar la carga y publicación de `template_version` mediante un script versionado o una API administrativa protegida por rol, sustituyendo el proceso manual actual de SQL directo.
- Introducir Flyway o Liquibase para gestionar `schema.sql` como migraciones incrementales versionadas, en lugar de un único archivo con `ALTER TABLE ... ADD COLUMN IF NOT EXISTS` acumulativos.
- Añadir pruebas unitarias a `domain/usecase` y `CatalogJpaAdapter` como prerrequisito para poder activar `check` (y por tanto la verificación de cobertura del 80%) en el pipeline de CI sin bloquear despliegues legítimos.
- Evaluar la necesidad real de mantener `InternalApiKeyFilter`: si el acceso S2S sin JWT de usuario es una capacidad deseada, documentarla y probarla explícitamente; si no, retirarla para reducir superficie de ataque.
- Considerar caché de lectura (p. ej. Caffeine en memoria, dado el volumen acotado de datos) para los catálogos que cambian con muy baja frecuencia (`iso-domains`, `steward-roles`, `entity-order-types`), ya que hoy cada petición reconsulta PostgreSQL sin ningún nivel de caché.

## 7. Ausencias explícitas

- No se encontró `CHANGELOG.md`, `ROADMAP.md` ni bitácora de incidentes/postmortems propia de `ms_catalog` en el repositorio.
- No se encontró documentación de SLA/SLO ni de capacidad esperada (RPS, latencia objetivo) para este microservicio.
- No se encontró un procedimiento documentado de *rollback* de una `template_version` publicada incorrectamente.
