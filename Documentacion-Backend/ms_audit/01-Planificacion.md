# ms_audit — Planificación

| Campo | Valor |
|---|---|
| Repositorio | `MSPI_NVA_CO_MR_BACK/ms_audit` |
| Sistema | MSPI (Modelo de Seguridad y Privacidad de la Información — ISO/IEC 27001) |
| Fecha del documento | 2026-08-18 |
| Alcance | Fase de planificación del microservicio `ms_audit` dentro de la arquitectura de microservicios MSPI |

---

## 1. Naturaleza real del repositorio (hallazgo principal)

A diferencia del resto de microservicios del monorepo `MSPI_NVA_CO_MR_BACK` (`ms_iam`, `ms_org`, `ms_catalog`, `ms_evidence`, `ms_assessment`, `ms_admin`, `ms_reporting`), **`ms_audit` no es un microservicio implementado**. El repositorio contiene únicamente tres archivos:

```
ms_audit/
├── README.md               (200 líneas — placeholder documentado)
├── .gitignore               (plantilla genérica, sin personalizar)
└── docs/
    ├── MIGRATION-NOTES.md   (notas de integración del MVP actual)
    └── openapi.yaml         (contrato de referencia, marcado deprecated)
```

No existe `build.gradle`, `pom.xml`, `package.json`, `Dockerfile`, código fuente Java/Kotlin/TypeScript, ni carpeta `src/`. El propio `README.md` lo declara explícitamente en su primera línea de contenido: *"Repositorio placeholder para un futuro microservicio... Este repositorio no contiene código ni despliegue activo"*. Esta constatación se confirma de forma independiente en `docker-config/docker/docker-compose.apps.yml`, donde **no existe ningún servicio `ms-audit`** — a diferencia de `ms-iam`, `ms-org`, `ms-catalog`, `ms-evidence`, `ms-assessment` y `ms-admin`, que sí están orquestados.

Esta documentación, por tanto, no puede describir una "implementación de ms_audit" porque esta no existe. En su lugar, documenta con precisión:

1. **Qué existe hoy realmente** como funcionalidad de auditoría en el sistema MSPI (implementada en `ms_iam`, invocada por `ms_assessment`), que es lo que `ms_audit` está destinado a reemplazar/asumir.
2. **Qué se planificó** como arquitectura objetivo para `ms_audit` (diagramas Mermaid y tablas presentes en el propio `README.md` y `docs/MIGRATION-NOTES.md`).
3. **Qué pasos de migración** se dejaron documentados para el momento en que el microservicio se implemente.

## 2. Contexto del sistema MSPI

MSPI es un sistema de gestión de seguridad de la información construido como un conjunto de microservicios Java/Spring independientes que colaboran vía HTTP/REST y comparten un modelo de datos lógico (`docs/proyecto/DB-MER.txt`) particionado por esquema de base de datos (uno por microservicio: `iam`, `org`, `catalog`, `evidence`, `assessment`, `audit`, …). El repositorio contenedor `MSPI_NVA_CO_MR_BACK` agrupa cada microservicio como carpeta independiente, y `docker-config/` centraliza la orquestación local con Docker Compose.

Dentro de este modelo, **`audit` está reservado como esquema de base de datos y como nombre de microservicio futuro**, pero en el MVP la responsabilidad de auditoría —que el propio MER describe como *"Auditoría central (ms_iam o servicio dedicado futuro)"* (`DB-MER.txt`, línea 313)— fue absorbida temporalmente por `ms_iam`, que persiste la tabla `iam.audit_log` (no `audit.audit_log`).

## 3. Alcance planificado de `ms_audit` (según README y MIGRATION-NOTES)

El alcance documentado para la versión futura de `ms_audit` es:

- **Consulta** de la bitácora de auditoría (`GET /audit/events`) con filtros por evaluación (`assessmentId`), tipo de evento (`eventType`) y rango de fechas — funcionalidad que **no existe** en el MVP actual (`ms_iam` solo expone ingesta, no consulta).
- **Exportación** de la bitácora (`GET /audit/export`) para reportes de auditoría/cumplimiento.
- **Ingesta** de eventos de auditoría (`POST /internal/audit/events`), migrada eventualmente desde `ms_iam`, con periodo de *dual-write* durante la transición.
- **Retención** de datos históricos (mencionada como objetivo en el README: "consultas, exportación, retención, separación de responsabilidades"), sin que exista aún una política de retención documentada con valores concretos (días/años).

