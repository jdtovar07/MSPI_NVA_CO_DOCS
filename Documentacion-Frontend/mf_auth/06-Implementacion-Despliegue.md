# mf_auth — Implementación y Despliegue

**Repositorio:** `MSPI_NVA_CO_MR_FRONT/mf_auth`
**Fecha del documento:** 2026-08-18
**Alcance:** Proceso de build, contenerización, configuración de Nginx, variables de entorno y puesta en marcha local vs. en contenedor del microfrontend `mf_auth`.

---

## 1. Scripts de build reales (`package.json`)

```json
"scripts": {
  "ng": "ng",
  "start": "ng serve",
  "start:api": "ng serve --configuration=api",
  "start:force": "ng serve --force",
  "build": "ng build",
  "build:docker": "docker build -f deployment/Dockerfile -t mspi/mf-auth:dev .",
  "clean": "node -e \"const fs=require('fs'); ['.angular','node_modules/.vite'].forEach(p=>{try{fs.rmSync(p,{recursive:true});console.log('Eliminado:',p)}catch(e){}})\""
}
```

| Comando | Efecto real |
|---|---|
| `npm start` | `ng serve` — arranca en `http://localhost:4201`, configuración `development` (por `defaultConfiguration` de `angular.json`), **modo mock** (`environment.ts` con `useMocks: true`) |
| `npm run start:api` | `ng serve --configuration=api` — mismo puerto, pero con `fileReplacements` que sustituyen `environment.ts` por `environment.api.ts` (`useMocks: false`), consumiendo `ms_iam`/`ms_org` reales en `localhost:8082`/`8083` |
| `npm run start:force` | Igual a `start` forzando reinstalación/optimización de dependencias de Angular CLI (`--force`) |
| `npm run build` | `ng build` — usa `defaultConfiguration: "production"` del target `build`; genera `dist/mf-auth/browser` con `outputHashing: all` |
| `npm run build:docker` | Construye la imagen Docker usando el `Dockerfile` propio del microfrontend |
| `npm run clean` | Elimina `.angular` (caché de build de Angular CLI) y `node_modules/.vite` (residual de la plantilla Vite original, ver `03-Diseno.md`) |

**Nota de precisión:** el `Dockerfile` propio construye con `npm run build -- --configuration=api` (ver sección 3), es decir, el build de contenedor por defecto **no** usa el modo mock, sino que apunta a `ms_iam`/`ms_org` reales — a diferencia de `npm run build` en local, que usa `production` sin el `api` configuration y por tanto conserva `useMocks: true` salvo que se indique explícitamente `--configuration=production,api`.

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

- `outputPath`: `dist/mf-auth` (el contenido servible queda en `dist/mf-auth/browser`, estructura estándar del builder `@angular-devkit/build-angular:application`).
- `browser`: `src/main.ts` (único punto de entrada).
- `polyfills`: `zone.js`.
- `assets`: todo el contenido de `public/` se copia tal cual (incluye `auditcyber-logo.png`, `vite.svg` residual y `README-logo.md`).
- `styles`: `src/styles.scss` como hoja global.
- Servidor de desarrollo (`serve`): puerto fijo **4201**, `defaultConfiguration: "development"`.

Las configuraciones `production`, `development` y `api` **son combinables** (Angular CLI permite `--configuration=production,api`), aunque no hay evidencia en los scripts de `package.json` de que se use esa combinación en local; sí se usa efectivamente en el `Dockerfile` (ver sección 3).

## 3. Contenerización — `deployment/Dockerfile` (propio de `mf_auth`)

```dockerfile
FROM node:22-alpine AS build
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci
COPY . .
RUN npm run build -- --configuration=api

FROM nginx:1.27-alpine
RUN apk add --no-cache curl
COPY deployment/nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/dist/mf-auth/browser /usr/share/nginx/html
RUN chown -R nginx:nginx /usr/share/nginx/html
EXPOSE 80
HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
  CMD curl -f http://127.0.0.1/ || exit 1
CMD ["nginx", "-g", "daemon off;"]
```

