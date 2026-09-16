# Pruebas locales en Windows

Perfil de prueba para levantar el stack en Windows (Docker Desktop) sin tocar la
configuración de producción.

## Nombres usados (limpieza fácil)

| Elemento | Valor |
|---|---|
| Proyecto Compose | `lms-moodle-dev` |
| Contenedores/redes/volúmenes | `lms-moodle-dev_*` |
| Imágenes | `lmsdev/moodle-web:5.2.3`, `lmsdev/moodle-app:5.2.3` |
| Endpoint | `http://localhost:18080` (solo `127.0.0.1`) |

Producción (servidor) usa otros nombres que este perfil no toca:
`lms-moodle` y `lms/moodle-*`.

## Archivos

- `.env.windows`: perfil de prueba (versionado; credenciales solo de test).
- `.env.server`: valores reales de producción (copia local, no versionada).
- `.env`: archivo activo que lee Docker Compose (ignorado por Git).

## Levantar

```powershell
Copy-Item .env.windows .env -Force
powershell -ExecutionPolicy Bypass -File .\scripts\windows\install.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\windows\smoke-test.ps1
```

Acceso: `http://localhost:18080` (usuario `admin` y la contraseña definida en
`.env.windows`). Requiere Docker Desktop iniciado y el puerto 18080 libre.

## Volver al perfil de producción

```powershell
Copy-Item .env.server .env -Force
```

## Limpieza completa del perfil de prueba

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\windows\clean-test.ps1
```

El script verifica que el proyecto activo sea `lms-moodle-dev` y elimina
contenedores, redes y volúmenes `lms-moodle-dev_*` y las imágenes `lmsdev/*`.
Nunca toca `lms-moodle_*` ni `lms/moodle-*` (producción).

Limpieza manual equivalente:

```powershell
docker compose down -v --remove-orphans
docker image rm lmsdev/moodle-web:5.2.3 lmsdev/moodle-app:5.2.3
```

## Notas

- Las imágenes base (`postgres`, `redis`, `php`, `nginx`) se comparten con otros
  stacks del equipo y no se eliminan.
- `code-init` termina en `Exited (0)`; es normal.
- El perfil de producción para el servidor se documenta en
  `production-config.md` y el despliegue en `deploy-runbook.md`.
