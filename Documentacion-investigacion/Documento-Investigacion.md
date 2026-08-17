# Componente Investigativo — Proyecto de Grado MSPI

**Fecha de elaboración del documento:** 2026-08-18
**Autor:** [PENDIENTE: a completar por el autor]
**Universidad / Programa académico:** [PENDIENTE: a completar por el autor]
**Asesor / Director de trabajo de grado:** [PENDIENTE: a completar por el autor]
**Fecha de sustentación:** [PENDIENTE: a completar por el autor]
**Línea de investigación / énfasis:** [PENDIENTE: a completar por el autor]

> **Nota metodológica sobre este documento.** La carpeta `Propuesta-grado` del repositorio estaba vacía al momento de elaborar este documento: no existía un anteproyecto o documento de investigación formal previo. Este componente investigativo fue reconstruido **a partir de evidencia real del repositorio de código** (microservicios backend, microfrontends, documentación técnica, historias de usuario, modelo de datos y guías de integración), no a partir de un formulario de anteproyecto ya diligenciado por el autor. Todo dato institucional, académico o cronológico que no pueda sustentarse con evidencia del repositorio se marca explícitamente como `[PENDIENTE: a completar por el autor]`. El autor del proyecto debe revisar, completar y validar estos vacíos antes de presentar el documento a su comité o asesor.

---

## 1. Título del proyecto (propuesto)

> **MSPI: Sistema de Gestión de Seguridad y Privacidad de la Información basado en ISO/IEC 27001, implementado con arquitectura de microservicios y microfrontends, para la automatización del Instrumento de Línea Base de Seguridad de MinTIC Colombia**

Título alternativo más corto: *"Automatización del diagnóstico de madurez en seguridad de la información bajo ISO/IEC 27001 mediante una plataforma de microservicios y microfrontends (MSPI)"*.

Este es un **título propuesto derivado del alcance funcional realmente construido** (ver Sección 10), sujeto a validación y ajuste por parte del autor y su asesor según los lineamientos de nomenclatura de su universidad. `[PENDIENTE: a completar por el autor]` — confirmación del título definitivo.

---

## 2. Planteamiento del problema

Las entidades públicas colombianas están obligadas, en el marco de la Política de Gobierno Digital y el Modelo de Seguridad y Privacidad de la Información (MSPI) de MinTIC, a evaluar periódicamente su nivel de madurez en seguridad de la información con base en el Anexo A de ISO/IEC 27001:2013, el ciclo PHVA (Planificar–Hacer–Verificar–Actuar) y el marco NIST CSF. La evidencia recogida en `docs/proyecto/Historias_Usuario_MSPI_v2.md` (líneas 35–37) documenta explícitamente el problema de origen:

> "El producto a desarrollar es una aplicación web que automatiza el Instrumento de Identificación de la Línea Base de Seguridad MSPI definido por MinTIC. **Reemplaza una hoja de cálculo Excel de nueve hojas** que actualmente se diligencia manualmente por evaluadores y consultores cuando una entidad pública colombiana audita su Modelo de Seguridad y Privacidad de la Información."

De esta evidencia se desprenden los problemas concretos que el sistema resuelve:

1. **Cálculo manual propenso a error humano.** El instrumento original en Excel exige fórmulas anidadas de `AVERAGE`, `VLOOKUP` e `IF` replicadas a mano en nueve hojas (Portada, Levantamiento, Áreas, Administrativas, Técnicas, PHVA, Madurez, Ciber, Escala de Evaluación), con jerarquías de hasta cuatro niveles (dominio → objetivo → sub-objetivo → control hoja) y reglas de exclusión de valores "N/A" que son fáciles de romper al copiar/pegar celdas (`Historias_Usuario_MSPI_v2.md`, Módulos 3–6).
2. **Ausencia de trazabilidad y control de versiones del instrumento.** Un archivo Excel no versiona quién calificó qué control, cuándo, ni con qué evidencia documental de soporte; tampoco impide que dos evaluadores sobrescriban el mismo archivo simultáneamente (riesgo de concurrencia documentado como caso borde en HU-CFG-01: *"Dos evaluadores no pueden editar simultáneamente la misma evaluación"*).
3. **Fragmentación de la evidencia documental.** El levantamiento de información exige 43 ítems de evidencia (HU-CFG-05) agrupados en cuatro bloques (Básica, Implementación, Evaluación, Mejora Continua), cada uno con múltiples archivos adjuntos; en el flujo Excel esta evidencia vive fuera del archivo de cálculo, sin vínculo trazable al control que sustenta.
4. **Ausencia de control de acceso diferenciado.** El instrumento en Excel no distingue entre quién puede calificar, quién puede solo revisar y quién solo debe leer resultados — una limitación crítica cuando la evaluación involucra a un equipo de auditores externos y funcionarios internos con distintos niveles de responsabilidad y confidencialidad.
5. **Imposibilidad de consolidar/comparar evaluaciones históricas.** Al ser un archivo suelto, no hay comparabilidad automática entre periodos, ni un dashboard consolidado de brechas priorizadas.

**Pregunta de investigación propuesta:** ¿Es posible diseñar e implementar una plataforma de software, basada en arquitectura de microservicios y microfrontends, que reproduzca con exactitud las reglas de cálculo del Instrumento de Línea Base de Seguridad MSPI (ISO/IEC 27001, PHVA, madurez, NIST CSF), eliminando el diligenciamiento manual en hoja de cálculo, garantizando trazabilidad de evidencias y control de acceso basado en roles?

