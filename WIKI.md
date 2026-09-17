# Cómo correr la wiki (MkDocs Material)

La wiki se genera desde los Markdown ya existentes en este repositorio (`mkdocs.yml` en la raíz).

## Requisitos

- Python 3.10+
- pip / venv

## Instalación

```bash
cd MSPI_NVA_CO_DOCS
python3 -m venv .venv
source .venv/bin/activate   # Windows: .venv\Scripts\activate
pip install -r requirements.txt
```

## Servir en local

```bash
mkdocs serve
# → http://127.0.0.1:8000
```

Opciones útiles:

```bash
mkdocs serve -a 127.0.0.1:8000 --livereload
```

## Build estático

```bash
mkdocs build
# salida en ./site/
```

Sirve el estático con cualquier servidor:

```bash
python3 -m http.server -d site 8080
```

## Publicar (GitHub Pages)

Con el tema Material / MkDocs:

```bash
# primera vez: configurar remoto GitHub del repo DOCS
mkdocs gh-deploy --force
```

Esto construye y publica la rama `gh-pages`. Ajusta `site_url` en `mkdocs.yml` al URL real de Pages cuando exista.

Alternativa CI: workflow que ejecute `pip install -r requirements.txt && mkdocs build` y suba el artefacto `site/`.

!!! note
    `site/` está en `.gitignore` — no se versiona el build.

## Estructura relevante

| Ruta | Uso |
|---|---|
| `mkdocs.yml` | Tema, plugins, navegación |
| `docs/` | Symlinks al contenido (MkDocs exige `docs_dir` hijo del config) |
| `wiki/Inicio.md` | Landing de la wiki |
| `wiki/Seguridad.md` | Postura de seguridad |
| `Documentacion-*` | Contenido SDLC existente |
| `legal/` | Marco legal: privacidad, aviso, autorización, términos, cookies, seguridad, retención, confidencialidad, propiedad intelectual, licencias |
| `Documentacion-General/assets/graphify/` | Copia publicable del grafo |