Características:
- **Multi-stage build**: etapa `build` con Node 22 (Alpine) instala dependencias con `npm ci` (instalación reproducible desde `package-lock.json`) y compila con `ng build --configuration=api` (fuerza el uso de `ms_iam`/`ms_org` reales, no mocks, en la imagen productiva).
- **Etapa `runtime`**: Nginx 1.27 (Alpine), copia únicamente el resultado compilado (`dist/mf-auth/browser`), sin Node ni código fuente — imagen final ligera.
- **`chown -R nginx:nginx`**: ajusta permisos del contenido estático al usuario `nginx` del contenedor (buena práctica de menor privilegio).
- **`HEALTHCHECK`**: verifica cada 30s que Nginx responde en `http://127.0.0.1/`, con periodo de gracia de 20s y 3 reintentos — apto para orquestadores tipo Docker Compose/Swarm/Kubernetes que consulten el estado de salud del contenedor.
- Expone el puerto **80** interno (el mapeo a 4201 se hace en tiempo de ejecución, ver sección 5).

Construcción documentada en el propio archivo:
```bash
docker build -f deployment/Dockerfile -t mspi/mf-auth:dev .
docker run --rm -p 4201:80 mspi/mf-auth:dev
```

## 4. Dockerfile genérico compartido del monorepo frontend

`MSPI_NVA_CO_MR_FRONT/deployment/docker/Dockerfile.angular` es una plantilla parametrizable (mediante `ARG`) pensada para reutilizarse entre todos los microfrontends del ecosistema (`mf_shell`, `mf_auth`, `mf_org`, etc.):

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

El propio comentario del archivo aclara la relación con el `Dockerfile` propio de cada MF:
> *"O usar `deployment/Dockerfile` en cada MF (wrapper con ARGs fijos)."*

Es decir, `mf_auth` **no usa directamente** esta plantilla genérica en su script `build:docker`; usa su propio `deployment/Dockerfile`, que es funcionalmente equivalente pero con los valores de `DIST_FOLDER=mf-auth` y `BUILD_CONFIGURATION=api` ya fijados (sin necesidad de pasar `--build-arg`). Ambos Dockerfiles comparten la misma estructura de dos etapas (Node 22-alpine → Nginx 1.27-alpine) y el mismo mecanismo de `HEALTHCHECK`.

## 5. Configuración de Nginx

`deployment/nginx.conf` (propio de `mf_auth`, copiado dentro de la imagen como `/etc/nginx/conf.d/default.conf`):

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

Puntos clave:
- **`try_files $uri $uri/ /index.html`**: enrutamiento SPA estándar, requerido porque Angular Router maneja las rutas client-side (`/login`, `/users/:id`, etc.) que no existen como archivos físicos.
- **Cacheo de 7 días** con `Cache-Control: public, immutable` para assets con hash en el nombre (JS/CSS con `outputHashing: all`), imágenes y fuentes — reduce peticiones repetidas en recargas.
- **`Content-Security-Policy: frame-ancestors`**: autoriza explícitamente que `mf_auth` sea embebido en un `<iframe>` únicamente desde `http://localhost:4200` y `http://127.0.0.1:4200` (el shell) — mecanismo de seguridad complementario a la integración documentada en `03-Diseno.md`, y a la vez la razón técnica por la que el shell puede embeber `/users` como iframe.
- **`error_page 404 /index.html`**: refuerza el fallback SPA también ante rutas no resueltas por `try_files`.

Existe además `MSPI_NVA_CO_MR_FRONT/deployment/nginx/spa.conf`, una configuración genérica equivalente a nivel de monorepo (mismo patrón `try_files`, mismo cacheo, mismo CSP hacia el shell), reforzando que todos los microfrontends Angular del ecosistema comparten el mismo criterio de despliegue.

## 6. Variables de entorno

### 6.1 `.env.example` (raíz de `mf_auth`)

```
# Mocks (login, sesión, cambio de contraseña): true
# APIs reales (ms_iam, localStorage): false o no definir
VITE_USE_MOCKS=true
```

