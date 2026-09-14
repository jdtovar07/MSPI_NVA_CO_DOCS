# Grafo de código (graphify)

Grafo de conocimiento generado con **graphify** sobre el corpus documental/código indexado en este repositorio.

## Visualización interactiva

<iframe src="assets/graphify/graph.html" width="100%" height="640" style="border:1px solid #e2e8f0;border-radius:8px;" title="Graphify graph"></iframe>

[Abrir graph.html a pantalla completa](assets/graphify/graph.html)

## Informe textual

Ver extracto y comunidades en:

→ [GRAPH_REPORT.md](assets/graphify/GRAPH_REPORT.md)

## Regeneración

En la raíz del monorepo / de este repo:

```bash
graphify update .
# o: graphify .
```

La salida local completa vive en `graphify-out/` (ignorada por git salvo la copia publicada en `assets/graphify/`).

!!! todo "Grafo monorepo completo"
    El `graph.html` embebido aquí corresponde al grafo indexado en **MSPI_NVA_CO_DOCS** (vista agregada). El grafo del monorepo BACK+FRONT+DOCS puede ser mayor; actualizar `assets/graphify/` tras un `graphify update` en la raíz del proyecto si se desea la vista unificada.
