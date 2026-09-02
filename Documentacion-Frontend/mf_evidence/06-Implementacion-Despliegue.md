# mf_evidence — Implementación y Despliegue

**Repositorio:** `MSPI_NVA_CO_MR_FRONT/mf_evidence`
**Fecha del documento:** 2026-08-18
**Alcance:** Proceso de build, contenerización, configuración de Nginx, variables de entorno y puesta en marcha local vs. en contenedor del microfrontend `mf_evidence`.

---

## 1. Scripts de build reales (`package.json`)

```json
"scripts": {
  "ng": "ng",
  "start": "ng serve",
  "start:api": "ng serve --configuration=api",
  "build": "ng build",
  "build:docker": "docker build -f deployment/Dockerfile -t mspi/mf-evidence:dev .",
  "clean": "node -e \"const fs=require('fs'); ['.angular'].forEach(p=>{try{fs.rmSync(p,{recursive:true})}catch(e){}})\""
}
```

| Comando | Efecto real |
|---|---|
| `npm start` | `ng serve` — arranca en `http://localhost:4204`, configuración `development` (por `defaultConfiguration` de `angular.json`), **modo mock** (`environment.ts` con `useMocks: true`) |
| `npm run start:api` | `ng serve --configuration=api` — mismo puerto, con `fileReplacements` que sustituyen `environment.ts` por `environment.api.ts` (`useMocks: false`), consumiendo `ms_evidence` real en `localhost:8086` |
| `npm run build` | `ng build` — usa `defaultConfiguration: "production"` del target `build`; genera `dist/mf-evidence/browser` con `outputHashing: all` |
| `npm run build:docker` | Construye la imagen Docker usando el `Dockerfile` propio del microfrontend |
| `npm run clean` | Elimina `.angular` (caché de build de Angular CLI) — más simple que el equivalente de `mf_auth`, que además limpia residuos de Vite (`mf_evidence` no tiene ese código heredado) |

**Nota de precisión:** el `Dockerfile` propio construye con `npm run build -- --configuration=api` (ver sección 3); es decir, el build de contenedor por defecto **no** usa el modo mock, sino que apunta a `ms_evidence` real — a diferencia de `npm run build` en local, que usa `production` sin la configuración `api` y por tanto conserva `useMocks: true` salvo que se indique explícitamente `--configuration=production,api`.

## 2. Configuración de build (`angular.json`)

```json
"configurations": {
  "production": { "outputHashing": "all" },
  "development": { "optimization": false, "sourceMap": true },
  "api": {
    "fileReplacements": [
      { "replace": "src/environments/environment.ts", "with": "src/environments/environment.api.ts" }
    ],
    "optimization": false,
    "sourceMap": true
  }
}
```

- `outputPath`: `dist/mf-evidence` (el contenido servible queda en `dist/mf-evidence/browser`, estructura estándar del builder `@angular-devkit/build-angular:application`).
- `browser`: `src/main.ts` (único punto de entrada).
- `polyfills`: `zone.js`.
- `assets`: todo el contenido de `public/` se copia tal cual — en este microfrontend, `public/` solo contiene `.gitkeep` (sin logos ni activos gráficos propios).
- `styles`: `src/styles.scss` como hoja global (3 reglas: `margin: 0`, `font-family: system-ui, sans-serif`, `background: #f8fafc`).
- Servidor de desarrollo (`serve`): puerto fijo **4204**, `defaultConfiguration: "development"`.

Las configuraciones `production`, `development` y `api` **son combinables** (`--configuration=production,api`), aunque no hay evidencia en los scripts de `package.json` de que se use esa combinación en local; sí se usa efectivamente en el `Dockerfile` (ver sección 3).

## 3. Contenerización — `deployment/Dockerfile` (propio de `mf_evidence`)

```dockerfile
# Build: docker build -f deployment/Dockerfile -t mspi/mf-evidence:dev .
# Run:   docker run --rm -p 4204:80 mspi/mf-evidence:dev

FROM node:22-alpine AS build
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci
COPY . .
RUN npm run build -- --configuration=api

FROM nginx:1.27-alpine
RUN apk add --no-cache curl
COPY deployment/nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/dist/mf-evidence/browser /usr/share/nginx/html
RUN chown -R nginx:nginx /usr/share/nginx/html
EXPOSE 80
HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
  CMD curl -f http://127.0.0.1/ || exit 1
CMD ["nginx", "-g", "daemon off;"]
```

Características (idénticas en estructura a `mf_auth`, confirmando un patrón de despliegue estandarizado en el ecosistema MSPI):