**Advertencia documentada explícitamente (ver también `03-Diseno.md`):** esta variable usa el prefijo `VITE_`, propio de **Vite**, y es leída únicamente por `src/config/env.ts` (`import.meta.env.VITE_USE_MOCKS`), archivo que **no se importa desde ningún módulo del árbol `src/app`** (el árbol realmente compilado por Angular CLI). En consecuencia, **crear un archivo `.env` a partir de este ejemplo no tiene ningún efecto sobre el comportamiento real de `mf_auth`**. El mecanismo real de conmutación mock/API es el **build configuration** de Angular (`ng serve`/`ng build --configuration=api`), descrito en las secciones 1 y 2. Se recomienda a futuros desarrolladores no asumir que editar `.env` cambia el comportamiento de la aplicación.

### 6.2 Variables reales (Angular `environment.*.ts`)

| Variable | `environment.ts` (dev/mock, por defecto) | `environment.api.ts` (`--configuration=api`) |
|---|---|---|
| `useMocks` | `true` | `false` |
| `msIamUrl` | `http://localhost:8082` | `http://localhost:8082` |
| `msOrgUrl` | `http://localhost:8083` | `http://localhost:8083` |
| `apiBaseUrl` | `http://localhost:8082` | `http://localhost:8082` |

Estas no son variables de entorno del sistema operativo ni de un `.env`; son **constantes TypeScript compiladas en el bundle** en tiempo de build, seleccionadas por sustitución de archivo (`fileReplacements`). Cualquier cambio de URL de backend requiere editar estos archivos y **recompilar** la aplicación — no hay soporte para configuración en tiempo de ejecución (runtime config) ni inyección vía contenedor.

## 7. Puesta en marcha — local vs. contenedor

### 7.1 Local (desarrollo)

```bash
npm install                 # instala dependencias (Angular 19, rxjs, qrcode, etc.)
npm start                   # ng serve, puerto 4201, modo mock (sin backend)
# o, con backend real disponible en 8082/8083:
npm run start:api
```

Requisitos: Node.js compatible con Angular 19 (Angular 19 requiere Node ^18.19 o ^20.11 o superior según los requisitos oficiales del framework; el `Dockerfile` usa Node 22). No se documenta en el repositorio una versión mínima de Node exigida explícitamente en `package.json` (no hay campo `engines`).

Para ejercitar el flujo completo localmente sin backend: usar cualquiera de los usuarios mock listados en `05-Pruebas.md` con contraseña `password123`.

### 7.2 Contenedor (build productivo)

```bash
npm run build:docker
# equivalente a:
docker build -f deployment/Dockerfile -t mspi/mf-auth:dev .
docker run --rm -p 4201:80 mspi/mf-auth:dev
```

En este modo:
- El build se ejecuta con `--configuration=api` (backend real requerido: `ms_iam` en 8082, `ms_org` en 8083, alcanzables desde el navegador del cliente final, no desde el contenedor — las URLs son `http://localhost:...`, es decir, se asume despliegue local/desarrollo donde el navegador y los backends comparten host).
- El contenedor sirve contenido **100% estático** vía Nginx; no hay proceso Node en producción.
- El puerto interno 80 se publica externamente como 4201, replicando el puerto de desarrollo para mantener consistencia con las URLs hardcodeadas de integración con el shell (`localhost:4201/login`, etc.).

### 7.3 Limitación relevante para despliegues distintos a local

Dado que `apiBaseUrl`, `msOrgUrl` y las URLs del shell (`http://localhost:4200`) están **hardcodeadas en el código fuente compilado**, desplegar `mf_auth` en un dominio o entorno distinto a `localhost` (por ejemplo, un ambiente de staging o producción con dominios reales) **requiere modificar `environment.api.ts` y los literales de URL del shell dispersos en `AuthSessionService`, `SessionExpiryService` y las páginas de login/2FA/cambio de contraseña, y recompilar** — no existe mecanismo de configuración externa (variables de entorno de contenedor, `config.json` servido en runtime, etc.) para estos valores.
