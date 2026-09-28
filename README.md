# Moodle 5.2.3 con Docker

Repositorio para instalar Moodle 5.2.3 desde cero con Docker Compose. Incluye
Nginx, PHP-FPM, PostgreSQL, Redis y el proceso programado de Moodle. Las
versiones y referencias de las imágenes están fijadas en
`releases/release.env`.

La guía paso a paso, los requisitos y las opciones de configuración están en
**[deploy-runbook.md](deploy-runbook.md)**.

## Organización del trabajo

En el equipo Windows se usan dos carpetas:

```text
D:\Servidor\Moodle_5.2.3_Dock\
├── produccion\   ← repositorio principal; aquí se editan y publican cambios
└── dev\          ← clon de GitHub para probar la revisión publicada
```

GitHub `main` es la fuente de la revisión que se prueba y se despliega. El
clon `dev` puede recrearse desde GitHub; su archivo de entorno privado no se
publica. Las guías antiguas se guardan fuera del repositorio, en
`D:\Servidor\documentacion general\Moodle`.

## Prueba local en Windows

Requiere Docker Desktop con contenedores Linux, Git y PowerShell. Dentro del
clon `dev`:

```powershell
.\scripts\windows\prepare-env.ps1
# Revisar environments/local.env y cambiar MOODLE_ADMIN_EMAIL.
.\scripts\windows\preflight.ps1 -EnvFile environments/local.env
.\scripts\windows\install.ps1 -EnvFile environments/local.env
.\scripts\windows\smoke-test.ps1 -EnvFile environments/local.env
```

La URL de prueba es `http://localhost:18080`. `install.ps1` instala una base
nueva. Para volver a empezar con datos vacíos, seguir el procedimiento de
limpieza de [deploy-runbook.md](deploy-runbook.md) antes de reinstalar.

## Despliegue en Ubuntu

Clonar `main` en `/srv/plataforma/moodle`, copiar `.env.example` a `.env`
y completar las contraseñas, la identidad del sitio, el correo del administrador
y la URL pública. Preparar Nginx y el certificado de esa URL antes de abrir el
sitio. Después:

```bash
sh ./scripts/preflight.sh
sh ./scripts/install.sh
sh ./scripts/smoke-test.sh
```

El archivo `.env` no se sube a Git. La base de datos, `moodledata` y el código
compartido viven en volúmenes Docker; hacer copias de seguridad antes de
actualizar o retirar esos volúmenes. `scripts/backup.sh` crea una copia local
que también debe guardarse fuera del servidor.

## Estado verificado

La revisión publicada se instaló desde cero en el clon de Windows. La prueba
confirmó Moodle 5.2.3, PostgreSQL, Redis, permisos de plugins y respuesta HTTP
200 en la página de acceso. El entorno de prueba se retiró después; este
repositorio aún no está desplegado en producción.
