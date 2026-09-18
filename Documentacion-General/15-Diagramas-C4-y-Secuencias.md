# 15 · Diagramas C4, despliegue, ER y secuencias

| Campo | Valor |
|---|---|
| Fuentes | Código `MSPI_NVA_CO_MR_BACK` / `MSPI_NVA_CO_MR_FRONT`; `MER-MSPI.sql`; `01-Arquitectura-General-del-Sistema.md`; `14-Flujos-…` |

> Todos los diagramas usan **Mermaid** (GitHub + MkDocs). Cada uno incluye **título** y **contexto**. Nombres de servicios, puertos y rutas verificados en código.

---

## 0. Cómo leer estos diagramas

| Tipo Mermaid | Qué muestra | Cómo leerlo |
|---|---|---|
| `flowchart` | Contenedores, despliegue, composición UI, hexágono | Flechas = llamadas o dependencias; cajas = procesos/servicios |
| `sequenceDiagram` | Interacción temporal entre actores | De arriba a abajo = tiempo; `->>` = mensaje síncrono |
| `erDiagram` | Tablas y cardinalidades | `\|\|--o{` = uno a muchos; UUID sin FK se anota en el texto |
| `classDiagram` | Tipos del dominio (en docs por MS) | `-->` = usa/depende; nombres = clases Java/TS reales |

**Leyenda transversal**

| Símbolo / convención | Significado |
|---|---|
| JWT | `Authorization: Bearer` validado por Resource Server (Keycloak JWK) |
| API-key | Header `X-Internal-Api-Key` en rutas `/internal/**` |
| iframe + postMessage | Composición real del frontend (`shell-iframe-bridge.ts`) |
| Module Federation | Solo evolución futura — no está en producción |

---

## 1. C4 — Contexto (nivel 1)

### Título: Fronteras del sistema MSPI / AUDITCYBER

**Contexto.** Ubica a MSPI frente a personas y sistemas externos. Interior = lo que el proyecto construye; exterior = IdP, correo e instrumento normativo MinTIC.

```mermaid
flowchart LR
    User([Usuario institucional<br/>AdminSistema · AdminInstrumento<br/>Evaluador · Revisor · Lector])
    MSPI[MSPI / AUDITCYBER<br/>8 microservicios + 6 MF]
    KC[Keycloak :8080<br/>realm iam]
    Brevo[Brevo<br/>correo transaccional]
    Instr[Instrumento MinTIC<br/>Excel Autodiagnóstico]

    User -->|HTTPS · JWT| MSPI
    MSPI -->|ROPC / JWK| KC
    MSPI -->|API HTTP SMTP| Brevo
    MSPI -.->|reproduce reglas de cálculo| Instr
```

**Qué mirar:** el usuario nunca habla con Keycloak o Brevo directamente desde el navegador de negocio; pasa por `ms_iam` / adaptadores.

---

## 2. C4 — Contenedores (nivel 2)

### Título: Contenedores — 8 MS + 6 MF + Keycloak + PostgreSQL

**Contexto.** Descompone MSPI en procesos desplegables. Protocolos: REST+JWT al público; REST+API-key entre MS (`/internal/**`).

