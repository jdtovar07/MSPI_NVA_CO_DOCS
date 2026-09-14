# Seguridad — postura y hardening

Resumen de controles presentes en MSPI y del trabajo de hardening reciente (SEG-A / SEG-B). Detalle operativo en los `06-Implementacion-Despliegue.md` de cada microservicio y en:

- `MSPI_NVA_CO_MR_BACK/docs/SEG-B-Dependency-Check.md`
- `MSPI_NVA_CO_MR_FRONT/docs/SEG-B-npm-audit.md`

---

## Controles implementados (baseline)

| Control | Dónde | Notas |
|---|---|---|
| **JWT / JWK** | Todos los MS (Resource Server) | Validación contra Keycloak (`JWT_ISSUER_URI` / `JWT_JWK_SET_URI`) |
| **CORS por entorno** | `CORS_ALLOWED_ORIGINS` | Sin orígenes fijos en código de producción |
| **API interna** | `/internal/**` + `X-Internal-Api-Key` | Comparación **constant-time** (`MessageDigest.isEqual`); rotar clave vía Infisical |
| **SQL parametrizado** | Repositorios JPA / queries | Sin concatenación de entrada de usuario |
| **Upload evidencias** | `ms_evidence` | Allowlist MIME + límite **20 MB** (50 MB `REPORT_OUTPUT`) + **magic bytes** |
| **Lockout de login** | `ms_iam` / Keycloak | Bloqueo por intentos fallidos (cuenta) |
| **Rate limit auth por IP** | `ms_iam` `AuthRateLimitFilter` | Default **20 req/min** en `/auth/login` y `/auth/change-password` → **429** (`AUTH_RATE_LIMIT_PER_MINUTE`) |
| **Cabeceras HTTP** | nginx MF + `SecurityHeadersFilter` (iam) | HSTS, CSP, `nosniff`, `X-Frame-Options` / `frame-ancestors`, `Referrer-Policy: no-referrer` |
| **Anti log-injection** | `LogSanitizer` (iam) | `\r`/`\n` → espacio en logs y summaries de auditoría |
| **Actuator** | `/actuator/health`, `/actuator/info` | Healthchecks Docker |
| **Borrado lógico** | Dominio MSPI | `deleted_at`; sin borrado físico de evidencias por defecto |
| **SCA dependencias** | Gradle OWASP Dependency-Check + `npm audit` | Boot **4.0.8** + pins Tomcat/Jackson; overrides npm en MF |

---

## Política de privacidad

La política de tratamiento de datos (Ley 1581/2012) está publicada en la aplicación en **`/privacidad`** (ruta pública del shell) y en este repositorio:

→ [Política de Privacidad y Tratamiento de Datos — AUDITCYBER / MSPI](../legal/POLITICA-PRIVACIDAD-MSPI.md)

---

## Hallazgos / residuales (TODO)

!!! todo "Revisión jurídica de la política"
    El documento en `legal/` es **borrador** con marcadores `[[ ... ]]`. Debe completarlos el área jurídica antes de publicación oficial.

!!! todo "SCA en CI con NVD_API_KEY"
    Dependency-Check sin `NVD_API_KEY` es muy lento. Configurar la variable en Bitbucket/GitHub y, si aplica, `DEPENDENCY_CHECK_FAIL_CVSS=7` en pipelines.

!!! todo "CVEs Angular 19 (framework)"
    Los avisos *high* de `@angular/core` / CLI en `npm audit` solo se cierran con **major** (21/22). Quedan documentados como residual SEG-B; requieren un upgrade de framework dedicado (rompe contratos).

!!! todo "Inventario formal de encargados (privacidad §10)"
    Completar en la política la lista de proveedores (hosting, Brevo, etc.) y acuerdos de tratamiento.

---

## Referencias rápidas en código / docs

| Tema | Documento |
|---|---|
| Rate limit / headers / magic / constant-time | Backend `ms_iam` / `ms_evidence` — Análisis y Despliegue |
| Dependency-Check | Repo BACK: `docs/SEG-B-Dependency-Check.md` |
| npm audit | Repo FRONT: `docs/SEG-B-npm-audit.md` |
| Arquitectura de seguridad | [01 — Arquitectura general](../Documentacion-General/01-Arquitectura-General-del-Sistema.md) |