`[PENDIENTE: a completar por el autor]` — delimitación formal del problema en términos de población objetivo (¿cuántas/qué tipo de entidades públicas?, ¿alcance nacional o de una entidad piloto?) y de la justificación normativa exacta (circular o decreto de MinTIC que exige el diligenciamiento del instrumento), que el repositorio no documenta con una referencia normativa formal citable.

---

## 3. Contexto y antecedentes

### 3.1 Contexto organizacional y normativo

El sistema MSPI se enmarca en el **Modelo de Seguridad y Privacidad de la Información** definido por el Ministerio de Tecnologías de la Información y las Comunicaciones (MinTIC) de Colombia, como lo confirma el encabezado del instrumento fuente (`docs/linea_base_seguridad_ISO27001.md`, líneas 1–2): *"Instrumento de Identificación de la Línea Base de Seguridad — Basado en ISO 27001:2013 – Modelo de Seguridad y Privacidad de la Información (MSPI) – MinTIC Colombia"*. El instrumento clasifica las entidades evaluadas en cuatro categorías (Nacional, Territorial A, Territorial B, Territorial C — HU-CFG-02), cada una con metas diferenciadas de avance esperado en el ciclo PHVA (40% para entidades de orden Nacional, 35% para Territorial A), lo que confirma que el público objetivo son **entidades del sector público colombiano** sujetas a esta política.

### 3.2 Antecedentes del instrumento origen

El repositorio documenta con precisión la estructura del instrumento Excel de nueve hojas que el sistema reemplaza: Portada, Escala de Evaluación, Levantamiento de Información, Áreas Involucradas, Controles Administrativos, Controles Técnicos, Ciclo PHVA, Madurez y Ciberseguridad (NIST). El archivo `docs/proyecto/DBvsExcel.md` explica la justificación de por qué se migra de una hoja de cálculo a una base de datos relacional particionada por esquemas (`catalog`, `assessment`, `evidence`, `iam`, `org`, `reporting`), distinguiendo explícitamente **catálogo** (la "plantilla vacía", versionable) de **ejecución** (el "Excel ya diligenciado", con snapshot congelado por evaluación) — un antecedente de diseño que evidencia una decisión arquitectónica deliberada de separar definición de instrumento y datos de evaluación para permitir historicidad.

### 3.3 Antecedentes de soluciones similares (categorías generales)

Sin que el repositorio referencie productos comerciales específicos, el proyecto se ubica dentro de la categoría de herramientas conocida en la industria como **GRC (Governance, Risk & Compliance)** o **ISMS (Information Security Management System) tooling**, cuyo propósito general —documentado ampliamente en la literatura de la disciplina— es digitalizar la operación de un SGSI (Sistema de Gestión de Seguridad de la Información) bajo ISO/IEC 27001: gestión de controles del Anexo A, evidencias de cumplimiento, auditorías internas, planes de tratamiento de riesgo y reportes de madurez. `[PENDIENTE: a completar por el autor]` — el autor debe documentar aquí, con las referencias bibliográficas correspondientes, un análisis comparativo de herramientas GRC/ISMS de mercado (comerciales u open-source) si su universidad exige antecedentes tecnológicos específicos con citación formal, dado que el repositorio no contiene ese análisis comparativo explícito.

---

## 4. Justificación

La justificación del proyecto se sostiene en evidencia funcional concreta, no en supuestos:

- **Trazabilidad de evidencias.** El microservicio `ms_evidence` (puerto 8086) expone un modelo de carga de archivos multipart con tipos de relación explícitos (`CONTEXT`, `LIFTING_DOC`, `REPORT_OUTPUT`) vinculados por UUID al control o ítem de levantamiento que sustentan (`docker-config/docs/PLAN_TRABAJO_MSPI_v2.md`, sección 6.2–6.3). Esto resuelve directamente la fragmentación de evidencia descrita en la Sección 2.
- **Cálculo automático y consistente.** El backend centraliza todas las fórmulas del instrumento (promedios con exclusión de N/A, redondeo *half-up*, herencia directa en objetivos de un solo hijo, cálculo recursivo de jerarquías de hasta cuatro niveles, determinación acumulativa del nivel de madurez) como lógica de dominio en `ms_assessment`, expuesta vía endpoints de solo lectura (`/scores/rollup`, `/phva/summary`, `/maturity/summary`, `/nist/summary`, `/diagnostic/dashboard`). El propio plan de trabajo v2 argumenta explícitamente por qué esto es superior a duplicar los cálculos en el frontend: *"Mantener dos implementaciones de los mismos algoritmos crea riesgo de inconsistencias"* (`PLAN_TRABAJO_MSPI_v2.md`, sección 14).
- **Control de acceso basado en roles (RBAC).** El sistema define cinco roles de negocio (`AdminSistema`, `AdminInstrumento`, `Evaluador`, `Revisor`, `Lector`) con autoridades diferenciadas (`USER_MANAGE`, `ORG_MANAGE`, `TEMPLATE_MANAGE`, `ASSESSMENT_EDIT`, `ASSESSMENT_REVIEW`, `REPORT_EXPORT`, `AUDIT_VIEW`), documentado en `Mspijdbs/RBAC-GUIDE.md` y validado en el backend real vía JWT con `realm_access.roles` de Keycloak (`Documentacion-Backend/ms_iam/01-Planificacion.md`, RI-3). Esto resuelve la ausencia de control de acceso diferenciado del instrumento Excel original.
- **Auditoría centralizada.** `ms_iam` mantiene una bitácora (`iam.audit_log`) que actúa como sumidero de eventos de autenticación propios y de eventos de negocio de otros microservicios vía un canal interno protegido (`POST /internal/audit/events`), lo que da trazabilidad de quién hizo qué y cuándo — inexistente en el flujo de archivo Excel compartido.
- **Consolidación y comparabilidad.** El endpoint `GET /assessments/{id}/diagnostic/dashboard` unifica en una sola respuesta la efectividad por dominio, el avance PHVA, el nivel de madurez y el desempeño NIST, además de comparar la autopercepción declarada por la entidad contra el resultado objetivo calculado (`selfPerceptionComparison`) — una capacidad analítica que el Excel no ofrece de forma nativa.
- **Segundo factor de autenticación (2FA/TOTP).** Su inclusión está justificada explícitamente en la documentación del propio proyecto como alineación con "los lineamientos de la línea base de seguridad ISO 27001 del proyecto" (`Documentacion-Backend/ms_iam/01-Planificacion.md`, objetivo 4) — es decir, el sistema aplica sobre sí mismo controles de seguridad equivalentes a los que audita, lo cual es un argumento de justificación reforzado por coherencia (el propio SGSI que digitaliza controles de acceso implementa control de acceso robusto).

