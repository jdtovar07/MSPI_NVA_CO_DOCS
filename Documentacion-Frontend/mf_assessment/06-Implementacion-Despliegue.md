# mf_assessment — Implementación y Despliegue

**Repositorio:** `MSPI_NVA_CO_MR_FRONT/mf_assessment`
**Fecha del documento:** 2026-08-18
**Alcance:** Proceso de build, contenerización, configuración de Nginx, variables de entorno y puesta en marcha local vs. en contenedor del microfrontend `mf_assessment`.

---

## 1. Scripts de build reales (`package.json`)

```json
"scripts": {
  "ng": "ng",
  "start": "ng serve",
  "start:api": "ng serve --configuration=api",
  "start:force": "ng serve --force",
  "build": "ng build",
  "build:docker": "docker build -f deployment/Dockerfile -t mspi/mf-assessment:dev .",
  "clean": "node -e \"const fs=require('fs'); ['.angular','node_modules/.vite'].forEach(p=>{try{fs.rmSync(p,{recursive:true});console.log('Eliminado:',p)}catch(e){}})\""
}
```

| Comando | Efecto real |
|---|---|
| `npm start` | `ng serve` — arranca en `http://localhost:4203`, configuración `development` (por `defaultConfiguration` de `angular.json`), **modo mock** (`environment.ts` con `useMocks: true`) |
| `npm run start:api` | `ng serve --configuration=api` — mismo puerto, con `fileReplacements` que sustituyen `environment.ts` por `environment.api.ts` (`useMocks: false`), consumiendo `ms_assessment`/`ms_catalog` reales en `localhost:8084`/`8085` |
| `npm run start:force` | Igual a `start` forzando reinstalación/optimización de dependencias de Angular CLI (`--force`) |
| `npm run build` | `ng build` — usa `defaultConfiguration: "production"` del target `build`; genera `dist/mf-assessment/browser` con `outputHashing: all` |
| `npm run build:docker` | Construye la imagen Docker usando el `Dockerfile` propio del microfrontend |
| `npm run clean` | Elimina `.angular` (caché de build de Angular CLI) y `node_modules/.vite` (residual, aunque en este proyecto no se detectó código fuente de Vite/React, a diferencia de `mf_auth`) |

**Nota de precisión importante:** el `Dockerfile` propio construye con `npm run build -- --configuration=api` (ver sección 3), es decir, **la imagen Docker no usa el modo mock**, sino que apunta a `ms_assessment`/`ms_catalog` reales. En cambio, `npm run build` ejecutado en local sin argumentos usa solo `production` (sin combinar con `api`) y por tanto **conserva `useMocks: true`** salvo que se indique explícitamente `ng build --configuration=production,api`. Este es el mismo comportamiento verificado en el resto de microfrontends del ecosistema MSPI (p. ej. `mf_auth`).

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

- `outputPath`: `dist/mf-assessment` (el contenido servible queda en `dist/mf-assessment/browser`, estructura estándar del builder `@angular-devkit/build-angular:application`).
- `browser`: `src/main.ts` (único punto de entrada).
- `polyfills`: `zone.js`.
- `assets`: todo el contenido de `public/` se copia tal cual — la carpeta está **vacía** en este repositorio, por lo que no hay logos ni assets estáticos propios detectados.
- `styles`: `src/styles.scss` como hoja global.
- Servidor de desarrollo (`serve`): puerto fijo **4203**, `defaultConfiguration: "development"`.

Las configuraciones `production`, `development` y `api` son combinables (Angular CLI permite `--configuration=production,api`); en local no hay evidencia de que se use esa combinación en los scripts de `package.json`, pero sí se usa efectivamente en el `Dockerfile` (ver sección 3).

## 3. Contenerización — `deployment/Dockerfile`

```dockerfile
# Build: docker build -f deployment/Dockerfile -t mspi/mf-assessment:dev .
# Run:   docker run --rm -p 4203:80 mspi/mf-assessment:dev

FROM node:22-alpine AS build
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci
COPY . .
RUN npm run build -- --configuration=api

FROM nginx:1.27-alpine
RUN apk add --no-cache curl
COPY deployment/nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/dist/mf-assessment/browser /usr/share/nginx/html
RUN chown -R nginx:nginx /usr/share/nginx/html
EXPOSE 80
HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
  CMD curl -f http://127.0.0.1/ || exit 1
CMD ["nginx", "-g", "daemon off;"]
```

Puntos de diseño verificados:

- **Build en dos etapas (multi-stage)**: la etapa `build` usa `node:22-alpine` con `npm ci` (instalación reproducible desde `package-lock.json`) y compila con la configuración `api`; la etapa final usa `nginx:1.27-alpine`, sin herramientas de Node en la imagen final.
- **`curl` instalado explícitamente** en la imagen Nginx (`apk add --no-cache curl`), usado únicamente por el `HEALTHCHECK`.
- **Permisos de usuario `nginx`** aplicados explícitamente al contenido estático (`chown -R nginx:nginx`).
- **Healthcheck** cada 30 s, timeout de 5 s, periodo de gracia de 20 s y 3 reintentos, contra la raíz (`http://127.0.0.1/`).
- El mapeo de puerto sugerido en el comentario (`-p 4203:80`) mantiene la convención de puerto del ecosistema (4203) aunque internamente Nginx escucha en el puerto 80 estándar del contenedor.

## 4. Configuración de Nginx — `deployment/nginx.conf`

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

Aspectos relevantes:

