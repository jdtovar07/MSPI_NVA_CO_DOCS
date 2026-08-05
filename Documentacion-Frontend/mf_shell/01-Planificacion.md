# mf_shell — Planificación

**Repositorio:** `MSPI_NVA_CO_MR_FRONT/mf_shell`
**Fecha del documento:** 2026-08-18
**Alcance:** Fase de planificación del microfrontend **host/orquestador** (`mf_shell`), componente central del ecosistema **MSPI** (sistema de gestión de seguridad de la información alineado a ISO 27001), construido bajo una arquitectura de microfrontends Angular.

---

## 1. Contexto del proyecto

MSPI es una plataforma web compuesta por un **shell** anfitrión y varios microfrontends independientes que se despliegan y ejecutan como aplicaciones Angular separadas:

| Microfrontend | Puerto | Responsabilidad |
|---|---|---|
| **`mf_shell`** | **4200** | **Host / navegación global / dashboard / sesión** |
| `mf_auth` | 4201 | Autenticación, 2FA, gestión de usuarios |
| `mf_org` | 4202 | Organizaciones |
| `mf_assessment` | 4203 | Evaluaciones MSPI |
| `mf_evidence` | 4204 | Evidencias / levantamiento |
| `mf_reports` | 4205 | Diagnóstico y reportes |

Esta relación está documentada en `MSPI_NVA_CO_MR_FRONT/docs/README.md`, índice general del frontend, que enlaza a la documentación propia de cada microfrontend en su carpeta `docs/`.

`mf_shell` es el **único punto de entrada del usuario** al sistema MSPI: aloja el layout principal (menú lateral, cabecera, perfil), el dashboard con contadores reales, los *guards* de autenticación y autorización (control centralizado de rutas) y los contenedores que embeben, mediante `<iframe>`, a los cinco microfrontends restantes. Coordina además la propagación de la sesión JWT y de la "evaluación activa" entre microfrontends mediante `postMessage` y `localStorage`.

## 2. Alcance del microfrontend

### 2.1 Incluido en el alcance de `mf_shell`

- **Layout global**: menú lateral, cabecera, notificaciones y menú de perfil (`ShellLayoutComponent`).
- **Dashboard** (`/dashboard`) con tarjetas de acceso filtradas por autoridad del usuario y contadores obtenidos de las APIs de organizaciones, usuarios, evaluaciones, evidencias y reportes.
- **Guards de enrutamiento**: `authGuard` (sesión requerida) y `roleGuard(authority)` / `systemAdminGuard()` (autorización por ruta) — el único microfrontend con control centralizado de rutas de todo el sistema.
- **Contenedores iframe** que embeben `mf_auth`, `mf_org`, `mf_assessment`, `mf_evidence` y `mf_reports` dentro del layout del shell, preservando el menú.
- **Puente de sesión** (`shell-iframe-bridge.ts`): retransmite la sesión JWT (`auth_session`) a los iframes hijos vía `postMessage`, escucha solicitudes de sesión (`MSPI_AUTH_REQUEST`) y eventos de navegación/evaluación activa (`MSPI_SHELL_NAV`, `MSPI_ACTIVE_ASSESSMENT`) emitidos por los hijos.
- **Interceptor HTTP** (`apiInterceptor`) que añade el header `Authorization: Bearer` y desenvuelve la respuesta `{ data, meta }` de las APIs propias del dashboard.
- Páginas *placeholder* para funcionalidades aún no integradas (Escalas, Banco de preguntas, Auditoría, Salud del sistema, Configuración del sistema).

### 2.2 Fuera del alcance de `mf_shell`

- **Lógica de negocio** de autenticación, organizaciones, evaluaciones, evidencias o reportes — cada una reside en su propio microfrontend; el shell solo enlaza/embebe.
- **Backend**: el shell consume APIs REST de solo lectura (conteos) para el dashboard; no implementa reglas de negocio de dominio.
- Módulos declarados como *placeholder* en el código (`FeaturePlaceholderPageComponent`): Escalas, Banco de preguntas, Auditoría, Salud del sistema, Configuración del sistema — pendientes de implementación real, según lo declara explícitamente `app.routes.ts` y `DESCRIPCION.md`.

## 3. Objetivos

### 3.1 Objetivo general