`[PENDIENTE: a completar por el autor]` — cuantificación del impacto (por ejemplo, tiempo estimado de diligenciamiento manual vs. asistido, número de entidades que podrían beneficiarse, costo de no automatizar) si la universidad exige justificación cuantitativa con fuentes primarias (encuestas, entrevistas a evaluadores).

---

## 5. Objetivos

### 5.1 Objetivo general

Diseñar e implementar una plataforma de software basada en arquitectura de microservicios (backend) y microfrontends (frontend) que automatice el Instrumento de Identificación de la Línea Base de Seguridad MSPI de MinTIC, reproduciendo con exactitud sus reglas de cálculo de efectividad de controles ISO/IEC 27001, avance del ciclo PHVA, nivel de madurez del SGSI y desempeño frente al marco NIST CSF, con trazabilidad de evidencias y control de acceso basado en roles.

### 5.2 Objetivos específicos

Derivados directamente de los ocho módulos funcionales documentados en `Historias_Usuario_MSPI_v2.md` y de los ocho sprints de `PLAN_TRABAJO_MSPI_v2.md`:

1. Implementar el módulo de **configuración y levantamiento de información** (creación de evaluaciones, clasificación por tipo de entidad, registro de contexto organizacional y captura de los 43 ítems de evidencia documental — HU-CFG-01 a HU-CFG-05).
2. Implementar el módulo de **asignación de áreas y responsables** que vincula funcionarios a los ocho ejes de seguridad predefinidos (Control Interno, Gestión Humana, Líderes de Proceso, Compras, Continuidad, Seguridad Física, TICs, Seguridad de la Información — HU-AR-01).
3. Implementar el motor de **calificación y cálculo automático de controles administrativos y técnicos** del Anexo A de ISO/IEC 27001 (14 dominios, jerarquía recursiva de hasta cuatro niveles, exclusión de valores N/A, redondeo *half-up* — HU-ADM-01 a HU-ADM-04, HU-TEC-01 a HU-TEC-02).
4. Implementar el cálculo del **avance ponderado del ciclo PHVA** (Planificación 40%, Implementación 20%, Evaluación de Desempeño 20%, Mejora Continua 20%, con herencia automática de valores desde controles administrativos y desde el promedio total del Anexo A — HU-PHVA-01 a HU-PHVA-05).
5. Implementar el algoritmo de **determinación del nivel de madurez del SGSI** (matriz de 50 requisitos × 5 niveles con umbrales no uniformes y progresión estrictamente acumulativa — HU-MAD-01 a HU-MAD-05).
6. Implementar el módulo de **evaluación frente al marco NIST CSF** (cinco funciones: Identificar, Proteger, Detectar, Responder, Recuperar).
7. Implementar un **tablero de diagnóstico consolidado** que integre efectividad por dominio, avance PHVA, madurez, NIST y comparación de autopercepción, junto con un listado de brechas priorizadas (`/diagnostic/dashboard`, `/gaps`).
8. Implementar el subsistema de **identidad y control de acceso** (`ms_iam`/`mf_auth`): autenticación centralizada vía Keycloak, gestión de usuarios con cinco roles de negocio, 2FA/TOTP y auditoría centralizada.
9. Implementar la **generación de reportes asíncronos** (PDF/Excel) mediante jobs con *polling* en `ms_reporting`, replicando la plantilla oficial de MinTIC.

`[PENDIENTE: a completar por el autor]` — formulación final de objetivos en el verbo y nivel de detalle que exija la guía metodológica de la universidad (los aquí propuestos están redactados a partir de evidencia funcional, no de una plantilla institucional específica).

---

## 6. Marco teórico

### 6.1 Fundamentos de ISO/IEC 27001 y gestión de seguridad de la información

