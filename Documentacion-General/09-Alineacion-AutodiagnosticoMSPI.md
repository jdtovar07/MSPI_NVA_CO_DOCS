# 09 · Alineación con el instrumento oficial (AutodiagnosticoMSPI.xlsx)

| | |
|---|---|
| **Proyecto** | MSPI: Sistema de Gestión de Seguridad y Privacidad de la Información |
| **Autores** | Bairon Alexander Suarez Camacho, Juan Diego Tovar Rodriguez |
| **Documento** | Trazabilidad instrumento ↔ implementación, brechas detectadas, cambios aplicados y validación |
| **Fecha** | 2026-10-08 |

> Este documento consolida el análisis de alineación entre el **Instrumento de Identificación de la Línea Base de Seguridad MSPI** (archivo `AutodiagnosticoMSPI.xlsx`, tipo MinTIC, basado en ISO/IEC 27001:2022 + NIST CSF) y la plataforma implementada. Registra las brechas encontradas, las decisiones tomadas, los cambios aplicados (versión de catálogo **v2**) y la validación realizada.

---

## 1. Objetivo

Verificar que la plataforma **reproduce con exactitud** las reglas de cálculo del instrumento oficial y cerrar las divergencias detectadas, sin romper la lógica existente. El instrumento es la fuente de verdad del dominio; la plataforma lo automatiza.

## 2. El instrumento (11 hojas) y su mapeo a la implementación

| Hoja del Excel | Qué define | Módulo que lo implementa | Estado |
|---|---|---|---|
| RECOMENDACIONES | Guía de diligenciamiento | — | N/A |
| PORTADA | Efectividad por dominio, avance PHVA, madurez, NIST | `ms_assessment` + `mf_reports` | ✅ |
| ESCALA DE EVALUACIÓN | Escala 0/20/40/60/80/100 + N/A | `ms_catalog` (escala/bandas) | ✅ |
| LEVANTAMIENTO DE INFO. | Contexto + ítems documentales | `ms_evidence` / `mf_evidence` | ✅ |
| ÁREAS INVOLUCRADAS | Responsables por eje | `ms_assessment` / `mf_assessment` | ✅ |
| CLÁUSULAS | Cláusulas de gestión ISO 4–10 (PHVA) | `ms_assessment` | ✅ (v2, 2 niveles) |
| ORGANIZACIONALES (A.5) | 37 controles Anexo A | `ms_catalog` / `ms_assessment` | ✅ (v2, 93 controles) |
| PERSONAS (A.6) | 8 controles Anexo A | idem | ✅ |
| FÍSICOS (A.7) | 14 controles Anexo A | idem | ✅ |
| TECNOLÓGICOS (A.8) | 34 controles Anexo A | idem | ✅ |
| NIST | NIST CSF 2.0 (6 funciones, 22 categorías) | `ms_assessment` | ✅ (v2) |

## 3. Brechas detectadas (análisis inicial)

Al comparar el instrumento con el seed real del catálogo y el código se confirmaron **tres divergencias estructurales**:

1. **Ponderación PHVA.** El seed usaba `{"PLAN":40,"DO":20,"CHECK":20,"ACT":20}`; el instrumento implica **56/16/14/14** a nivel de fase (Planificación = 4 cláusulas ISO × 14 %, Operación 16 %, Evaluación 14 %, Mejora 14 %). Además el módulo PHVA usaba ítems propios (P.1…M.2) en lugar de las 7 cláusulas ISO (4–10) con sus sub-numerales.
2. **NIST CSF 1.1 vs 2.0.** La implementación era CSF 1.1 (5 funciones; gobernanza como `ID.GV-*` bajo *Identificar*; `FUNCTION_ORDER` hardcodeado). El instrumento es **CSF 2.0**: 6 funciones incluyendo **GOBERNAR (GV)** y 22 categorías mapeadas a ISO 27001:2022.
3. **Catálogo de controles incompleto.** El seed tenía un subconjunto reducido; el instrumento enumera los **93 controles completos** del Anexo A 2022 (37 A.5 + 8 A.6 + 14 A.7 + 34 A.8).

## 4. Decisiones

