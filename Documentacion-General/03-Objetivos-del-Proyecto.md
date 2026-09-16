# Objetivos del Proyecto — MSPI

| | |
|---|---|
| **Proyecto** | MSPI: Sistema de Gestión de Seguridad y Privacidad de la Información basado en ISO/IEC 27001 |
| **Autores** | Bairon Alexander Suarez Camacho, Juan Diego Tovar Rodriguez |
| **Programa** | Ingeniería de Sistemas |
| **Documento** | Objetivos general y específicos, versión de referencia rápida para el asesor/profesor |

> Este documento es un extracto de referencia rápida de los objetivos del proyecto. La versión formal, integrada con planteamiento del problema, justificación y marco referencial completo, está en [`Propuesta-grado/Propuesta_de_Grado_MSPI.docx`](../Propuesta-grado/Propuesta_de_Grado_MSPI.docx) (plantilla institucional CORHUILA). El sustento de evidencia detallado de cada objetivo está en [`Documentacion-investigacion/Documento-Investigacion.md`](../Documentacion-investigacion/Documento-Investigacion.md), secciones 5 y 10.

---

## Objetivo general

> Diseñar e implementar una plataforma de software basada en arquitectura de microservicios (backend) y microfrontends (frontend) que automatice el Instrumento de Identificación de la Línea Base de Seguridad MSPI de MinTIC, reproduciendo con exactitud sus reglas de cálculo de efectividad de controles ISO/IEC 27001, avance del ciclo PHVA, nivel de madurez del SGSI y desempeño frente al marco NIST CSF, con trazabilidad de evidencias y control de acceso basado en roles.

---

## Objetivos específicos

| # | Objetivo específico | Módulo(s) / microservicio(s) que lo materializan | Estado |
|---|---|---|---|
| 1 | Implementar el módulo de configuración y levantamiento de información (creación de evaluaciones, clasificación por tipo de entidad, registro de contexto organizacional y 43 ítems de evidencia documental). | `ms_evidence`, `mf_evidence` | ✅ Implementado |
| 2 | Implementar el módulo de asignación de áreas y responsables, vinculando funcionarios a los ocho ejes de seguridad predefinidos. | `ms_assessment`, `mf_assessment` | ✅ Implementado |
| 3 | Implementar el motor de calificación y cálculo automático de controles administrativos y técnicos del Anexo A de ISO/IEC 27001 (jerarquía de hasta cuatro niveles; v1 hasta 14 dominios 2013; v2 temas A.5–A.8 / ~93 controles 2022). | `ms_assessment` | ✅ Implementado |
| 4 | Implementar el cálculo del avance ponderado del ciclo PHVA (planificación 56 %, implementación 16 %, evaluación de desempeño 14 %, mejora continua 14 %), alineado al Autodiagnóstico MSPI / plantilla `template_version` v2. | `ms_assessment` | ✅ Implementado |
| 5 | Implementar el algoritmo de determinación del nivel de madurez del SGSI (progresión acumulativa de cinco niveles). | `ms_assessment` | ✅ Implementado |
| 6 | Implementar el módulo de evaluación frente al marco NIST CSF 2.0 (seis funciones, incluyendo Gobernar / GV). | `ms_assessment`, `mf_assessment` | ✅ Implementado |
| 7 | Implementar un tablero de diagnóstico consolidado (efectividad por dominio, avance PHVA, madurez, NIST, brechas priorizadas). | `ms_assessment`, `mf_assessment` | ✅ Implementado (hub único en la evaluación; `mf_reports` solo exporta PDF/Excel) |
| 8 | Implementar el subsistema de identidad y control de acceso (autenticación centralizada, 5 roles de negocio, 2FA/TOTP, auditoría centralizada). | `ms_iam`, `mf_auth` | ✅ Implementado |
| 9 | Implementar la generación de reportes de resultados (PDF/Excel), replicando la plantilla oficial de MinTIC. | `ms_reporting`, `mf_reports` | ✅ Implementado: instrumento oficial completo (11 hojas) en Excel protegido y PDF; pendiente la verificación final en vivo |

Matriz detallada objetivo → evidencia en código: [`18-Matriz-Trazabilidad.md`](18-Matriz-Trazabilidad.md).

**Nota de trazabilidad:** los objetivos específicos 1–9 se derivan directamente de los ocho módulos funcionales documentados en `Historias_Usuario_MSPI_v2.md` y de los ocho sprints de `PLAN_TRABAJO_MSPI_v2.md` del repositorio backend. El estado "Implementado" indica que existe código funcional real verificado durante la elaboración de la documentación técnica (`Documentacion-Backend/`, `Documentacion-Frontend/`); no certifica ausencia de errores ni cobertura de pruebas completa — ver limitaciones en [`01-Arquitectura-General-del-Sistema.md`](01-Arquitectura-General-del-Sistema.md).

---

## Capacidades transversales añadidas al alcance

Además de los nueve objetivos específicos, la plataforma incorporó dos microservicios transversales que
originalmente estaban solo previstos en la arquitectura y que hoy están **implementados y en operación**:

| Capacidad | Microservicio | Qué aporta |
|---|---|---|
| Auditoría transversal consolidada | `ms_audit` (:8088, esquema `audit`) | Bitácora central de eventos de todos los servicios y línea de tiempo por radicado `SOL-*` |
| Administración general del sistema | `ms_admin` (:8089, esquema `admin`) | Parámetros globales versionados (plazos, días de gracia, tipos de archivo) con historial |

También se agregaron las **solicitudes aprobables** con radicado (ampliación, eliminación lógica con periodo de
gracia, eliminación de catálogo y reenvío de contraseña con reinicio de 2FA). Detalle en
[`14-Flujos-Solicitudes-Auditoria-y-Seguridad.md`](14-Flujos-Solicitudes-Auditoria-y-Seguridad.md).

## Fuera de alcance

- Despliegue productivo en una entidad real (el proyecto se valida con datos de prueba).
- Composición de microfrontends con Module Federation (la composición actual es iframe + `postMessage`).
- Integración con sistemas externos de la entidad (directorio activo, gestor documental).

---

*Documento de referencia rápida — para el desarrollo completo de objetivos, ver la Propuesta de Grado y el Documento de Investigación referenciados arriba.*