- **Sistema de Gestión de Seguridad de la Información (SGSI):** marco de políticas, procesos y controles que una organización implementa para gestionar el riesgo sobre la confidencialidad, integridad y disponibilidad de la información, según la norma ISO/IEC 27001.
- **Anexo A de ISO/IEC 27001:** el instrumento versiona dos alineaciones. La plantilla **v1** conserva el Anexo A **2013** (114 controles / 14 dominios A.5–A.18, documentado en `docs/linea_base_seguridad_ISO27001.md`). La plantilla activa **v2** (`template_version` `d0…002`) alinea el árbol a ISO/IEC **27001:2022** (4 temas A.5–A.8, ~93 controles hoja) y calcula la efectividad de portada solo con los dominios presentes en el snapshot de la evaluación.
- **Ciclo PHVA (Plan-Do-Check-Act):** modelo de mejora continua del SGSI. **v1**: cuatro componentes ponderados 40/20/20/20 con ítems planos. **v2**: pesos 56/16/14/14 y jerarquía de dos niveles (7 cláusulas ISO `C.4`–`C.10` + 23 sub-numerales), con rollup cláusula→fase en `ms_assessment`.
- **Niveles de madurez de un SGSI:** el instrumento define seis niveles de efectividad por control (Inexistente, Inicial, Repetible, Efectivo, Gestionado, Optimizado, en escala 0–100) y cinco niveles de madurez organizacional acumulativos (Inicial, Gestionado, Definido, Gestionado Cuantitativamente, Optimizado), un patrón que evoca modelos de madurez de capacidades tipo CMMI adaptados al dominio de seguridad de la información. En v2, requisitos que heredan de una cláusula PHVA usan el promedio de sus sub-numerales.
- **NIST Cybersecurity Framework (CSF):** segunda lente de evaluación. **v2** usa **CSF 2.0** (6 funciones incl. Gobernar/GV y 22 categorías); **v1** permanece en el enfoque CSF 1.1 de 5 funciones, con mapeos control↔subcategoría donde aplica.

`[PENDIENTE: a completar por el autor]` — desarrollo teórico completo con citación formal (APA/IEEE) de ISO/IEC 27001, ISO/IEC 27002, NIST CSF y modelos de madurez de referencia (p. ej. CMMI), que este documento no puede sustituir por tratarse de contenido normativo con derechos de autor.

### 6.2 Fundamentos de arquitectura de software aplicados

- **Arquitectura de microservicios:** estilo arquitectónico que descompone un sistema en servicios autónomos, desplegables de forma independiente y organizados alrededor de capacidades de negocio. El backend aplica este estilo con ocho carpetas de microservicio (`ms_admin`, `ms_assessment`, `ms_audit`, `ms_catalog`, `ms_evidence`, `ms_iam`, `ms_org`, `ms_reporting`), de las cuales seis están activas con puerto asignado (8082–8087) y dos (`ms_admin`, `ms_audit`) son, según el propio README del backend, *"Placeholders / docs"* — es decir, reservadas en el diseño pero sin implementación funcional completa al momento de este análisis. Esta distinción es relevante para no sobrestatar el alcance logrado (ver Sección 10).
- **Arquitectura hexagonal / Clean Architecture:** patrón que aísla el dominio de negocio de los detalles de infraestructura (framework web, ORM, proveedores externos) mediante puertos y adaptadores. Confirmado en el código real de `ms_iam`, cuyo `settings.gradle` define ocho módulos Gradle separando `domain/model`, `domain/usecase`, adaptadores de persistencia (`jpa-repository`), adaptadores REST salientes (`rest-consumer`), orquestación de casos de uso (`service`), adaptador de correo (`brevo-sender`), entrada REST (`api-rest`) y el módulo ejecutable (`app-service`) — aplicada "manualmente vía convención de carpetas" sin el plugin de Clean Architecture de Bancolombia (comentado en `build.gradle`), según documenta `Documentacion-Backend/ms_iam/01-Planificacion.md`, sección 6.
- **Microfrontends:** extensión del principio de microservicios a la capa de presentación, donde distintos equipos/módulos de UI se desarrollan y despliegan de forma independiente y se componen en un *shell* anfitrión. El frontend define seis microfrontends (`mf_shell`, `mf_auth`, `mf_org`, `mf_assessment`, `mf_evidence`, `mf_reports`) en puertos 4200–4205. Es relevante señalar, como hallazgo honesto del marco teórico aplicado, que al menos `mf_auth` **no usa Module Federation de Webpack** (mecanismo estándar de composición de microfrontends) sino integración por composición en tiempo de ejecución del navegador (iframe, `postMessage`, `localStorage`/cookie compartidos y navegación de página completa) — documentado explícitamente como hallazgo en `Documentacion-Frontend/mf_auth/01-Planificacion.md`, sección 5, mientras que el plan de trabajo v2 del backend (`PLAN_TRABAJO_MSPI_v2.md`, sección 10) sí especifica una configuración de `webpack.config.js` con `remotes` de Module Federation para los seis MFs. Esta discrepancia entre el plan documentado y lo verificado en el código de `mf_auth` es un punto legítimo de discusión arquitectónica para el marco teórico y las conclusiones.
- **Snapshot / versionado de catálogo vs. ejecución:** patrón de diseño de datos (documentado en `DBvsExcel.md`) que separa la definición versionable de un instrumento de evaluación (`catalog.*`) de la instancia congelada de una evaluación concreta (`assessment.*`), garantizando que actualizaciones futuras del instrumento no alteren evaluaciones históricas ya publicadas.
- **Bloqueo optimista (optimistic locking):** patrón de concurrencia implementado mediante el campo `rowVersion`, devuelto en cada respuesta de `AssessmentResponse` y exigido en cada `PATCH`/`PUT` de modificación, con manejo explícito del conflicto HTTP 409 (recarga de datos + notificación al usuario) — resuelve directamente el caso borde de edición concurrente identificado en el planteamiento del problema.

---

## 7. Marco tecnológico

