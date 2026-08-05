# ms_admin — Desarrollo

| Campo | Valor |
|---|---|
| Repositorio | `MSPI_NVA_CO_MR_BACK/ms_admin` |
| Fecha del documento | 2026-08-18 |
| Alcance | Implementación real, librerías, patrones y funcionalidades concretas de `ms_admin` |
| Estado del repositorio | **Sin desarrollo iniciado** |

---

## 1. Declaración explícita de alcance de este documento

Este documento normalmente describiría, para un microservicio ya implementado, las librerías declaradas en `build.gradle`, los patrones de diseño aplicados en el código y las funcionalidades concretas entregadas. **Ninguno de esos elementos existe en `ms_admin`.**

Verificación realizada:

- No existe `build.gradle` en ningún nivel del repositorio (raíz ni subcarpetas).
- No existe `main.gradle`, `settings.gradle` ni `gradlew`.
- No existe ni un solo archivo `.java`, `.kt` ni de ningún otro lenguaje de aplicación.
- No existe `src/` en ninguna forma.
- No existe `application.yaml`/`application.properties`.
- No existe carpeta `deployment/`.

Por lo tanto, las secciones siguientes documentan **por qué no hay nada que reportar** en cada categoría, en lugar de simular contenido inexistente.

## 2. Librerías y dependencias

No hay archivo de dependencias (`build.gradle`) del cual extraer versiones de librerías. No se puede afirmar qué framework web, ORM, cliente HTTP, librería de seguridad o utilitario usaría `ms_admin`, porque ninguna de esas decisiones se ha materializado en configuración.

La única pista documental sobre el ecosistema tecnológico es la pregunta abierta del `README.md`: *"¿`ms_admin` será un BFF (Node/Spring) o un MS con persistencia propia?"*, que deja sin resolver incluso el lenguaje de implementación.

## 3. Patrones de diseño aplicados

No hay patrones de diseño aplicados en código, porque no hay código. Los patrones que aparecen en el `README.md` (Ports & Adapters / arquitectura hexagonal, con `Gateways` como puertos salientes hacia otros microservicios) son **patrones propuestos en un diagrama**, no patrones verificables en una implementación. Se documentan como intención en `03-Diseno.md`, no aquí, para no mezclar diseño propuesto con desarrollo real.

## 4. Funcionalidades concretas implementadas

Ninguna. El propio `README.md` lo resume en una tabla de estado:

| Aspecto | Estado |
|---|---|
| Código fuente | No implementado |
| API REST | No disponible |
| Despliegue | No aplica |

No hay ningún endpoint HTTP que responda, ni siquiera un health check. No hay lógica de negocio, validaciones, manejo de excepciones, mapeo de DTOs, ni integración real con `ms_iam`, `ms_org` o `ms_assessment` — todas esas integraciones existen únicamente como flechas en los diagramas Mermaid del README (ver `03-Diseno.md`, §3).

## 5. Convenciones de código

No aplican: no hay código sobre el cual establecer o verificar convenciones (nomenclatura de paquetes, formateo, linters, `checkstyle`, etc.). No hay ningún archivo de configuración de estilo (`.editorconfig`, `checkstyle.xml`, `.eslintrc`, etc.) en el repositorio.

## 6. Control de versiones y estado del repositorio

El único control de versiones verificable es el `.gitignore` del repositorio, que existe pero cuyo contenido no fue solicitado como parte de este análisis funcional (no aporta información de desarrollo). No hay historial de commits analizado en este documento (no se tuvo acceso a `git log`, ya que el entorno de análisis no expone metadatos de Git para esta carpeta).

## 7. Qué se necesitaría para iniciar desarrollo real

A partir de lo que sí está documentado (`ROADMAP.md`, Fase 2 — "Implementación inicial"), el desarrollo de `ms_admin` requeriría, en orden:

1. Cerrar la decisión de arquitectura (MS propio vs. BFF) — Fase 1 del ROADMAP, aún pendiente.
2. Publicar una versión no-stub de `docs/openapi.yaml` con al menos un endpoint, como exige la gobernanza del propio ROADMAP.
3. Crear la estructura de build (multi-módulo Gradle, si se sigue el patrón de `ms_iam`/`ms_org`, o un proyecto Node si se opta por BFF en ese stack).
4. Integrar con Infisical para gestión de secretos, como en los demás microservicios del ecosistema.
5. Implementar los primeros casos de uso de agregación/proxy hacia `ms_iam` y `ms_org`.

Ninguno de estos pasos se ha ejecutado a la fecha de este documento.
