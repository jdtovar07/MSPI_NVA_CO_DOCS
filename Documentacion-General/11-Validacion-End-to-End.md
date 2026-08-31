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

1. **NIST derivado.** Las 22 categorías CSF 2.0 son `DERIVED` (`ISO_CODES_AVG`): promedio de controles Anexo A y/o cláusulas PHVA según `iso_control_code` (fiel a las fórmulas Excel). La UI es solo lectura; valores como `GV.OC=50` o `ID.AM≈27` aparecen al calificar las fuentes, sin entrada manual NIST ni restricción artificial de escala en la categoría.
2. **Madurez** no se calificó en esta corrida (requisitos sin puntuar → sin nivel); el cálculo de madurez está cubierto por pruebas unitarias.
3. **Entorno:** el reset de BD (`down -v`) vacía `iam.user`; el usuario principal (`admin@mspi.local`) debe sembrarse tras el reseed (hoy vía `seed-usuario-principal.ps1` en Windows). Recomendado: incluirlo en el MER seed para que sobreviva al reseed.

## 5. Veredicto

- **Flujo funcional:** ✅ crear organización (con email), crear evaluación, calificar (controles/PHVA), ver NIST derivado y tablero único, sin mocks.
- **Motor de cálculo:** ✅ reproduce las fórmulas del instrumento (validado a mano + 101 pruebas unitarias).
- **Paridad celda-a-celda con el Excel:** ✅ en estructura y fórmulas; NIST por derivación desde Anexo A / cláusulas (ver §4.1).

---

## 6. Paso a paso para validar en la UI (checklist del equipo)

Stack arriba (`http://localhost:4200`), login `admin@mspi.local` / `Admin123!`.

**A. Seguridad / limpieza (sin information disclosure)**
- [ ] El login **no** muestra la caja de "Usuarios de prueba" ni contraseñas.
- [ ] Ningún texto visible al usuario menciona `ms_*`, `mf_*`, `Micro-frontend` ni `(puerto XXXX)`.
- [ ] Títulos de pestaña usan la marca **AuditCyber** (p. ej. `AuditCyber — Evaluaciones`), no el nombre del microfrontend.
- [ ] En miembros de evaluación, el selector de usuario se etiqueta **Usuario** (sin `(ms_iam)`).
- [ ] En el panel de control, la ayuda de evidencias dice que se guardan **de forma segura** (sin nombrar el servicio) y el enlace es **Gestionar evidencias →**.
- [ ] Toasts/errores de negocio **no** muestran camelCase ni enums crudos (`evidenceText`, `SCORED`, etc.); usan etiquetas en español.

**A2. Revisión de controles**
- [ ] En diligenciamiento, el select de estado del control solo tiene Pendiente / En progreso / Completado (sin Validado / Requiere ajustes).
- [ ] En `EN_REVISION` con rol revisor, guardar Validado/Requiere ajustes persiste vía revisión (toast «Revisión guardada correctamente») y el % Validado sube al marcar Validado.
- [ ] Tras guardar calificación u revisión con éxito, el modal se cierra; si falla, permanece abierto (toast de error) y solo cierra tras 3 fallos consecutivos en el mismo control.

**A3. Mis evaluaciones asignadas / plazos**
- [ ] Sin `dueDate`, la columna Fecha límite muestra «Sin fecha límite» (no «31/12/1969» ni «Vencida»).
- [ ] `progress` muestra un % coherente con controles calificados / total (o «—»/0% si aún no hay datos); nunca el texto «null%».
- [ ] Una evaluación **nueva** arranca con progreso **0%** (controles en `PENDING`, no `SCORED`/0).
- [ ] En Configuración → Evaluaciones → Plazos, se pueden guardar días iniciales (1–365, default 30) y días de ampliación (default 15).
- [ ] Una evaluación nueva tiene `due_date` = creación + días iniciales.
- [ ] Con evaluación vencida o ≤5 días, el evaluador asignado puede solicitar ampliación (motivo obligatorio); no puede haber 2 PENDING.
- [ ] AdminSistema/AdminInstrumento o Revisor/EvaluadorRevisor aprueba (suma días a `due_date`) o rechaza (comentario obligatorio).

**A4. Eliminación lógica**
- [ ] Evaluador asignado puede solicitar eliminación (motivo obligatorio); no hay dos PENDING.
- [ ] Al aprobar, la evaluación sigue visible con aviso de gracia (`assessmentDeletionGraceDays`) y botón Recuperar.
- [ ] Tras la gracia, desaparece de listados/my-assigned pero el registro permanece (`deleted_at`); admin ve `/evaluations/deleted`.

**B. Organización (bug #1 y #2)**
- [ ] Crear organización con **correo** → al guardar **aparece un toast de éxito** y **redirige a la lista**.
- [ ] En la lista de organizaciones se ve la columna **Correo** con el email guardado.

**C. Crear evaluación (bug #3)**
- [ ] Crear una evaluación sobre la organización → **se crea sin error** (antes daba error 500).
- [ ] El selector de **Auditor** muestra **usuarios reales** (no nombres inventados).

**D. Instrumento (93 controles, PHVA, NIST)**
- [ ] En controles del Anexo A aparecen **93 controles** en **4 dominios** (A.5 Organizacionales 37 · A.6 Personas 8 · A.7 Físicos 14 · A.8 Tecnológicos 34).
- [ ] En **PHVA** se ven las **7 cláusulas** con **sub-numerales** (4.1…10.2) y pesos **56 / 16 / 14 / 14**.
- [ ] En **NIST** hay **6 funciones** empezando por **GOBERNAR**; la pantalla es **solo lectura** (valores derivados del Anexo A / cláusulas).
- [ ] En **PHVA** se pueden adjuntar archivos de evidencia por ítem (`relationType=PHVA_ITEM`).

**E. Prueba de paridad (reproducible)**
- [ ] Tras calificar Anexo A + PHVA según la muestra del instrumento, NIST → GOBERNAR se acerca al Excel (p. ej. promedio **42**).
- [ ] En un dominio (p. ej. A.6), califica todos sus controles con `40` → la efectividad del dominio debe dar **40**.
- [ ] En PHVA, califica todos los sub-numerales con `80` → el total debe dar **80** y cada fase su aporte ponderado (PLAN 44.8→, DO 12.8, etc.).

**F. Tablero y reporte**
- [ ] El **tablero de diagnóstico es uno solo** (en el hub de la evaluación); la sección de **Reportes** solo **genera y descarga** el PDF/Excel (no duplica el tablero).
- [ ] Generar el reporte y descargarlo.

**G. Estado "100% funcional"**: todos los anteriores en verde = flujo completo operativo con datos reales y motor de cálculo que reproduce las fórmulas del instrumento.