| Capa / componente | Tecnología verificada | Evidencia en el repositorio |
|---|---|---|
| Lenguaje backend | Java 21 | `Documentacion-Backend/ms_iam/01-Planificacion.md`, `main.gradle` |
| Framework backend | Spring Boot 4.0.2 (Spring MVC, servlet) | `build.gradle` de `ms_iam` |
| Gestor de build backend | Gradle 9.3.0 (multi-módulo) | `settings.gradle` |
| Seguridad backend | Spring Security + OAuth2 Resource Server (JWT) | dependencias `spring-security-oauth2-resource-server/-jose` |
| Identidad / IdP | Keycloak (realm `iam`), Resource Owner Password Credentials | `docker-config/docs/docker/keycloak/README.md`, README raíz del backend |
| Persistencia | Spring Data JPA + Hibernate; H2 en memoria (dev), PostgreSQL (producción) | `application.yaml`, `runtimeOnly 'org.postgresql:postgresql'` |
| Base de datos | PostgreSQL, esquema `MSPI` particionado por microservicio (`iam`, `org`, `catalog`, `assessment`, `evidence`, `reporting`) | `docs/proyecto/DB-MER.txt`, `docs/proyecto/DBvsExcel.md`, README raíz |
| 2FA/TOTP | java-otp 0.4.0 + commons-codec | `jpa-repository/build.gradle` (`ms_iam`) |
| Gestión de secretos | Infisical SDK 3.0.2; alterno AWS Secrets Manager Sync (Bancolombia) | `Documentacion-Backend/ms_iam/01-Planificacion.md` |
| Resiliencia | Resilience4j Spring Boot 3 (2.3.0) | `rest-consumer/build.gradle` |
| Observabilidad backend | Micrometer + Prometheus registry | `api-rest/build.gradle` |
| Contenerización backend | `eclipse-temurin:21-jdk-alpine` (build) → `-jre-alpine` (runtime); `ms_reporting` usa `-jre-jammy` + LibreOffice | `deployment/Dockerfile`, `docker-config/` |
| Framework frontend | Angular ^19.0.0 (standalone components), TypeScript ~5.6.0 (modo `strict`) | `Documentacion-Frontend/mf_auth/01-Planificacion.md`, `package.json` |
| Composición de microfrontends | Module Federation de Webpack (planificado en backend/plan v2); `mf_auth` verificado usa composición por navegador (iframe/postMessage/localStorage) en lugar de Module Federation | `PLAN_TRABAJO_MSPI_v2.md` sec. 10 vs. `01-Planificacion.md` de `mf_auth` sec. 5 |
| UI / diseño | Angular Material + CDK, Tailwind CSS, `@ng-icons/lucide`, `ng2-charts`/Chart.js (gráficos NIST/PHVA) | `PLAN_TRABAJO_MSPI_v2.md` secciones 3.1, 5.1 |
| Gestión de estado frontend | Angular Signals (`signal`, `computed`) para `AuthStore` y `AssessmentStateService` | `PLAN_TRABAJO_MSPI_v2.md` secciones 2.3, 5.6 |
| Contenerización frontend | Node 22-alpine (build) + Nginx 1.27-alpine (runtime) | `Documentacion-Frontend/mf_auth/01-Planificacion.md` |
| Reportería | Jobs asíncronos en `ms_reporting` (PDF/Excel), plantilla MinTIC PORTADA, XLSX→PDF con LibreOffice en la imagen Docker Jammy | `ms_reporting/deployment/Dockerfile`, `PLAN_TRABAJO_MSPI_v2.md` §14 |
| Notificaciones | Brevo (Sendinblue) para correo transaccional | `Documentacion-Backend/ms_iam/01-Planificacion.md` |
| Calidad / pruebas backend | JUnit 5, Mockito, MockWebServer 5.3.2, ArchUnit 1.4.1, JaCoCo 0.8.14, Pitest (mutation testing), SonarQube | `Documentacion-Backend/ms_iam/01-Planificacion.md` sección 5 |
| CI/CD backend | Bitbucket Pipelines, despliegue a Railway | `bitbucket-pipelines.yml` (`ms_iam`) |
| Pruebas frontend | **No verificadas**: sin archivos `*.spec.ts` ni configuración Karma/Jest en `mf_auth` | `Documentacion-Frontend/mf_auth/01-Planificacion.md` sección 8 (riesgo documentado) |

**Justificación técnica breve de las elecciones observadas:**
- *Microservicios + arquitectura hexagonal*: aísla el motor de cálculo del instrumento (dominio) de Spring/JPA/Keycloak, facilitando pruebas unitarias del algoritmo sin infraestructura y permitiendo evolucionar cada esquema de base de datos de forma independiente.
- *Keycloak como IdP externo*: delega el manejo de credenciales fuera de la aplicación (reduce superficie de ataque y cumple con el principio de no almacenar secretos de autenticación propios), alineado con el marco teórico de ISO/IEC 27001 sobre gestión de acceso (dominio A.9).
- *PostgreSQL con snapshot de catálogo*: sostiene la trazabilidad histórica exigida por auditoría (control A.18 Cumplimiento) sin sacrificar la capacidad de versionar el instrumento.
- *Angular + microfrontends*: permite que los seis módulos funcionales (auth, org, assessment, evidence, reports, shell) se desarrollen y desplieguen de forma desacoplada, aunque —como se documenta en la Sección 6.2— la implementación real de esa composición difiere entre lo planificado (Module Federation) y lo verificado en al menos un microfrontend piloto.

---

## 8. Metodología

### 8.1 Metodología de desarrollo de software

El repositorio no contiene actas de sprint, tableros Scrum/Kanban exportados, ni un `CHANGELOG.md` formal a nivel de microservicio o microfrontend individual — hallazgo declarado explícitamente en `Documentacion-Backend/ms_iam/01-Planificacion.md` (sección 7) y en `Documentacion-Frontend/mf_auth/01-Planificacion.md` (sección 7.2): *"No existe en el repositorio un backlog, roadmap o bitácora de sprints formal para `mf_auth`"*.