- **Multi-stage build**: etapa `build` con Node 22 (Alpine) instala dependencias con `npm ci` (instalación reproducible desde `package-lock.json`) y compila con `ng build --configuration=api`.
- **Etapa `runtime`**: Nginx 1.27 (Alpine), copia únicamente el resultado compilado (`dist/mf-evidence/browser`), sin Node ni código fuente — imagen final ligera.
- **`chown -R nginx:nginx`**: ajusta permisos del contenido estático al usuario `nginx` del contenedor (principio de menor privilegio).
- **`HEALTHCHECK`**: verifica cada 30s que Nginx responde en `http://127.0.0.1/`, con periodo de gracia de 20s y 3 reintentos.
- Expone el puerto **80** interno (el mapeo a 4204 se hace en tiempo de ejecución, ver sección 5).

Construcción documentada en el propio archivo (comentarios en las dos primeras líneas del `Dockerfile`):

```bash
docker build -f deployment/Dockerfile -t mspi/mf-evidence:dev .
docker run --rm -p 4204:80 mspi/mf-evidence:dev
```

## 4. Dockerfile genérico compartido del monorepo frontend

`MSPI_NVA_CO_MR_FRONT/deployment/docker/Dockerfile.angular` es una plantilla parametrizable (mediante `ARG`) pensada para reutilizarse entre todos los microfrontends del ecosistema:

```dockerfile
ARG NODE_VERSION=22-alpine
FROM node:${NODE_VERSION} AS build
ARG BUILD_CONFIGURATION=api
ARG DIST_FOLDER=shell
...
RUN npm run build -- --configuration=${BUILD_CONFIGURATION}
FROM nginx:1.27-alpine AS runtime
...
COPY --from=build /app/dist/${DIST_FOLDER}/browser /usr/share/nginx/html
```

Igual que en `mf_auth`, `mf_evidence` **no usa directamente** esta plantilla genérica en su script `build:docker`; usa su propio `deployment/Dockerfile`, funcionalmente equivalente pero con los valores `DIST_FOLDER=mf-evidence` y `BUILD_CONFIGURATION=api` ya fijados (sin necesidad de pasar `--build-arg`). Ambos Dockerfiles comparten la misma estructura de dos etapas (Node 22-alpine → Nginx 1.27-alpine) y el mismo mecanismo de `HEALTHCHECK`, confirmando que el patrón de contenerización es consistente en todo el frontend MSPI (verificado ya en `mf_auth` y `mf_evidence`).

## 5. Configuración de Nginx

`deployment/nginx.conf` (propio de `mf_evidence`, copiado dentro de la imagen como `/etc/nginx/conf.d/default.conf`):

```nginx
server {
    listen 80;
    server_name localhost;
    root /usr/share/nginx/html;
    index index.html;

    gzip on;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml;

    location / {
        try_files $uri $uri/ /index.html;
    }

    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff2?)$ {
        expires 7d;
        add_header Cache-Control "public, immutable";
        try_files $uri =404;
    }

    add_header Content-Security-Policy "frame-ancestors 'self' http://localhost:4200 http://127.0.0.1:4200" always;

    error_page 404 /index.html;
}
```

Puntos clave (idénticos a los de `mf_auth` en estructura, con el mismo origen de shell permitido):

- **`try_files $uri $uri/ /index.html`**: enrutamiento SPA estándar, requerido porque Angular Router maneja las rutas client-side (`/assessments/:id/context`, `/assessments/:id/inventory`) que no existen como archivos físicos.
- **Cacheo de 7 días** con `Cache-Control: public, immutable` para assets con hash en el nombre (JS/CSS con `outputHashing: all`), imágenes y fuentes.
- **`Content-Security-Policy: frame-ancestors`**: autoriza explícitamente que `mf_evidence` sea embebido en un `<iframe>` únicamente desde `http://localhost:4200` y `http://127.0.0.1:4200` (el shell) — es la razón técnica que permite al shell embeber `4204/assessments/{activeId}/context` en su ruta `/evidence` (`docs/INTEGRACION-SHELL.md`).
- **`error_page 404 /index.html`**: refuerza el fallback SPA también ante rutas no resueltas por `try_files`.

Existe además `MSPI_NVA_CO_MR_FRONT/deployment/nginx/spa.conf`, una configuración genérica equivalente a nivel de monorepo (mismo patrón `try_files`, mismo cacheo, mismo CSP hacia el shell), confirmando que todos los microfrontends Angular del ecosistema comparten el mismo criterio de despliegue.

