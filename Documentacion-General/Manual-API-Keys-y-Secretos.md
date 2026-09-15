# Manual — API keys y secretos necesarios

Guía para crear/obtener y configurar todas las claves que MSPI necesita para funcionar. Cada secreto se
inyecta por **variable de entorno** (en despliegue se gestionan con **Infisical**; en local pueden ir como
variables de entorno o un `.env`). **Nunca** se escriben en el código ni se suben al repositorio.

## Resumen de claves requeridas

| Variable de entorno | Para qué sirve | Origen | ¿Quién la usa? |
|---|---|---|---|
| `INTERNAL_API_KEY` | Proteger las rutas internas `/internal/**` entre microservicios | **La generas tú** (aleatoria) | Los 8 microservicios |
| `BREVO_API_KEY` | Envío de correos (contraseña temporal, etc.) | Cuenta en **Brevo** | ms_iam |
| `BREVO_FROM_EMAIL` | Remitente verificado del correo | Brevo (remitente verificado) | ms_iam |
| `KEYCLOAK_CLIENT_ID` / `KEYCLOAK_CLIENT_SECRET` / `KEYCLOAK_TOKEN_URI` | Cliente admin para gestionar usuarios en Keycloak | **Keycloak** (consola admin) | ms_iam |
| `JWT_ISSUER_URI` | Validar el token (issuer del realm) | Keycloak (URL del realm) | Todos (resource server) |
| `LOCATION_API_KEY` / `BASE_URL_LOCATION_API` | Países/estados/ciudades | **Country State City API** | ms_org |
| `DB_CREDENTIAL` | Credenciales de conexión a PostgreSQL (JSON) | **Infisical** | Todos |
| `REPORT_PROTECTION_PASSWORD` | Contraseña de protección del Excel oficial | **La eliges tú** | ms_reporting |
| `CORS_ALLOWED_ORIGINS` | Orígenes permitidos (no es clave, es config) | Tú (lista de dominios) | Todos |

> `JWT_ISSUER_URI`, `BASE_URL_LOCATION_API` y `CORS_ALLOWED_ORIGINS` son URLs/configuración, no claves secretas.

---

## 1. `INTERNAL_API_KEY` (la generas tú)

Es una clave compartida entre los microservicios para que las rutas `/internal/**` solo se acepten entre
ellos (se envía en el header `X-Internal-Api-Key`; si no coincide → 401).

**Crear:** genera una cadena aleatoria larga, por ejemplo:
```bash
openssl rand -hex 32
```
Usa **el mismo valor** en los 8 microservicios. Rótala periódicamente (cambia el valor en todos a la vez).

---

## 2. Brevo — `BREVO_API_KEY` y `BREVO_FROM_EMAIL`

Brevo (antes Sendinblue) es el proveedor de correo transaccional.

1. Crea una cuenta en **https://www.brevo.com** e inicia sesión.
2. Ve a **SMTP & API → API Keys** (menú de tu perfil → *SMTP & API*).
3. Clic en **Generate a new API key**, ponle un nombre (p. ej. `mspi-backend`) y **copia la clave** (solo
   se muestra una vez) → ese valor es `BREVO_API_KEY`.
4. Verifica un remitente en **Senders, Domains & Dedicated IPs → Senders**: agrega y confirma el correo que
   usarás como remitente → ese correo es `BREVO_FROM_EMAIL`.

> Sin remitente verificado, Brevo rechaza el envío. En desarrollo puedes usar buzones de prueba (p. ej.
> yopmail) como destinatarios, pero el remitente debe estar verificado en tu cuenta.

---

## 3. Keycloak — `KEYCLOAK_CLIENT_ID`, `KEYCLOAK_CLIENT_SECRET`, `KEYCLOAK_TOKEN_URI`

ms_iam usa un **cliente confidencial** de Keycloak para administrar usuarios (crear, resetear contraseña).

1. Entra a la **consola de administración de Keycloak** y selecciona el realm **`iam`**.
2. **Clients → Create client**:
   - *Client type*: **OpenID Connect**.
   - *Client ID*: por ejemplo `mspi-admin` → ese valor es `KEYCLOAK_CLIENT_ID`.
3. En **Capability config** activa **Client authentication** (lo vuelve *confidential*) y habilita
   **Service accounts roles** (flujo `client_credentials`). Guarda.
4. Pestaña **Credentials** → copia el **Client secret** → es `KEYCLOAK_CLIENT_SECRET`.
5. Pestaña **Service account roles** → asigna los roles de administración necesarios (p. ej. del cliente
   `realm-management`: `manage-users`, `view-users`).
6. `KEYCLOAK_TOKEN_URI` es el endpoint de token del realm:
   `https://<host-keycloak>/realms/iam/protocol/openid-connect/token`.
7. `JWT_ISSUER_URI` es el issuer del realm: `https://<host-keycloak>/realms/iam`.

---

## 4. Country State City — `LOCATION_API_KEY` y `BASE_URL_LOCATION_API`

ms_org consume la **Country State City API** para poblar países/estados/ciudades.

1. Regístrate en **https://countrystatecity.in**.
2. En el panel, sección **API Keys**, copia tu clave → es `LOCATION_API_KEY`.
3. `BASE_URL_LOCATION_API` es la URL base de la API (p. ej. `https://api.countrystatecity.in/v1`).

---

## 5. Infisical y `DB_CREDENTIAL`

En despliegue, los secretos (incluido el de base de datos) se gestionan con **Infisical**.

1. Crea un proyecto en **https://infisical.com** (o tu instancia) y un **entorno** (dev/prod).
2. Añade los secretos de este manual como variables del proyecto.
3. `DB_CREDENTIAL` es un **JSON** con las credenciales de PostgreSQL (host, puerto, base, usuario,
   contraseña), leído por `DBCredentialConfig`. Créalo como secreto en Infisical.
4. Para que los servicios lean Infisical, configura una **Machine Identity** (Universal Auth) y entrega su
   *client id* / *client secret* a cada servicio según su configuración de despliegue.

> En **local** puedes saltarte Infisical y exportar las variables directamente (o usar el fallback H2 donde
> aplique); en **producción** todas vienen de Infisical.

---

## 6. `REPORT_PROTECTION_PASSWORD` (la eliges tú)

Contraseña con la que ms_reporting protege el Excel oficial. Elige una contraseña fuerte y guárdala como
secreto. No es cifrado fuerte (es la protección nativa de Excel); no la reutilices de otras cuentas.

---

## Buenas prácticas
- **Nunca** subas claves al repositorio ni las dejes en el código. Solo variables de entorno / Infisical.
- **Rota** periódicamente `INTERNAL_API_KEY`, el secreto de Keycloak y las API keys externas.
- Usa **valores distintos** por entorno (dev/prod).
- Da a cada clave el **mínimo privilegio** necesario (p. ej. el cliente de Keycloak solo con los roles de
  gestión de usuarios que requiere).
