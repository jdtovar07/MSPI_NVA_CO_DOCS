# 05 · Manual de despliegue (entorno local, Docker)

## 1. Prerrequisitos

- **Docker Desktop** en ejecución (motor Linux).
- **PowerShell** (Windows PowerShell 5.1+). Los scripts de arranque son `.ps1` — ejecutarlos desde una consola PowerShell, no `cmd.exe`.
- Los dos repositorios de código como carpetas hermanas:
  ```
  <carpeta padre>/
    ├── MSPI_NVA_CO_MR_BACK/
    └── MSPI_NVA_CO_MR_FRONT/
  ```

## 2. Primer arranque

```powershell
cd MSPI_NVA_CO_MR_BACK\docker-config
cp docker\env-mspi-docker.env.example docker\env-mspi-docker.env
# Completar LOCATION_API_KEY e INTERNAL_API_KEY en docker\env-mspi-docker.env

.\levantar-todo.ps1 -Rebuild
```

`-Rebuild` construye la imagen de cada microservicio (`gradle build`) y de cada microfrontend (`ng build`) dentro de un contenedor. Internamente:

1. Levanta infraestructura (Postgres + Keycloak, red `mspi-net`).
2. Levanta los 8 microservicios, puertos **8082–8089** (incluye `ms_audit` 8088 y `ms_admin` 8089).
3. Levanta los 6 microfrontends, puertos **4200-4205**.

## 3. Arranques posteriores

```powershell
.\levantar-todo.ps1
```

Reutiliza las imágenes ya construidas.

## 4. Reconstruir un solo servicio

```powershell
cd MSPI_NVA_CO_MR_BACK\docker-config\docker

# Backend
docker compose -f docker-compose.apps.yml --env-file env-mspi-docker.env up -d --build ms-assessment

# Frontend
docker compose -f docker-compose.front.yml up -d --build mf-assessment
```

## 5. Reset completo (reinicializa la base de datos)

```powershell
cd MSPI_NVA_CO_MR_BACK\docker-config
.\levantar-todo.ps1 -Reset
```

El DDL real de la base de datos vive en `docker-config/docker/postgres/init/MER-MSPI.sql` y solo se ejecuta al **crear** el volumen de Postgres — un reset es necesario para aplicar cambios de esquema. Los seeds (`MER-SEED-*.sql`, incluido `MER-SEED-TESTGUIDANCE.sql` con el texto completo de PRUEBA) siguen la misma regla: en un volumen ya existente hay que reaplicarlos a mano o hacer `-Reset`.

## 6. Verificación

```powershell
docker ps
```

Contenedores esperados: `postgres_mspi_local`, `keycloak`, `ms_iam`, `ms_org`, `ms_catalog`, `ms_evidence`, `ms_assessment`, `ms_reporting`, `mf_shell`, `mf_auth`, `mf_org`, `mf_assessment`, `mf_evidence`, `mf_reports`.

Punto de entrada: **http://localhost:4200**

## 7. Detener el stack

```powershell
cd MSPI_NVA_CO_MR_BACK\docker-config
.\detener-todo.ps1
```

## 8. Despliegue del frontend en un dominio real

La misma imagen Docker de cada microfrontend sirve en local y en un dominio productivo: solo cambian variables de entorno.

1. Copiar `MSPI_NVA_CO_MR_BACK/docker-config/docker/.env.example` a `.env` y ajustar URLs HTTPS.
2. Asegurar que el navegador alcanza las URLs de MF y de APIs (DNS / reverse proxy).
3. Levantar:

```bash
cd MSPI_NVA_CO_MR_BACK/docker-config/docker
docker compose -f docker-compose.front.yml --env-file .env up -d --build
```

### Tabla de variables (frontend)

| Variable | Descripción | Ejemplo local |
|---|---|---|
| `MSPI_SHELL_URL` | Origen del shell | `http://localhost:4200` |
| `MSPI_AUTH_URL` | Origen de mf_auth | `http://localhost:4201` |
| `MSPI_ORG_URL` | Origen de mf_org | `http://localhost:4202` |
| `MSPI_ASSESSMENT_URL` | Origen de mf_assessment | `http://localhost:4203` |
| `MSPI_EVIDENCE_URL` | Origen de mf_evidence | `http://localhost:4204` |
| `MSPI_REPORTS_URL` | Origen de mf_reports | `http://localhost:4205` |
| `MSPI_MS_IAM_URL` … `MSPI_MS_ADMIN_URL` | Bases de los 8 MS | `http://localhost:8082` … `8089` |
| `MSPI_API_URLS` | Orígenes para CSP `connect-src` (espacio-separado) | (derivado si se omite) |
| `MSPI_FRAME_SRC` | CSP `frame-src` del shell | URLs de los 6 MF |
| `MSPI_FRAME_ANCESTORS` | CSP de remotes (quién embebe) | `self` + URL del shell |
| `MSPI_FRAME_ANCESTORS_SHELL` | CSP del shell | `self` |
| `MSPI_ALLOWED_ORIGINS_JSON` | Allowlist JSON de `postMessage` | (derivado si se omite) |

Al arrancar, cada contenedor escribe `/assets/config.json` y regenera la CSP de nginx. No hace falta rebuild de Angular al cambiar solo el dominio.
