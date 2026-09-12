# Política de Privacidad y Tratamiento de Datos Personales — AUDITCYBER / MSPI

> **Borrador para revisión legal.** Reemplaza los marcadores `[[ ... ]]` con los datos reales de la
> organización antes de publicar. Alineado con la Ley 1581 de 2012, el Decreto 1377 de 2013 y la Ley 1266
> de 2008 (Colombia). Revísalo con el área jurídica antes de su publicación oficial.

**Responsable del tratamiento:** [[Razón social]] — NIT [[NIT]]
**Domicilio:** [[Dirección]], [[Ciudad]], Colombia
**Correo de contacto / habeas data:** [[correo@dominio]] · **Teléfono:** [[teléfono]]
**Vigente desde:** [[fecha]] · **Versión:** 1.0

---

## 1. Objeto
Esta política regula la recolección, almacenamiento, uso, circulación y supresión de los datos personales
tratados por AUDITCYBER a través de la plataforma MSPI (Modelo de Seguridad y Privacidad de la Información),
en el marco de las evaluaciones de seguridad y privacidad de la información para entidades.

## 2. Definiciones (Ley 1581/2012, art. 3)
- **Dato personal:** cualquier información vinculada o que pueda asociarse a una persona natural determinada
  o determinable.
- **Dato sensible:** el que afecta la intimidad o cuyo uso indebido puede generar discriminación.
- **Titular:** persona natural cuyos datos son objeto de tratamiento.
- **Responsable / Encargado:** quien decide / quien trata los datos por cuenta del responsable.
- **Tratamiento:** cualquier operación sobre datos personales (recolección, uso, circulación, supresión).

## 3. Datos que se recolectan
La plataforma trata principalmente datos de **usuarios institucionales** (no de público general):
- **Identificación y contacto:** nombre, correo electrónico, rol en la entidad.
- **Datos de cuenta y autenticación:** credenciales gestionadas vía Keycloak, segundo factor (TOTP),
  registros de inicio de sesión e intentos fallidos.
- **Datos de actividad:** acciones dentro de la plataforma, registros de auditoría (quién hizo qué y cuándo),
  solicitudes (eliminación, ampliación, reenvío de contraseña) y sus decisiones.
- **Documentos y evidencias** cargados por las entidades como soporte de las evaluaciones.

> MSPI **no** está diseñada para recolectar datos sensibles. Si una entidad adjunta documentos con datos
> sensibles o de terceros, es responsable de contar con la autorización correspondiente.

## 4. Finalidades del tratamiento
1. Crear y administrar cuentas de usuario y controlar el acceso por roles.
2. Ejecutar y gestionar las evaluaciones de seguridad y privacidad (MSPI).
3. Generar reportes, instrumentos y documentos oficiales de las evaluaciones.
4. Garantizar la **trazabilidad y auditoría** de las operaciones realizadas.
5. Enviar notificaciones operativas (p. ej. contraseña temporal, estados de solicitudes).
6. Cumplir obligaciones legales, contractuales y de seguridad de la información.

## 5. Autorización del titular
La autorización se obtiene al momento de la creación de la cuenta y/o aceptación de los términos de uso, de
forma previa, expresa e informada, por medios que permiten su posterior consulta (registro de aceptación).

## 6. Derechos del titular (Ley 1581/2012, art. 8)
El titular puede: **conocer, actualizar y rectificar** sus datos; solicitar **prueba de la autorización**;
ser **informado** sobre el uso dado a sus datos; **presentar quejas** ante la SIC; **revocar** la autorización
y/o solicitar la **supresión** cuando proceda; y **acceder** gratuitamente a sus datos.

## 7. Procedimiento para ejercer los derechos (consultas y reclamos)
- **Canal:** [[correo@dominio]] con asunto "Habeas Data — [consulta/reclamo]".
- **Consultas:** se atienden en máximo **10 días hábiles** (prorrogables 5 más).
- **Reclamos:** en máximo **15 días hábiles** (prorrogables 8 más), conforme a los arts. 14 y 15 de la Ley
  1581/2012.

## 8. Seguridad de la información
AUDITCYBER aplica medidas técnicas y administrativas razonables para proteger los datos:
- Autenticación con **Keycloak** y **segundo factor (TOTP)**; contraseñas no almacenadas en texto plano.
- Comunicaciones cifradas en tránsito (**HTTPS/TLS**).
- Control de acceso por **roles** y principio de mínimo privilegio.
- **Registros de auditoría** de las operaciones y conservación de evidencias.
- **Borrado lógico**: la información no se elimina físicamente; se conserva bajo estado lógico eliminado
  para fines de trazabilidad, salvo obligación legal de supresión definitiva.
- Secretos gestionados fuera del código (gestor de secretos), sin credenciales embebidas.

## 9. Conservación y supresión
Los datos se conservan mientras exista la relación con la entidad y por el término exigido por obligaciones
legales o contractuales. Vencido el plazo o ante una solicitud procedente, se aplicará supresión o
anonimización según corresponda.

## 10. Transferencia y transmisión de datos
[[Indicar si hay encargados/proveedores (p. ej. hosting, correo transaccional) y su ubicación. Con
proveedores que actúen como Encargados se suscriben acuerdos de tratamiento.]]

## 11. Uso de cookies
[[Si la plataforma usa cookies/almacenamiento local, describir cuáles y su finalidad. MSPI usa
almacenamiento local del navegador para conveniencia de sesión; no se usa para rastreo publicitario.]]

## 12. Vigencia y cambios
Esta política rige desde su publicación. Cualquier cambio sustancial será comunicado a los titulares por los
canales de la plataforma. La versión vigente estará siempre disponible en la ruta `/privacidad`.

---

*Documento generado como borrador técnico para el proyecto MSPI. Requiere validación del área jurídica de
la organización antes de su adopción oficial.*
