# mf_org — Implementación y Despliegue

**Repositorio:** `MSPI_NVA_CO_MR_FRONT/mf_org`
**Fecha del documento:** 2026-08-18
**Alcance:** Proceso de build, contenerización, configuración de Nginx, variables de entorno y puesta en marcha local vs. en contenedor del microfrontend `mf_org`.

---

## 1. Scripts de build reales (`package.json`)

```json
"scripts": {
  "ng": "ng",
  "start": "ng serve",
  "start:api": "ng serve --configuration=api",
  "build": "ng build",
  "build:docker": "docker build -f deployment/Dockerfile -t mspi/mf-org:dev ."
}
```

| Comando | Efecto real |
|---|---|
| `npm start` | `ng serve` — arranca en `http://localhost:4202`, configuración `development` (por `defaultConfiguration` de `angular.json`), **modo mock** (`environment.ts` con `useMocks: true`) |
| `npm run start:api` | `ng serve --configuration=api` — mismo puerto, con `fileReplacements` que sustituyen `environment.ts` por `environment.api.ts` (`useMocks: false`), consumiendo `ms_org` real en `localhost:8083` |
| `npm run build` | `ng build` — usa `defaultConfiguration: "production"` del target `build`; genera `dist/mf-org/browser` con `outputHashing: all` |
| `npm run build:docker` | Construye la imagen Docker usando el `Dockerfile` propio del microfrontend |

**Nota de precisión:** a diferencia de `mf_auth` (que define además `start:force` y `clean`), `mf_org` tiene un conjunto de scripts más reducido — no hay script de limpieza de caché ni de arranque forzado.

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

- `outputPath`: `dist/mf-org` (el contenido servible queda en `dist/mf-org/browser`, estructura estándar del builder `@angular-devkit/build-angular:application`).
- `browser`: `src/main.ts` (único punto de entrada real; distinto del `index.html`/`main.tsx` residual de la raíz del repositorio, ver `03-Diseno.md`).
- `polyfills`: `zone.js`.
- `assets`: todo el contenido de `public/` se copia tal cual (`{ "glob": "**/*", "input": "public" }`).
- `styles`: `src/styles.scss` como hoja global.
- Servidor de desarrollo (`serve`): puerto fijo **4202**, `defaultConfiguration: "development"`.

Las configuraciones `production`, `development` y `api` son combinables (`--configuration=production,api`), y esta combinación es efectivamente la que usa el `Dockerfile` propio (ver sección 3).

## 3. Contenerización — `deployment/Dockerfile` (propio de `mf_org`)

```dockerfile
# Build: docker build -f deployment/Dockerfile -t mspi/mf-org:dev .
# Run:   docker run --rm -p 4202:80 mspi/mf-org:dev

FROM node:22-alpine AS build
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci
COPY . .
RUN npm run build -- --configuration=api

FROM nginx:1.27-alpine
RUN apk add --no-cache curl
COPY deployment/nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/dist/mf-org/browser /usr/share/nginx/html
RUN chown -R nginx:nginx /usr/share/nginx/html
EXPOSE 80
HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
  CMD curl -f http://127.0.0.1/ || exit 1
CMD ["nginx", "-g", "daemon off;"]
```

Características, idénticas en estructura a `mf_auth`:
- **Multi-stage build**: etapa `build` con Node 22 (Alpine), `npm ci` (instalación reproducible desde `package-lock.json`), y `ng build --configuration=api` (fuerza el consumo de `ms_org` real, no mocks, en la imagen productiva).
- **Etapa `runtime`**: Nginx 1.27 (Alpine), copia únicamente `dist/mf-org/browser`, sin Node ni código fuente.
- **`chown -R nginx:nginx`**: ajusta permisos del contenido estático al usuario `nginx` del contenedor.
- **`HEALTHCHECK`**: verifica cada 30s que Nginx responde en `http://127.0.0.1/`, con periodo de gracia de 20s y 3 reintentos.
- Expone el puerto **80** interno (el mapeo a 4202 se hace en tiempo de ejecución).

Construcción documentada en el propio archivo (comentario inicial del `Dockerfile`):
```bash
docker build -f deployment/Dockerfile -t mspi/mf-org:dev .
docker run --rm -p 4202:80 mspi/mf-org:dev
```

## 4. Dockerfile genérico compartido del monorepo frontend

`MSPI_NVA_CO_MR_FRONT/deployment/docker/Dockerfile.angular` es la misma plantilla parametrizable (mediante `ARG`) usada como base conceptual para todos los microfrontends del ecosistema:

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

El propio comentario del archivo aclara la relación con el `Dockerfile` propio de cada MF: *"O usar `deployment/Dockerfile` en cada MF (wrapper con ARGs fijos)."* `mf_org` **no usa directamente** esta plantilla genérica en su script `build:docker`; usa su propio `deployment/Dockerfile`, funcionalmente equivalente pero con `DIST_FOLDER=mf-org` y `BUILD_CONFIGURATION=api` ya fijados. Ambos Dockerfiles comparten la misma estructura de dos etapas y el mismo mecanismo de `HEALTHCHECK`.

## 5. Configuración de Nginx

`deployment/nginx.conf` (propio de `mf_org`, copiado dentro de la imagen como `/etc/nginx/conf.d/default.conf`):

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

