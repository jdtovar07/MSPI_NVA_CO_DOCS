# 15 · Diagramas C4 y de secuencia

| Campo | Valor |
|---|---|
| Última revisión cruzada con código | **2026-10-19** |
| Fuentes | `01-Arquitectura-General-del-Sistema.md`, `14-Flujos-Solicitudes-Auditoria-y-Seguridad.md`, `MER-MSPI.sql`, código en `MSPI_NVA_CO_MR_BACK` / `MSPI_NVA_CO_MR_FRONT` |

> Diagramas en **Mermaid** (renderizan en GitHub y en la wiki MkDocs). No inventan componentes: solo lo verificado en código/docs.

---

## 1. C4 — Contexto del sistema

(Estilo C4 con Mermaid estándar — compatible con GitHub.)

```mermaid
flowchart LR
    User([Usuario institucional<br/>roles IAM]) -->|HTTPS · JWT| MSPI[MSPI / AUDITCYBER<br/>8 microservicios + 6 MF]
    MSPI -->|ROPC / validación JWK| KC[Keycloak :8080<br/>realm iam]
    MSPI -->|API correo| Brevo[Brevo]
    MSPI -.->|reproduce reglas| Instr[Instrumento MinTIC<br/>Excel Autodiagnóstico]
```

---

## 2. C4 — Contenedores (8 MS + 6 MF + Keycloak + Postgres)

