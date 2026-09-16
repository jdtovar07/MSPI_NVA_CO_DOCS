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
| 2026-09-15 | **DOCS-3** | Ilustración profesional: C4/despliegue/ER/secuencias generales + diagramas hexagonales/clases/rutas en cada `03-Diseno` (8 MS + 6 MF). |
| 2026-09-15 | MER regenerado | `MER-MSPI.sql`/`.dbml`/`.pdf` desde base + todos los `patch-*.sql` (incl. `password_reset_request`, `request_number`, `audit`/`admin`). |
| 2026-09-15 | MER vectorial | Sustituye PDF raster por `MER-MSPI.svg`; `erDiagram` Mermaid por esquema en `Modelo-Datos-MER.md`. |
| 2026-09-15 | Referencia de API por microservicio | `08-Referencia-API.md` en los 8 ms (156 endpoints generados desde el código) e inventario/grafo de llamadas en la referencia consolidada. |
| 2026-09-16 | MER completo | `erDiagram` por esquema con las 73 tablas, 684 columnas y 135 FK; propósito de cada tabla y dependencias entre esquemas. |
| 2026-09-16 | Diagramas validados | Los diagramas Mermaid del repositorio compilan sin errores; se corrigieron 3 secuencias de reportes. |
| 2026-09-16 | SDLC alineado al código | `ms_iam` sin bitácora/config; inventario de pruebas generado en cada `05-Pruebas.md`. |
| 2026-09-16 | Mapas de microfrontends | `08-Mapa-Rutas-y-Endpoints.md` en los 6 mf; contraste de 148 llamadas frontend ↔ backend. |
| 2026-09-16 | Documentos generales | Guía de pruebas (CP-01…CP-33), manual de usuario, glosario, objetivos, ADR y matriz de trazabilidad (`18`). |
| — | Extracción `ms_audit` / `ms_admin` (código) | Auditoría → `:8088` esquema `audit`; config → `:8089` esquema `admin` (patches SQL). Ver BACK. |
| — | Features de solicitudes (código) | Radicados `SOL-*`, soft-delete + gracia + sweeper; bandeja en `mf_shell`. |
| — | SEG-A (código) | Rate limit, cabeceras, magic bytes, constant-time API-key, log sanitizer — `wiki/Seguridad.md`. |

!!! note "Regla de fechas"
    No poner en los Markdown campos tipo «Fecha de elaboración» o «Última revisión cruzada con código». Si una fecha es imprescindible, debe ser la del commit que toca el archivo; si no se puede alinear, omitirla.
