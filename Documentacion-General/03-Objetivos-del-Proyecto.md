# Objetivos del Proyecto — MSPI

| | |
|---|---|
| **Proyecto** | MSPI: Sistema de Gestión de Seguridad y Privacidad de la Información basado en ISO/IEC 27001 |
| **Autores** | Bairon Alexander Suarez Camacho, Juan Diego Tovar Rodriguez |
| **Programa** | Ingeniería de Sistemas |
| **Documento** | Objetivos general y específicos, versión de referencia rápida para el asesor/profesor |
| **Fecha** | 2026-08-27 |

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
| 3 | Implementar el motor de calificación y cálculo automático de controles administrativos y técnicos del Anexo A de ISO/IEC 27001 (14 dominios, jerarquía de hasta cuatro niveles). | `ms_assessment` | ✅ Implementado |
| 4 | Implementar el cálculo del avance ponderado del ciclo PHVA (planificación 40 %, implementación 20 %, evaluación de desempeño 20 %, mejora continua 20 %). | `ms_assessment` | ✅ Implementado |
| 5 | Implementar el algoritmo de determinación del nivel de madurez del SGSI (progresión acumulativa de cinco niveles). | `ms_assessment` | ✅ Implementado |
| 6 | Implementar el módulo de evaluación frente al marco NIST CSF (cinco funciones). | `ms_assessment`, `mf_assessment` | ✅ Implementado |
| 7 | Implementar un tablero de diagnóstico consolidado (efectividad por dominio, avance PHVA, madurez, NIST, brechas priorizadas). | `ms_assessment`, `mf_reports` | ✅ Implementado |
| 8 | Implementar el subsistema de identidad y control de acceso (autenticación centralizada, 5 roles de negocio, 2FA/TOTP, auditoría centralizada). | `ms_iam`, `mf_auth` | ✅ Implementado |
| 9 | Implementar la generación de reportes de resultados (PDF/Excel), replicando la plantilla oficial de MinTIC. | `ms_reporting`, `mf_reports` | ⚠️ Implementado con limitaciones (ver hallazgos de `ms_reporting`) |

**Nota de trazabilidad:** los objetivos específicos 1–9 se derivan directamente de los ocho módulos funcionales documentados en `Historias_Usuario_MSPI_v2.md` y de los ocho sprints de `PLAN_TRABAJO_MSPI_v2.md` del repositorio backend. El estado "Implementado" indica que existe código funcional real verificado durante la elaboración de la documentación técnica (`Documentacion-Backend/`, `Documentacion-Frontend/`); no certifica ausencia de errores ni cobertura de pruebas completa — ver limitaciones en [`01-Arquitectura-General-del-Sistema.md`](01-Arquitectura-General-del-Sistema.md).

---

## Alcance explícitamente fuera de los objetivos actuales

Para que el profesor tenga claridad de frontera de alcance, se declara explícitamente qué **no** se implementó dentro del perímetro funcional actual, aunque la arquitectura lo contempla:

- **Administración general del sistema** — microservicio `ms_admin`: existe como carpeta *placeholder* (solo `README.md`, `docs/ROADMAP.md` y un stub de OpenAPI vacío), sin código ni API funcional.
- **Auditoría transversal consolidada** — microservicio `ms_audit`: también *placeholder*; la auditoría que sí opera en producción vive dentro de `ms_iam` (tabla `iam.audit_log`) y es consumida puntualmente por `ms_assessment`, no como un servicio independiente de auditoría transversal.

Ambos se documentan en detalle en `Documentacion-Backend/ms_admin/` y `Documentacion-Backend/ms_audit/`.

---

*Documento de referencia rápida — para el desarrollo completo de objetivos, ver la Propuesta de Grado y el Documento de Investigación referenciados arriba.*
