# 07 · Manual de usuario final

Qué puede hacer cada rol dentro de MSPI y cómo. Acceso al sistema: **http://localhost:4200** en el entorno local (en un despliegue real, la URL corporativa correspondiente).

## 1. Iniciar sesión

1. Ingresar usuario/correo y contraseña.
2. Si la cuenta tiene verificación en dos pasos activada, ingresar el código de la aplicación autenticadora.

## 2. Navegación general

El menú superior muestra únicamente las secciones a las que el rol del usuario tiene acceso: Dashboard, Usuarios, Organizaciones, Escalas / Banco de preguntas, Evaluaciones, Mis Evaluaciones, Evidencias, Diagnóstico / Reportes, Auditoría y Configuración (estas dos últimas solo para `AdminSistema`). La campana de notificaciones muestra alertas priorizadas (Alta/Media/Baja).

## 3. Guía por rol

### `AdminSistema`

Acceso total: gestión de usuarios y sus roles, configuración del sistema (con historial), auditoría completa del sistema, y edición/revisión de cualquier evaluación.

### `AdminInstrumento`

Administra el instrumento de evaluación: crea y publica Escalas (con sus versiones), crea y mantiene Bancos de preguntas, y puede crear organizaciones y definir sus áreas base.

### `Evaluador`

Diligencia las evaluaciones donde es miembro asignado:

1. Ir a **Mis Evaluaciones**, abrir la evaluación.
2. Recorrer el árbol de controles (Administrativos / Técnicos) por dominio.
3. Calificar cada control (0, 20, 40, 60, 80, 100 o N/A), describir evidencia/hallazgo, brecha y recomendación, y adjuntar evidencia.
4. Completar las hojas PHVA, Madurez y NIST.
5. Enviar la evaluación a revisión cuando el diligenciamiento está completo.

### `Revisor`

Revisa evaluaciones diligenciadas donde es miembro: consulta calificaciones, evidencias y recomendaciones, y aprueba (publica) la evaluación.

### `EvaluadorRevisor`

Combina ambos permisos sobre la misma evaluación.

### `Lector`

Solo lectura: consulta el tablero de Diagnóstico de las evaluaciones a las que tiene acceso y la vista "Mi organización" si aplica.

## 4. Diagnóstico y reportes

Disponible para cualquier rol con acceso a la evaluación:

1. Seleccionar la evaluación en **Diagnóstico / Reportes**.
2. Consultar calificación por dominios ISO, avance PHVA, nivel de madurez y desempeño NIST, calculados en tiempo real.
3. Generar el reporte PDF de diagnóstico completo o el export Excel del instrumento.
4. Consultar la lista de brechas priorizadas.
5. Generar un comparativo temporal entre evaluaciones de la misma organización.
