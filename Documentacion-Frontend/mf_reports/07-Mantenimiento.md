# mf_reports — Mantenimiento

**Repositorio:** `MSPI_NVA_CO_MR_FRONT/mf_reports`
**Fecha del documento:** 2026-08-18
**Alcance:** Consideraciones de mantenimiento, control de versiones, monitoreo y mejoras futuras del microfrontend `mf_reports`, basadas en el estado real observado del repositorio.

---

## 1. Estado de versionamiento

- `package.json` fija `"version": "1.0.0"` de forma estática; no se encontró evidencia de que este número se incremente automáticamente (no hay script de *release*, no hay `CHANGELOG.md`, no hay *tags* de Git verificables desde el contenido del repositorio entregado).
- No existe carpeta `.github/workflows` ni configuración de integración continua (CI) visible en el repositorio de `mf_reports`.
- No se encontró ningún archivo de bitácora de cambios, historial de decisiones (ADR) o backlog dentro del repositorio.
- La documentación técnica en `docs/` (8 archivos Markdown breves) no incluye fecha de última actualización ni número de versión de documento.

**Recomendación:** adoptar versionado semántico (`MAJOR.MINOR.PATCH`) ligado a los tipos de reporte soportados y a cambios de contrato con `ms_reporting`/`ms_assessment`, dado que un cambio en la forma de respuesta de estos backends (como ya se observa tolerado defensivamente en `reporting-diagnostic.mapper.ts`) es el tipo de cambio más probable que rompa compatibilidad.

## 2. Dependencias y actualización

| Paquete | Versión declarada | Consideración de mantenimiento |
|---|---|---|
| `@angular/*` | `^19.0.0` | Seguir el calendario de versiones mayores de Angular (una versión mayor cada ~6 meses); Angular 19 recibirá soporte activo por un tiempo limitado — planificar migración a versiones LTS posteriores |
| `rxjs` | `~7.8.0` | Estable; usada de forma acotada (solo en el interceptor y en la adaptación de `downloadReport`) |
| `zone.js` | `~0.15.0` | Angular está migrando hacia *zoneless change detection*; este proyecto ya usa Signals para estado local, lo que facilitaría una futura migración a `provideZoneChangeDetection` sin `zone.js` |
| `typescript` | `~5.6.0` | Alineada con el rango soportado por Angular 19 |

No hay dependencias de terceros para UI, gráficos o manejo de tablas (a diferencia de otros microfrontends del ecosistema que sí incorporan librerías como `qrcode`); esto simplifica el mantenimiento de dependencias pero también significa que cualquier visualización adicional (por ejemplo, gráficos de barras/radar más sofisticados que las barras HTML actuales) requeriría evaluar e incorporar una nueva dependencia.

Se recomienda ejecutar `npm audit` y `npm outdated` periódicamente; no se encontró evidencia de que esto esté automatizado (ausencia de CI).

## 3. Monitoreo y observabilidad

- El único mecanismo de monitoreo presente es el `HEALTHCHECK` HTTP del contenedor Docker (`curl -f http://127.0.0.1/`), que solo verifica que Nginx responda en la raíz — **no verifica** que la aplicación Angular cargue correctamente ni que los backends `ms_reporting`/`ms_assessment` sean alcanzables.
- No se encontró integración con herramientas de observabilidad de frontend (Sentry, LogRocket, Google Analytics, etc.).
- El manejo de errores se limita a mostrarlos en la interfaz (`error()`, `message()` en los componentes) y, en el caso de errores HTTP, a registrar el `traceId` cuando el backend lo provee (`ApiError.traceId`, extraído en `api.interceptor.ts` y en `report-download.helper.ts::parseJsonBlobError`) — pero este `traceId` **no se muestra en la interfaz de usuario ni se envía a ningún sistema de *logging* centralizado**; queda disponible solo en el objeto de error en memoria, útil únicamente si se inspecciona con herramientas de desarrollador.

**Recomendación:** mostrar el `traceId` en los mensajes de error visibles al usuario cuando exista (facilita el soporte y la correlación con logs de backend), y considerar la integración de un *logger* de errores de cliente.

## 4. Puntos de fragilidad para el mantenimiento futuro