```mermaid
flowchart TB
    User([Usuario]) --> Shell["mf_shell :4200<br/>host · iframe bridge"]

    subgraph FE["6 microfrontends Angular 19"]
        Shell
        Auth["mf_auth :4201"]
        Org["mf_org :4202"]
        AsmF["mf_assessment :4203"]
        EvF["mf_evidence :4204"]
        RepF["mf_reports :4205"]
    end

    Shell -->|"iframe + postMessage<br/>shell-iframe-bridge"| Auth
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

    Auth --> IAM
    Org --> ORG
    AsmF --> ASM
    AsmF --> CAT
    EvF --> EVI
    RepF --> RPT
    RepF --> ASM
    Shell --> AUD
    Shell --> ADM

    IAM --> AUD
    ASM --> AUD
    CAT --> AUD
    ASM --> ADM
    CAT --> ADM

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

**Composición frontend (canónica):** iframes + `window.postMessage` + `shell-iframe-bridge.ts`. Module Federation = **evolución futura**, no arquitectura actual.

---

## 3. Modelo de datos (8 esquemas)

Vista conceptual; detalle tabular en [`MER-MSPI.sql`](MER-MSPI.sql) / [dbdocs](https://dbdocs.io/jdtovar-2021a/MER-MSPI) / [`Modelo-Datos-MER.md`](Modelo-Datos-MER.md).

```mermaid
erDiagram
    IAM_USER ||--o{ IAM_USER_ROLE : has
    IAM_ROLE ||--o{ IAM_USER_ROLE : assigned
    ORG_ORGANIZATION ||--o{ ASM_ASSESSMENT : evaluates
    CAT_TEMPLATE ||--o{ ASM_ASSESSMENT : snapshots
    ASM_ASSESSMENT ||--o{ EVI_EVIDENCE_FILE : attaches
    ASM_ASSESSMENT ||--o{ RPT_JOB : reports
    AUD_AUDIT_LOG }o--|| ASM_ASSESSMENT : "assessment_id UUID sin FK"
    ADM_SYSTEM_CONFIG ||--o{ ADM_SYSTEM_CONFIG_HISTORY : versions

    IAM_USER {
        uuid id PK
        string email
        string keycloak_sub
    }
    ORG_ORGANIZATION {
        uuid id PK
        string name
    }
    CAT_TEMPLATE {
        uuid id PK
        string code
    }
    ASM_ASSESSMENT {
        uuid id PK
        timestamptz deleted_at
    }
    EVI_EVIDENCE_FILE {
        uuid id PK
        timestamptz deleted_at
    }
    RPT_JOB {
        uuid id PK
        string status
    }
    AUD_AUDIT_LOG {
        bigint id PK
        string event_type
        jsonb metadata_json
    }
    ADM_SYSTEM_CONFIG {
        string key PK
        jsonb value_json
    }
```

Esquemas propietarios: `iam` · `org` · `catalog` · `assessment` · `evidence` · `reporting` · `audit` · `admin`.

---

## 4. Secuencia — (a) Evaluación end-to-end (resumen)

```mermaid
sequenceDiagram
    actor U as Usuario
    participant Shell as mf_shell
    participant AsmUI as mf_assessment
    participant EvUI as mf_evidence
    participant ASM as ms_assessment
    participant CAT as ms_catalog
    participant EVI as ms_evidence
    participant AUD as ms_audit

    U->>Shell: Abre evaluación
    Shell->>AsmUI: iframe /evaluations
    AsmUI->>CAT: GET catálogo / plantilla activa
    AsmUI->>ASM: POST /assessments (crear)
    ASM-->>AUD: ASSESSMENT_* (best-effort S2S)
    AsmUI->>ASM: PATCH controles / PHVA / madurez / NIST
    AsmUI->>Shell: postMessage MSPI_ACTIVE_ASSESSMENT
    Shell->>EvUI: iframe evidencia
    EvUI->>EVI: contexto + levantamiento + archivos
    AsmUI->>ASM: POST .../publish
    ASM-->>AUD: ASSESSMENT_PUBLISHED
```

---

## 5. Secuencia — (b) Solicitud → aprobación → ejecución (+ auditoría)

Ejemplo genérico (`SOL-ELIM` / `SOL-AMPL` / `SOL-PWD` / `SOL-CAT`):

```mermaid
sequenceDiagram
    actor Sol as Solicitante
    actor Apr as Aprobador AdminSistema
    participant UI as mf_shell / MF dueño
    participant Dom as MS dueño<br/>iam|assessment|catalog
    participant AUD as ms_audit :8088
    participant ADM as ms_admin :8089

    Sol->>UI: Crea solicitud
    UI->>Dom: POST ...-requests
    Dom->>Dom: Genera radicado SOL-*-######
    Dom->>AUD: POST /internal/audit/events<br/>*_REQUESTED + metadata.requestNumber
    Apr->>UI: Bandeja / ficha radicado
    UI->>AUD: GET /audit/requests/{n}
    AUD->>Dom: GET /internal/requests/{n} (cabecera)
    Apr->>UI: Aprobar
    UI->>Dom: POST .../approve
    alt SOL-ELIM / SOL-CAT
        Dom->>ADM: GET /internal/system/config (gracia)
        Dom->>Dom: scheduledDeletionAt = now + graceDays
        Dom->>AUD: *_APPROVED
        Note over Dom: Sweeper horario → soft-delete deleted_at
        Dom->>AUD: *_EXECUTED
    else SOL-PWD
        Dom->>Dom: reset password + reset TOTP
        Dom->>AUD: PASSWORD_RESET_APPROVED + EXECUTED
    else SOL-AMPL
        Dom->>Dom: extiende dueDate
        Dom->>AUD: EXTENSION_APPROVED
    end
```

Detalle de prefijos y eventos: [`14-Flujos-Solicitudes-Auditoria-y-Seguridad.md`](14-Flujos-Solicitudes-Auditoria-y-Seguridad.md).

---

## 6. Secuencia — (c) Generación de reporte

```mermaid
sequenceDiagram
    actor U as Usuario
    participant RepUI as mf_reports
    participant RPT as ms_reporting :8087
    participant ASM as ms_assessment
    participant CAT as ms_catalog
    participant EVI as ms_evidence

    U->>RepUI: Solicita PDF/Excel
    RepUI->>RPT: POST /reports/jobs
    RPT-->>RepUI: 202 jobId PENDING
    loop Polling
        RepUI->>RPT: GET /reports/jobs/{jobId}
    end
    RPT->>ASM: GET /internal/.../report-export-bundle
    RPT->>CAT: plantillas / escala
    RPT->>RPT: POI / LibreOffice
    RPT->>EVI: POST /internal/.../report-outputs
    RPT-->>RepUI: COMPLETED
    RepUI->>RPT: GET .../download
```

---

## 7. Secuencia — (d) Login + 2FA

```mermaid
sequenceDiagram
    actor U as Usuario
    participant Auth as mf_auth :4201
    participant Shell as mf_shell :4200
    participant IAM as ms_iam :8082
    participant KC as Keycloak
    participant AUD as ms_audit :8088

    U->>Auth: email + password
    Auth->>IAM: POST /auth/login
    IAM->>KC: token (ROPC)
    alt 2FA requerido
        IAM-->>Auth: challenge TOTP
        U->>Auth: código TOTP
        Auth->>IAM: POST /auth/totp/verify
    end
    IAM->>AUD: AUTH_LOGIN_SUCCESS (S2S)
    IAM-->>Auth: JWT + perfil
    Auth->>Auth: localStorage / cookie auth_session
    Auth->>Shell: postMessage MSPI_AUTH_SESSION
    Auth->>Shell: location → :4200/dashboard
```

Fuentes: `AuthApi` / `LoginUseCase` / `TotpVerifyUseCase` (`ms_iam`); `shell-iframe-bridge.ts` (`mf_shell`).
