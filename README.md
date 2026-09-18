# MSPI — Documentación del Proyecto de Grado

Repositorio de documentación del **Sistema de Gestión de Seguridad y Privacidad de la Información (MSPI)** / **AUDITCYBER**, plataforma que automatiza el Instrumento de Identificación de la Línea Base de Seguridad de MinTIC Colombia.

Este repositorio **no contiene código fuente**. Agrupa la propuesta de grado, el componente investigativo y la documentación técnica del ciclo de vida de cada microservicio y microfrontend.

**8** microservicios activos (8082–8089) · **6** microfrontends (4200–4205) · documentos SDLC por componente

`Java 21` · `Spring Boot` · `Arquitectura hexagonal` · `Angular 19` · `Keycloak` · `PostgreSQL` · `Docker` · composición UI: **iframe + postMessage** (`shell-iframe-bridge`)

| Campo | Valor |
|---|---|
| **Proyecto** | MSPI: Sistema de Gestión de Seguridad y Privacidad de la Información basado en ISO/IEC 27001 |
| **Autores** | Bairon Alexander Suarez Camacho, Juan Diego Tovar Rodriguez |
| **Programa** | Ingeniería de Sistemas |
| **Institución** | CORHUILA |

---

## Cómo navegar esta documentación

| Si buscas… | Empieza por |
|---|---|
| **Wiki navegable y buscable** (punto de entrada recomendado) | [`WIKI.md`](WIKI.md) → `mkdocs serve` · landing [`wiki/Inicio.md`](wiki/Inicio.md) |
| Índice completo (asesor) | [`Documentacion-General/00-Indice-General.md`](Documentacion-General/00-Indice-General.md) |
| Arquitectura + C4 | [`01-Arquitectura-General-del-Sistema.md`](Documentacion-General/01-Arquitectura-General-del-Sistema.md) |
| Diagramas Mermaid (contexto, contenedores, secuencias) | [`15-Diagramas-C4-y-Secuencias.md`](Documentacion-General/15-Diagramas-C4-y-Secuencias.md) |
| Modelo de datos / MER | [`Modelo-Datos-MER.md`](Documentacion-General/Modelo-Datos-MER.md) · [dbdocs](https://dbdocs.io/jdtovar-2021a/MER-MSPI) |
| Glosario | [`16-Glosario.md`](Documentacion-General/16-Glosario.md) |
| Historial de cambios docs | [`17-Changelog.md`](Documentacion-General/17-Changelog.md) |
| Flujos SOL-* / auditoría / seguridad | [`14-Flujos-Solicitudes-Auditoria-y-Seguridad.md`](Documentacion-General/14-Flujos-Solicitudes-Auditoria-y-Seguridad.md) |
| API consolidada | [`08-Referencia-API.md`](Documentacion-General/08-Referencia-API.md) |
| SDLC por microservicio / MF | `Documentacion-Backend/<ms>/` · `Documentacion-Frontend/<mf>/` |
| Marco legal (privacidad, términos, autorización, seguridad, licencias) | [`legal/README.md`](legal/README.md) |
| Matriz de trazabilidad | [`18-Matriz-Trazabilidad.md`](Documentacion-General/18-Matriz-Trazabilidad.md) |
| Revisión académica (propuesta y cartas) | [`Propuesta-grado/Revision-Propuesta-y-Cartas.md`](Propuesta-grado/Revision-Propuesta-y-Cartas.md) |

---

## Qué es MSPI

MSPI reemplaza el diligenciamiento manual de una hoja de cálculo Excel de nueve pestañas por una aplicación web con motor de cálculo centralizado, trazabilidad de evidencias y control de acceso basado en roles.

La plataforma reproduce las reglas del instrumento de MinTIC para:

- efectividad de controles **ISO/IEC 27001** (Anexo A)
- avance del ciclo **PHVA**
- nivel de madurez del **SGSI**
- desempeño frente a **NIST CSF**

---

## Arquitectura de alto nivel

Versión resumida para orientación. El C4 completo, el despliegue Docker y las decisiones están en [`01-Arquitectura-General-del-Sistema.md`](Documentacion-General/01-Arquitectura-General-del-Sistema.md).

```mermaid
flowchart TB
    User([Usuario]) --> Shell["mf_shell :4200"]

    subgraph Frontend["Microfrontends Angular 19"]
        Shell
        Auth["mf_auth :4201"]
        Org["mf_org :4202"]
        Assess["mf_assessment :4203"]
        Evid["mf_evidence :4204"]
        Rep["mf_reports :4205"]
    end

    Shell -->|"iframe + postMessage"| Auth
    Shell --> Org
    Shell --> Assess
    Shell --> Evid
    Shell --> Rep

    subgraph Backend["Microservicios Spring Boot"]
        IAM["ms_iam :8082"]
        MSORG["ms_org :8083"]
        ASM["ms_assessment :8084"]
        CAT["ms_catalog :8085"]
        EVI["ms_evidence :8086"]
        RPT["ms_reporting :8087"]
        AUD["ms_audit :8088"]
        ADM["ms_admin :8089"]
    end

    Auth --> IAM
    Org --> MSORG
    Assess --> ASM
    Assess --> CAT
    Evid --> EVI
    Rep --> RPT
    Rep --> ASM
    Shell --> AUD
    Shell --> ADM
    IAM --> AUD
    ASM --> AUD
    CAT --> AUD
    ASM --> ADM
    CAT --> ADM

    IAM --> KC["Keycloak :8080"]
    IAM --> PG[("PostgreSQL — iam · org · catalog · assessment · evidence · reporting · audit · admin")]
    MSORG --> PG
    ASM --> PG
    CAT --> PG
    EVI --> PG
    RPT --> PG
    AUD --> PG
    ADM --> PG
```

---

## Hallazgos verificados en código

La documentación se elaboró leyendo los repositorios reales, no a partir de plantillas. Cuando algo no está implementado, se declara. Detalle y trazabilidad en la [sección de deuda técnica](Documentacion-General/01-Arquitectura-General-del-Sistema.md).

- **`ms_admin`** (:8089) posee la configuración global; **`ms_audit`** (:8088) posee la bitácora.
- Los **6** microfrontends se componen con **iframe + `postMessage`** (`shell-iframe-bridge.ts`). Module Federation queda como **evolución futura**, no como arquitectura actual.
- El pipeline de CI ejecuta las pruebas del backend en cada build (`test` + JaCoCo); el umbral de cobertura del 80 % aún no es compuerta obligatoria. En el frontend solo `mf_org` tiene una prueba automatizada; el backend suma 89 clases y 377 casos de prueba.
- El instrumento fuente usa **ISO/IEC 27001:2013**; la versión vigente de la norma es **2022**.

---

## Repositorios relacionados

| Recurso | Descripción |
|---|---|
| [MSPI Front](https://github.com/jdtovar07/MSPI_NVA_CO_MR_FRONT.git) | Código de microfrontends, UI y lógica de presentación |
| [MSPI Back](https://github.com/jdtovar07/MSPI_NVA_CO_MR_BACK.git) | Código de microservicios, APIs y lógica de negocio |
| [Figma](https://www.figma.com/design/tJchFUjVOMD20Homvf5TTC/MSPI---Definitivo?node-id=0-1&t=l4YlEHnhBgfLsxDP-1) | Diseño visual, prototipos y guía de estilo |
| [MER-MSPI (dbdocs)](https://dbdocs.io/jdtovar-2021a/MER-MSPI) | Modelo entidad-relación interactivo (8 esquemas: `iam`…`admin`) |

Índice de enlaces: [`MSPI-Enlaces.md`](MSPI-Enlaces.md).

---

## Estructura del repositorio

```
MSPI_NVA_CO_DOCS/
├── mkdocs.yml                      # Wiki MkDocs Material
├── requirements.txt                # Dependencias de la wiki
├── WIKI.md                         # Cómo servir / publicar la wiki
├── docs/                           # Symlinks al contenido (docs_dir de MkDocs)
├── wiki/                           # Landing e índice de seguridad
├── legal/                          # Marco legal (11 documentos)
├── CartasVoBo/                     # Cartas de aval (estudiantes y director)
├── Propuesta-grado/                # Propuesta de grado y su revisión
├── Documentacion-General/          # Arquitectura, dominio y objetivos
├── Documentacion-Backend/          # 8 microservicios × (7 fases SDLC + referencia de API)
├── Documentacion-Frontend/         # 6 microfrontends × (7 fases SDLC + mapa de rutas)
├── Documentacion-investigacion/    # Componente investigativo extendido
├── Propuesta-grado/                # Documento formal (plantilla CORHUILA)
├── CartasVoBo/                     # Cartas de solicitud de aval
├── MSPI-Enlaces.md                 # Enlaces a código y diseño
└── README.md
```

### Documentación general

Punto de entrada recomendado para el asesor. En menos de 30 minutos da una visión completa del sistema.

| Documento | Contenido |
|---|---|
| [`00-Indice-General.md`](Documentacion-General/00-Indice-General.md) | Índice único de toda la documentación |
| [`01-Arquitectura-General-del-Sistema.md`](Documentacion-General/01-Arquitectura-General-del-Sistema.md) | C4, despliegue, seguridad, decisiones y deuda técnica |
| [`02-Modelo-de-Dominio.md`](Documentacion-General/02-Modelo-de-Dominio.md) | Bounded contexts, entidades, ER y glosario |
| [`03-Objetivos-del-Proyecto.md`](Documentacion-General/03-Objetivos-del-Proyecto.md) | Objetivo general y específicos, con trazabilidad a módulos |
| [MER-MSPI (dbdocs)](https://dbdocs.io/jdtovar-2021a/MER-MSPI) | MER interactivo; fuente SQL: [`MER-MSPI.sql`](Documentacion-General/MER-MSPI.sql) · DBML: [`MER-MSPI.dbml`](Documentacion-General/MER-MSPI.dbml) · SVG: [`MER-MSPI.svg`](Documentacion-General/MER-MSPI.svg) |
| [`04-Decisiones-Tecnicas-Complementarias.md`](Documentacion-General/04-Decisiones-Tecnicas-Complementarias.md) | Decisiones técnicas de RBAC fino, catálogo y funcionalidades administrativas |
| [`05-Manual-Despliegue.md`](Documentacion-General/05-Manual-Despliegue.md) | Cómo levantar el stack completo en Docker |
| [`06-Guia-Pruebas-Funcionales.md`](Documentacion-General/06-Guia-Pruebas-Funcionales.md) | Flujos funcionales end-to-end para demostración |
| [`07-Manual-Usuario.md`](Documentacion-General/07-Manual-Usuario.md) | Manual de usuario final por rol |
| [`08-Referencia-API.md`](Documentacion-General/08-Referencia-API.md) | Referencia consolidada de la API |

### Backend

Ocho microservicios, cada uno con los 7 documentos del ciclo de vida más `08-Referencia-API.md` generado desde el código. El enlace abre la carpeta del componente.

| Microservicio | Rol | Puerto | Estado |
|---|---|---|---|
| [`ms_iam`](Documentacion-Backend/ms_iam/) | Identidad, autenticación, 2FA, auditoría | 8082 | Activo |
| [`ms_org`](Documentacion-Backend/ms_org/) | Organizaciones y geografía | 8083 | Activo |
| [`ms_catalog`](Documentacion-Backend/ms_catalog/) | Catálogo versionado de controles, escalas, PHVA, madurez, NIST | 8085 | Activo |
| [`ms_assessment`](Documentacion-Backend/ms_assessment/) | Ciclo de vida de evaluaciones y motor de cálculo | 8084 | Activo |
| [`ms_evidence`](Documentacion-Backend/ms_evidence/) | Contexto organizacional y evidencias documentales | 8086 | Activo |
| [`ms_reporting`](Documentacion-Backend/ms_reporting/) | Generación asíncrona de reportes PDF/Excel | 8087 | Activo |
| [`ms_admin`](Documentacion-Backend/ms_admin/) | Configuración global (`admin.system_config`) | 8089 | Activo |
| [`ms_audit`](Documentacion-Backend/ms_audit/) | Auditoría central (`audit.audit_log`) | 8088 | Activo |

### Frontend

Seis microfrontends, misma estructura de 7 documentos más `08-Mapa-Rutas-y-Endpoints.md` por componente.

| Microfrontend | Rol | Puerto |
|---|---|---|
| [`mf_shell`](Documentacion-Frontend/mf_shell/) | Host / orquestador | 4200 |
| [`mf_auth`](Documentacion-Frontend/mf_auth/) | Autenticación, 2FA, usuarios | 4201 |
| [`mf_org`](Documentacion-Frontend/mf_org/) | Organizaciones | 4202 |
| [`mf_assessment`](Documentacion-Frontend/mf_assessment/) | Evaluación (áreas, controles, PHVA, madurez, NIST) | 4203 |
| [`mf_evidence`](Documentacion-Frontend/mf_evidence/) | Contexto y levantamiento de evidencias | 4204 |
| [`mf_reports`](Documentacion-Frontend/mf_reports/) | Reportes y brechas | 4205 |

### Documentos formales

| Recurso | Uso |
|---|---|
| [`Propuesta-grado/Propuesta_de_Grado_MSPI.docx`](Propuesta-grado/Propuesta_de_Grado_MSPI.docx) | Documento formal a radicar (plantilla institucional) |
| [`Documentacion-investigacion/Documento-Investigacion.md`](Documentacion-investigacion/Documento-Investigacion.md) | Fundamento académico ampliado, con trazabilidad al código |
| [`CartasVoBo/`](CartasVoBo/) | Cartas de solicitud de aval de proyecto de grado |

---

## Documentos por componente (ciclo de vida)

Cada microservicio y microfrontend sigue la misma estructura:

```
01-Planificacion.md
02-Analisis.md
03-Diseno.md
04-Desarrollo.md
05-Pruebas.md
06-Implementacion-Despliegue.md
07-Mantenimiento.md
```

Cuando un dato no pudo confirmarse en el código, se declara como ausente o `[PENDIENTE]`, en lugar de inferirse.

---

## Orden de lectura recomendado

1. [`Propuesta-grado/Propuesta_de_Grado_MSPI.docx`](Propuesta-grado/Propuesta_de_Grado_MSPI.docx) — documento formal.
2. [`03-Objetivos-del-Proyecto.md`](Documentacion-General/03-Objetivos-del-Proyecto.md) — qué se propuso lograr.
3. [`01-Arquitectura-General-del-Sistema.md`](Documentacion-General/01-Arquitectura-General-del-Sistema.md) — cómo está construido.
4. [`02-Modelo-de-Dominio.md`](Documentacion-General/02-Modelo-de-Dominio.md) — qué dominios cubre.
5. [MER-MSPI (dbdocs)](https://dbdocs.io/jdtovar-2021a/MER-MSPI) — modelo físico de la base de datos.
6. Un componente backend y uno frontend en detalle (por ejemplo [`ms_iam`](Documentacion-Backend/ms_iam/) y [`mf_auth`](Documentacion-Frontend/mf_auth/)).
7. [`Documento-Investigacion.md`](Documentacion-investigacion/Documento-Investigacion.md) — referencia académica ampliada.

El índice completo está en [`Documentacion-General/00-Indice-General.md`](Documentacion-General/00-Indice-General.md).

---

## Wiki (MkDocs Material) — punto de entrada navegable

La **wiki** es la forma recomendada de leer este repo (menú, búsqueda, Mermaid):

```bash
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
mkdocs serve    # http://127.0.0.1:8000  → wiki/Inicio.md
```

Guía completa (build, `gh-deploy`, estructura): [`WIKI.md`](WIKI.md). Landing: [`wiki/Inicio.md`](wiki/Inicio.md).
