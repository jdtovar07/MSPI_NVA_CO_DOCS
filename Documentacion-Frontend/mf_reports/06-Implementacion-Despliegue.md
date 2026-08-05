# mf_reports — Implementación y Despliegue

**Repositorio:** `MSPI_NVA_CO_MR_FRONT/mf_reports`
**Fecha del documento:** 2026-08-18
**Alcance:** Proceso de *build*, contenerización, configuración de Nginx, variables de entorno y puesta en marcha real del microfrontend, verificados en `package.json`, `angular.json`, `deployment/Dockerfile` y `deployment/nginx.conf`.

---

## 1. Scripts disponibles (`package.json`)

| Script | Comando | Uso |
|---|---|---|
| `start` | `ng serve` | Ejecuta en modo desarrollo (configuración `development` por defecto → `useMocks: true`), puerto 4205 |
| `start:api` | `ng serve --configuration=api` | Ejecuta contra `ms_reporting`/`ms_assessment` reales (`environment.api.ts`) |
| `build` | `ng build` | Compila con la configuración por defecto declarada en `angular.json` (`production`) |
| `build:docker` | `docker build -f deployment/Dockerfile -t mspi/mf-reports:dev .` | Construye la imagen Docker |
| `clean` | Script Node inline que elimina `.angular` | Limpia caché de build de Angular CLI |

No existe script `lint` ni `test` — consistente con la ausencia de ESLint y de infraestructura de pruebas documentada en `05-Pruebas.md`.

## 2. Configuraciones de build (`angular.json`)

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

- **`production`** (configuración por defecto de `build`, `defaultConfiguration: "production"`): aplica *hashing* a todos los artefactos de salida (`outputHashing: "all"`) para invalidación de caché de navegador; no reemplaza el archivo de entorno, por lo que **una compilación `ng build` simple sigue usando `environment.ts` (`useMocks: true`)** salvo que se combine explícitamente con `--configuration=api`.
- **`development`** (configuración por defecto de `serve`): sin optimización, con *source maps*, para depuración local.
- **`api`**: reemplaza el archivo de entorno vía `fileReplacements`, apuntando a `environment.api.ts` (`useMocks: false`, con `shellOrigin` definido). Es la configuración usada tanto por `npm run start:api` como por el `Dockerfile` (`RUN npm run build -- --configuration=api`).

**Hallazgo relevante:** no existe una configuración `production` que a la vez desactive los mocks (`fileReplacements`) y aplique `outputHashing`. El `Dockerfile` resuelve esto usando `--configuration=api`, que sí desactiva mocks pero **no** aplica `outputHashing: "all"` (esa opción solo está definida bajo la configuración `production`, y Angular CLI no combina automáticamente configuraciones nombradas distintas salvo que se encadenen explícitamente, p. ej. `--configuration=production,api`, lo cual no se usa en este repositorio). En consecuencia, **la imagen Docker de este microfrontend se construye sin hashing de salida en sus artefactos JS/CSS**, a diferencia de lo que produciría `ng build` con la configuración `production` por defecto.

- **`outputPath`**: `dist/mf-reports` (el navegador compilado queda en `dist/mf-reports/browser`, estructura estándar del builder `application` de Angular 17+).

## 3. Contenerización (`deployment/Dockerfile`)

```dockerfile
# Build: docker build -f deployment/Dockerfile -t mspi/mf-reports:dev .
# Run:   docker run --rm -p 4205:80 mspi/mf-reports:dev

FROM node:22-alpine AS build
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci
COPY . .
RUN npm run build -- --configuration=api

FROM nginx:1.27-alpine
RUN apk add --no-cache curl
COPY deployment/nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/dist/mf-reports/browser /usr/share/nginx/html
RUN chown -R nginx:nginx /usr/share/nginx/html
EXPOSE 80
HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
  CMD curl -f http://127.0.0.1/ || exit 1
CMD ["nginx", "-g", "daemon off;"]
```

Es un **build multi-etapa** estándar:

1. **Etapa `build`**: imagen `node:22-alpine`, instala dependencias con `npm ci` (instalación reproducible desde `package-lock.json`), copia el código y compila con la configuración `api` (backend real, no mocks).
2. **Etapa final**: imagen `nginx:1.27-alpine`, con `curl` instalado explícitamente (necesario porque las imágenes Alpine no lo incluyen por defecto) para que el `HEALTHCHECK` funcione. Copia únicamente el resultado compilado (`dist/mf-reports/browser`) y la configuración de Nginx propia del microfrontend. Ajusta el propietario de los archivos estáticos al usuario `nginx`.
3. Expone el puerto **80** dentro del contenedor — el mapeo a **4205** en el host se hace en tiempo de ejecución (`-p 4205:80`, documentado en el comentario del propio Dockerfile).
4. El `HEALTHCHECK` consulta cada 30 segundos la raíz (`/`) con un tiempo de espera de 5 segundos, un período de gracia inicial de 20 segundos y 3 reintentos antes de marcar el contenedor como no saludable.

Este Dockerfile es funcionalmente equivalente al patrón genérico compartido `MSPI_NVA_CO_MR_FRONT/deployment/docker/Dockerfile.angular` (parametrizable por `ARG MF_NAME`/`DIST_FOLDER`/`BUILD_CONFIGURATION`), pero está fijado ("wrapper con ARGs fijos", según el propio comentario de la plantilla genérica) con los valores concretos de `mf_reports` (`DIST_FOLDER=mf-reports`, configuración `api`).