Quedan **fuera de alcance** — y siguen siéndolo hasta que el microservicio se implemente —: la generación de los eventos de negocio (responsabilidad de los microservicios productores: `ms_assessment`, `ms_iam`, `ms_org`), la autenticación de usuarios (`ms_iam`) y el análisis/reporting agregado (`ms_reporting`, `ms_admin` como consumidores potenciales).

## 4. Objetivos (planificados, no ejecutados)

1. Separar la responsabilidad de auditoría de `ms_iam`, que hoy la absorbe junto con su función principal de identidad y acceso, para reducir el acoplamiento y permitir que la bitácora crezca (en volumen y en consultas) sin afectar el rendimiento del servicio de autenticación.
2. Ofrecer un punto único de **consulta** de trazabilidad para todo el ecosistema MSPI (evaluaciones, cambios de configuración, autenticación), hoy inexistente porque `ms_iam` solo implementa el lado de ingesta.
3. Habilitar `ms_admin` y un futuro *frontend* de soporte como consumidores de reportes de auditoría sin necesidad de acceso directo a la base de datos de `ms_iam`.
4. Mantener compatibilidad temporal (dual-write o *feature flag*) con el endpoint `POST /internal/audit/events` de `ms_iam` durante la transición, evitando una migración disruptiva para los productores de eventos ya integrados (`ms_assessment`).
5. Preservar el mismo contrato de datos (`AuditEventRequest`) documentado en `docs/openapi.yaml` de `ms_iam`, para minimizar cambios en los adaptadores existentes (`IamAuditGatewayAdapter`) cuando se apunte a `ms_audit`.

## 5. Requerimientos identificados (a partir de README y MIGRATION-NOTES)

- **RI-1** — El microservicio debe implementar como mínimo el mismo contrato de ingesta que hoy expone `ms_iam` (`POST /internal/audit/events`, autenticación `X-Internal-Api-Key`), para no romper a los productores existentes.
- **RI-2** — Debe exponer una API de consulta paginada y filtrable (`GET /audit/events`) protegida con JWT y restringida al rol `AdminSistema`, según el diagrama de flujo "consulta de bitácora (futuro)" del README.
- **RI-3** — Debe soportar exportación de la bitácora (`GET /audit/export`), mencionada en la arquitectura objetivo pero sin contrato HTTP detallado (parámetros, formato de salida) documentado aún.
- **RI-4** — Debe definirse un mecanismo de migración de datos (*backfill*) desde `iam.audit_log` hacia el esquema `audit` si el modelo de datos destino difiere del actual, según el paso 3 de la sección "Migración futura a ms_audit" de `MIGRATION-NOTES.md`.
- **RI-5** — Los productores actuales (`ms_assessment` vía `IamAuditGatewayAdapter`, y el propio `ms_iam` para sus eventos `AUTH_LOGIN_*`) deben poder redirigirse a `ms_audit` cambiando únicamente una URL base (`MS_IAM_URL` → `MS_AUDIT_URL`), sin cambios de contrato.
- **RI-6** — Una vez migrado, `ms_iam` debe **deprecar** su endpoint `POST /internal/audit/events` (paso 5 de la migración futura), lo cual implica coordinación de versiones entre ambos repositorios.

Estos requerimientos son **inferencias documentadas a partir de las fuentes existentes**, no un backlog formal: no hay historias de usuario, tickets ni criterios de aceptación específicos de `ms_audit` en el repositorio.

## 6. Stack tecnológico

**No hay stack tecnológico propio de `ms_audit` que verificar**, porque no existe código ni configuración de build. No se puede afirmar, por ejemplo, que use Spring Boot, Gradle o Java, aunque es la suposición más razonable dado que:

- Todos los demás microservicios del monorepo (`ms_iam`, `ms_org`, `ms_catalog`, `ms_evidence`, `ms_assessment`, `ms_admin`) están construidos en Java 21 + Spring Boot + Gradle multi-módulo con arquitectura hexagonal.
- El `docs/openapi.yaml` de `ms_audit` usa las mismas convenciones (`ErrorResponseRef`, `CorrectResponse` implícito, seguridad `internalApiKey`) que el resto de contratos MSPI, generados desde controladores Spring MVC equivalentes.