Proveer el microfrontend host de la plataforma MSPI, responsable del punto de entrada único del usuario, la autenticación/autorización centralizada por rutas, el layout compartido y la orquestación en tiempo de ejecución (vía navegador) de los cinco microfrontends restantes, sin acoplamiento de código en tiempo de compilación con ninguno de ellos.

### 3.2 Objetivos específicos

1. Centralizar el control de acceso por ruta mediante `authGuard` (sesión) y `roleGuard`/`systemAdminGuard` (autoridad), evitando que cada microfrontend hijo reimplemente la protección de sus rutas de nivel superior.
2. Ofrecer un dashboard único con indicadores agregados (organizaciones, usuarios, evaluaciones, evidencias, reportes) consumidos en paralelo desde los microservicios `ms_org`, `ms_iam` y `ms_evidence`.
3. Embeber cada microfrontend hijo dentro de un `<iframe>` que conserve el layout (menú, cabecera) del shell, en lugar de una redirección de página completa, para dar sensación de aplicación única.
4. Propagar la sesión (`auth_session`) y la evaluación en curso (`active_assessment_id`) entre el shell y sus microfrontends hijos mediante un protocolo de mensajes `postMessage` (`MSPI_AUTH_SESSION`, `MSPI_AUTH_REQUEST`, `MSPI_ACTIVE_ASSESSMENT`, `MSPI_SHELL_NAV`) validado por origen.
5. Aislar la lógica de negocio propia (obtención del usuario de dashboard, cálculo de autoridades) de la infraestructura (localStorage, HTTP) mediante capas de dominio/aplicación/infraestructura/presentación.
6. Permitir el despliegue en contenedor Docker con Nginx, homogéneo con el resto de microfrontends del ecosistema MSPI.

## 4. Requerimientos iniciales (alto nivel)

- El shell debe ejecutarse de forma independiente en el puerto **4200** (`ng serve`), siendo la única puerta de entrada recomendada al sistema (`docs/README.md`: "Entrar siempre por http://localhost:4200").
- Debe bloquear el acceso a cualquier ruta protegida sin sesión válida, redirigiendo a `/login` (que a su vez reenvía a `mf_auth` en 4201).
- Debe filtrar el menú y las rutas visibles según las autoridades del usuario (`USER_MANAGE`, `ORG_MANAGE`, `TEMPLATE_MANAGE`, `ASSESSMENT_VIEW`, `ASSESSMENT_EDIT`, `ASSESSMENT_REVIEW`, `REPORT_EXPORT`, `AUDIT_VIEW`) derivadas de los roles del backend (`AdminSistema`, `AdminInstrumento`, `Evaluador`, `Revisor`, `EvaluadorRevisor`, `Lector`).
- Debe embeber cada microfrontend hijo únicamente cuando el usuario navega a la ruta correspondiente (`/users`, `/organizations`, `/my-organization`, `/evaluations`, `/evidence`, `/reports`).
- Debe sincronizar la "evaluación activa" (`active_assessment_id`) para habilitar correctamente las vistas de Evidencias y Reportes, que dependen de una evaluación seleccionada en `mf_assessment`.

## 5. Stack tecnológico (verificado en `package.json` y `angular.json`)

| Categoría | Tecnología | Versión |
|---|---|---|
| Framework | Angular (`@angular/core`, `@angular/common`, `@angular/forms`, `@angular/router`, `@angular/platform-browser*`) | `^19.0.0` |
| Animaciones | `@angular/animations` | `^19.0.0` |
| Reactividad | `rxjs` | `~7.8.0` |
| Runtime Angular | `zone.js` | `~0.15.0` |
| CLI / build | `@angular/cli`, `@angular-devkit/build-angular` (builder `application`) | `^19.0.0` |
| Compilador | `@angular/compiler-cli`, `typescript` | `~5.6.0` |
| Lenguaje | TypeScript | `~5.6.0` |
| Contenedor | Node 22-alpine (build) + Nginx 1.27-alpine (runtime) | — |