Sin embargo, sí existe evidencia sólida de un **proceso iterativo estructurado a nivel de todo el sistema**, documentado en `docs/proyecto/PLAN_TRABAJO_MSPI_v2.md`: el plan de trabajo v2 organiza la construcción del frontend en **8 sprints** de 1 a 2 semanas cada uno (Sprint 0 – Infraestructura común, Sprint 1 – Login/usuarios/orgs, Sprint 2 – Evaluación/catálogo/áreas, Sprint 3 – Contexto y levantamiento, Sprint 4 – Controles administrativos y técnicos, Sprint 5 – PHVA/Madurez/NIST, Sprint 6 – Dashboard y reportes, Sprint 7 – Integración y pruebas), con entregables verificables por sprint (checklist de APIs cubiertas, sección 13) y con una segunda versión del plan que reemplaza explícitamente a una primera (v1), documentando el motivo del cambio (sección "Por qué este plan supera al v1") — un patrón de **iteración incremental con retrospectiva documentada**, propio de metodologías ágiles (Scrum/Kanban), aunque sin la ceremonia formal completa (no hay evidencia de retrospectivas de equipo, *daily stand-ups* o *story points*).

Asimismo, las historias de usuario en `Historias_Usuario_MSPI_v2.md` siguen el formato estándar ágil (Como/Quiero/Para que) con criterios de aceptación verificables, lo que confirma el uso de **historias de usuario como unidad de especificación funcional**, típico de Scrum/Kanban.

**Conclusión metodológica:** se propone documentar la metodología de desarrollo como **ágil, con enfoque iterativo-incremental por sprints de alcance funcional (similar a Scrum/Kanban adaptado)**, dejando constancia explícita de que no hay evidencia de las ceremonias formales completas del framework Scrum. `[PENDIENTE: a completar por el autor]` — si el autor empleó formalmente Scrum, Kanban o un híbrido con roles definidos (Scrum Master, Product Owner), debe documentarlo aquí con las actas o herramientas de gestión (Jira, Trello, Azure DevOps) que lo respalden, dado que el repositorio de código no las contiene.

### 8.2 Metodología de investigación

El proyecto corresponde a una **investigación de tipo aplicada (o tecnológica)**, orientada a la resolución de un problema práctico concreto (la automatización de un instrumento regulatorio) mediante el diseño y construcción de un artefacto de software, y no a la generación de conocimiento teórico nuevo. Dentro de la clasificación por enfoque, se trata predominantemente de un enfoque **cualitativo de investigación-acción / desarrollo tecnológico** (se analiza un proceso manual existente —el diligenciamiento del Excel—, se diseña una solución y se valida su correspondencia funcional con las reglas originales), complementado con validación **cuantitativa** en el sentido estricto de que las fórmulas de cálculo (promedios, redondeo, ponderaciones PHVA, umbrales de madurez) admiten pruebas de verificación numérica exacta contra los ejemplos documentados en las propias historias de usuario (p. ej., HU-ADM-02 documenta tres ejemplos numéricos resueltos que sirven como casos de prueba de aceptación).

`[PENDIENTE: a completar por el autor]` — el autor debe declarar formalmente el diseño de investigación (p. ej., "investigación aplicada de enfoque cualitativo con componente de verificación cuantitativa", según la taxonomía exigida por su universidad) y, si aplica, el método de recolección de requerimientos utilizado con la entidad o consultor que originó el Excel base (entrevistas, análisis documental), que no está documentado en el repositorio de código.

---

## 9. Análisis de alternativas

El repositorio no contiene documentos de tipo ADR (*Architecture Decision Record*) formales, pero sí contiene **al menos una comparación explícita y documentada entre dos versiones de un mismo plan arquitectónico**, que constituye evidencia real de un proceso de decisión:

### 9.1 Alternativa descartada documentada: cálculos en el frontend (Plan v1) vs. cálculos en el backend (Plan v2)

`PLAN_TRABAJO_MSPI_v2.md` (sección "Por qué este plan supera al v1") documenta que una primera versión del plan de trabajo proponía una librería compartida (`shared-lib`) en el frontend Angular para replicar las fórmulas de promedio, redondeo y ponderación, con catálogos de controles/PHVA/madurez *hardcoded* en el cliente. Esta alternativa fue **descartada explícitamente** a favor de centralizar todo el cálculo en `ms_assessment` y cargar los catálogos dinámicamente desde `ms_catalog`, con los criterios de decisión documentados: riesgo de inconsistencia entre dos implementaciones del mismo algoritmo, rigidez ante cambios del instrumento por parte de MinTIC (requeriría *redeploy* del frontend en vez de solo actualizar el catálogo), y la necesidad de manejar de forma centralizada los ítems heredados (`editable: false`) y el bloqueo optimista (`rowVersion`).

### 9.2 Alternativas de arquitectura general (análisis estándar de industria aplicado al contexto, sin evidencia de descarte explícito en el repositorio)

