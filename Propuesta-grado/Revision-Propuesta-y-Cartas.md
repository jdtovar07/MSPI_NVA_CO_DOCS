# Revisión de la propuesta de grado y las cartas de aval

Registro de la revisión de los documentos académicos contra el estado real del sistema y contra las indicaciones
del Coordinador Editorial de CORHUILA que venían como comentarios en la plantilla. La versión anterior de cada
archivo queda en el historial de Git.

## 1. Propuesta de grado (`Propuesta_de_Grado_MSPI.docx`)

### Indicaciones de la plantilla aplicadas

| Indicación del Coordinador Editorial / CTeI | Acción |
|---|---|
| «La información entre corchetes debe diligenciarla» | Se diligenciaron los marcadores verificables (ver tabla siguiente) |
| «Elimine esta página y todas las demás indicaciones y orientaciones» | Se retiraron el texto guía de la tabla de contenido y la tabla de ejemplo APA |
| «Dedicatoria y agradecimientos solo aplica para el informe final» | Se retiraron ambas secciones |
| Formato de cita (Apellido & Apellido, año) | Se diligenció la página de cita: (Suarez Camacho & Tovar Rodriguez, 2026) y su referencia APA |
| Las tablas llevan número en negrilla y título en cursiva | Se agregó «Tabla 1 · Cronograma de actividades por sprint» |
| Comentarios de la plantilla | Se eliminaron del documento, porque eran instrucciones ya aplicadas |

### Correcciones de contenido (desactualizado frente al sistema)

| Sección | Decía | Ahora dice |
|---|---|---|
| Título | «gestion», «informacion» | Con tildes: «gestión», «información» |
| Resumen / Abstract | 8 microservicios, «seis activos»; administración y auditoría pendientes | Los 8 activos (incluye `ms_audit` y `ms_admin`), 156 servicios REST y 73 tablas |
| Objetivo específico NIST | NIST CSF con cinco funciones | NIST CSF 2.0 con seis funciones (incluye «gobernar»), como implementa el catálogo |
| Antecedentes / marco teórico | Solo ISO/IEC 27001:2013 | Soporta 2013 (catálogo v1) y 2022 (catálogo v2, 93 controles) |
| Marco teórico | Sin citas | Citas APA: ISO (2022a, 2022b), NIST (2024), Lewis & Fowler (2014), Newman (2021), Cockburn (2005), Martin (2017), Geers (2020), Richardson (2018) |
| Resultados | `ms_admin` y `ms_audit` sin funcionalidad; frontend sin pruebas; discrepancia con Module Federation | Los 8 servicios descritos; 83 clases y 354 casos de prueba en backend; composición iframe + `postMessage` justificada como decisión de arquitectura; ajustes previos a producción |
| Conclusiones y recomendaciones | Pedían implementar `ms_admin`/`ms_audit` y unificar Module Federation | Reflejan lo implementado y recomiendan lo que sí falta (parametrizar URLs, control de propiedad en notificaciones, pruebas en el pipeline) |
| Tabla de contenido | «Accedentes de la investigación» | «Antecedentes de la investigación» |
| Referencias | 1 referencia y 4 marcadores pendientes | 15 referencias en APA 7 en orden alfabético |

### Marcadores cerrados (de 19 a 7)

| Marcador | Cómo se cerró |
|---|---|
| Director o asesor | Ing. Luis Ángel Vargas Narvaez (dato de las cartas de aval) |
| Facultad | Facultad de Ingeniería |
| Delimitación de la población y referencia normativa | Entidades sujetas a la Política de Gobierno Digital; Decreto 1078 de 2015, Decreto 767 de 2022 y Resolución MinTIC 500 de 2021 |
| Antecedentes con herramientas GRC | Comparación con Eramba, CISO Assistant y SimpleRisk |
| Marco teórico ampliado con APA | Citas agregadas en el texto |
| Marco normativo | Gobierno Digital, Resolución 500 de 2021, Ley 1581 de 2012, Decreto 1377 de 2013, Ley 1273 de 2009, derecho de autor |
| Director en la metodología | Nombre agregado |
| Consideraciones éticas | Se remite al marco legal del repositorio |
| Anexos | Anexos A–D apuntando a la documentación técnica, trazabilidad, pruebas y marco legal |
| Referencias pendientes (4) | Reemplazadas por las referencias reales |

### Marcadores que dependen de ustedes (7)

| Marcador | Qué falta |
|---|---|
| Grupo y semillero de investigación | Nombre y código institucional |
| Repositorio institucional | URL del repositorio de CORHUILA |
| Justificación cuantitativa | Tiempo de diligenciamiento manual frente al asistido o número de entidades beneficiadas, con fuente |
| Técnicas de recolección | Indicar si hubo entrevistas con quien originó el instrumento en Excel |
| Cronograma | Fechas reales de inicio y cierre de cada sprint |
| Conclusiones finales | Redactarlas y validarlas tras su propia evaluación crítica |

## 2. Cartas de solicitud de aval (`CartasVoBo/`)

| Hallazgo | Corrección |
|---|---|
| No mencionaban el título del proyecto | Se agregó el título completo |
| «Ingeniera de sistemas», «Ingenieria de sistemas» | «Ingeniería de Sistemas» |
| «Corporacion Universitaria Del Huila» | «Corporación Universitaria del Huila» |
| Caracteres invisibles de dirección de texto (U+200F) | Eliminados |
| Fecha «[Día] de [Mes] de [Año]» | Línea para diligenciar al firmar: «____ de ______ de 2026» |
| Faltaba el aval del director | Nueva carta: `carta_aval_director_proyecto_grado.docx` |

## 3. Datos personales en el repositorio

El repositorio `MSPI_NVA_CO_DOCS` es **público** y las cartas contienen números de cédula y códigos estudiantiles.
**Decisión de los autores:** el repositorio se mantiene público y el riesgo queda en seguimiento (registrado en la
[política de seguridad](../legal/POLITICA-SEGURIDAD-INFORMACION.md)). Si el repositorio se difunde fuera del ámbito
académico, se deben retirar esos datos de las cartas y del historial.
