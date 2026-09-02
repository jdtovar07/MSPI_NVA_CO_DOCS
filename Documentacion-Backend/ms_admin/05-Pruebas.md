# ms_admin — Pruebas

| Campo | Valor |
|---|---|
| Repositorio | `MSPI_NVA_CO_MR_BACK/ms_admin` |
| Fecha del documento | 2026-08-18 |
| Alcance | Frameworks de prueba, estructura y cobertura de `ms_admin` |
| Estado del repositorio | **Sin pruebas — no existe código que probar** |

---

## 1. Declaración explícita

No existe carpeta `src/test` en `ms_admin`, ni en ninguna otra ubicación del repositorio. No hay ningún archivo de prueba (`*Test.java`, `*Spec.*`, `*.test.*`, etc.). Esto es consistente con el hecho, ya documentado en `01-Planificacion.md` y `04-Desarrollo.md`, de que **no existe código de aplicación**: no puede haber pruebas unitarias, de integración, de arquitectura ni de contrato sobre un sistema que no ha sido implementado.

## 2. Frameworks de prueba

No hay ningún framework de pruebas configurado, porque no hay `build.gradle` (ni equivalente Node) que declare dependencias de tipo `test`. No se puede afirmar que se usarán JUnit, Mockito, ArchUnit u otra herramienta, aunque —a modo de referencia de lo que usan los microservicios hermanos ya implementados del mismo ecosistema (`ms_iam`)— sería razonable esperar continuidad tecnológica si `ms_admin` se implementa en Java/Spring: JUnit 5, Mockito, MockWebServer y ArchUnit. Esto se deja explícito como **expectativa no confirmada**, no como hecho documentado de `ms_admin`.

## 3. Estructura de pruebas

No aplica. No hay estructura que describir.

## 4. Tipos de pruebas evidenciadas

| Tipo de prueba | Evidencia en `ms_admin` |
|---|---|
| Unitarias | Ninguna |
| Integración | Ninguna |
| Arquitectura (ArchUnit o similar) | Ninguna |
| Contrato de API | Ninguna — el propio `docs/openapi.yaml` es un stub sin `paths`, por lo que no hay contrato que validar |
| Extremo a extremo | Ninguna |
| Carga/rendimiento | Ninguna |

## 5. Cobertura de código

No hay configuración de cobertura (no existe configuración de JaCoCo, Istanbul, ni ninguna otra herramienta), porque no hay código fuente sobre el cual calcular cobertura. No es posible reportar un porcentaje de cobertura.

## 6. Análisis estático / calidad

No hay configuración de SonarQube, Pitest, ni ningún otro análisis de calidad o mutación en el repositorio.

## 7. Recomendación

Siguiendo la gobernanza que el propio `ROADMAP.md` establece para el desarrollo de `ms_admin` (Fase 2 — "Estructura Clean Architecture (alineada con `ms_iam` / `ms_org`)"), se recomienda que, cuando se inicie la implementación, la estrategia de pruebas replique la ya verificada en `ms_iam` (documentada en su propio `05-Pruebas.md`): pruebas unitarias de `domain/usecase` con mocks de los gateways, pruebas de arquitectura con ArchUnit para blindar la regla de dependencia hexagonal, y pruebas de integración de los adaptadores HTTP salientes hacia `ms_iam`/`ms_org` (previsiblemente con `MockWebServer`, dado que ese es el patrón ya usado en el ecosistema para simular servicios externos). Esta es una recomendación prospectiva, no una descripción de algo existente.
