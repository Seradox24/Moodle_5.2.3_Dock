# Estado de preparación para producción

Revisión del 30 de septiembre de 2026, rama `refactorizacion`. E-learning SOM quedó operativo en `https://moodle.minayao.site`, con correo `noreply@minayao.site`, SMTP configurado y acceso de la app móvil desactivado. El servidor sigue siendo un ensayo: faltan la prueba de entrega de correo y las comprobaciones operativas indicadas abajo antes de incorporar usuarios.

## Comprobado

| Área | Resultado |
| --- | --- |
| Revisión instalada | Instalación limpia sobre `5f6adf8`; correcciones posteriores probadas sobre `01ba777`, launcher 1.0.6 y Moodle 5.2.3. `.env` privado de seis campos con permisos `0600`. |
| Instalación | `preflight.sh`, construcción, `install.sh`, `smoke-test.sh` y `start.sh` pasaron. PostgreSQL, Redis, `app`, `web` y cron están activos; reiniciar no reinstaló la base. |
| HTTPS | DNS apunta al servidor, certificado válido emitido para el subdominio y Nginx central entrega Moodle por HTTPS. La prueba externa de inicio de sesión devolvió HTTP 200; HTTP redirige a HTTPS. |
| Funciones normales | Inicio de sesión de administrador, creación de usuario y curso, carga y lectura de archivo, y limpieza de datos temporales aprobados. El código de `app` continúa en solo lectura. |
| Respaldo | `backup.sh` generó siete archivos íntegros. Se verificaron sus hashes tanto en el servidor como en una copia local fuera de él. |
| Recuperación | Base, `moodledata` y código restaurados en un proyecto Compose aislado; comprobaciones de runtime y funciones normales aprobadas. Se eliminó solo el proyecto aislado. |
| SMTP | `pro.turbo-smtp.com:465`, SSL y LOGIN; certificado TLS verificado y autenticación aceptada (235). Sin envío de mensajes en esta prueba. |
| App móvil | `enablemobilewebservice=0` y servicio oficial móvil deshabilitado. El navegador móvil sigue disponible. El ajuste se puede modificar después de instalar. |
| Navegador | Cuenta temporal sin permisos administrativos: carga de archivo de 64 bytes, guardado en archivos privados y descarga. SHA-256 coincide con el original. El selector quedó esperando tras la carga; se completó mediante Archivos recientes. Usuario y archivos temporales limpiados. |
| Seguridad | El informe pasó las rutas internas después de corregir Nginx siguiendo la guía oficial. Queda el aviso del rol con permiso para respaldar datos de usuarios. Las comprobaciones CLI de estado pasaron después de corregir la frecuencia de cron. |
| Host | Docker 29.8.1 y Compose 5.5.1 coinciden con los candidatos del repositorio oficial. Socket Docker `0660 root:docker`, grupo sin miembros adicionales; `.env` `0600`. Puerto 18080 solo en localhost y base/Redis sin puertos públicos. Aproximadamente 87 GB de disco y 6 GB de RAM disponibles. |

El ZIP de `mod_customcert` se probó en el sitio de desarrollo anterior. La instalación limpia pública aún no incluye ese plugin.

## Pendiente antes de recibir usuarios

1. Comprobar entrega efectiva del SMTP, recuperación de contraseña y notificaciones con una bandeja de entrada indicada por el operador. La autenticación aceptada no prueba la entrega.
2. La política de respaldos queda aplazada por instrucción del operador. Las copias y la restauración ensayada siguen documentadas, sin programar una política nueva.
3. Aplicar en una ventana de mantenimiento las tres actualizaciones de OpenSSL detectadas después de refrescar los índices de Ubuntu. Falta definir usuarios concurrentes y ejecutar una prueba de carga; el espacio disponible no garantiza capacidad para una carga desconocida. Revisar el aviso de permisos de respaldo del rol docente y el comportamiento del selector de carga antes de incorporar usuarios.
4. La contraseña administrativa solicitada para esta prueba es numérica y no cumple la política fuerte de Moodle, que permanece habilitada. Cambiarla antes de admitir usuarios reales. La contraseña inicial permanece en el entorno de `app`; restringir acceso al host, Docker y `.env`.

El `.env`, las credenciales SMTP vigentes y el procedimiento para aplicar los ajustes tras reinstalar se guardaron fuera de Git en `D:\Servidor\documentacion general\Moodle`, con permisos restringidos para los archivos privados.

El registro detallado, incluido el 503 temporal durante el desafío del certificado y la restauración, está en [validation-log.md](validation-log.md).