```mermaid
flowchart TB
    User([Usuario]) --> Shell["mf_shell :4200"]

    subgraph FE["6 microfrontends Angular 19"]
        Shell
        Auth["mf_auth :4201"]
        Org["mf_org :4202"]
        AsmF["mf_assessment :4203"]
        EvF["mf_evidence :4204"]
        RepF["mf_reports :4205"]
    end

    Shell -->|"iframe + postMessage"| Auth
    Shell --> Org
    Shell --> AsmF
    Shell --> EvF
    Shell --> RepF

    subgraph BE["8 microservicios Spring Boot"]
        IAM["ms_iam :8082"]
        ORG["ms_org :8083"]
        ASM["ms_assessment :8084"]
        CAT["ms_catalog :8085"]
        EVI["ms_evidence :8086"]
        RPT["ms_reporting :8087"]
        AUD["ms_audit :8088"]
        ADM["ms_admin :8089"]
    end

    Auth -->|JWT| IAM
    Org -->|JWT| ORG
    AsmF -->|JWT| ASM
    AsmF -->|JWT| CAT
    EvF -->|JWT| EVI
    RepF -->|JWT| RPT
    Shell -->|JWT| AUD
    Shell -->|JWT| ADM

    IAM -->|API-key| AUD
    ASM -->|API-key| AUD
    CAT -->|API-key| AUD
    ASM -->|API-key| ADM
    CAT -->|API-key| ADM
    RPT -->|API-key| ASM
    RPT -->|API-key| EVI
    RPT -->|API-key| CAT

    IAM --> KC["Keycloak :8080"]
    IAM --> PG[("PostgreSQL<br/>iam · org · catalog · assessment<br/>evidence · reporting · audit · admin")]
    ORG --> PG
    ASM --> PG
    CAT --> PG
    EVI --> PG
    RPT --> PG
    AUD --> PG
    ADM --> PG
    KC --> PGKC[("PostgreSQL Keycloak")]
```

**Quién habla con quién (resumen):** productores de auditoría → `ms_audit`; plazos/gracia → `ms_admin`; reportes leen assessment/catalog/evidence por canal interno.

---

## 3. Despliegue Docker

### Título: Compose — redes, apps, front e identidad

**Contexto.** Vista operativa del stack local (`docker-compose*.yml` / `mspi-net`). Cada MS/MF es un contenedor con healthcheck donde aplica.

```mermaid
flowchart TB
    subgraph Net["red Docker: mspi-net"]
        subgraph Infra["postgres + keycloak"]
            PG["postgres_mspi :5432 · DB MSPI"]
            PGKC["postgres_keycloak :5433"]
            KC["keycloak :8080"]
        end
        subgraph Apps["mspi-apps — 8 MS"]
            IAM["ms_iam :8082"]
            ORG["ms_org :8083"]
            ASM["ms_assessment :8084"]
            CAT["ms_catalog :8085"]
            EVI["ms_evidence :8086"]
            RPT["ms_reporting :8087"]
            AUD["ms_audit :8088"]
            ADM["ms_admin :8089"]
        end
        subgraph Front["mspi-front — 6 MF (runtime MSPI_* → config.json + CSP)"]
            S["mf_shell :4200"]
            A["mf_auth :4201"]
            O["mf_org :4202"]
            AS["mf_assessment :4203"]
            E["mf_evidence :4204"]
            R["mf_reports :4205"]
        end
    end
    Browser([Navegador]) --> S
    Browser -.fetch /assets/config.json.-> S
    Browser -.fetch /assets/config.json.-> A
    IAM --> PG
    ORG --> PG
    ASM --> PG
    CAT --> PG
    EVI --> PG
    RPT --> PG
    AUD --> PG
    ADM --> PG
    IAM --> KC
    KC --> PGKC
    ORG -.depends_on.-> IAM
    ASM -.depends_on.-> IAM
```

**Volúmenes típicos:** evidencias (`mspi_evidence_data`), salidas de reporte (`mspi_report_outputs`). Detalle de arranque: `05-Manual-Despliegue.md`.

**Runtime front:** cada contenedor MF genera `/assets/config.json` y la CSP nginx desde `MSPI_*` al arrancar (misma imagen local/dominio real). Ver `05-Manual-Despliegue.md` §8.


---

## 4. Modelo de datos (8 esquemas)

### Título: ER conceptual por dominios

**Contexto.** Una instancia PostgreSQL, ocho esquemas propietarios. `audit`/`admin` guardan UUID **sin FK** a `iam`/`assessment` (desacople). Fuente: `MER-MSPI.sql`, `patch-audit-schema.sql`, `patch-admin-schema.sql`.