## 4. Configuración de Nginx (`deployment/nginx.conf`)

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

- **`try_files $uri $uri/ /index.html`**: soporte de *fallback* a `index.html` requerido por el enrutamiento del lado del cliente de Angular Router (rutas como `/assessments/mock-assessment-1/dashboard` no existen como archivo físico).
- **Compresión gzip** habilitada para los tipos de contenido de texto habituales de una SPA.
- **Caché agresiva** (7 días, `immutable`) para activos estáticos con extensión reconocida — coherente con el uso de `outputHashing` en builds `production` (aunque, como se señaló en la sección 2, la imagen Docker actual no aplica ese hashing por usar la configuración `api`, no `production`).
- **`Content-Security-Policy: frame-ancestors`**: restringe explícitamente qué orígenes pueden embeber este microfrontend en un `<iframe>`, a `'self'` y a los dos orígenes de desarrollo del shell (`localhost:4200`, `127.0.0.1:4200`). **No incluye ningún origen de un entorno de staging o producción** — es un hallazgo relevante: si el ecosistema MSPI se despliega en un dominio distinto a `localhost`, esta cabecera bloqueará el *embedding* del microfrontend en el shell real, salvo que se reemplace `nginx.conf` en el pipeline de despliegue de ese entorno.
- Es prácticamente idéntica a la plantilla compartida `MSPI_NVA_CO_MR_FRONT/deployment/nginx/spa.conf`, con la única diferencia de un comentario adicional en la plantilla genérica.

## 5. Variables de entorno y configuración

`mf_reports` **no usa variables de entorno en tiempo de ejecución** (no hay lectura de `process.env` ni de un archivo `.env` inyectado en el contenedor): toda la configuración de entorno (`useMocks`, URLs de backend, `shellOrigin`) se resuelve **en tiempo de compilación** mediante los dos archivos TypeScript de `src/environments/` y el mecanismo `fileReplacements` de Angular CLI.

| Variable (a nivel de archivo de entorno) | `environment.ts` (mock/development) | `environment.api.ts` (api) |
|---|---|---|
| `useMocks` | `true` | `false` |
| `msReportingUrl` | `http://localhost:8087` | `http://localhost:8087` |
| `msAssessmentUrl` | `http://localhost:8084` | `http://localhost:8084` |
| `apiBaseUrl` | `http://localhost:8087` | `http://localhost:8087` |
| `shellOrigin` | *(no definido)* | `http://localhost:4200` |

Todas las URLs están **fijadas a `localhost`** en ambos archivos, lo que confirma que el proyecto, en su estado actual, está pensado para ejecutarse en un entorno local de desarrollo/demo (probablemente `docker-config` orquestando todos los microfrontends y backends en la misma máquina) y no contempla, sin modificación manual del código fuente, un despliegue en un dominio o red distintos.

## 6. Puesta en marcha — desarrollo local

```bash
# Instalar dependencias
npm ci

# Modo mock (sin backend)
npm start                    # ng serve, puerto 4205, useMocks: true

# Modo API real (requiere ms_reporting:8087 y ms_assessment:8084 activos)
npm run start:api            # ng serve --configuration=api
```

Acceso directo: `http://localhost:4205/reports`. Para probar la integración completa con el shell, se requiere `mf_shell` corriendo en el puerto 4200 y navegar desde allí (ver `docs/INTEGRACION-SHELL.md`: la ruta `/reports` del shell embebe `4205/assessments/{id}/dashboard`).

## 7. Puesta en marcha — contenedor

```bash
# Build
npm run build:docker
# equivalente a: docker build -f deployment/Dockerfile -t mspi/mf-reports:dev .

# Run
docker run --rm -p 4205:80 mspi/mf-reports:dev
```

El contenedor queda accesible en `http://localhost:4205`. Al estar compilado con la configuración `api` de forma fija dentro del `Dockerfile`, el contenedor **siempre** se construye contra `ms_reporting`/`ms_assessment` reales (`useMocks: false`) — no existe una variante Docker que sirva el modo mock.

## 8. Orquestación con el resto del ecosistema

Aunque no se encontró un `docker-compose.yml` dentro del propio repositorio `mf_reports`, la documentación de nivel superior (`MSPI_NVA_CO_MR_FRONT/docs/README.md`) referencia una configuración central en `docker-config/` (fuera del alcance de este repositorio) que orquesta el `mf_shell` y todos los microfrontends, incluyendo `mf_reports`, junto con los backends `ms_assessment` y `ms_reporting`. Esa orquestación central no fue explorada en detalle por quedar fuera de la carpeta `MSPI_NVA_CO_MR_FRONT/mf_reports` objeto de esta documentación.

## 9. Resumen de hallazgos de esta fase

| Hallazgo | Detalle |
|---|---|
| Imagen Docker sin `outputHashing` | El build de la imagen usa `--configuration=api`, que no incluye `outputHashing: "all"` (solo presente en `production`) |
| CSP sin orígenes de staging/producción | `nginx.conf` solo permite `frame-ancestors` de `localhost:4200`/`127.0.0.1:4200` |
| URLs de backend fijas a `localhost` en ambos entornos | No hay mecanismo de variables de entorno en tiempo de ejecución para reconfigurar sin recompilar |
| Sin variante Docker en modo mock | El `Dockerfile` fija `--configuration=api`; una demo sin backend requiere `ng serve` local, no el contenedor |
| Sin pipeline CI/CD visible | No hay `.github/workflows` ni configuración de integración continua en el repositorio |
