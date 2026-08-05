# mf_shell — Mantenimiento

**Repositorio:** `MSPI_NVA_CO_MR_FRONT/mf_shell`
**Fecha del documento:** 2026-08-18

---

## 1. Versionado

- `package.json` fija `"version": "1.0.0"` de forma estática; no se encontró `CHANGELOG.md`, historial de tags de Git accesible en el análisis, ni archivo de notas de versión dentro del repositorio.
- No hay pipeline de CI/CD (`.github/workflows` ausente) que automatice la publicación de versiones o imágenes Docker.
- Recomendación: adoptar versionado semántico (`MAJOR.MINOR.PATCH`) ligado a cambios en el protocolo `postMessage` (`MSPI_*`), dado que cualquier cambio en el contrato de mensajes entre el shell y sus 5 microfrontends hijos es, de facto, un cambio de interfaz pública que puede romper la integración si no se coordina entre repositorios.

## 2. Monitoreo

- El único mecanismo de monitoreo presente es el `HEALTHCHECK` de Docker (`curl -f http://127.0.0.1/` cada 30s, definido en `deployment/Dockerfile`), que solo verifica que Nginx sirve el `index.html`, sin comprobar la salud de los microfrontends hijos ni de los microservicios backend.
- La ruta `/system-health` está reservada en `app.routes.ts` (protegida por `systemAdminGuard()`) para un futuro "Monitoreo de microservicios y dependencias — pendiente de integración en el host", según el propio texto del *placeholder* (`FeaturePlaceholderPageComponent`). Es decir, el propio código documenta que el monitoreo operativo del ecosistema **aún no está implementado** en el shell.
- No existe integración con herramientas de observabilidad (Sentry, Datadog, OpenTelemetry, etc.) en `package.json` ni en el código.

## 3. Mantenimiento del protocolo de sesión compartida

Dado que la sesión se propaga por `postMessage` con lista blanca de orígenes `localhost:420[1-5]` (`isShellChildOrigin` en `shell-iframe-bridge.ts`, y la lista explícita `localhost:4201`/`127.0.0.1:4201` en `shell-layout.component.ts`), cualquier cambio de infraestructura que modifique los puertos o dominios de los microfrontends hijos **requiere actualizar estos valores en el código del shell**, ya que no son configurables por variable de entorno. Esto se identifica como deuda técnica prioritaria para un despliegue fuera de `localhost`.

## 4. Guía real: cómo integrar un nuevo microfrontend en `mf_shell`

**Advertencia sobre la documentación existente:** el documento `docs/INTEGRAR-NUEVOS-MF.md` del repositorio describe pasos para un shell **Vite + React + `@originjs/vite-plugin-federation`** (añadir `remotes` en `vite.config.ts`, crear un `RemoteAppId`, un `ModuleFederationRemoteLoader`, un hook `useRemoteApp`). Esa guía **no aplica al shell real**, que es Angular puro y orquesta por `<iframe>` (confirmado con evidencia exhaustiva en `03-Diseno.md`, sección 1). La guía siguiente se reconstruye a partir del patrón que **sí existe y se repite** en el código real (`*-redirect.component.ts`, `shell-iframe-bridge.ts`, `app.routes.ts`, `shell-layout.component.ts`).

### Paso 1 — Confirmar el puerto fijo del nuevo microfrontend

Cada microfrontend hijo corre en un puerto fijo y conocido (4201–4205 para los actuales). Un nuevo microfrontend (por ejemplo `mf_dashboard` en el puerto 5174, tomando el ejemplo numérico usado en la documentación original) debe exponer sus rutas HTTP normalmente (no requiere `remoteEntry.js` ni ningún artefacto de Module Federation).

### Paso 2 — Autorizar el nuevo origen en el puente de mensajería

En `src/app/infrastructure/shell-iframe-bridge.ts`, ampliar `isShellChildOrigin` (y, si aplica, la lista de `SHELL_ORIGINS`) para incluir el nuevo puerto:

```ts
export function isShellChildOrigin(origin: string): boolean {
  return /^http:\/\/(localhost|127\.0\.0\.1):(420[1-5]|5174)$/.test(origin);
}
```

Si el nuevo microfrontend necesita recibir la sesión igual que los actuales, no se requiere tocar `SHELL_ORIGINS` (que son los orígenes válidos *del shell*, no de los hijos).

### Paso 3 — Crear el componente de redirección iframe

Siguiendo el patrón de `users-redirect.component.ts` (caso simple) o `evidence-redirect.component.ts` (caso con dependencia de `active_assessment_id`), crear `src/app/presentation/pages/nuevo-mf-redirect.component.ts`:

```ts
@Component({
  selector: 'app-nuevo-mf-redirect',
  standalone: true,
  template: `
    <div class="remote-container">
      <iframe src="http://localhost:5174/ruta" title="Nuevo módulo" class="remote-frame"></iframe>
    </div>
  `,
  styles: [/* mismas reglas .remote-container / .remote-frame que los demás redirects */],
})
export class NuevoMfRedirectComponent {}
```

Si el módulo requiere sincronizar sesión de forma dinámica (por ejemplo, al depender de una variable como `active_assessment_id`), replicar el patrón `AfterViewInit`/`@ViewChild('frame')` + `installIframeAuthRelay` + `postAuthSessionToIframe` de `EvidenceRedirectComponent`.

### Paso 4 — Registrar la ruta en `app.routes.ts`