```mermaid
erDiagram
    IAM_USER ||--o{ IAM_USER_ROLE : has
    IAM_ROLE ||--o{ IAM_USER_ROLE : assigned
    IAM_USER ||--o{ IAM_PWD_RESET : requests
    ORG_ORGANIZATION ||--o{ ASM_ASSESSMENT : evaluates
    CAT_TEMPLATE ||--o{ ASM_ASSESSMENT : snapshots
    ASM_ASSESSMENT ||--o{ ASM_DELETION_REQ : may_have
    ASM_ASSESSMENT ||--o{ EVI_FILE : attaches
    ASM_ASSESSMENT ||--o{ RPT_JOB : reports
    AUD_LOG }o--o| ASM_ASSESSMENT : "assessment_id UUID sin FK"
    ADM_CONFIG ||--o{ ADM_HISTORY : versions

    IAM_USER { uuid id PK }
    ORG_ORGANIZATION { uuid id PK }
    CAT_TEMPLATE { uuid id PK }
    ASM_ASSESSMENT { uuid id PK timestamptz deleted_at }
    ASM_DELETION_REQ { string request_number UK }
    EVI_FILE { uuid id PK timestamptz deleted_at }
    RPT_JOB { uuid id PK string status }
    AUD_LOG { bigint id PK jsonb metadata_json }
    ADM_CONFIG { string key PK jsonb value_json }
```

**Claves cruzadas sin FK:** `audit.audit_log.actor_user_id` / `assessment_id`; `admin.system_config.updated_by`. Correlación de radicados: `metadata_json.requestNumber`.

Vista embebida: [`Modelo-Datos-MER.md`](Modelo-Datos-MER.md).

---

## 5. Composición del frontend

### Título: Shell, iframes y `shell-iframe-bridge`

**Contexto.** Los 6 MF son SPAs independientes. El host embebe hijos en `<iframe>` y sincroniza sesión/navegación con `postMessage` (`MSPI_AUTH_*`, `MSPI_ACTIVE_ASSESSMENT`, `MSPI_SHELL_NAV`). Module Federation = evolución futura.

```mermaid
flowchart TB
    Browser([Navegador]) --> Shell["mf_shell :4200<br/>ShellLayout + *-redirect"]
    Shell -->|iframe src :4201| Auth[mf_auth]
    Shell -->|iframe :4202| Org[mf_org]
    Shell -->|iframe :4203| Asm[mf_assessment]
    Shell -->|iframe :4204| Ev[mf_evidence]
    Shell -->|iframe :4205| Rep[mf_reports]
    Shell <-->|"postMessage<br/>shell-iframe-bridge.ts"| Auth
    Shell <-->|postMessage| Asm
    Shell <-->|postMessage| Ev
    Auth -.->|localStorage / cookie auth_session| Browser
```

**Qué mirar:** el JWT viaja al API desde cada MF (interceptor); el bridge solo replica sesión entre orígenes (puertos).

---

## 6. Secuencia — (a) Login + 2FA

### Título: Autenticación con TOTP opcional

**Contexto.** Flujo de `mf_auth` → `ms_iam` → Keycloak; evento de login hacia `ms_audit`.

```mermaid
sequenceDiagram
    actor U as Usuario
    participant Auth as mf_auth
    participant Shell as mf_shell
    participant IAM as ms_iam
    participant KC as Keycloak
    participant AUD as ms_audit

    U->>Auth: email + password
    Auth->>IAM: POST /auth/login
    IAM->>KC: token ROPC
    alt 2FA requerido
        IAM-->>Auth: challenge TOTP
        U->>Auth: código
        Auth->>IAM: POST /auth/totp/verify
    end
    IAM->>AUD: POST /internal/audit/events AUTH_LOGIN_*
    IAM-->>Auth: JWT + perfil
    Auth->>Shell: postMessage MSPI_AUTH_SESSION
    Auth->>Shell: navigate :4200/dashboard
```

---

## 7. Secuencia — (b) Evaluación end-to-end

### Título: Crear, diligenciar y publicar evaluación

**Contexto.** Orquestación típica vía `mf_assessment` / `mf_evidence` y APIs de assessment, catalog y evidence.

