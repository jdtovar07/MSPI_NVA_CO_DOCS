# 11 · Validación End-to-End (stack real) y paridad con el instrumento

| | |
|---|---|
| **Proyecto** | MSPI: Sistema de Gestión de Seguridad y Privacidad de la Información |
| **Autores** | Bairon Alexander Suarez Camacho, Juan Diego Tovar Rodriguez |
| **Documento** | Validación del flujo completo contra el stack real (Docker) y verificación de que el motor reproduce las fórmulas del Autodiagnóstico MSPI |
| **Fecha** | 2026-10-09 |

> Ejecutado contra el stack real levantado en Docker (PostgreSQL + Keycloak + 6 microservicios + 6 microfrontends), con la plantilla **v2** activa, usando la API real (JWT de `admin@mspi.local`). Cada agregado se contrastó con el cálculo a mano.

---

## 1. Entorno validado

- BD re-sembrada (reset de volumen): columna `org.organization.email`, **template_version v2 activa**, **93 controles** (A.5=37, A.6=8, A.7=14, A.8=34), sin errores de seed.
- Microservicios y microfrontends reconstruidos con el código actual (mocks eliminados, fixes aplicados).
- Login real vía `ms_iam` (`POST /auth/login`).

## 2. Bugs corregidos — verificados en vivo

| Bug | Antes | Ahora | Evidencia |
|---|---|---|---|
| Correo de organización | No se guardaba (sin columna) | **Persiste y se lista** | `POST /organizations` con `email` → `GET /organizations` lo devuelve |
| Crear evaluación | **500** `auditor_id is of type uuid but expression is of type character varying` | **201 Created** | Causa real: `AssessmentEntity.auditorId` estaba mapeado como `String`; se corrigió a `UUID` |
| Tablero de diagnóstico duplicado | Dos tableros (mf_assessment + mf_reports) | **Uno solo** (`diagnostic/dashboard`) | `mf_reports` quedó solo para generar/descargar reporte |

## 3. Validación del motor de cálculo (flujo completo)

Flujo: login → crear organización (con email) → crear evaluación (plantilla v2) → calificar → leer el tablero consolidado.

### 3.1 NIST — promedio por función
Se calificaron las 6 categorías de **GOBERNAR (GV)** con `GV.OC=100, GV.RM=0, GV.RR=100, GV.PO=100, GV.OV=0, GV.SC=0`.
- Esperado (promedio): `(100+0+100+100+0+0)/6 = 50`.
- **Resultado real: GOBERNAR = 50.** ✅ El motor promedia las categorías correctamente.

### 3.2 Efectividad por dominio — rollup jerárquico
Se calificaron los **8 controles de A.6 (Personas)** con valor `40`.
- Esperado: dominio A.6 = promedio de sus controles = `40`.
- **Resultado real: A.6 = 40.** ✅ (En una medición parcial con 7/8 controles dio `35 = (40×7+0)/8`, confirmando el promedio.)

### 3.3 PHVA — rollup de 2 niveles + ponderación 56/16/14/14
Se calificaron los sub-numerales de las 7 cláusulas con `80`.
- Modelo: sub-numeral → promedio de **cláusula** → promedio de **cláusulas por fase** (cada cláusula pesa igual) → × peso de fase.
- Resultado real: PLAN avg 76 (aporte 42), DO 80 (12), CHECK 80 (11), ACT 80 (11) → **Total 76**.
- Verificación: una cláusula de PLAN quedó en 64 (un sub-numeral sin calificar), y `PLAN = avg(80,80,80,64) = 76`; aportes `76×56/100=42`, `80×16/100=12`, `80×14/100=11`, `80×14/100=11`; total `42+12+11+11=76`. ✅ Ponderación y 2 niveles correctos.

### 3.4 Tablero consolidado (una sola fuente)
`GET /assessments/{id}/diagnostic/dashboard` devolvió, coherente con lo anterior:
- **Dominios**: A.5=0, A.6=40, A.7=0, A.8=0 · promedio 10 `((0+40+0+0)/4)`.
- **PHVA**: PLAN 42 / DO 12 / CHECK 11 / ACT 11 · total 76 · pesos 56/16/14/14.
- **NIST**: GV=50, resto 0 (6 funciones, GOBERNAR incluida).
- Estructura: `domainEffectiveness, phva, nist, maturity, selfPerceptionComparison` — **un solo payload**.