| Alternativa | A favor | En contra | Decisión evidenciada |
|---|---|---|---|
| **Monolito** vs. **microservicios** | Monolito: menor complejidad operativa, un solo despliegue | Monolito: acopla el ciclo de vida de módulos con responsabilidades distintas (identidad, catálogo, evaluación, reportes) que en este dominio cambian a ritmos distintos (el catálogo cambia cuando MinTIC actualiza el instrumento; la identidad casi nunca) | El repositorio construyó microservicios (8 carpetas, 6 activas) — no hay documento de descarte explícito del monolito, pero la partición por esquema de BD (`iam`, `org`, `catalog`, `assessment`, `evidence`, `reporting`) es consistente con una decisión deliberada de acotar *bounded contexts* |
| **Frontend monolítico Angular** vs. **microfrontends** | Monolítico: integración más simple, un solo `ng build` | Monolítico: un solo equipo/repo para seis dominios funcionales distintos (auth, org, evaluación, evidencia, reportes, dashboard) | El repositorio construyó 6 microfrontends con planificación de Module Federation, aunque con implementación real heterogénea (ver Sección 6.2) |
| **IdP propio** (gestión de contraseñas en `ms_iam`) vs. **Keycloak externo** | Propio: menos infraestructura externa | Propio: obliga a implementar hashing, políticas de bloqueo, MFA y cumplimiento normativo de credenciales desde cero, con mayor superficie de riesgo | El repositorio usa Keycloak como *Resource Server*/IdP externo (RI-1 en `Documentacion-Backend/ms_iam/01-Planificacion.md`), delegando la gestión de contraseñas fuera del microservicio |
| **Reportes generados en cliente** (jsPDF/ExcelJS) vs. **jobs asíncronos server-side** | Cliente: sin infraestructura adicional | Cliente: limitado para reproducir con exactitud la plantilla oficial de Excel de MinTIC (formato, fórmulas, estilos) | El Plan v1 proponía generación en cliente; el Plan v2 (adoptado) usa jobs asíncronos en `ms_reporting` con plantilla oficial — decisión documentada en la sección 9.1 |

`[PENDIENTE: a completar por el autor]` — si existieron otras alternativas evaluadas formalmente (p. ej., otro lenguaje/framework backend, otra base de datos, otro IdP) que no dejaron rastro en el código o la documentación, el autor debe reconstruirlas de memoria y con las matrices de decisión que haya usado durante el desarrollo, dado que este documento solo puede reportar lo que el repositorio evidencia.

---

## 10. Resultados

Con base en la estructura real del repositorio, el sistema construido comprende:

### 10.1 Backend — 8 microservicios (6 activos con puerto asignado)

| Microservicio | Puerto | Estado según evidencia |
|---|---|---|
| `ms_iam` | 8082 | Activo — autenticación, 2FA/TOTP, gestión de usuarios y roles, auditoría centralizada. Arquitectura hexagonal en 8 módulos Gradle confirmada en código real. |
| `ms_org` | 8083 | Activo — CRUD de organizaciones, geografía (país/departamento/ciudad), creación automática de usuario `Lector` al crear organización. |
| `ms_catalog` | 8085 | Activo — catálogo versionado de plantillas, controles, escala, ítems PHVA, requisitos de madurez, ítems NIST y presets de áreas (solo lectura para el frontend). |
| `ms_assessment` | 8084 | Activo — ciclo de vida de evaluaciones, calificación de controles administrativos/técnicos, cálculo de rollup jerárquico, PHVA, madurez, NIST y tablero de diagnóstico consolidado. |
| `ms_evidence` | 8086 | Activo — contexto/misión de la entidad, levantamiento de 43 ítems documentales, carga y descarga de archivos multipart. |
| `ms_reporting` | 8087 | Activo — generación asíncrona de reportes PDF/Excel mediante jobs con *polling*, reportes comparativos. |
| `ms_admin` | — | **Placeholder / solo documentación**, según el README raíz del backend. |
| `ms_audit` | — | **Placeholder / solo documentación**, según el README raíz del backend. |

### 10.2 Frontend — 6 microfrontends

`mf_shell` (4200, host/dashboard), `mf_auth` (4201, login/2FA/usuarios), `mf_org` (4202, organizaciones), `mf_assessment` (4203, evaluación completa: áreas, controles, PHVA, madurez, NIST, diagnóstico), `mf_evidence` (4204, contexto y levantamiento), `mf_reports` (4205, reportes y brechas). Construidos en Angular 19 con TypeScript en modo estricto, contenerizados con Nginx.

### 10.3 Funcionalidades por dominio efectivamente especificadas (nivel de historia de usuario)

El documento `Historias_Usuario_MSPI_v2.md` especifica, con fórmulas, pseudocódigo, ejemplos numéricos y casos borde, ocho módulos funcionales completos: (1) Configuración y levantamiento, (2) Áreas y responsables, (3) Controles administrativos (7 dominios ISO), (4) Controles técnicos (7 dominios ISO), (5) Ciclo PHVA (4 componentes ponderados), (6) Nivel de madurez (50 requisitos × 5 niveles), y adicionalmente NIST CSF y diagnóstico consolidado, cubriendo los 14 dominios completos del Anexo A de ISO/IEC 27001:2013.

### 10.4 Complemento de alcance funcional (prototipo Figma Make)

La carpeta `MSPI_NVA_CO_MR_FRONT/Mspijdbs` documenta un **prototipo funcional adicional** (generado con Figma Make, según su estructura de `src/imports` y `ATTRIBUTIONS.md`) que profundiza y valida decisiones de dominio: sistema RBAC de 5 roles con autoridades granulares (`RBAC-GUIDE.md`), políticas de seguridad, flujos de 2FA, gestión de evidencias y línea base — documentación que **complementa el alcance funcional** del sistema real pero corresponde a un prototipo de exploración de UI/UX, no al código de producción Angular. `[PENDIENTE: a completar por el autor]` — aclarar en el documento final si este prototipo fue insumo de diseño previo, entregable paralelo, o material exploratorio fuera del alcance final entregado, dado que el repositorio no declara explícitamente su relación con el sistema Angular productivo.

---

## 11. Conclusiones

