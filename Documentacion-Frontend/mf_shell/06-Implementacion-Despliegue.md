# mf_shell — Implementación y Despliegue

**Repositorio:** `MSPI_NVA_CO_MR_FRONT/mf_shell`
**Fecha del documento:** 2026-08-18
**Fuente:** `package.json`, `angular.json`, `deployment/Dockerfile`, `deployment/nginx.conf`, `.env.example`, `.dockerignore`, `docs/README.md`, y equivalentes genéricos en `MSPI_NVA_CO_MR_FRONT/deployment/`.

---

## 1. Build de desarrollo

```bash
cd mf_shell
npm install
npm start          # ng serve — puerto 4200, proxyConfig proxy.conf.json
```

`angular.json` define el target `serve` con `defaultConfiguration: development` (`optimization: false`, `sourceMap: true`) y puerto **4200** fijo. Usa `proxy.conf.json` para reenviar, en desarrollo, las rutas `/__mf_auth` → `http://localhost:4201` y `/__mf_org` → `http://localhost:4202` (mecanismo de proxy parcial, no usado por el modelo de producción real basado en iframe directo — ver `03-Diseno.md`).

## 2. Build de producción

```bash
npm run build       # ng build — configuración "production" por defecto
```

- `defaultConfiguration: production` en `angular.json`, con `outputHashing: all`.
- Salida en `dist/shell/browser` (estructura de Angular CLI 17+, que separa el *browser bundle* del *server bundle* aunque este proyecto no usa SSR).
- No hay *build* condicional por variables de entorno de mocks (a diferencia de lo que sugiere `.env.example`, ver sección 6).

## 3. Build de imagen Docker

```bash
npm run build:docker
# equivalente a:
docker build -f deployment/Dockerfile -t mspi/mf-shell:dev .
```

### 3.1 `deployment/Dockerfile` (propio de mf_shell)

Build multi-stage:

1. **Etapa `build`**: `node:22-alpine`, `npm ci`, copia todo el contexto, ejecuta `npm run build -- --configuration=production`.
2. **Etapa `runtime`**: `nginx:1.27-alpine`, instala `curl` (para el healthcheck), copia `deployment/nginx.conf` como configuración por defecto de Nginx, copia el resultado del build (`dist/shell/browser`) a `/usr/share/nginx/html`, ajusta propietario (`chown nginx:nginx`).
3. Expone el puerto **80** internamente (mapeable a 4200 en el host, según el comentario del propio archivo: `docker run --rm -p 4200:80 mspi/mf-shell:dev`).
4. Define `HEALTHCHECK` cada 30s (timeout 5s, 3 reintentos, 20s de arranque) contra `http://127.0.0.1/`.

### 3.2 `deployment/nginx.conf` (propio de mf_shell)

```nginx
server {
    listen 80;
    root /usr/share/nginx/html;
    index index.html;
    gzip on;
    location / { try_files $uri $uri/ /index.html; }         # SPA fallback
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff2?)$ { # cache de assets
        expires 7d;
        add_header Cache-Control "public, immutable";
    }
    error_page 404 /index.html;
}
```

Configuración estándar de SPA: toda ruta no encontrada como archivo físico cae a `index.html` (necesario para que el `Router` de Angular resuelva rutas como `/evaluations` al recargar directamente esa URL). Compresión gzip habilitada para texto/JS/CSS/JSON/XML. Cache agresivo (7 días, `immutable`) para assets con hash en el nombre.

**Diferencia relevante frente a la plantilla genérica del repositorio raíz** (`deployment/nginx/spa.conf`, sección 5): la plantilla genérica añade un header `Content-Security-Policy: frame-ancestors 'self' http://localhost:4200 http://127.0.0.1:4200`, pensado para los microfrontends **hijos** que deben permitir ser embebidos en un iframe del shell. El `nginx.conf` propio de `mf_shell` **no incluye este header** — es coherente, ya que el shell es quien embebe, no quien es embebido, y por tanto no necesita autorizar `frame-ancestors` de sí mismo.

## 4. Plantilla de despliegue compartida a nivel de repositorio frontend

`MSPI_NVA_CO_MR_FRONT/deployment/docker/Dockerfile.angular` es un Dockerfile genérico parametrizable por `ARG` (`NODE_VERSION`, `BUILD_CONFIGURATION`, `DIST_FOLDER`, `MF_NAME`), pensado para construir cualquiera de los microfrontends Angular del ecosistema (incluido `mf_shell`) desde un único archivo reutilizable:

```bash
docker build -f ../deployment/docker/Dockerfile.angular \
  --build-arg MF_NAME=mf_shell \
  --build-arg DIST_FOLDER=shell \
  --build-arg BUILD_CONFIGURATION=production \
  -t mspi/mf-shell:dev .
```

