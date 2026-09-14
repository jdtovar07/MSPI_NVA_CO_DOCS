# 17 · Changelog / control de versiones documental

| Campo | Valor |
|---|---|
| Alcance | Cambios mayores de **documentación** y hitos de arquitectura reflejados en DOCS |
| Convención | Las fechas de esta tabla, si aparecen, deben coincidir con commits de este repo (author/committer). Preferir omitir fecha a inventarla. |

> No sustituye el CHANGELOG de código BACK/FRONT. Solo registra hitos que impactan cómo se lee este repositorio.

| Fecha (commit DOCS) | Hito | Resumen |
|---|---|---|
| 2026-09-11 | SEG-B documentado | Dependency-Check / npm audit en docs por MS/MF. |
| 2026-09-12 | Política de privacidad | `legal/POLITICA-PRIVACIDAD-MSPI.md` (borrador Ley 1581). |
| 2026-09-12 → 2026-09-14 | Wiki MkDocs Material | `mkdocs.yml`, `requirements.txt`, `docs/` symlinks, landing `wiki/Inicio.md`, seguridad, MER/grafo embebidos. |
| 2026-09-14 | **DOCS-1** | Docs alineadas a **8 MS activos**; SDLC audit/admin desde código; `14-Flujos-…`; MER con esquemas `audit`/`admin`. |
| 2026-09-14 | **DOCS-2** | Consistencia iframe/`shell-iframe-bridge`; diagramas C4/secuencias; glosario; changelog; README → wiki. |
| 2026-09-14 | Regla de fechas en docs | Sin fechas de elaboración/revisión escritas a mano; la historia la lleva Git. |
| — | Extracción `ms_audit` / `ms_admin` (código) | Auditoría → `:8088` esquema `audit`; config → `:8089` esquema `admin` (patches SQL). Ver BACK. |
| — | Features de solicitudes (código) | Radicados `SOL-*`, soft-delete + gracia + sweeper; bandeja en `mf_shell`. |
| — | SEG-A (código) | Rate limit, cabeceras, magic bytes, constant-time API-key, log sanitizer — `wiki/Seguridad.md`. |

!!! note "Regla de fechas"
    No poner en los Markdown campos tipo «Fecha de elaboración» o «Última revisión cruzada con código». Si una fecha es imprescindible, debe ser la del commit que toca el archivo; si no se puede alinear, omitirla.
