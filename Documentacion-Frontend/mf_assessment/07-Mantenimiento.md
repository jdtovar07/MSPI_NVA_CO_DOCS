# mf_assessment — Mantenimiento

**Repositorio:** `MSPI_NVA_CO_MR_FRONT/mf_assessment`
**Fecha del documento:** 2026-08-18
**Alcance:** Consideraciones de mantenimiento, control de versiones, monitoreo y mejoras futuras del microfrontend de evaluaciones de madurez (`mf_assessment`), basadas en evidencia real del repositorio.

---

## 1. Versionado

`package.json` fija `"version": "1.0.0"` de forma estática. **No se encontró evidencia** de:

- Versionado semántico automatizado (no hay `standard-version`, `semantic-release`, ni scripts relacionados).
- Archivo `CHANGELOG.md` en el repositorio.
- Etiquetas de build embebidas en el artefacto (no hay inyección de `git describe`, hash de commit o fecha de build en `environment.ts` ni en `index.html`).

**Recomendación de mantenimiento**: dado que `mf_assessment` es el microfrontend con mayor superficie de contrato con el backend (24 métodos en `AssessmentRepository`, tres microservicios consumidos), sería especialmente valioso incorporar un número de versión visible en la UI o en un endpoint de diagnóstico, para poder correlacionar reportes de incidentes con la versión desplegada del frontend frente a la versión del contrato OpenAPI de `ms_assessment`.

## 2. Gestión de dependencias

Dependencias de producción, todas en rango `^19.0.0` / `~7.8.0` / `~0.15.0` (`package.json`):

| Paquete | Rango |
|---|---|
| `@angular/*` (core, common, compiler, forms, platform-browser*, router, animations) | `^19.0.0` |
| `rxjs` | `~7.8.0` |
| `tslib` | `^2.3.0` |
| `zone.js` | `~0.15.0` |

`overrides` forzados en `package.json`:

```json
"overrides": {
  "tar": "^7.0.0",
  "glob": "^11.0.0"
}
```

Estos *overrides* sugieren que alguna dependencia transitiva (probablemente de la cadena de build de Angular CLI) arrastraba versiones vulnerables o desactualizadas de `tar`/`glob`, y el equipo las fijó explícitamente — una práctica de mantenimiento de seguridad de la cadena de suministro que debe revisarse periódicamente, ya que versiones futuras de `@angular/cli` podrían dejar de necesitar el override o requerir uno distinto.

No existe archivo de auditoría de dependencias (`npm audit` no está automatizado en ningún script), por lo que la vigilancia de vulnerabilidades es, hasta donde el repositorio permite verificar, manual.

## 3. Compatibilidad y actualización de Angular

El proyecto usa Angular 19 con builder `application` (esbuild/Vite internamente), TypeScript `~5.6.0` y `zone.js ~0.15.0`. Puntos a vigilar en futuras actualizaciones:

- Angular 19 introduce el control de flujo `@if`/`@for` (usado en el 100% de los templates del proyecto) y **signals** de forma estable — el proyecto ya está alineado con las prácticas recomendadas de esta versión, lo que facilita migraciones a versiones mayores posteriores.
- `zone.js` sigue presente como polyfill (`polyfills: ["zone.js"]` en `angular.json`); una futura migración a *zoneless change detection* (disponible de forma experimental en versiones recientes de Angular) implicaría revisar el uso de `provideZoneChangeDetection({ eventCoalescing: true })` en `app.config.ts`.
- El uso extendido de Signals en `AssessmentStateService` y `CatalogCacheService` deja al proyecto bien posicionado para adoptar zoneless en el futuro sin una reescritura mayor del manejo de estado.

## 4. Monitoreo

**No se encontró infraestructura de observabilidad** en el repositorio:

- Sin integración de un SDK de errores en frontend (Sentry, Rollbar, Application Insights, etc.).
- Sin métricas de rendimiento en cliente (Web Vitals, RUM).
- Sin logging estructurado; los `catch` observados en el código (`assessment-index.service.ts`, `auth-parent-bridge.ts`, `catalog-cache.service.ts`) silencian errores de `localStorage`/`sessionStorage`/parsing con comentarios como `/* ignore quota */` o `/* ignore malformed session */`, sin reportarlos a ningún sistema externo.
- El único mecanismo de "monitoreo" presente es el `HEALTHCHECK` de Docker (`curl -f http://127.0.0.1/`), que verifica exclusivamente que Nginx sirve la SPA, no que la aplicación funcione correctamente end-to-end (no valida conectividad con `ms_assessment`, `ms_catalog` ni con el shell).
- Los errores de API sí se normalizan en el cliente (`ApiError` con `status`, mensajes y `traceId` de `err.error?.meta?.traceId`), lo que indica que el backend expone un `traceId` de diagnóstico — pero no hay evidencia de que el frontend lo muestre en UI o lo envíe a un sistema de trazabilidad centralizado; queda disponible en el objeto de error para depuración manual.