**Hallazgo crítico — mecanismo real de orquestación:** el `package.json` y el `angular.json` confirman que `mf_shell` es una aplicación **Angular pura** (builder `@angular-devkit/build-angular:application`), sin ninguna dependencia de *Module Federation* de Webpack (no existe `@angular-architects/module-federation`), de Native Federation, ni de Vite/`@originjs/vite-plugin-federation`. La orquestación real, verificada en el código fuente (`src/app/presentation/pages/*-redirect.component.ts`, `src/app/infrastructure/shell-iframe-bridge.ts`), se implementa mediante **`<iframe>` HTML embebido apuntando a `http://localhost:420X`** y un protocolo propio de mensajería `window.postMessage` para sincronizar la sesión y la navegación. Este hallazgo coincide con el encontrado en el piloto de `mf_auth` (que tampoco usa Module Federation) y se detalla con evidencia exhaustiva en `03-Diseno.md`.

**Documentación inconsistente detectada:** el repositorio contiene documentación contradictoria sobre este punto. `mf_shell/README.md` y `docs/ARQUITECTURA-CLEAN-ARCHITECTURE.md` describen un shell construido en **Vite + React + `@originjs/vite-plugin-federation`** que carga `mf_auth` como remoto federado (`import("mf_auth/AppWithProviders")`), con estructura de carpetas `src/features/shell/{domain,application,infrastructure,presentation}` en TypeScript/TSX. `docs/INTEGRAR-NUEVOS-MF.md` repite ese mismo modelo (Vite + React) como guía "vigente" para añadir microfrontends. Ninguna de esas rutas ni archivos (`vite.config.ts`, `src/features/shell/domain/RemoteAppId.ts`, `AppWithProviders.tsx`) existe en el árbol real de `src/`, que es 100 % Angular (`src/app/**`). Los documentos `docs/DESCRIPCION.md`, `docs/ARQUITECTURA.md`, `docs/RUTAS-Y-PANTALLAS.md`, `docs/FLUJOS.md`, `docs/API-INTEGRACION.md`, `docs/INTEGRACION-SHELL.md` y `docs/DIAGRAMAS.md` sí describen correctamente el modelo Angular + iframe, y `INTEGRACION-SHELL.md` lo declara de forma explícita: *"Modelo actual: iframe (no Module Federation activo)"*. Se concluye que el README raíz y `ARQUITECTURA-CLEAN-ARCHITECTURE.md` son artefactos residuales de un prototipo o plan anterior (probablemente compartido con una versión temprana de `mf_auth` en React) que **no reflejan el código Angular real** y no deben tomarse como fuente de verdad. Este documento y los siguientes se basan exclusivamente en el código Angular verificado y en los siete documentos de `docs/` consistentes con él.

## 6. Restricciones y supuestos

- Los cinco microfrontends hijos deben estar disponibles en sus puertos fijos (4201–4205) para que el shell pueda embeberlos vía iframe; si un puerto no responde, el iframe correspondiente queda en blanco o con error de carga.
- Los orígenes permitidos para recibir/emitir mensajes `postMessage` están *hardcodeados* mediante expresión regular (`isShellChildOrigin`: `http://(localhost|127.0.0.1):420[1-5]`), lo que ata el mecanismo de seguridad a puertos de desarrollo local.
- Se recomienda explícitamente (`docs/INTEGRACION-SHELL.md`) entrar siempre por el puerto 4200 para que la sesión se propague correctamente a los iframes; abrir un microfrontend hijo de forma directa (por ejemplo `http://localhost:4201`) rompe la propagación automática de sesión.
- Las vistas de Evidencias y Reportes dependen de una `active_assessment_id` almacenada en `localStorage`; sin evaluación activa muestran una pantalla de "Sin evaluación activa" en lugar del iframe.
- No se encontró documentación ni configuración de CI/CD dentro del repositorio de `mf_shell` (no hay carpeta `.github/workflows` ni pipeline visible en el microfrontend).

## 7. Recursos y planificación

### 7.1 Recursos identificados en el repositorio

