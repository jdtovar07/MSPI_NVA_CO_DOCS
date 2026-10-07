# Índice General de Documentación — Proyecto de Grado MSPI

| | |
|---|---|
| **Proyecto** | MSPI: Sistema de Gestión de Seguridad y Privacidad de la Información basado en ISO/IEC 27001 |
| **Autores** | Bairon Alexander Suarez Camacho, Juan Diego Tovar Rodriguez |
| **Programa** | Ingeniería de Sistemas |
| **Fecha** | 2026-08-27 (índice inicial); **última revisión API/código** 2026-10-07 |

Este índice es el punto de entrada único de toda la documentación generada para el proyecto de grado. Está pensado para que el profesor/asesor pueda revisar el trabajo de lo general a lo particular, sin necesidad de explorar el código fuente directamente.

---

## 1. Documento formal de propuesta de grado

📄 [**`Propuesta-grado/Propuesta_de_Grado_MSPI.docx`**](../Propuesta-grado/Propuesta_de_Grado_MSPI.docx)

Documento en la plantilla institucional CORHUILA, con portada, resumen (español/inglés), planteamiento del problema, justificación, objetivos, marco referencial (antecedentes, teórico, normativo), metodología, resultados y discusión, conclusiones, recomendaciones y referencias. **Es el documento formal a radicar**; contiene marcadores `[PENDIENTE: ...]` en los puntos que solo los autores o la coordinación académica pueden completar (director asignado, facultad, grupo de investigación, cronograma con fechas exactas, referencias bibliográficas adicionales).

## 2. Documento de investigación (fundamento académico ampliado)

📄 [**`Documentacion-investigacion/Documento-Investigacion.md`**](../Documentacion-investigacion/Documento-Investigacion.md)

Versión extendida y más detallada del componente investigativo (12 secciones), con citas explícitas a los archivos del repositorio que sustentan cada afirmación. Es la fuente de la que se derivó el contenido de la propuesta formal; útil como material de consulta y como respaldo de trazabilidad ante preguntas del asesor o del jurado.

## 3. Documentación general del sistema (arquitectura y dominio)

Carpeta `Documentacion-General/` (esta misma carpeta):

