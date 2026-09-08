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
2. Levanta los 6 microservicios, puertos **8082-8087**.
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

El DDL real de la base de datos vive en `docker-config/docker/postgres/init/MER-MSPI.sql` y solo se ejecuta al **crear** el volumen de Postgres — un reset es necesario para aplicar cambios de esquema.

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