Esta documentación **no asume** que la implementación futura replicará ese stack; solo señala que es la convención dominante en el resto del sistema, en caso de que el equipo decida mantener consistencia tecnológica.

| Componente | Estado |
|---|---|
| Lenguaje / framework | No definido (sin código) |
| Build | No definido (sin `build.gradle`/`pom.xml`) |
| Base de datos | Esquema `audit` reservado en `DB-MER.txt`, sin tabla física definida para `ms_audit` (solo existe `iam.audit_log` en `ms_iam`) |
| Contenedor / Docker | Sin `Dockerfile`; sin entrada en `docker-compose.apps.yml` |
| CI/CD | Sin pipeline propio |
| Documentación de contrato | OpenAPI 3.1.0 (`docs/openapi.yaml`), con todos los `operationId` marcados `deprecated: true` y apuntando por `externalDocs` al contrato real de `ms_iam` |

## 7. Recursos y planificación del desarrollo

No existe cronograma, backlog, `ROADMAP.md` ni estimación de esfuerzo específicos de `ms_audit` en el repositorio (a diferencia de `ms_admin/docs/ROADMAP.md`, que sí existe para otro microservicio del mismo monorepo). La única "planificación" verificable son los **pasos de migración enumerados en `docs/MIGRATION-NOTES.md`, sección 7**:

1. Implementar ingesta equivalente (mismo contrato o versión v2).
2. Periodo de *dual-write* (`ms_assessment` → `ms_iam` **y** `ms_audit`) o *feature flag*.
3. *Backfill* histórico desde `iam.audit_log` si el esquema destino difiere.
4. Cambiar `MS_IAM_URL` por `MS_AUDIT_URL` en los productores.
5. Deprecar `POST /internal/audit/events` en `ms_iam` tras validación.

Estos pasos constituyen la única guía de planificación disponible; no incluyen fechas, responsables ni hitos. El documento cierra con una instrucción operativa explícita: *"Hasta completar esos pasos, no apuntar integraciones nuevas a ms_audit"*, lo cual confirma que, a la fecha de este documento (2026-08-18), el equipo decidió **no iniciar** la implementación dentro del alcance del proyecto de grado.

## 8. Actores interesados (stakeholders) inferidos

| Actor | Interés en `ms_audit` (futuro) |
|---|---|
| `AdminSistema` | Consumidor previsto de `GET /audit/events` para trazabilidad y cumplimiento ISO 27001 |
| `ms_assessment` | Productor actual de eventos de negocio (`ASSESSMENT_PUBLISHED`, `ENTITY_ORDER_TYPE_CHANGED`) vía `IamAuditGatewayAdapter`; sería re-apuntado a `ms_audit` cuando exista |
| `ms_iam` | Implementación actual (transitoria) de la responsabilidad de auditoría; futuro productor de sus propios eventos de autenticación hacia `ms_audit` |
| `ms_org` | Productor futuro potencial ("otros productores futuros" en el diagrama de arquitectura objetivo), sin integración actual |
| `ms_admin` | Consumidor futuro potencial de reportes administrativos de auditoría |
| Frontend de soporte | Consumidor futuro potencial de la API de consulta (`GET /audit/events`) |
| Equipo DevOps / DBA | Responsable de decidir y ejecutar la migración de `iam.audit_log` al esquema `audit` cuando se implemente el microservicio |

## 9. Relación con otros repositorios del monorepo

| Repositorio | Rol respecto a `ms_audit` |
|---|---|
| `ms_iam` | Implementación **actual y real** de la funcionalidad de auditoría (`InternalAuditApi`, `RecordAuditEventUseCase`, `AuditLogEntity`, tabla `iam.audit_log`) — ver `02-Analisis.md` y `03-Diseno.md` de este documento para el detalle |
| `ms_assessment` | Único productor de eventos de negocio verificado en código (`IamAuditGatewayAdapter`, `IamAuditGateway`) |
| `ms_admin` | Consumidor futuro mencionado en el README, sin integración verificable en su código actual |