- **Fallback SPA**: `try_files $uri $uri/ /index.html` en la ruta raíz, necesario porque el enrutamiento es manejado por Angular Router (`app.routes.ts`) del lado del cliente.
- **Compresión gzip** habilitada para texto, CSS, JSON, JavaScript y XML.
- **Caché agresivo de estáticos** (7 días, `immutable`) para extensiones `js|css|png|jpg|jpeg|gif|ico|svg|woff2?`, coherente con el `outputHashing: all` del build de producción (los nombres de archivo cambian en cada build, por lo que el caché largo es seguro).
- **`Content-Security-Policy: frame-ancestors`** restringido a `'self'`, `http://localhost:4200` y `http://127.0.0.1:4200` — es la pieza de configuración que **habilita técnicamente** que `mf_shell` pueda embeber `mf_assessment` en un `<iframe>`; cualquier otro origen padre sería bloqueado por el navegador.
- **`error_page 404 /index.html`** refuerza el comportamiento SPA también para errores 404 explícitos de Nginx.

## 5. Variables de entorno / configuración por ambiente

El proyecto **no usa variables de entorno en tiempo de ejecución** (no hay `.env`, `process.env` en el navegador, ni sustitución de variables en el contenedor Nginx); toda la configuración de URLs de backend está **fijada en tiempo de build** mediante los archivos de `src/environments/`:

**`environment.ts`** (modo mock, usado por defecto en `development` y `production`):

```typescript
export const environment = {
  useMocks: true,
  msAssessmentUrl: 'http://localhost:8084',
  msCatalogUrl: 'http://localhost:8085',
  msOrgUrl: 'http://localhost:8083',
  msEvidenceFrontUrl: 'http://localhost:4204',
  shellOrigin: 'http://localhost:4200',
  apiBaseUrl: 'http://localhost:8084',
};
```

**`environment.api.ts`** (modo API real, activado por `fileReplacements` en la configuración `api`):

```typescript
export const environment = {
  useMocks: false,
  msAssessmentUrl: 'http://localhost:8084',
  msCatalogUrl: 'http://localhost:8085',
  msOrgUrl: 'http://localhost:8083',
  msEvidenceFrontUrl: 'http://localhost:4204',
  shellOrigin: 'http://localhost:4200',
  apiBaseUrl: 'http://localhost:8084',
};
```

**Hallazgo relevante**: ambos archivos apuntan a las **mismas URLs `localhost`** — la única diferencia funcional entre ellos es el flag `useMocks`. Esto significa que, para desplegar `mf_assessment` en un ambiente distinto a `localhost` (staging, producción con dominios reales), es necesario **editar y recompilar** `environment.api.ts` con las URLs reales de `ms_assessment`, `ms_catalog`, `ms_org` y del shell — no existe mecanismo de configuración externa (ni variables de entorno de contenedor, ni archivo de configuración cargado en runtime).

## 6. Puesta en marcha — desarrollo local

```bash
cd mf_assessment
npm install
npm start              # modo mock, puerto 4203
npm run start:api      # contra ms_assessment (8084) y ms_catalog (8085) reales
```

Acceso recomendado por el propio equipo (`docs/README.md`, `docs/INTEGRACION-SHELL.md`): en un entorno con el ecosistema completo levantado, **no abrir `http://localhost:4203` directamente**, sino navegar a través del shell:

```
http://localhost:4200/evaluations
```

Esto es necesario porque solo a través del shell se propaga correctamente la sesión JWT (`postMessage` `MSPI_AUTH_SESSION`) y la evaluación activa compartida entre microfrontends.

## 7. Puesta en marcha — contenedor Docker

```bash
docker build -f deployment/Dockerfile -t mspi/mf-assessment:dev .
docker run --rm -p 4203:80 mspi/mf-assessment:dev
```

Requisitos para que el contenedor funcione correctamente dentro del ecosistema:

- `ms_assessment` accesible en `http://localhost:8084` desde el navegador del usuario final (no desde el contenedor — las llamadas HTTP las hace el navegador, no Nginx, ya que es una SPA servida estáticamente).
- `ms_catalog` accesible en `http://localhost:8085`.
- `mf_shell` sirviendo el iframe desde `http://localhost:4200` (o `127.0.0.1:4200`), únicos orígenes permitidos por la `Content-Security-Policy` del `nginx.conf` propio.

## 8. Infraestructura de despliegue compartida (nivel de repositorio frontend)

El repositorio `MSPI_NVA_CO_MR_FRONT` incluye, fuera de `mf_assessment/`, una carpeta `deployment/` de nivel superior con:

- `deployment/docker/Dockerfile.angular`: plantilla genérica de Dockerfile, presumiblemente parametrizable para cualquiera de los microfrontends del ecosistema.
- `deployment/nginx/spa.conf`: configuración Nginx genérica para SPA.

`mf_assessment` **no usa esta infraestructura compartida**: tiene su propio `Dockerfile` y `nginx.conf` en `mf_assessment/deployment/`, con la particularidad propia de la `Content-Security-Policy` y del `--configuration=api` en el build. No se verificó si el resto del ecosistema (`docker-config/`) orquesta estos contenedores mediante `docker-compose` u otra herramienta, ya que dicho directorio está fuera del repositorio `mf_assessment` analizado.

## 9. Ausencia de CI/CD

No se encontró carpeta `.github/workflows/`, `.gitlab-ci.yml`, `Jenkinsfile`, `azure-pipelines.yml` ni ningún otro artefacto de integración/entrega continua dentro del repositorio `mf_assessment`. El build y despliegue documentados en este capítulo son, hasta donde el código permite verificar, **procesos manuales** (`npm run build:docker` + `docker run`, o el equivalente que orqueste `docker-config/` a nivel de todo el ecosistema, no auditado aquí).