Añadir la ruta como hija de `ShellLayoutComponent`, con `loadComponent` (carga perezosa) y, si corresponde, un guard de autoridad:

```ts
{
  path: 'nuevo-modulo',
  canActivate: [roleGuard('NUEVA_AUTORIDAD')],
  loadComponent: () =>
    import('./presentation/pages/nuevo-mf-redirect.component').then(
      (m) => m.NuevoMfRedirectComponent
    ),
},
```

Si el módulo introduce una autoridad nueva, añadirla primero al tipo `Authority` y a `ROLE_AUTHORITIES` en `src/app/domain/dashboard/authority.ts`.

### Paso 5 — Añadir el ítem de menú

En `shell-layout.component.ts`, dentro del `computed<NavItem[]>` `navItems`, agregar la entrada correspondiente con su condición `show` basada en `hasAuthority`/`isSystemAdmin`.

### Paso 6 — (Opcional) Añadir tarjeta y contador en el dashboard

Si el nuevo módulo debe aparecer en `/dashboard`, añadir una entrada a `cards` en `dashboard-page.component.ts` y, si tiene contador propio, extender `DashboardStats` y `DashboardStatsService.load()` con la llamada HTTP correspondiente (siguiendo el patrón `safeCount` para no romper el resto de contadores ante un fallo).

### Paso 7 — Verificar manualmente el flujo completo

Dado que no hay pruebas automatizadas (ver `05-Pruebas.md`), verificar manualmente:

1. Arrancar el nuevo microfrontend en su puerto.
2. Arrancar `mf_shell` y entrar por `http://localhost:4200`.
3. Confirmar que el ítem de menú aparece solo para el rol/autoridad esperado.
4. Confirmar que el iframe carga y que la sesión (Bearer/roles) llega correctamente al hijo (verificar en las DevTools del navegador el mensaje `MSPI_AUTH_SESSION` recibido).

### Checklist resumido

- [ ] Puerto fijo asignado y documentado.
- [ ] Origen añadido a `isShellChildOrigin` en `shell-iframe-bridge.ts`.
- [ ] Componente `*-redirect.component.ts` creado con el patrón iframe existente.
- [ ] Ruta añadida en `app.routes.ts` con `loadComponent` y guard si aplica.
- [ ] Nueva autoridad (si aplica) añadida en `authority.ts`.
- [ ] Ítem de menú añadido en `shell-layout.component.ts` (`navItems`).
- [ ] (Opcional) Tarjeta y contador en `dashboard-page.component.ts` / `dashboard-stats.service.ts`.
- [ ] Verificación manual de sesión y menú por rol.

## 5. Deuda técnica y mejoras futuras identificadas

| Ítem | Detalle | Prioridad sugerida |
|---|---|---|
| Corregir/retirar documentación inconsistente | `README.md` y `docs/ARQUITECTURA-CLEAN-ARCHITECTURE.md` describen un stack (Vite+React+Module Federation) inexistente en el código; `docs/INTEGRAR-NUEVOS-MF.md` hereda el mismo error | Alta — riesgo directo de confusión para desarrolladores y evaluadores |
| Ausencia de pruebas automatizadas | Ver `05-Pruebas.md` | Alta — impacta directamente la seguridad (guards, validación de origen) |
| Orígenes y URLs de microservicios hardcodeados a `localhost` | `shell-iframe-bridge.ts`, `shell-layout.component.ts`, `environment.ts` sin `environment.prod.ts` | Alta — bloqueante para despliegue fuera de desarrollo local |
| `.env.example` con variable `VITE_USE_MOCKS` sin efecto real en Angular | Confirmado residuo de migración (comentario en `.gitignore`) | Media — limpieza de higiene de repositorio |
| Falta de monitoreo real de microfrontends/microservicios | `/system-health` es un placeholder explícito | Media — funcionalidad planificada pero no iniciada |
| `DashboardStatsService` sin puerto de dominio (`GetDashboardStatsPort`) | Inconsistencia menor respecto al patrón de puertos aplicado al usuario | Baja — mejora de consistencia arquitectónica |
| Ausencia de CI/CD | No hay `.github/workflows` | Media — depende de la estrategia global del proyecto de grado |
| Migración futura a Module Federation o Native Federation | Mencionada como intención en `docs/INTEGRACION-SHELL.md` ("Module Federation (futuro)") pero sin implementación ni cronograma | Baja/exploratoria |

## 6. Consideraciones para la evolución del shell

- Cualquier evolución hacia Module Federation real (Webpack Module Federation o `@angular-architects/native-federation`, la vía recomendada para Angular moderno) implicaría reemplazar íntegramente `shell-iframe-bridge.ts` y los componentes `*-redirect`, y coordinar el cambio con los 5 microfrontends hijos simultáneamente — no es un cambio incremental aislado al shell.
- Mientras se mantenga el modelo iframe, cualquier ampliación de funcionalidad de sincronización (por ejemplo, temas visuales compartidos, notificaciones cross-MF) debería extender el protocolo `MSPI_*` existente en `shell-iframe-bridge.ts` en lugar de introducir un mecanismo paralelo, para mantener un único punto de auditoría de la comunicación entre orígenes.
- Se recomienda, antes de cualquier despliegue fuera de entornos de desarrollo local, resolver la limitación de `environment.ts` único (sin `environment.prod.ts` ni *file replacements*) para permitir apuntar a hosts de backend distintos de `localhost`.