Puntos clave, idénticos en criterio al resto del ecosistema (ver `deployment/nginx/spa.conf` a nivel de monorepo):
- **`try_files $uri $uri/ /index.html`**: enrutamiento SPA estándar, requerido porque Angular Router maneja rutas client-side (`/organizations`, `/organizations/:id`, `/my-organization`) que no existen como archivos físicos.
- **Cacheo de 7 días** con `Cache-Control: public, immutable` para assets con hash en el nombre (`outputHashing: all`), imágenes y fuentes.
- **`Content-Security-Policy: frame-ancestors`**: autoriza explícitamente que `mf_org` sea embebido en un `<iframe>` únicamente desde `http://localhost:4200` y `http://127.0.0.1:4200` (el shell) — mecanismo de seguridad complementario a la integración por `iframe` documentada en `03-Diseno.md`.
- **`error_page 404 /index.html`**: refuerza el fallback SPA también ante rutas no resueltas por `try_files`.

## 6. Variables de entorno

### 6.1 Ausencia de `.env`/`.env.example` en la raíz

A diferencia de `mf_auth` (que conserva un `.env.example` con `VITE_USE_MOCKS`), en `mf_org` **no existe** ningún archivo `.env` ni `.env.example` en la raíz del repositorio. Sin embargo, persiste `src/config/env.ts`, que replica el mismo patrón de lectura `import.meta.env.VITE_USE_MOCKS ?? import.meta.env.VITE_USE_MOCK` (sintaxis Vite) — código muerto sin archivo de ejemplo asociado, y sin ningún efecto real porque no se importa desde `src/app` (ver `03-Diseno.md`).

### 6.2 Variables reales (Angular `environment.*.ts`)

| Variable | `environment.ts` (dev/mock, por defecto) | `environment.api.ts` (`--configuration=api`) |
|---|---|---|
| `useMocks` | `true` | `false` |
| `msOrgUrl` | `http://localhost:8083` | `http://localhost:8083` |
| `msIamUrl` | `http://localhost:8082` | `http://localhost:8082` |
| `apiBaseUrl` | `http://localhost:8083` | `http://localhost:8083` |

**Observación:** `mf_org` declara `msIamUrl` en ambos entornos pese a que **ningún archivo bajo `src/app` lo referencia** (verificado por búsqueda de uso) — `mf_org` no llama directamente a `ms_iam`; el campo parece copiado por consistencia con la plantilla de entorno compartida entre microfrontends (la misma forma que usa `mf_auth`), sin uso funcional propio. `apiBaseUrl` (el único efectivamente usado por `ApiOrganizationRepository` y `ApiLocationRepository`) coincide con `msOrgUrl` en ambos entornos.

Estas no son variables de entorno del sistema operativo ni de un `.env`; son **constantes TypeScript compiladas en el bundle** en tiempo de build, seleccionadas por sustitución de archivo (`fileReplacements`). Cualquier cambio de URL de backend requiere editar estos archivos y **recompilar** — no hay soporte para configuración en tiempo de ejecución.

## 7. Puesta en marcha — local vs. contenedor

### 7.1 Local (desarrollo)

```bash
npm install                 # instala dependencias (Angular 19, rxjs, etc.)
npm start                   # ng serve, puerto 4202, modo mock (sin backend)
# o, con backend real disponible en 8083:
npm run start:api
```

Requisitos: Node.js compatible con Angular 19 (Node ^18.19 o ^20.11 o superior según los requisitos oficiales del framework; el `Dockerfile` usa Node 22). No se documenta en el repositorio una versión mínima de Node exigida explícitamente en `package.json` (no hay campo `engines`).

Para ejercitar el flujo completo localmente sin backend: usar el modo mock por defecto, que expone las dos organizaciones de prueba listadas en `05-Pruebas.md` y el catálogo geográfico estático de `src/data/locations.ts`. Para probar la vista "Mi organización" y la redirección del rol `Lector`, es necesario simular manualmente una sesión con `roles: ['Lector']` en `localStorage`/cookie `auth_session` (normalmente generada por `mf_auth`), ya que `mf_org` no emite sesión propia.

### 7.2 Contenedor (build productivo)

```bash
npm run build:docker
# equivalente a:
docker build -f deployment/Dockerfile -t mspi/mf-org:dev .
docker run --rm -p 4202:80 mspi/mf-org:dev
```

En este modo:
- El build se ejecuta con `--configuration=api` (backend real requerido: `ms_org` en 8083, alcanzable desde el navegador del cliente final, no desde el contenedor — las URLs son `http://localhost:...`, es decir, se asume despliegue local/desarrollo donde el navegador y los backends comparten host).
- El contenedor sirve contenido **100% estático** vía Nginx; no hay proceso Node en producción.
- El puerto interno 80 se publica externamente como 4202, replicando el puerto de desarrollo para mantener consistencia con las URLs de integración con el shell.

### 7.3 Limitación relevante para despliegues distintos a local

Dado que `apiBaseUrl` y la política `frame-ancestors` hacia el shell (`http://localhost:4200`) están **hardcodeadas en el código fuente compilado**, desplegar `mf_org` en un dominio o entorno distinto a `localhost` requiere modificar `environment.api.ts` y `deployment/nginx.conf`, y **recompilar/reconstruir la imagen** — no existe mecanismo de configuración externa (variables de entorno de contenedor, `config.json` servido en runtime) para estos valores, la misma limitación documentada para `mf_auth`.
