# Política de cookies y almacenamiento local — AUDITCYBER / MSPI

La plataforma **no usa cookies de publicidad, analítica ni de terceros**. Solo guarda en el navegador lo
necesario para funcionar. Por eso no muestra un banner de consentimiento de cookies: el almacenamiento técnico
estrictamente necesario no requiere consentimiento adicional, y se informa en esta política y en la
[política de privacidad](POLITICA-PRIVACIDAD-MSPI.md).

## Inventario (verificado en el código de los microfrontends)

| Nombre | Tipo | Contenido | Finalidad | Duración |
|---|---|---|---|---|
| `auth_session` | `localStorage` y cookie propia (`SameSite=Lax`, ruta `/`) | Token de acceso (JWT), identificador, nombre y correo del usuario, roles y vencimiento | Mantener la sesión y compartirla entre el shell y los microfrontends | Hasta cerrar sesión o vencer el token |
| `active_assessment_id` | `localStorage` | Identificador de la evaluación abierta | Recordar en qué evaluación se trabaja al cambiar de módulo | Hasta que se cambie o se cierre sesión |
| `mspi_assessment_index`, `mspi_assessment_*`, `mspi_assessment_entity_*` | `localStorage` | Datos de trabajo de la evaluación (formulario de entidad) | Conservar el avance del formulario si se recarga la página | Hasta enviarlo o limpiarlo |
| `mspi_org_areas_base` | `localStorage` / cookie propia | Áreas base de la organización | Precargar áreas al crear evaluaciones | Sesión de trabajo |
| `catalog_bundle` | `sessionStorage` | Catálogo de referencia del instrumento (sin datos personales) | Evitar descargarlo en cada pantalla | Hasta cerrar la pestaña |
| `change_password_username` | `sessionStorage` | Usuario que debe cambiar la contraseña temporal | Completar el cambio de contraseña obligatorio | Hasta cerrar la pestaña |

Ninguno se comparte con terceros. Al cerrar sesión se eliminan los datos de sesión.

## Cómo borrarlos
Cerrar sesión elimina la sesión. El usuario también puede borrar el almacenamiento desde la configuración de su
navegador (datos de sitios); en ese caso deberá volver a iniciar sesión.

## Consideración de seguridad
Guardar el token en almacenamiento accesible por JavaScript facilita la composición por iframes, pero lo expone si
existiera una vulnerabilidad de *cross-site scripting*. Se mitiga con cabeceras de seguridad, la ausencia de
contenido de terceros y tokens de corta duración. Para un despliegue productivo se recomienda migrar a una cookie
`HttpOnly` y `Secure` emitida por el servidor (ver la
[política de seguridad](POLITICA-SEGURIDAD-INFORMACION.md)).