## 6. Variables de entorno

### 6.1 Sin archivo `.env.example`

A diferencia de `mf_auth` (que sí incluye un `.env.example` con la variable `VITE_USE_MOCKS`, sin efecto real sobre el build Angular), **`mf_evidence` no tiene ningún archivo `.env*` en el repositorio**. Esto elimina la fuente de confusión documentada para `mf_auth`: en `mf_evidence` no existe ninguna variable de entorno "fantasma" que sugiera un mecanismo de configuración inexistente.

### 6.2 Variables reales (Angular `environment.*.ts`)

| Variable | `environment.ts` (dev/mock, por defecto) | `environment.api.ts` (`--configuration=api`) |
|---|---|---|
| `useMocks` | `true` | `false` |
| `msEvidenceUrl` | `http://localhost:8086` | `http://localhost:8086` |
| `shellOrigin` | `http://localhost:4200` | `http://localhost:4200` |
| `apiBaseUrl` | `http://localhost:8086` | `http://localhost:8086` |

Estas no son variables de entorno del sistema operativo; son **constantes TypeScript compiladas en el bundle** en tiempo de build, seleccionadas por sustitución de archivo (`fileReplacements`). Cualquier cambio de URL de backend o de origen del shell requiere editar estos archivos y **recompilar** la aplicación — no hay soporte para configuración en tiempo de ejecución (*runtime config*) ni inyección vía contenedor.

**Observación:** `msEvidenceUrl` y `apiBaseUrl` tienen exactamente el mismo valor en ambos archivos de entorno (`http://localhost:8086`); el código solo usa `environment.msEvidenceUrl` (`ApiEvidenceRepository`), por lo que `apiBaseUrl` está declarado pero **sin uso real** en el código fuente inspeccionado — posible remanente de una convención compartida entre microfrontends (en `mf_auth`, `apiBaseUrl` sí es el nombre usado activamente).

## 7. Puesta en marcha — local vs. contenedor

### 7.1 Local (desarrollo)

```bash
npm install                 # instala dependencias (Angular 19, rxjs)
npm start                   # ng serve, puerto 4204, modo mock (sin backend)
# o, con backend real disponible en 8086:
npm run start:api
```

Requisitos: Node.js compatible con Angular 19 (Angular 19 requiere Node ^18.19, ^20.11 o superior según los requisitos oficiales del framework; el `Dockerfile` usa Node 22). No se documenta en el repositorio una versión mínima de Node exigida explícitamente en `package.json` (no hay campo `engines`).

Para ejercitar el flujo completo localmente sin backend ni shell: establecer manualmente `localStorage.setItem('active_assessment_id', '<cualquier-id>')` desde la consola del navegador antes de navegar a `http://localhost:4204/`, o navegar directamente a `http://localhost:4204/assessments/<cualquier-id>/context`.

### 7.2 Contenedor (build productivo)

```bash
npm run build:docker
# equivalente a:
docker build -f deployment/Dockerfile -t mspi/mf-evidence:dev .
docker run --rm -p 4204:80 mspi/mf-evidence:dev
```

En este modo:

- El build se ejecuta con `--configuration=api` (backend real requerido: `ms_evidence` en 8086, alcanzable desde el navegador del cliente final, no desde el contenedor — las URLs son `http://localhost:...`, es decir, se asume despliegue local/desarrollo donde el navegador y el backend comparten host).
- El contenedor sirve contenido **100% estático** vía Nginx; no hay proceso Node en producción.
- El puerto interno 80 se publica externamente como 4204, replicando el puerto de desarrollo para mantener consistencia con la ruta de integración del shell (`4204/assessments/{id}/context`).

### 7.3 Limitación relevante para despliegues distintos a local

Dado que `msEvidenceUrl`/`apiBaseUrl` y `shellOrigin` están **hardcodeados en el código fuente compilado** (y, adicionalmente, la lista `ALLOWED_PARENTS`/`SHELL_ORIGINS` en `auth-parent-bridge.ts`/`shell-bridge.ts` incluye literales `http://localhost:4200`/`http://127.0.0.1:4200` además del valor de `environment.shellOrigin`), desplegar `mf_evidence` en un dominio o entorno distinto a `localhost` requiere modificar `environment.api.ts` **y** los literales de origen del shell dispersos en `auth-parent-bridge.ts` y `shell-bridge.ts`, y recompilar — no existe mecanismo de configuración externa (variables de entorno de contenedor, `config.json` servido en runtime) para estos valores. Esta limitación es equivalente a la ya documentada para `mf_auth`.