**Recomendación**: dado que `traceId` ya viaja en las respuestas de error del backend, una mejora de bajo costo sería mostrarlo en los mensajes de error de UI (p. ej. en el mensaje de `AssessmentConflictError` o en errores de `ApiError` no controlados), facilitando la correlación con logs de backend durante el soporte.

## 5. Deuda técnica identificada

| Deuda | Evidencia | Prioridad sugerida |
|---|---|---|
| Ausencia total de pruebas automatizadas | Ver `05-Pruebas.md` | Alta — es el hallazgo de mayor impacto sobre la capacidad de evolucionar el código con confianza |
| Listado de evaluaciones dependiente de `localStorage` local | `AssessmentIndexService`, `docs/DESCRIPCION.md` ("limitación actual") | Alta — bloquea un caso de uso multiusuario/multi-dispositivo real |
| Alias duplicados en el dominio (`score`/`scoreValue`, `evidenceText`/`findingText`, `recommendationText`/`improvementText`) | `assessment.types.ts`, `assessment-api.mapper.ts` | Media — no rompe funcionalidad, pero incrementa el costo cognitivo de mantenimiento |
| Configuración de backend fija en archivos de build (`environment.ts`/`environment.api.ts`), sin variables de entorno de contenedor | `06-Implementacion-Despliegue.md`, sección 5 | Media — cualquier cambio de dominio/URL de backend exige recompilar y republicar la imagen |
| Sin publicación de evaluación visible en UI | `AssessmentRepository.publishAssessment` definido en el dominio sin página localizada que lo invoque (ver `02-Analisis.md`, sección 8) | Media — a verificar si es una funcionalidad pendiente o si se dispara desde otro punto no cubierto por este análisis |
| Sin observabilidad de errores en producción | Ver sección 4 de este documento | Media — dificulta el diagnóstico de incidentes en ambientes desplegados |
| Sin CI/CD | Ver `06-Implementacion-Despliegue.md`, sección 9 | Media — el build/despliegue depende de ejecución manual, con riesgo de desviación entre ambientes |

## 6. Mejoras futuras sugeridas (no implementadas, a título de trabajo de tesis / roadmap)

1. **Endpoint de listado paginado en `ms_assessment`** que reemplace el índice local en `localStorage`, permitiendo un listado de evaluaciones centralizado, filtrable y consistente entre usuarios y dispositivos.
2. **Suite de pruebas unitarias** priorizando `assessment-api.mapper.ts` y `assessment-conflict.handler.ts` (ver `05-Pruebas.md`, sección 6, para el detalle priorizado).
3. **Externalización de configuración de ambiente** (URLs de `ms_assessment`, `ms_catalog`, `ms_org`, origen del shell) fuera del build, mediante un archivo `config.json` servido junto al `index.html` y leído en runtime, o mediante variables de entorno inyectadas al contenedor Nginx al arrancar (patrón común en SPAs contenerizadas).
4. **Integración de un SDK de monitoreo de errores** en el cliente, aprovechando el `traceId` ya provisto por el backend en `ApiError` para correlacionar incidentes de frontend y backend.
5. **Guards de ruta por rol** (`CanActivate`/`CanMatch`), actualmente ausentes; hoy el control de acceso depende enteramente del shell/backend, lo que implica que acceder directamente a `http://localhost:4203/evaluations/:id/...` sin pasar por el shell no está bloqueado a nivel de router del propio microfrontend.
6. **Pipeline de CI/CD** que automatice `npm ci`, `npm run build:docker` y, cuando exista, la ejecución de pruebas antes de publicar la imagen.
7. **Página o flujo explícito de publicación de evaluación** (`publishAssessment`) si actualmente no existe una entrada de UI, o documentación de dónde se invoca si existe fuera del alcance revisado.

Estas mejoras se formulan como recomendaciones derivadas del análisis del código y la documentación existente; ninguna de ellas está implementada en el estado actual del repositorio.