```mermaid
sequenceDiagram
    actor U as Evaluador
    participant UI as mf_assessment
    participant Ev as mf_evidence
    participant ASM as ms_assessment
    participant CAT as ms_catalog
    participant EVI as ms_evidence
    participant AUD as ms_audit

    U->>UI: crear evaluación
    UI->>CAT: GET plantilla / catálogo
    UI->>ASM: POST /assessments
    UI->>ASM: PATCH controles / PHVA / madurez / NIST
    U->>Ev: contexto + levantamiento
    Ev->>EVI: PATCH context / POST files
    U->>UI: publicar
    UI->>ASM: POST .../publish
    ASM->>AUD: ASSESSMENT_PUBLISHED
```

---

## 8. Secuencia — (c) Solicitud → aprobación → ejecución

### Título: Ciclo SOL-* con auditoría

**Contexto.** Prefijos `SOL-ELIM` / `SOL-AMPL` / `SOL-PWD` / `SOL-CAT`. Gracia desde `ms_admin` cuando aplica soft-delete.

```mermaid
sequenceDiagram
    actor Sol as Solicitante
    actor Apr as AdminSistema
    participant UI as mf_shell / MF
    participant Dom as MS dueño
    participant ADM as ms_admin
    participant AUD as ms_audit

    Sol->>UI: crea solicitud
    UI->>Dom: POST ...-requests
    Dom->>Dom: radicado SOL-*-######
    Dom->>AUD: *_REQUESTED
    Apr->>UI: ficha radicado
    UI->>AUD: GET /audit/requests/{n}
    Apr->>UI: aprobar
    UI->>Dom: POST .../approve
    opt soft-delete
        Dom->>ADM: GET /internal/system/config
        Dom->>AUD: *_APPROVED
        Note over Dom: sweeper → deleted_at
        Dom->>AUD: *_EXECUTED
    end
```

Detalle: [`14-Flujos-Solicitudes-Auditoria-y-Seguridad.md`](14-Flujos-Solicitudes-Auditoria-y-Seguridad.md).

---

## 9. Secuencia — (d) Generación de reporte

### Título: Job asíncrono PDF/Excel

**Contexto.** `mf_reports` crea job; `ms_reporting` procesa con datos internos de assessment/catalog/evidence.

```mermaid
sequenceDiagram
    actor U as Usuario
    participant UI as mf_reports
    participant RPT as ms_reporting
    participant ASM as ms_assessment
    participant CAT as ms_catalog
    participant EVI as ms_evidence

    U->>UI: solicitar export
    UI->>RPT: POST /reports/jobs
    RPT-->>UI: 202 jobId
    loop polling
        UI->>RPT: GET /reports/jobs/{id}
    end
    RPT->>ASM: GET /internal/.../report-export-bundle
    RPT->>CAT: plantillas
    RPT->>RPT: POI / LibreOffice
    RPT->>EVI: POST report-outputs
    UI->>RPT: GET .../download
```

---

## 10. Secuencia — (e) Trazabilidad en ms_audit

### Título: Ingesta S2S y consulta de timeline

**Contexto.** Productores empujan eventos; el admin consulta listado y trail por radicado (`RequestOwnerGateway` resuelve cabecera según prefijo SOL-*).

```mermaid
sequenceDiagram
    participant Prod as ms_iam / assessment / catalog
    participant AUD as ms_audit
    participant Own as MS dueño SOL-*
    actor Admin as AdminSistema
    participant UI as mf_shell

    Prod->>AUD: POST /internal/audit/events + API-key
    AUD->>AUD: INSERT audit.audit_log
    Admin->>UI: abrir Auditoría
    UI->>AUD: GET /audit/events?requestNumber=
    UI->>AUD: GET /audit/requests/{n}
    AUD->>Own: GET /internal/requests/{n}
    AUD-->>UI: header + timeline ASC
```

---

## Referencias

- Arquitectura narrativa: [`01-Arquitectura-General-del-Sistema.md`](01-Arquitectura-General-del-Sistema.md)
- Glosario: [`16-Glosario.md`](16-Glosario.md)
- Diagramas por componente: `Documentacion-Backend/*/03-Diseno.md` y `Documentacion-Frontend/*/03-Diseno.md` (sección *Ilustraciones*).
