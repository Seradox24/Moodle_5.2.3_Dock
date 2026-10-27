# Instrucciones del componente Moodle

- Leer README.md y deploy-runbook.md. Este repositorio es reutilizable: no incorporar valores reales de proyectos, dominios, IP, rutas privadas ni secretos al código o ejemplos.
- Cada instalación selecciona un perfil privado con --env-file. Usar opciones existentes antes de añadir variables; conectar consumidores, preflight, lista de variables administradas y documentación en el mismo cambio.
- Las versiones e imágenes pertenecen a releases/release.env y permanecen fijadas. Revisar compatibilidad y avisos oficiales antes de publicar una release de seguridad.
- Mantener el puerto web en loopback detrás del proxy del host; no publicar PostgreSQL, Redis ni PHP. El generador de Nginx consume el perfil efectivo, no nombres de proyectos.
- No cambiar COMPOSE_PROJECT_NAME, identidades persistentes ni volúmenes de una instalación existente como efecto lateral. Nunca usar down -v en producción.
- Datos iniciales de sitio y administrador no se actualizan editando el perfil. Las rotaciones de contraseñas requieren cambiar el consumidor persistente y el perfil coordinadamente.
- Validar sintaxis shell y ejecutar python3 tests/profiles.py en Linux con Compose. Las pruebas funcionales y restauraciones usan un proyecto aislado y nunca datos de demostración en producción.
- Trabajar en rama y PR; describir verificaciones realmente realizadas. El estado de una instalación se registra fuera del repositorio reutilizable. No confundir un merge con un despliegue verificado.
- No imprimir secretos, perfiles completos, Docker inspect completo ni argumentos de procesos que puedan contener credenciales. El instalador PHP construye argumentos sensibles dentro del proceso.
