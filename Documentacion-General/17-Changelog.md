# 17 · Changelog / control de versiones documental

| Campo | Valor |
|---|---|
| Alcance | Cambios mayores de **documentación** y hitos de arquitectura reflejados en DOCS |
| Convención | Fechas en zona America/Bogota (−05:00). Detalle de commits en el historial Git del repo |

> No sustituye el CHANGELOG de código BACK/FRONT. Solo registra hitos que impactan cómo se lee este repositorio.

| Fecha | Hito | Resumen |
|---|---|---|
| 2026-08-27 | Índice y docs generales iniciales | Arquitectura, dominio, objetivos; SDLC por componente. |
| 2026-09-12 | Política de privacidad | `legal/POLITICA-PRIVACIDAD-MSPI.md` (borrador Ley 1581). |
| 2026-09-12 → 09-14 | Wiki MkDocs Material | `mkdocs.yml`, `requirements.txt`, `docs/` symlinks, landing `wiki/Inicio.md`, seguridad, MER/grafo embebidos. |
| 2026-09-11 | SEG-B documentado | Dependency-Check / npm audit en docs por MS/MF. |
| **2026-10-11** | Extracción `ms_audit` / `ms_admin` | Auditoría → `:8088` esquema `audit`; config global → `:8089` esquema `admin` (patches SQL). |
| 2026-10-11 → 10-12 | Features de solicitudes | Radicados `SOL-ELIM` / `SOL-AMPL` / `SOL-PWD` / `SOL-CAT`; soft-delete + gracia + sweeper; bandeja en `mf_shell`. |
| 2026-10-19 | **DOCS-1** | Docs alineadas a **8 MS activos**; SDLC audit/admin desde código; `14-Flujos-…`; MER con esquemas `audit`/`admin`. |
| 2026-10-19 | **DOCS-2** | Consistencia iframe/`shell-iframe-bridge` (Module Federation = futuro); diagramas C4/secuencias; glosario; este changelog; README → wiki. |
| — | SEG-A (código) | Rate limit auth, cabeceras, magic bytes, constant-time API-key, log sanitizer — resumidos en `wiki/Seguridad.md`. |

!!! note "Cómo actualizar esta tabla"
    Añadir una fila por hito mayor (extracción de servicio, feature transversal, pase editorial). No listar cada commit menor.