| Punto | Riesgo | Mitigación sugerida |
|---|---|---|
| `reporting-diagnostic.mapper.ts` con múltiples formas de campo tolerado | Si `ms_assessment` estabiliza su contrato con nombres distintos a los ya cubiertos, el mapeador dejará de reconocer el campo silenciosamente (devolviendo 0 o vacío) sin lanzar error | Agregar pruebas unitarias por cada forma de respuesta conocida (ver `05-Pruebas.md`) y, si es posible, alinear el contrato con `ms_assessment` para eliminar la necesidad de tolerar variantes |
| URLs de backend y origen del shell fijas a `localhost` en el código fuente | Cualquier despliegue fuera de `localhost` requiere editar y recompilar `environment.api.ts` y `nginx.conf` | Migrar a inyección de configuración en tiempo de ejecución (por ejemplo, un `assets/env.json` cargado antes del *bootstrap*, o variables de entorno sustituidas por un *entrypoint* del contenedor) |
| Ausencia de verificación de autoridad `REPORT_EXPORT` en el frontend | Un usuario sin permisos podría ver e intentar accionar los botones de exportación (aunque el backend probablemente los rechace) | Añadir un guard de ruta o verificación condicional basada en la sesión/roles disponibles, análogo al patrón `authority.ts` usado en `mf_auth` |
| Imagen Docker sin `outputHashing` (ver `06-Implementacion-Despliegue.md`) | Los artefactos JS/CSS no cambian de nombre entre versiones, lo que puede causar problemas de caché de navegador tras un despliegue | Ajustar el `Dockerfile` para compilar con `--configuration=production,api` (o crear una configuración combinada dedicada en `angular.json`) |
| Doble consulta de metadatos de evaluación (`GET /assessments/{id}`) entre el tablero y la pantalla de exportación | Latencia innecesaria; no hay caché entre pantallas | Introducir un pequeño servicio de caché en memoria por `assessmentId` durante la sesión de navegación, o propagar los metadatos ya cargados vía `state` de navegación de Angular Router |
| `README.md` raíz sin contenido específico | Onboarding deficiente si un desarrollador nuevo no revisa `docs/` | Reemplazar el contenido de plantilla de Bitbucket por un resumen real del proyecto, enlazando a `docs/README.md` |

## 5. Mejoras futuras identificadas (no implementadas, declaradas como trabajo pendiente)

1. **Pantalla dedicada para reportes comparativos.** El dominio y la infraestructura ya soportan `createComparativeReportJob` (`COMPARATIVE_DIAGNOSTIC_PDF`/`_XLSX`), pero no existe ninguna pantalla ni botón en `presentation/pages` que lo invoque — es funcionalidad de backend/dominio sin UI que la exponga.
2. **Reincorporación de pruebas automatizadas**, priorizando las funciones puras de mapeo y resolución de nombre de archivo (detallado en `05-Pruebas.md`).
3. **Configuración de entorno en tiempo de ejecución** en lugar de en tiempo de compilación, para permitir una única imagen Docker desplegable en múltiples entornos (desarrollo, staging, producción) sin recompilar.
4. **Guard de autorización** para la pantalla de exportación, verificando la autoridad `REPORT_EXPORT` de forma análoga al patrón de `mf_auth`.
5. **Visualización de `traceId`** en los mensajes de error de la interfaz, para facilitar el soporte técnico.
6. **Pipeline de CI/CD** (lint, build, y en el futuro pruebas) para el repositorio, actualmente inexistente.
7. **Combinar `outputHashing` con la configuración `api`** en el proceso de build de la imagen Docker, para asegurar invalidación correcta de caché de navegador entre despliegues.

## 6. Consideraciones de compatibilidad con el resto del ecosistema

Cualquier cambio en `mf_reports` debe considerar su impacto en:

- **`mf_shell`**: que embebe `mf_reports` vía iframe y espera que la ruta `/assessments/:id/dashboard` exista y responda; un cambio de rutas rompería la integración documentada en `docs/INTEGRACION-SHELL.md`.
- **`mf_assessment`**: que navega hacia `mf_reports` mediante `openShellRoute('/reports', id)` desde su módulo NIST; depende de que `active_assessment_id` se establezca correctamente en `localStorage` antes de esa navegación.
- **`ms_reporting`** y **`ms_assessment`**: cualquier cambio de contrato en estos backends (nuevos campos, renombrado de campos, cambio de estructura de `CorrectResponse`) debe reflejarse en `reporting-diagnostic.mapper.ts`, `reporting.types.ts` y `api.interceptor.ts`. El error conocido y ya documentado por el propio equipo (`docs/FLUJOS.md`: fallos de *job* envueltos incorrectamente en `CorrectResponse` por Jackson en `ms_reporting`) sigue pendiente de corrección del lado del backend a la fecha de este documento.

## 7. Resumen

`mf_reports` es, de los siete documentos de esta serie, el que presenta menor superficie de mantenimiento en términos de líneas de código (17 archivos TypeScript) y de dependencias externas, pero concentra su complejidad en la tolerancia a variantes del contrato de `ms_assessment` y en el flujo de *polling*/descarga asíncrona. La ausencia de pruebas automatizadas y de configuración de entorno en tiempo de ejecución son, junto con la falta de una pantalla para reportes comparativos ya soportados a nivel de dominio, los tres puntos de mayor prioridad para la evolución futura del microfrontend.
