# ms_audit — Pruebas

| Campo | Valor |
|---|---|
| Repositorio | `MSPI_NVA_CO_MR_BACK/ms_audit` |
| Fecha del documento | 2026-08-18 |
| Alcance | Estrategia de pruebas del repositorio `ms_audit` y de la funcionalidad de auditoría equivalente probada en `ms_iam`/`ms_assessment` |

---

## 1. Pruebas en `ms_audit`: ausencia total

`ms_audit` **no tiene ningún framework de pruebas configurado, ninguna carpeta `test/`, ni un solo archivo de prueba**, porque no tiene código fuente ni configuración de build (ver `01-Planificacion.md` y `04-Desarrollo.md`). No existe:

- Configuración de JUnit, Mockito, ni ningún *test runner*.
- Carpeta `src/test`.
- Pipeline de CI que ejecute pruebas (no hay pipeline de ningún tipo, ver `06-Implementacion-Despliegue.md`).
- Pruebas de contrato sobre `docs/openapi.yaml` (p. ej. Spectral, Dredd, Prism) — el archivo existe únicamente como documentación de referencia, sin validación automatizada.

Esta ausencia se declara explícitamente en cumplimiento de la instrucción de no inventar cobertura ni herramientas no verificadas en el repositorio.

## 2. Pruebas de la funcionalidad de auditoría real (verificadas en ms_iam)

La funcionalidad que `ms_audit` deberá eventualmente asumir **sí** cuenta con pruebas, en el repositorio donde está implementada. Se documentan aquí como referencia de la cobertura existente sobre el comportamiento que se migraría.

### 2.1 Frameworks verificados (en `ms_iam/build.gradle` y módulos)

| Framework / librería | Uso |
|---|---|
| JUnit 5 (Jupiter) | Motor de pruebas (`test { useJUnitPlatform() }`) |
| `spring-boot-starter-test` | Pruebas unitarias y de contexto (incluye Mockito, AssertJ) |
| Mockito | *Mocking* de gateways/puertos |
| `spring-security-test` | Simulación de contexto JWT para pruebas de API |

### 2.2 Prueba directamente relacionada con auditoría encontrada en el repositorio

```
ms_iam/infrastructure/driven-adapters/jpa-repository/src/test/java/co/com/mspi/jpa/adapter/AuthAuditAdapterTest.java
```

Esta es la **única** prueba unitaria dedicada específicamente al subdominio de auditoría localizada en el monorepo. Cubre el adaptador `AuthAuditAdapter`, responsable de persistir los eventos de autenticación propios de `ms_iam` (`AUTH_LOGIN_SUCCESS`, `AUTH_LOGIN_FAILED`, `AUTH_LOGIN_INACTIVE`).

### 2.3 Componentes del flujo de auditoría **sin** prueba unitaria dedicada encontrada

A partir de la búsqueda en el árbol de test de `ms_iam` y `ms_assessment`, no se encontraron pruebas dedicadas para:

- `InternalAuditApi` (controlador de ingesta) — no aparece en `infrastructure/entry-points/api-rest/src/test/java/co/com/mspi/api/` (esa carpeta solo lista pruebas para `auth`, `roles`, `users`, `config`, `exception`, ver `05-Pruebas.md` del piloto `ms_iam`).
- `RecordAuditEventUseCase` — no aparece en `domain/usecase/src/test/java/co/com/mspi/usecase/` (esa carpeta solo lista `login`, `totp`, `user`).
- `AuditEventAdapter` (distinto de `AuthAuditAdapterTest`, que prueba `AuthAuditAdapter`) — sin prueba dedicada localizada.
- `IamAuditGatewayAdapter` (el consumidor en `ms_assessment`) — sin prueba dedicada localizada en la carpeta de tests de `rest-consumer` de `ms_assessment`.

**Implicación relevante para un futuro `ms_audit`**: el flujo de ingesta de eventos de negocio (`ms_assessment` → `ms_iam`), que es exactamente el contrato que `ms_audit` deberá replicar o asumir, tiene la **menor cobertura de pruebas verificada** de todo el subdominio de auditoría. Si se reutiliza este código como base, se recomienda añadir pruebas antes o durante la migración, no después.

## 3. Pruebas de contrato / esquema

No se encontró evidencia de pruebas de contrato automatizadas (OpenAPI-driven testing, *consumer-driven contracts*, Pact, Spectral lint en CI) sobre `docs/openapi.yaml` de `ms_audit` ni de `ms_iam`. La validación del contrato es, hoy, completamente manual (lectura del archivo YAML).

## 4. Recomendaciones (declaradas como tales, no como hechos)

Dado que no existe implementación de `ms_audit`, no es posible recomendar mejoras de cobertura sobre código inexistente. Las recomendaciones aplicables son sobre el proceso de desarrollo futuro:

1. Si se implementa `ms_audit` reutilizando el diseño de `ms_iam` (arquitectura hexagonal Gradle multi-módulo, como sugiere la convención del resto del monorepo), se recomienda desde el inicio incluir pruebas unitarias del caso de uso de ingesta (equivalente a `RecordAuditEventUseCase`) y del futuro `QueryAuditEventsUseCase`/`ExportAuditLogUseCase`, dado que estos últimos son funcionalidad enteramente nueva sin precedente de código a reutilizar.
2. Se recomienda escribir pruebas del adaptador HTTP de ingesta (equivalente a `InternalAuditApi`) verificando explícitamente los códigos `202`, `400` (validación) y `401`/`503` (autenticación por `X-Internal-Api-Key`), ya que este comportamiento de error está documentado en `MIGRATION-NOTES.md` pero no se encontró prueba automatizada que lo confirme en el código actual de `ms_iam`.
3. Durante el periodo de *dual-write* planificado (`MIGRATION-NOTES.md`, paso 2), se recomienda una prueba de integración que verifique que un evento se registra correctamente en **ambos** destinos (`ms_iam` y `ms_audit`) o que, si uno falla, el comportamiento *best-effort* (RN-03 en `02-Analisis.md`) se preserva de forma consistente en los dos flujos.