El comentario en la cabecera del propio archivo aclara que puede usarse esta plantilla genérica **o** el `deployment/Dockerfile` propio de cada MF ("wrapper con ARGs fijos"). `mf_shell` incluye ambos: su Dockerfile propio (con valores fijos, usado por `npm run build:docker`) y la posibilidad de usar la plantilla genérica del repositorio raíz.

`MSPI_NVA_CO_MR_FRONT/deployment/nginx/spa.conf` es el equivalente genérico de `nginx.conf`, con la diferencia del header CSP `frame-ancestors` mencionada arriba.

## 5. Orquestación de despliegue de los microfrontends (evidencia disponible)

Dentro de `MSPI_NVA_CO_MR_FRONT` no se encontró un `docker-compose.yml` propio del repositorio frontend que orqueste los 6 microfrontends juntos. `docs/README.md` (raíz del repositorio frontend) y `mf_shell/docs/README.md` remiten reiteradamente a una carpeta externa al árbol analizado: `docker-config/` (ubicada, según las rutas relativas usadas en la documentación, fuera de `MSPI_NVA_CO_MR_FRONT`, probablemente como repositorio hermano), que centraliza:

- `docker-config/docs/README.md` — índice central de documentación de infraestructura.
- `docker-config/docs/frontend/FLUJO-USO-API.md` — flujo end-to-end con API real.
- `docker-config/docs/local/USUARIO-PRINCIPAL.md` — credenciales de desarrollo.

Esa carpeta **no forma parte del alcance analizado** (no está dentro de `MSPI_NVA_CO_MR_FRONT/mf_shell` ni se proporcionó su contenido), por lo que no se puede confirmar con evidencia directa la existencia de un `docker-compose` real ni su contenido; se documenta la referencia tal como aparece en las fuentes primarias, sin inventar su contenido.

**Orden de arranque manual recomendado** (`docs/INTEGRAR-NUEVOS-MF.md`, `docs/README.md`, `docs/FLUJOS.md`, consistente entre sí en este punto):

1. Levantar los microservicios backend (`ms_iam` 8082, `ms_org` 8083, `ms_assessment` 8084, `ms_evidence` 8086, `ms_reporting` 8087).
2. Levantar los 5 microfrontends hijos en sus puertos fijos (4201 mf_auth, 4202 mf_org, 4203 mf_assessment, 4204 mf_evidence, 4205 mf_reports).
3. Levantar `mf_shell` en el puerto 4200.
4. Acceder siempre por `http://localhost:4200` para que la sesión se propague correctamente a los iframes.

## 6. Variables de entorno

### 6.1 `.env.example` (raíz del repositorio `mf_shell`)

```
VITE_USE_MOCKS=true
```

**Inconsistencia detectada:** el prefijo `VITE_` es específico del *bundler* Vite; Angular CLI (usado realmente por este proyecto) no lee variables `VITE_*` ni archivos `.env` de forma nativa — las variables de entorno de Angular se gestionan mediante los archivos `src/environments/environment*.ts` y *file replacements* en `angular.json`, mecanismo no configurado en este proyecto (no existe `environment.prod.ts` ni sección `fileReplacements`). Este `.env.example` es, con alta probabilidad, otro residuo del prototipo Vite/React mencionado en `01-Planificacion.md` y `03-Diseno.md`, y **no tiene efecto en el build Angular real**. El propio `.gitignore` del proyecto lo confirma con un comentario explícito: *"# Legacy bundler (Vite / migración React)"* sobre la sección que ignora `.vite/` y `*.local`, evidenciando una migración histórica de Vite/React hacia Angular que dejó artefactos sin depurar.

### 6.2 `src/environments/environment.ts` (fuente real de configuración)

```ts
export const environment = {
  msIamUrl: 'http://localhost:8082',
  msOrgUrl: 'http://localhost:8083',
  msAssessmentUrl: 'http://localhost:8084',
  msEvidenceUrl: 'http://localhost:8086',
  msReportingUrl: 'http://localhost:8087',
};
```

Es el **único** archivo de entorno del proyecto (no existe `environment.prod.ts`); las URLs de los microservicios backend están fijas a `localhost` incluso en el build de producción, ya que `angular.json` no declara `fileReplacements` para la configuración `production`. Esto implica que, tal como está el repositorio, **el build de producción apunta a los mismos hosts que el de desarrollo**, una limitación relevante para cualquier despliegue fuera de la máquina de desarrollo local (documentada también en `07-Mantenimiento.md`).

## 7. Resumen de puertos y despliegue

| Elemento | Valor |
|---|---|
| Puerto dev (`ng serve`) | 4200 |
| Puerto contenedor (Nginx interno) | 80 |
| Mapeo sugerido en `docker run` | `4200:80` |
| Imagen base build | `node:22-alpine` |
| Imagen base runtime | `nginx:1.27-alpine` |
| Carpeta de salida del build | `dist/shell/browser` |
| Healthcheck | `curl -f http://127.0.0.1/` cada 30s |
