# Licencias de terceros — AUDITCYBER / MSPI

Componentes de software de terceros que usa la plataforma, obtenidos de los `build.gradle` del backend y los
`package.json` de los microfrontends. Las licencias corresponden a las versiones usadas; antes de redistribuir,
confirmar en el repositorio de cada proyecto.

## Backend (Java)

| Componente | Uso | Licencia |
|---|---|---|
| Spring Boot, Spring Framework, Spring Security | Base de los microservicios, seguridad OAuth2/JWT | Apache 2.0 |
| Jackson (`jackson-databind`) | Serialización JSON | Apache 2.0 |
| Apache POI (`poi-ooxml`) | Lectura y escritura del Excel oficial | Apache 2.0 |
| Apache PDFBox | Manipulación de PDF | Apache 2.0 |
| OpenPDF (`com.github.librepdf`) | Marca de agua y PDF | LGPL 2.1 / MPL 2.0 (doble licencia) |
| java-otp (`com.eatthepath`) | Códigos TOTP del segundo factor | MIT |
| Apache Commons Codec | Codificación Base32/hash | Apache 2.0 |
| Resilience4j | Reintentos y tolerancia a fallos | Apache 2.0 |
| Micrometer (`registry-prometheus`) | Métricas | Apache 2.0 |
| PostgreSQL JDBC | Conexión a la base de datos | BSD 2-Clause |
| SLF4J | Registro de eventos | MIT |
| Kotlin stdlib | Dependencia transitiva | Apache 2.0 |
| Infisical SDK | Lectura de secretos | Verificar en el repositorio del SDK |
| Lombok (solo compilación) | Generación de código | MIT |
| JUnit 5, Mockito, AssertJ, ArchUnit, H2 (solo pruebas) | Pruebas | EPL 2.0 / MIT / Apache 2.0 / Apache 2.0 / MPL 2.0 o EPL 1.0 |

## Frontend (Angular)

| Componente | Uso | Licencia |
|---|---|---|
| Angular (`@angular/*`) | Framework de los 6 microfrontends | MIT |
| RxJS | Programación reactiva | Apache 2.0 |
| zone.js | Detección de cambios | MIT |
| tslib | Utilidades de TypeScript | 0BSD |
| qrcode | QR de configuración del segundo factor (`mf_auth`) | MIT |

## Infraestructura y herramientas de ejecución

| Componente | Uso | Licencia |
|---|---|---|
| PostgreSQL | Base de datos | PostgreSQL License |
| Keycloak | Proveedor de identidad | Apache 2.0 |
| LibreOffice (ejecutable en la imagen de `ms_reporting`) | Conversión del Excel oficial a PDF | MPL 2.0 |
| nginx | Servidor de los microfrontends | BSD 2-Clause |
| Eclipse Temurin (JDK/JRE) | Ejecución de Java | GPL v2 con *Classpath Exception* |
| Docker / Docker Compose | Contenedores | Apache 2.0 |

## Servicios externos

| Servicio | Uso | Condiciones |
|---|---|---|
| Brevo | Correo transaccional | Términos de servicio del proveedor; actúa como encargado del tratamiento |
| Country State City API | Catálogo de países, departamentos y ciudades | Términos del proveedor; requiere clave de API; no recibe datos personales |
| Infisical | Gestión de secretos | Términos del proveedor (o instalación propia) |

## Obligaciones que se derivan

- **Apache 2.0:** conservar los avisos de copyright y el archivo `NOTICE` si se redistribuye.
- **MIT / BSD / 0BSD:** conservar el aviso de copyright y la licencia.
- **LGPL / MPL (OpenPDF, LibreOffice):** se usan sin modificar; si se modificaran sus fuentes, esas modificaciones
  deben publicarse bajo la misma licencia.
- **GPL con Classpath Exception (Temurin):** permite ejecutar aplicaciones con cualquier licencia.

Ninguna de estas licencias impide licenciar MSPI de forma propietaria o abierta.