| Documento | Contenido |
|---|---|
| [`01-Arquitectura-General-del-Sistema.md`](01-Arquitectura-General-del-Sistema.md) | Arquitectura completa del sistema: diagrama C4 de contenedores, tabla de los 8 microservicios y 6 microfrontends, diagrama de despliegue Docker, arquitectura de seguridad (Keycloak/JWT/RBAC/2FA/auditoría), capas hexagonales, decisiones arquitectónicas y deuda técnica conocida. |
| [`02-Modelo-de-Dominio.md`](02-Modelo-de-Dominio.md) | Los 7 dominios (bounded contexts) del sistema + 2 placeholders, entidades principales con atributos reales, diagrama entidad-relación consolidado, patrón catálogo-vs-ejecución, mapa de módulos funcionales → microservicios y glosario de dominio (SGSI, PHVA, Anexo A, NIST CSF, etc.). |
| [`03-Objetivos-del-Proyecto.md`](03-Objetivos-del-Proyecto.md) | Objetivo general y objetivos específicos en formato de referencia rápida, con trazabilidad a los módulos que los implementan y su estado real (implementado / con limitaciones / no implementado). |
| [MER-MSPI (dbdocs)](https://dbdocs.io/jdtovar-2021a/MER-MSPI) | Modelo entidad-relación interactivo de PostgreSQL (esquemas `iam`, `org`, `catalog`, `assessment`, `evidence`, `reporting`). Fuente local: [`MER-MSPI.sql`](MER-MSPI.sql), [`MER-MSPI.dbml`](MER-MSPI.dbml) (DBML actualizado 1:1 con el DDL real ejecutado) y [`MER-MSPI.pdf`](MER-MSPI.pdf). |
| [`04-Decisiones-Tecnicas-Complementarias.md`](04-Decisiones-Tecnicas-Complementarias.md) | Decisiones técnicas puntuales tomadas en la implementación de RBAC fino, catálogo (escalas/bancos de preguntas) y funcionalidades administrativas de `ms_iam` |
| [`05-Manual-Despliegue.md`](05-Manual-Despliegue.md) | Cómo levantar el stack completo en Docker paso a paso |
| [`06-Guia-Pruebas-Funcionales.md`](06-Guia-Pruebas-Funcionales.md) | Secuencia de flujos funcionales end-to-end para demostrar el sistema |
| [`07-Manual-Usuario.md`](07-Manual-Usuario.md) | Qué puede hacer cada rol, en lenguaje de usuario final |
| [`08-Referencia-API.md`](08-Referencia-API.md) | Índice consolidado de la API de los 6 microservicios (rutas verificadas contra `*Api.java`, 2026-10-07) |

Estos documentos son el **punto de entrada recomendado para el profesor**: en menos de 30 minutos de lectura dan una visión completa de qué se construyó, cómo está arquitecturado y qué dominios de negocio cubre, sin tener que leer los 99 documentos técnicos detallados por componente.

## 4. Documentación técnica detallada por componente (ciclo de vida completo)

Cada uno de los 8 microservicios backend y los 6 microfrontends tiene **7 documentos propios**, uno por cada fase del ciclo de vida del desarrollo de software (Planificación → Análisis → Diseño → Desarrollo → Pruebas → Implementación/Despliegue → Mantenimiento), construidos a partir de la lectura directa del código fuente real de cada repositorio.

### 4.1 Backend — `Documentacion-Backend/` (8 microservicios × 7 documentos = 56 documentos)

| Microservicio | Estado | Carpeta |
|---|---|---|
| `ms_iam` — Identidad, autenticación, 2FA, auditoría | ✅ Activo | [`Documentacion-Backend/ms_iam/`](../Documentacion-Backend/ms_iam/) |
| `ms_org` — Organizaciones y geografía | ✅ Activo | [`Documentacion-Backend/ms_org/`](../Documentacion-Backend/ms_org/) |
| `ms_catalog` — Catálogo versionado de controles, escalas, PHVA, madurez, NIST | ✅ Activo | [`Documentacion-Backend/ms_catalog/`](../Documentacion-Backend/ms_catalog/) |
| `ms_assessment` — Ciclo de vida de evaluaciones y motor de cálculo | ✅ Activo | [`Documentacion-Backend/ms_assessment/`](../Documentacion-Backend/ms_assessment/) |
| `ms_evidence` — Contexto organizacional y evidencias documentales | ✅ Activo | [`Documentacion-Backend/ms_evidence/`](../Documentacion-Backend/ms_evidence/) |
| `ms_reporting` — Generación asíncrona de reportes PDF/Excel | ✅ Activo (con limitaciones) | [`Documentacion-Backend/ms_reporting/`](../Documentacion-Backend/ms_reporting/) |
| `ms_admin` — Administración general | ⚠️ Placeholder, sin código | [`Documentacion-Backend/ms_admin/`](../Documentacion-Backend/ms_admin/) |
| `ms_audit` — Auditoría transversal | ⚠️ Placeholder, sin código | [`Documentacion-Backend/ms_audit/`](../Documentacion-Backend/ms_audit/) |

### 4.2 Frontend — `Documentacion-Frontend/` (6 microfrontends × 7 documentos = 42 documentos)

| Microfrontend | Puerto | Carpeta |
|---|---|---|
| `mf_shell` — Host/orquestador | 4200 | [`Documentacion-Frontend/mf_shell/`](../Documentacion-Frontend/mf_shell/) |
| `mf_auth` — Autenticación, 2FA, usuarios | 4201 | [`Documentacion-Frontend/mf_auth/`](../Documentacion-Frontend/mf_auth/) |
| `mf_org` — Organizaciones | 4202 | [`Documentacion-Frontend/mf_org/`](../Documentacion-Frontend/mf_org/) |
| `mf_assessment` — Evaluación (áreas, controles, PHVA, madurez, NIST) | 4203 | [`Documentacion-Frontend/mf_assessment/`](../Documentacion-Frontend/mf_assessment/) |
| `mf_evidence` — Contexto y levantamiento de evidencias | 4204 | [`Documentacion-Frontend/mf_evidence/`](../Documentacion-Frontend/mf_evidence/) |
| `mf_reports` — Reportes y brechas | 4205 | [`Documentacion-Frontend/mf_reports/`](../Documentacion-Frontend/mf_reports/) |

Cada uno de los 14 componentes tiene la misma estructura interna:

```
01-Planificacion.md
02-Analisis.md
03-Diseno.md
04-Desarrollo.md
05-Pruebas.md
06-Implementacion-Despliegue.md
07-Mantenimiento.md
```

---

## 5. Cómo se construyó esta documentación (nota de método)

Toda la documentación técnica detallada (sección 4) y la documentación general (sección 3) se construyó **a partir de la lectura directa del código fuente real** de los repositorios `MSPI_NVA_CO_MR_BACK` y `MSPI_NVA_CO_MR_FRONT` — no es contenido genérico ni una plantilla rellenada por adivinanza. Cuando un dato no pudo confirmarse en el código (por ejemplo, cobertura real de pruebas, existencia de CI/CD, o alcance normativo exacto), se declaró explícitamente como ausente o como `[PENDIENTE: a completar por los autores]`, en vez de inventarse. Esto incluye hallazgos honestos y relevantes para la sustentación, entre ellos:

- **`ms_admin` y `ms_audit`** son carpetas *placeholder* sin código funcional, aunque la arquitectura los contempla.
- **Ningún microfrontend** tiene pruebas automatizadas verificadas (sin `*.spec.ts` ni configuración Karma/Jest).
- La integración de microfrontends **no usa Module Federation** de Webpack (como sí lo especifica el plan de trabajo v2), sino composición por `iframe` + `postMessage` + almacenamiento compartido — confirmado en los 6 microfrontends.
- El backend define pruebas y umbrales de cobertura (JaCoCo 80 %) en Gradle, pero el pipeline de CI (`bitbucket-pipelines.yml`) solo ejecuta `assemble`, nunca `test`/`check`.
- El instrumento fuente usa ISO/IEC 27001:**2013**, mientras la versión vigente de la norma es **2022**.

Estos hallazgos están documentados con detalle y trazabilidad en cada componente afectado (sección 4) y consolidados en [`01-Arquitectura-General-del-Sistema.md`](01-Arquitectura-General-del-Sistema.md) (sección de deuda técnica) y en las conclusiones del [Documento de Investigación](../Documentacion-investigacion/Documento-Investigacion.md).

---

## 6. Recomendación de orden de lectura para el profesor

1. [`Propuesta-grado/Propuesta_de_Grado_MSPI.docx`](../Propuesta-grado/Propuesta_de_Grado_MSPI.docx) — documento formal completo.
2. [`03-Objetivos-del-Proyecto.md`](03-Objetivos-del-Proyecto.md) — qué se propuso lograr.
3. [`01-Arquitectura-General-del-Sistema.md`](01-Arquitectura-General-del-Sistema.md) — cómo está construido.
4. [`02-Modelo-de-Dominio.md`](02-Modelo-de-Dominio.md) — qué dominios de negocio cubre.
5. [MER-MSPI (dbdocs)](https://dbdocs.io/jdtovar-2021a/MER-MSPI) — modelo físico de la base de datos (también [`MER-MSPI.sql`](MER-MSPI.sql) / [`MER-MSPI.pdf`](MER-MSPI.pdf)).
6. Uno o dos componentes de la sección 4 en detalle (por ejemplo, `ms_iam` y `mf_auth`, que fueron los primeros documentados como piloto y sirven de referencia de profundidad) — para verificar el nivel de detalle técnico disponible por componente.
7. [`Documentacion-investigacion/Documento-Investigacion.md`](../Documentacion-investigacion/Documento-Investigacion.md) — como referencia ampliada si se requiere profundizar en algún punto académico.

---

*Este índice se mantiene en `Documentacion-General/00-Indice-General.md`. Actualícelo si se agregan o modifican documentos.*