- Código fuente Angular real: `src/app/**` (dominio, aplicación, infraestructura, presentación) — únicas carpetas incluidas en `tsconfig.app.json`.
- Documentación técnica preexistente en `mf_shell/docs/` (8 documentos Markdown), usada como fuente primaria para esta documentación de tesis, con la salvedad de `ARQUITECTURA-CLEAN-ARCHITECTURE.md` (descartado por inconsistente, ver sección 5).
- Assets estáticos: `public/auditcyber-logo.png` (logo del producto "AuditCyber").
- Infraestructura de despliegue propia: `deployment/Dockerfile`, `deployment/nginx.conf`.
- Infraestructura de despliegue compartida a nivel de repositorio frontend: `MSPI_NVA_CO_MR_FRONT/deployment/docker/Dockerfile.angular` (plantilla genérica parametrizable) y `MSPI_NVA_CO_MR_FRONT/deployment/nginx/spa.conf`.
- Configuración de proxy de desarrollo: `proxy.conf.json` (rutas `/__mf_auth`, `/__mf_org` hacia 4201/4202) — usada solo parcialmente, ya que el mecanismo de producción real es el iframe directo a cada puerto, no el proxy.

### 7.2 Plan de trabajo inferido (por evidencia de código, no por bitácora explícita)

No existe en el repositorio un backlog, roadmap o bitácora de sprints formal para `mf_shell`. La planificación documentada aquí se reconstruye a partir de la evidencia funcional del código y de la documentación en `docs/`, siguiendo el orden natural de dependencia funcional:

1. **Base del shell**: bootstrap Angular standalone (`main.ts`, `app.config.ts`, `app.routes.ts`).
2. **Autenticación centralizada**: `AuthSessionService`, `authGuard`, redirección a `/login`.
3. **Layout y navegación**: `ShellLayoutComponent` con menú dinámico por autoridad (`navItems`).
4. **Autorización por ruta**: `role.guard.ts` (`roleGuard`, `systemAdminGuard`) aplicado a cada ruta hija.
5. **Dashboard con contadores reales**: `DashboardStatsService` consumiendo `ms_org`, `ms_iam`, `ms_evidence` en paralelo con manejo de fallos individuales (`safeCount`).
6. **Integración iframe de microfrontends**: componentes `*-redirect.component.ts` para `mf_auth`, `mf_org`, `mf_assessment`, `mf_evidence`, `mf_reports`.
7. **Puente de sesión entre iframes**: `shell-iframe-bridge.ts` con protocolo `postMessage` propio.
8. **Placeholders de módulos futuros**: `FeaturePlaceholderPageComponent` para Escalas, Banco de preguntas, Auditoría, Salud y Configuración del sistema.
9. **Empaquetado y despliegue**: Dockerfile propio + Nginx.
10. **Documentación técnica** (`docs/*.md`), generada como parte del proyecto (con la inconsistencia señalada en la sección 5).

Declaración explícita de limitación: **no hay evidencia en el repositorio de control de versiones semántico por hitos, ni de un archivo `CHANGELOG.md`, ni de tickets/historias de usuario formales**; el archivo `package.json` fija `"version": "1.0.0"` de forma estática.

## 8. Riesgos identificados

| Riesgo | Evidencia | Impacto |
|---|---|---|
| Documentación raíz (README.md, ARQUITECTURA-CLEAN-ARCHITECTURE.md) describe un stack (Vite+React+Module Federation) que no existe en el código real (Angular) | Comparación directa `package.json`/`angular.json` vs. contenido de esos documentos | Alto riesgo de confusión para nuevos desarrolladores o evaluadores del proyecto de grado |
| Orígenes de `postMessage` e iframe hardcodeados a `localhost:420X` | `isShellChildOrigin`, URLs literales en cada `*-redirect.component.ts` | Rigidez para despliegues en dominios/ambientes distintos a desarrollo local |
| Ausencia total de pruebas automatizadas | No existen archivos `*.spec.ts` ni configuración Karma/Jest (ver `05-Pruebas.md`) | Riesgo de regresiones no detectadas en guards, cálculo de autoridades y bridge de sesión |
| Dependencia de disponibilidad simultánea de 5 microfrontends + 5 microservicios para experiencia completa | `docs/FLUJOS.md`, `docs/API-INTEGRACION.md` | Complejidad operativa alta para levantar el entorno completo de desarrollo/pruebas |
| Guía `INTEGRAR-NUEVOS-MF.md` no aplicable al código real | Contradice el modelo iframe confirmado en `INTEGRACION-SHELL.md` y en el propio código | Riesgo de que un desarrollador siga pasos incorrectos al integrar un nuevo microfrontend |

Estos hallazgos se retoman con mayor detalle en `03-Diseno.md`, `04-Desarrollo.md` y `07-Mantenimiento.md`.
