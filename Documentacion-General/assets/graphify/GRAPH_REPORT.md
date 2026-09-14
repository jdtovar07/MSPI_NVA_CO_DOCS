# Graph Report - MSPI_NVA_CO_DOCS  (2026-10-07)

## Corpus Check
- cluster-only mode — file stats not available

## Summary
- 48 nodes · 115 edges · 11 communities (6 shown, 5 thin omitted)
- Extraction: 100% EXTRACTED · 0% INFERRED · 0% AMBIGUOUS
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `cec74a8d`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- Community 0
- Community 1
- Community 2
- Community 3
- Community 4
- Community 5
- Community 6
- Community 7
- Community 8
- Community 9
- Community 10

## God Nodes (most connected - your core abstractions)
1. `"assessment"."assessment"` - 18 edges
2. `"iam"."user"` - 15 edges
3. `"catalog"."control_catalog_node"` - 10 edges
4. `"catalog"."template_version"` - 10 edges
5. `"assessment"."assessment_control_node"` - 7 edges
6. `"assessment"."control_response"` - 7 edges
7. `"catalog"."scale_version"` - 5 edges
8. `"catalog"."maturity_requirement_catalog"` - 4 edges
9. `"catalog"."nist_mapping"` - 4 edges
10. `"evidence"."evidence_file"` - 4 edges

## Surprising Connections (you probably didn't know these)
- `"assessment"."assessment_control_node"` --references--> `"assessment"."assessment"`  [EXTRACTED]
  Documentacion-General/MER-MSPI.sql → Documentacion-General/MER-MSPI.sql  _Bridges community 0 → community 4_
- `"assessment"."control_response"` --references--> `"assessment"."assessment_control_node"`  [EXTRACTED]
  Documentacion-General/MER-MSPI.sql → Documentacion-General/MER-MSPI.sql  _Bridges community 0 → community 3_
- `"catalog"."nist_mapping"` --references--> `"catalog"."nist_subcategory"`  [EXTRACTED]
  Documentacion-General/MER-MSPI.sql → Documentacion-General/MER-MSPI.sql  _Bridges community 0 → community 9_
- `"catalog"."lifting_document_item_catalog"` --references--> `"catalog"."template_version"`  [EXTRACTED]
  Documentacion-General/MER-MSPI.sql → Documentacion-General/MER-MSPI.sql  _Bridges community 0 → community 7_
- `"catalog"."lifting_question_catalog"` --references--> `"catalog"."template_version"`  [EXTRACTED]
  Documentacion-General/MER-MSPI.sql → Documentacion-General/MER-MSPI.sql  _Bridges community 0 → community 8_

## Import Cycles
- None detected.

## Communities (11 total, 5 thin omitted)

### Community 0 - "Community 0"
Cohesion: 0.25
Nodes (11): "assessment"."assessment_control_node", "catalog"."control_catalog_node", "catalog"."control_rule", "catalog"."iso_domain", "catalog"."maturity_requirement_catalog", "catalog"."maturity_requirement_control_map", "catalog"."maturity_threshold", "catalog"."nist_mapping" (+3 more)

### Community 1 - "Community 1"
Cohesion: 0.53
Nodes (5): "catalog"."scale", "catalog"."scale_band", "catalog"."scale_level", "catalog"."scale_version", "reporting"."report_template"

### Community 2 - "Community 2"
Cohesion: 0.40
Nodes (6): "assessment"."assessment_member", "evidence"."evidence_file", "iam"."audit_log", "iam"."system_config", "iam"."user", "reporting"."report_generation_job"

### Community 3 - "Community 3"
Cohesion: 0.33
Nodes (6): "assessment"."control_comment", "assessment"."control_comment_thread", "assessment"."control_response", "assessment"."control_review", "assessment"."gap_action", "assessment"."gap_register"

### Community 4 - "Community 4"
Cohesion: 0.40
Nodes (5): "assessment"."assessment", "assessment"."assessment_metadata", "assessment"."assessment_status_history", "evidence"."process_scope_metric", "reporting"."analytics_cache"

### Community 5 - "Community 5"
Cohesion: 0.50
Nodes (4): "org"."organization", "org"."organization_area_base", "org"."organization_area_base_topic", "org"."organization_contact"

## Knowledge Gaps
- **1 isolated node(s):** `"reporting"."report_template"`
  These have ≤1 connection - possible missing edges. (Counts symbols only; 1 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **5 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `"assessment"."assessment"` connect `Community 4` to `Community 0`, `Community 1`, `Community 2`, `Community 3`, `Community 5`, `Community 6`, `Community 7`, `Community 8`?**
  _High betweenness centrality (0.053) - this node is a cross-community bridge._
- **What connects `"reporting"."report_template"` to the rest of the system?**
  _1 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Why does `"iam"."user"` connect `Community 2` to `Community 1`, `Community 3`, `Community 4`, `Community 7`, `Community 8`, `Community 10`?**
  _High betweenness centrality (0.032) - this node is a cross-community bridge._
- **Why does `"catalog"."template_version"` connect `Community 0` to `Community 8`, `Community 1`, `Community 4`, `Community 7`?**
  _High betweenness centrality (0.015) - this node is a cross-community bridge._