- **Versionado**: crear una nueva `template_version` **v2** `PUBLISHED` (UUID `d0000000-0000-4000-8000-000000000002`), con `published_at` posterior a v1, dejando **v1 intacta**. La versión activa se resuelve por `findFirstByStatusOrderByPublishedAtDesc("PUBLISHED")`. Las evaluaciones existentes conservan su snapshot (inmutabilidad).
- **PHVA**: modelo de **2 niveles** (cláusula → sub-numeral) con réplica numérica exacta de la PORTADA.
- **NIST**: migración **completa a CSF 2.0** (6 funciones, 22 categorías).
- **Controles**: poblar los **93 controles** del Anexo A 2022.

## 5. Cambios aplicados (en v2)

### 5.1 PHVA — 2 niveles (cláusula → sub-numeral)
- `phva_item_catalog` extendido con `parent_code` y `node_type` (`CLAUSE` | `ITEM`).
- v2: **7 cláusulas** (C.4…C.10) + **23 sub-numerales** (4.1…10.2). Solo los sub-numerales son calificables (`MANUAL`).
- Pesos `phva_weights = phva_caps = {"PLAN":56,"DO":16,"CHECK":14,"ACT":14}`.
- Cálculo (`ComputePhvaAdvanceUseCase` / `PhvaScoreResolver.averageComponentScore`): score de sub-numeral → promedio de cláusula → promedio de cláusulas por fase (cada cláusula pesa igual, sin importar cuántos sub-numerales tenga) → × peso de fase. Fallback plano para v1.

Mapeo fase → cláusulas:

| Fase | Peso | Cláusulas (sub-numerales) |
|---|---|---|
| PLAN | 56 % | 4 Contexto (4.1–4.4) · 5 Liderazgo (5.1–5.3) · 6 Planificación (6.1–6.3) · 7 Soporte (7.1–7.5) |
| DO | 16 % | 8 Operación (8.1–8.3) |
| CHECK | 14 % | 9 Evaluación del desempeño (9.1–9.3) |
| ACT | 14 % | 10 Mejora (10.1–10.2) |

### 5.2 NIST — CSF 2.0 (6 funciones, 22 categorías)
- `nist_function`: agregada **GV 'Gobernar'** (posición 1). Orden: GV, ID, PR, DE, RS, RC.
- 22 categorías CSF 2.0 (ítems `MANUAL`, `source_type='NIST'`) con referencia ISO 27001:2022:
  GV: OC, RM, RR, PO, OV, SC · ID: AM, RA, IM · PR: AA, AT, DS, PS, IR · DE: CM, AE · RS: MA, AN, CO, MI · RC: RP, CO.
- `nist_function_targets` incluye `GV`.
- Backend: `ComputeNistSummaryUseCase` ahora deriva las funciones **dinámicamente** del snapshot (sin lista hardcodeada); se añadió `functionName`/`position` al snapshot/DTO/catálogo.
- El promedio de una función = media de sus categorías (ej. **GOBERNAR = avg(50,0,100,100,0,0) = 42**, idéntico a la PORTADA).

### 5.3 Controles del Anexo A 2022 (93)
- `control_catalog_node` v2: 4 dominios (A.5–A.8) + **93 controles hoja** con la numeración `ID.ITEM` del instrumento (`AD.1.x`, `P.1.x`, `F.1.x`, `T.1.x`) y su código ISO 2022.
- Inventario completo: [`anexo_a_2022_controls.csv`](anexo_a_2022_controls.csv).
- `control_rule` regenerado para v2. Herencias de madurez/NIST remapeadas a los códigos 2022 (sin referencias rotas).

### 5.4 Efectividad por dominio
- `ComputeDomainEffectivenessUseCase` corregido: muestra solo los dominios presentes en la plantilla de la evaluación (v2 = 4 temas A.5–A.8), no los 14 dominios globales (2013). `mf_reports` encabezado corregido a "Dominios ISO (A.5–A.8)".

## 6. Validación

### 6.1 Pruebas unitarias (motor de cálculo) — ✅ 101 en verde
- `ms_assessment`: **84 tests**, 0 fallos. Incluye paridad PHVA 2 niveles y NIST GOBERNAR=42.
- `ms_catalog`: **17 tests**, 0 fallos. Incluye `V2AnnexA2022ControlCatalogSeedTest` (93 controles).
- Comando: `./gradlew test` en cada microservicio.

### 6.2 Carga del seed contra PostgreSQL real — ✅ sin errores
Se levantó un PostgreSQL desechable con los scripts reales de init de Docker (`docker-config/docker/postgres/init/`: `MER-MSPI.sql` + `MER-SEED-CATALOG.sql` + …). Resultados:

| Verificación | Resultado |
|---|---|
| Carga del seed | Sin errores SQL (FK/sintaxis/referencias) |
| Versión activa | **v2, PUBLISHED** |
| Controles v2 por dominio | A.5=37, A.6=8, A.7=14, A.8=34 → **93** |
| PHVA v2 | 7 `CLAUSE` + 23 `ITEM`; pesos 56/16/14/14 |
| NIST funciones | GV, ID, PR, DE, RS, RC (6) + 22 categorías |
| Referencias de control rotas en madurez | **0** |
| Herencias PHVA rotas en madurez | **0** (hereda de C.5/C.6/C.7/C.10) |

> **Nota importante de infraestructura:** el stack Docker **no** siembra desde `ms_catalog/.../resources/data.sql` (`spring.sql.init.mode: never`, `ddl-auto: none`), sino desde `docker-config/docker/postgres/init/MER-SEED-CATALOG.sql` (montado en `/docker-entrypoint-initdb.d`). Ambos archivos quedaron sincronizados con v2; para validar contra Docker hay que mirar el MER-SEED, no el `data.sql`.

### 6.3 Validación end-to-end por UI — ⬜ pendiente (requiere entorno con secretos)
Levantar el stack completo (6 microservicios + Keycloak + UI) con los secretos de Infisical, crear una evaluación, cargar los puntajes de muestra del Excel y comparar la PORTADA **celda a celda**. Procedimiento en la sección 7.

## 7. Procedimiento de validación (reproducible)

**A) Validación del seed contra Postgres real (sin secretos):**
```bash
INIT="MSPI_NVA_CO_MR_BACK/docker-config/docker/postgres/init"
docker run -d --name mspi_pg_validate \
  -e POSTGRES_USER=admin -e POSTGRES_PASSWORD=admin123 -e POSTGRES_DB=MSPI \
  -v "$INIT":/docker-entrypoint-initdb.d:ro -p 55432:5432 postgres:16-alpine
# esperar init; revisar que NO haya errores:
docker logs mspi_pg_validate 2>&1 | grep -iE "error|fatal|violates|does not exist"
```
Consultas clave (v2 = `d0000000-0000-4000-8000-000000000002`):
```sql
-- versión activa
SELECT version, status FROM catalog.template_version ORDER BY published_at DESC LIMIT 1;
-- 93 controles por dominio
SELECT iso_domain_code, count(*) FROM catalog.control_catalog_node
 WHERE template_version_id='d0000000-0000-4000-8000-000000000002' AND node_type='CONTROL' AND is_scored
 GROUP BY iso_domain_code ORDER BY 1;
-- PHVA: 7 cláusulas + 23 sub-numerales
SELECT node_type, count(*) FROM catalog.phva_item_catalog
 WHERE template_version_id='d0000000-0000-4000-8000-000000000002' GROUP BY node_type;
-- NIST: 6 funciones
SELECT string_agg(code,',' ORDER BY position) FROM catalog.nist_function;
-- madurez sin referencias rotas (debe dar 0)
SELECT count(*) FROM catalog.maturity_requirement_catalog m
 WHERE m.template_version_id='d0000000-0000-4000-8000-000000000002'
   AND m.source_phva_item_code IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM catalog.phva_item_catalog p
     WHERE p.template_version_id=m.template_version_id AND p.code=m.source_phva_item_code);
```
Limpieza: `docker rm -f mspi_pg_validate`.

**B) Validación end-to-end completa:** seguir el manual de despliegue ([`05-Manual-Despliegue.md`](05-Manual-Despliegue.md)) con el entorno de secretos, y la guía de pruebas funcionales ([`06-Guia-Pruebas-Funcionales.md`](06-Guia-Pruebas-Funcionales.md)). Caso de paridad recomendado: cargar en NIST GOBERNAR los valores 50/0/100/100/0/0 y confirmar que la función promedia **42**.

## 8. Estado final

- **Estructura**: completa y alineada con el instrumento (PHVA 2 niveles 56/16/14/14, NIST CSF 2.0, 93 controles 2022, 4 dominios, escala, levantamiento, áreas).
- **Motor de cálculo**: validado (101 pruebas unitarias en verde).
- **Datos/seed**: validado contra PostgreSQL real (carga íntegra, sin referencias rotas).
- **Pendiente**: validación visual end-to-end por UI (requiere entorno con secretos).