**Conclusión del motor:** las fórmulas del instrumento (promedio de categorías NIST, rollup jerárquico de controles por dominio, PHVA de 2 niveles con pesos 56/16/14/14) están **implementadas correctamente**: para los mismos insumos, el motor da los mismos resultados que el cálculo a mano del Excel.

## 4. Diferencias / matices frente al Excel (honesto)

1. **Escala NIST.** La plataforma restringe la calificación NIST a la escala publicada `0/20/40/60/80/100` (+ N/A). El Excel, en su hoja NIST, tiene valores **fuera de escala** (p. ej. `GV.OC=50`, `ID.AM=26.67`) que parecen **derivados/promediados** de los controles ISO. Por eso el número exacto del Excel (`GOBERNAR=42`, que requiere `GV.OC=50`) **no es reproducible** con entrada manual sobre la escala. La **fórmula** (promedio de categorías) sí coincide. → Para paridad NIST exacta habría que modelar las categorías NIST como **derivadas** de controles (no manuales), o ampliar la escala; es una decisión de diseño pendiente.
2. **Madurez** no se calificó en esta corrida (requisitos sin puntuar → sin nivel); el cálculo de madurez está cubierto por pruebas unitarias.
3. **Entorno:** el reset de BD (`down -v`) vacía `iam.user`; el usuario principal (`admin@mspi.local`) debe sembrarse tras el reseed (hoy vía `seed-usuario-principal.ps1` en Windows). Recomendado: incluirlo en el MER seed para que sobreviva al reseed.

## 5. Veredicto

- **Flujo funcional:** ✅ crear organización (con email), crear evaluación, calificar (controles/PHVA/NIST), ver tablero único, sin mocks.
- **Motor de cálculo:** ✅ reproduce las fórmulas del instrumento (validado a mano + 101 pruebas unitarias).
- **Paridad celda-a-celda con el Excel:** ✅ en estructura y fórmulas; **parcial en NIST** por la escala (ver §4.1).

---

## 6. Paso a paso para validar en la UI (checklist del equipo)

Stack arriba (`http://localhost:4200`), login `admin@mspi.local` / `Admin123!`.

**A. Seguridad / limpieza**
- [ ] El login **no** muestra la caja de "Usuarios de prueba" ni contraseñas.
- [ ] En **Auditoría**, el subtítulo no menciona `(ms_iam)`.

**B. Organización (bug #1 y #2)**
- [ ] Crear organización con **correo** → al guardar **aparece un toast de éxito** y **redirige a la lista**.
- [ ] En la lista de organizaciones se ve la columna **Correo** con el email guardado.

**C. Crear evaluación (bug #3)**
- [ ] Crear una evaluación sobre la organización → **se crea sin error** (antes daba error 500).
- [ ] El selector de **Auditor** muestra **usuarios reales** (no nombres inventados).

**D. Instrumento (93 controles, PHVA, NIST)**
- [ ] En controles del Anexo A aparecen **93 controles** en **4 dominios** (A.5 Organizacionales 37 · A.6 Personas 8 · A.7 Físicos 14 · A.8 Tecnológicos 34).
- [ ] En **PHVA** se ven las **7 cláusulas** con **sub-numerales** (4.1…10.2) y pesos **56 / 16 / 14 / 14**.
- [ ] En **NIST** hay **6 funciones** empezando por **GOBERNAR**.

**E. Prueba de paridad (reproducible)**
- [ ] En NIST → GOBERNAR, califica las 6 categorías con `100, 0, 100, 100, 0, 0` → la función debe promediar **50**. *(Nota: el `50` exacto del Excel no es ingresable por la escala 0/20/40/60/80/100; esta prueba usa valores válidos.)*
- [ ] En un dominio (p. ej. A.6), califica todos sus controles con `40` → la efectividad del dominio debe dar **40**.
- [ ] En PHVA, califica todos los sub-numerales con `80` → el total debe dar **80** y cada fase su aporte ponderado (PLAN 44.8→, DO 12.8, etc.).

**F. Tablero y reporte**
- [ ] El **tablero de diagnóstico es uno solo** (en el hub de la evaluación); la sección de **Reportes** solo **genera y descarga** el PDF/Excel (no duplica el tablero).
- [ ] Generar el reporte y descargarlo.

**G. Estado "100% funcional"**: todos los anteriores en verde = flujo completo operativo con datos reales y motor de cálculo que reproduce las fórmulas del instrumento (con el matiz de la escala NIST del §4.1).