1. **Cumplimiento funcional del objetivo central.** La evidencia documental (historias de usuario con fórmulas, pseudocódigo y ejemplos numéricos verificables) demuestra que el sistema fue diseñado para reproducir con fidelidad matemática exacta las reglas de cálculo del instrumento MSPI de MinTIC, incluyendo casos borde no triviales (exclusión de N/A sin distorsionar promedios, herencia directa en objetivos de un solo hijo, progresión acumulativa estricta del nivel de madurez, topes de ponderación PHVA).
2. **Arquitectura coherente con el dominio.** La separación por microservicios sigue líneas de responsabilidad de negocio claras (identidad, organización, catálogo, evaluación, evidencia, reportes), y la arquitectura hexagonal verificada en `ms_iam` aísla el algoritmo de cálculo de los detalles de infraestructura, lo cual favorece la mantenibilidad y la prueba unitaria del motor de reglas.
3. **Limitación técnica relevante — cobertura de pruebas automatizadas heterogénea.** El análisis piloto de `ms_iam` documenta uso de JUnit 5, Mockito, ArchUnit, JaCoCo y Pitest, sugiriendo disciplina de pruebas en el backend; en contraste, el análisis piloto de `mf_auth` documenta **ausencia total de pruebas automatizadas** (sin archivos `*.spec.ts` ni configuración Karma/Jest). Esta asimetría entre backend y frontend es una limitación técnica que debe discutirse en el documento final como riesgo de regresión no mitigado en la capa de presentación.
4. **Limitación de alcance — dos microservicios sin implementar.** `ms_admin` y `ms_audit` existen como carpetas placeholder en el repositorio backend sin funcionalidad activa, lo que indica que el alcance de auditoría transversal consolidada y administración general quedó fuera del perímetro efectivamente construido, aun cuando la arquitectura los contempla.
5. **Discrepancia entre plan y código en la composición de microfrontends.** El plan de trabajo especifica Module Federation de Webpack como mecanismo de integración de los 6 MFs, mientras que la verificación puntual de `mf_auth` encontró una integración por composición de navegador (iframe/postMessage/localStorage), sin Module Federation. Esta discrepancia debe documentarse como hallazgo de la fase de desarrollo y discutirse sus implicaciones (rigidez de URLs *hardcodeadas* al shell, propagación de sesión "parcial" entre orígenes distintos, según el propio código fuente citado).
6. **Discrepancia de versión normativa.** El instrumento fuente referencia ISO/IEC 27001:**2013**, mientras que la versión vigente de la norma es **2022**; esta decisión (mantener fidelidad al instrumento MinTIC de 2013 vs. actualizar a 2022) debe justificarse explícitamente como alcance académico del proyecto.
7. **Código residual y artefactos de plantilla.** Se identificó, en la fase piloto de `mf_auth`, la convivencia de artefactos de una plantilla previa (React + Vite, *shadcn/ui*) que no forman parte del build de Angular real — riesgo de confusión documental que conviene depurar antes de una entrega académica final.

### Trabajo futuro propuesto

- Completar la implementación funcional de `ms_admin` y `ms_audit`.
- Uniformar Module Federation (o documentar y justificar formalmente la composición alternativa) en los seis microfrontends.
- Incorporar pruebas automatizadas de frontend (unitarias con Jest/Karma y end-to-end) equivalentes en rigor a las ya existentes en el backend.
- Actualizar o justificar formalmente la versión de ISO/IEC 27001 empleada (2013 vs. 2022).
- Validar el sistema con una entidad piloto real y medir el impacto cuantitativo frente al proceso manual en Excel (tiempo de diligenciamiento, tasa de error).

`[PENDIENTE: a completar por el autor]` — conclusiones finales deben ser redactadas y validadas por el autor tras su propia evaluación crítica del sistema terminado; lo anterior es un borrador fundamentado en evidencia de repositorio, no una evaluación de desempeño en producción.

---

## 12. Referencias

Las referencias bibliográficas formales de este trabajo (normas, libros, artículos científicos) deben ser completadas por el autor en el formato exigido por su universidad (APA o IEEE, según corresponda). Este documento solo puede afirmar con certeza la siguiente referencia normativa, por estar explícitamente citada en el repositorio del proyecto:

- International Organization for Standardization. (2013). *ISO/IEC 27001:2013 — Information technology — Security techniques — Information security management systems — Requirements.* [Referenciada como base normativa del instrumento MSPI en `docs/linea_base_seguridad_ISO27001.md` y `docs/proyecto/Historias_Usuario_MSPI_v2.md` del repositorio].

`[PENDIENTE: a completar por el autor]` — se recomienda añadir, con la referencia bibliográfica formal correspondiente:
- ISO/IEC 27001:2022 (versión vigente de la norma, para discutir la brecha señalada en la Sección 6.1 y la Conclusión 6).
- NIST Cybersecurity Framework (versión y año exactos usados como referencia).
- Documentación oficial de MinTIC sobre el Modelo de Seguridad y Privacidad de la Información (circular, guía o resolución que exige el diligenciamiento del instrumento).
- Literatura de arquitectura de software citada en el marco teórico (microservicios, arquitectura hexagonal/Clean Architecture, microfrontends) — p. ej. Newman (microservicios), Cockburn (arquitectura hexagonal), Geers (microfrontends), según lo que el autor haya efectivamente consultado.
- Bibliografía de metodologías ágiles (Scrum/Kanban) si se formaliza la metodología de desarrollo en la Sección 8.1.

---

*Fin del componente investigativo. Documento generado por reconstrucción de evidencia del repositorio del proyecto MSPI (`MSPI_NVA_CO_MR_BACK`, `MSPI_NVA_CO_MR_FRONT`, `Documentacion-Backend/ms_iam`, `Documentacion-Frontend/mf_auth`). Todo apartado marcado `[PENDIENTE: a completar por el autor]` requiere validación, ampliación o dato institucional que solo el autor del proyecto de grado puede aportar.*
