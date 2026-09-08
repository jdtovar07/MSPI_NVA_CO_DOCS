# 06 · Guía de pruebas funcionales end-to-end

Secuencia recomendada para demostrar el sistema completo, con el stack levantado (ver [05-Manual-Despliegue.md](05-Manual-Despliegue.md)) en **http://localhost:4200**.

## 1. Login y 2FA

1. Ingresar credenciales de un usuario existente.
2. Si el usuario tiene 2FA habilitado, verificar el código TOTP (flujo real contra Keycloak).
3. Bloqueo de cuenta: fallar el login 3 veces seguidas → el 4.º intento debe indicar que la cuenta está bloqueada temporalmente.

## 2. Panel administrativo del shell (requiere `AdminSistema`)

1. **Configuración del sistema**: editar un valor, guardar, revisar el historial de cambios.
2. **Auditoría**: filtrar eventos por tipo y por entidad.
3. **Notificaciones**: verificar prioridad (Alta/Media/Baja) y marcar como leídas.

## 3. Organizaciones

1. Crear una organización, seleccionando país/ciudad.
2. Definir sus "áreas base" (plantilla de áreas y responsables).

## 4. Catálogo (requiere `AdminInstrumento` o `AdminSistema`)

1. Crear una Escala, agregar una versión, publicarla.
2. Crear un Banco de preguntas, agregar preguntas, buscar/filtrar por texto, dominio y tipo de evaluación.

## 5. Ciclo completo de una evaluación

1. **Crear evaluación**: organización, tipo de entidad, escala, datos de preparación/auditoría.
2. **Asignar miembros** con rol (`Evaluador`, `Revisor`, `EvaluadorRevisor`).
3. **Diligenciar controles**: calificar (0-100/N/A), registrar evidencia/hallazgo, brecha, recomendación, estado del control, adjuntar evidencia.
4. **PHVA, Madurez, NIST**: completar los ítems manuales; los ítems heredados se calculan automáticamente.
5. **Enviar a revisión** y confirmar que el flujo de aprobación respeta el rol de cada miembro.
6. **Publicar** la evaluación.

## 6. Evidencia

Adjuntar un archivo a un control y confirmar que queda disponible para descarga desde el módulo de evidencias.

## 7. Diagnóstico y reportes

1. Abrir el tablero de diagnóstico: dominios ISO, avance PHVA, nivel de madurez, desempeño NIST (calculados en tiempo real).
2. Generar el reporte PDF y el export Excel del instrumento.
3. Consultar la lista de brechas priorizadas.
4. Generar un comparativo entre dos evaluaciones de la misma organización.

## 8. Verificación de mensajes de error

Cualquier error de validación o de servidor debe mostrarse como un mensaje específico dentro de la interfaz, con el detalle devuelto por la API.
