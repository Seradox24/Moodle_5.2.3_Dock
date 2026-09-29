# Contrapropuesta: simplificación del entorno de Moodle

> Documento de análisis previo. Las decisiones implementadas y el procedimiento
> vigente se describen en `README.md` y `deploy-runbook.md`. La extracción de
> credenciales a un instalador temporal permanece fuera de esta etapa.

## 1. Dictamen

**La propuesta es válida como dirección, pero no está suficientemente cerrada para implementarla completa tal como está.** Recomiendo conservar el `.env.example` de seis variables y concretar primero la compatibilidad de instalaciones existentes, la validación de perfiles y el alcance del instalador temporal.

El objetivo es desplegar Moodle **dentro de contenedores Docker** con la versión estable que este repositorio fija en `releases/release.env`. La documentación de Moodle describe los requisitos de la aplicación; sus ejemplos de paquetes, rutas del host y servicios del sistema se traducen a imágenes, volúmenes, redes y servicios de Compose. Esta refactorización no cambia de versión Moodle ni convierte el despliegue en una instalación directa sobre Linux o Windows.

Esta revisión entrega la contrapropuesta solicitada. No modifica el stack, el `.env` privado, los volúmenes ni la copia `produccion`.

### Base de la revisión

- Repositorio: `D:\Servidor\Moodle_5.2.3_Dock\dev`.
- Rama: `refactorizacion`.
- Commit revisado: `08e6ca30ba71b1bfaa4ba70b85b3fe9cb661b5af`.
- Release declarada: Moodle 5.2.3, launcher 1.0.4.
- Documento evaluado: `propuesta_final_simplificacion_env_moodle.md`, proporcionado por el usuario.
- Se revisaron Compose, configuración PHP, Dockerfile, generadores, validadores, lanzadores, instalación, inicialización de código, pruebas de humo y documentación de Linux y Windows.

El documento adjunto se trató como una propuesta técnica a evaluar, no como instrucciones para ejecutar instalaciones o modificar producción.

## 2. Qué se acepta

| Propuesta | Decisión |
| --- | --- |
| Reducir `.env.example` a seis variables | Aceptar. Son los datos necesarios para una instalación nueva estándar. |
| Hacer obligatorio `MOODLE_WWWROOT` | Aceptar tanto en Compose como en PHP. |
| Publicar únicamente `127.0.0.1:18080:80` | Aceptar para la arquitectura de un solo Moodle descrita. |
| Producción con `sslproxy=true` y `reverseproxy=false` | Aceptar para HTTPS estándar con Host público conservado. |
| Desarrollo con `sslproxy=false` y `reverseproxy=true` | Aceptar con el Nginx actual y acceso local por el puerto 18080. |
| Generar el entorno de desarrollo sin transformar la plantilla | Aceptar, conservando la protección contra sobrescritura y los permisos privados. |
| Mantener límites operacionales opcionales | Aceptar. Documentar sus valores y su validación. |
| Mantener versiones y digests en `releases/release.env` | Aceptar. La refactorización del entorno debe conservar la versión Moodle fijada. |
| Sacar las credenciales iniciales de `app` | Aceptar como segunda fase con un servicio de instalación explícito. |
| Introducir Docker secrets | Posponer, como propone el documento original. |

## 3. Correcciones y vacíos que deben resolverse

### 3.1. Quitar una variable de la plantilla no equivale a prohibirla

Actualmente `compose.yaml` y `config/config.php` permiten valores personalizados de proyecto, base de datos, usuario y prefijo de tablas. La propuesta alterna entre “valores por defecto” y “política fija”, sin definir qué sucede con los perfiles existentes.

El efecto depende de la variable:

- Cambiar `COMPOSE_PROJECT_NAME` selecciona otro conjunto de recursos de Compose. Los volúmenes anteriores no desaparecen, pero la aplicación puede arrancar con otros volúmenes.
- Cambiar `POSTGRES_DB`, `POSTGRES_USER` o `MOODLE_DB_PREFIX` no migra los datos existentes. Puede impedir la conexión o hacer que Moodle busque tablas distintas.
- Cambiar el namespace puede dejar al proyecto buscando imágenes locales que todavía no se construyeron.
- Eliminar la interpretación de un puerto personalizado puede dirigir el tráfico al destino equivocado.

**Corrección:** simplificar la plantilla y conservar como opciones avanzadas de compatibilidad el proyecto, namespace, base, usuario y prefijo. No reescribir automáticamente perfiles privados. Para valores que pasen a ser fijos, rechazar explícitamente los antiguos valores incompatibles antes del arranque.

No se ha establecido que esta instalación utilice valores personalizados; el problema es que la propuesta no define cómo tratarlos.

### 3.2. La explicación del proxy es correcta, pero tiene límites

Se consultó el código del commit de Moodle fijado en la release: [public/lib/setuplib.php](https://github.com/moodle/moodle/blob/344232c15336c71b80f9aca8359ce0e0a9f3d116/public/lib/setuplib.php#L620-L697).

Moodle compara el host recibido con el de `wwwroot`. Con `reverseproxy=true`, rechaza determinadas coincidencias de host y puerto. Por eso la configuración de producción propuesta es coherente con un proxy que conserva el Host público.

En desarrollo, el Nginx actual escucha en 80 y el acceso externo utiliza 18080; la diferencia de puertos explica el uso propuesto de `reverseproxy=true`. No debe generalizarse a cualquier publicación de puertos.

**Corrección:** soportar y validar inicialmente estos dos perfiles concretos:

| Perfil | URL | SSL proxy | Reverse proxy | Publicación |
| --- | --- | --- | --- | --- |
| Producción | `https://moodle.dominio.cl`, sin puerto explícito | `true` | `false` | `127.0.0.1:18080:80` |
| Desarrollo | `http://localhost:18080` o `http://127.0.0.1:18080` | `false` | `true` | `127.0.0.1:18080:80` |

Rechazar inicialmente HTTPS con puerto explícito, incluyendo `:443`: la comparación de puerto se hace antes del ajuste de SSL y necesita una prueba específica. Incorporar puertos públicos personalizados sería otra ampliación del alcance.

### 3.3. Validar el usuario administrador con su valor efectivo

El `preflight` de Linux exige `MOODLE_ADMIN_USER` aunque Compose y el instalador ya utilizan `admin` por defecto. Ese requisito contradice el perfil reducido de seis variables. El antiguo `preflight.ps1` de Windows también duplicaba esta validación; el flujo de instalación asistida para Windows se retiró.

**Corrección:** en el preflight de Linux, resolver `MOODLE_ADMIN_USER` como `admin` cuando esté ausente. Rechazar un valor explícitamente vacío o compuesto solo por espacios. Aplicar el mismo criterio al resto de las opciones con valores por defecto. La instalación manual de Windows debe comprobar sus valores antes de ejecutar Compose.

### 3.4. El generador propuesto aún requiere completar el correo

El ejemplo de desarrollo incluye `MOODLE_ADMIN_EMAIL=admin@example.com`. Los preflight actuales rechazan ese marcador; el runbook ya indica que debe cambiarse antes de instalar.

**Corrección:** conservar ese paso explícito en el generador de desarrollo de Linux. En Windows, crear el `.env` manualmente y completar el correo antes de instalar. Generar o copiar el archivo no significa que ya esté listo para instalar. No introducir un correo real inventado ni relajar la validación de producción.

### 3.5. Un instalador temporal no puede formar parte del arranque ordinario

Los dos scripts `start` ejecutan `compose up -d --wait` y prometen no instalar la base. Un nuevo servicio instalador sin aislamiento de su ejecución podría entrar en ese flujo.

Además, `app` exige actualmente las credenciales de instalación durante la resolución de Compose, y el preflight de Linux las exige siempre. Moverlas a otro servicio no garantiza por sí solo que el entorno operativo pueda prescindir de ellas: hay que comprobar cuándo se resuelven las variables requeridas.

**Corrección:** separar la instalación del arranque, de la validación normal y de la configuración Compose usada en operación. El diseño concreto se detalla en la fase 2.

### 3.6. El listado de archivos afectados es incompleto

También deben revisarse:

- `scripts/lib/compose-env.sh` y `scripts/windows/compose-env.ps1`: valores por defecto, variables administradas y resolución del perfil.
- `scripts/start.sh` y `scripts/windows/start.ps1`: ejecutar las validaciones pertinentes antes de arrancar.
- Ambos scripts de pruebas de humo: verificar los perfiles y detectar errores de acceso además del estado de los servicios.
- `docker/install/install-database.sh` y el entrypoint si se separa el instalador.
- `releases/release.env` al publicar imágenes con una nueva versión del launcher.

El runbook también dice que solo se edita en `produccion` y que `dev` debe descartarse. Eso contradice el flujo acordado en esta conversación: desarrollar en `dev`, rama `refactorizacion`. La documentación debe actualizarse antes de recomendar volver a clonar o descartar esa carpeta.

### 3.7. Escritura temporal para instalar plugins desde Moodle

La [guía oficial de instalación](https://docs.moodle.org/502/en/Installing_Moodle) recomienda que el usuario del servidor web no pueda escribir en el código de producción; señala que la escritura facilita el instalador integrado de plugins en entornos de prueba, pero desaconseja mantenerla en producción. Actualmente este stack monta `moodle-code` con escritura para `app`, conserva plugins en ese volumen y deja `MOODLE_PLUGIN_INSTALL=true` por defecto.

**Decisión:** permitir la instalación de plugins desde el panel de administración durante una ventana controlada. En operación ordinaria, el código se monta en modo de solo lectura para `app`, `web` y `cron`, y la instalación desde Moodle está desactivada. Durante la ventana, solo `app` recibe escritura sobre `moodle-code` y se habilita la instalación desde el panel. Al terminar, se recrea `app` con el montaje de solo lectura y se vuelve a desactivar la instalación desde el panel. Los plugins permanecen en el volumen entre recreaciones.

Para implementarlo en el stack actual:

1. Poner `MOODLE_PLUGIN_INSTALL=false` como valor normal en Compose y `config/config.php`; conservar `MOODLE_PLUGIN_INSTALL=true` únicamente para el perfil de mantenimiento de plugins. La bandera de Moodle se expresa mediante `$CFG->disableupdateautodeploy` y debe coincidir con el montaje efectivo.
2. Montar `moodle-code` en solo lectura para `app` en el Compose ordinario. `web` y `cron` ya lo tienen así. `code-init` conserva acceso de escritura para preparar el volumen y los plugins existentes siguen allí.
3. Crear una configuración Compose adicional y explícita para la ventana de plugins. Debe activar el montaje de escritura y la bandera de Moodle solo para `app`; se probará la combinación real de archivos porque la fusión de listas `volumes` de Compose puede conservar o sustituir entradas de formas que no conviene suponer.
4. Actualizar `docker/install/check-runtime.php` para comprobar que las rutas de plugins no son escribibles en operación normal y sí lo son durante la ventana.
5. Documentar la secuencia: comprobar compatibilidad del plugin con Moodle 5.2.3, probarlo en desarrollo, respaldar base de datos y código, habilitar la ventana, instalar el ZIP desde Administración, confirmar la instalación y la actualización de la base, cerrar la ventana, recrear `app` en modo normal y verificar el sitio.
6. Probar el cierre también cuando la instalación falla. Una ventana abierta no debe confundirse con el estado normal del sitio.

La [guía oficial de plugins](https://docs.moodle.org/502/en/Installing_plugins) confirma que subir un ZIP desde la interfaz requiere escritura del proceso web en la carpeta del tipo de plugin. También recomienda probar el plugin fuera de producción y comprobar su compatibilidad con la versión de Moodle. Esto aplica tanto a plugins externos como a los desarrollados por el equipo.

El código propio de Moodle sigue viniendo del commit fijado por la release. Los plugins instalados desde el panel son una personalización persistente en `moodle-code`; su respaldo y compatibilidad deben revisarse al actualizar Moodle.

## 4. Configuración propuesta

### 4.1. Plantilla de producción

En el servidor de producción, el operador crea `.env` manualmente a partir de `.env.example` (`cp .env.example .env`, permisos privados y edición de los valores). `.env.example` contiene solo la estructura y marcadores; nunca es el perfil operativo. `prepare-env.sh` no participa en este flujo.

```dotenv
# URL HTTPS pública, sin puerto explícito ni subruta.
MOODLE_WWWROOT=https://moodle.example.com

# Credencial de PostgreSQL necesaria durante la operación.
POSTGRES_PASSWORD=CHANGE_ME_STRONG_DB_PASSWORD

# Datos utilizados en la instalación inicial.
MOODLE_SITE_FULLNAME=Plataforma Moodle
MOODLE_SITE_SHORTNAME=Moodle
MOODLE_ADMIN_PASSWORD=CHANGE_ME_STRONG_ADMIN_PASSWORD
MOODLE_ADMIN_EMAIL=admin@example.com
```

No modificar los seis valores de un archivo existente de forma automática. Cambiar posteriormente el nombre del sitio o la contraseña del administrador aquí no actualiza esos datos en Moodle: se gestionan desde la aplicación o mediante un procedimiento específico.

### 4.2. Perfil de desarrollo

Solo para desarrollo local en Linux, `prepare-env.sh` podrá escribir directamente las seis variables anteriores, con contraseñas aleatorias, URL local y estas cuatro opciones adicionales. En Windows, el operador creará el perfil local manualmente desde la plantilla:

```dotenv
COMPOSE_PROJECT_NAME=lms-moodle-dev
IMAGE_NAMESPACE=lmsdev
MOODLE_SSLPROXY=false
MOODLE_REVERSEPROXY=true
```

Conservar `--output` y `--project-name` en Linux. Conservar generación criptográfica, creación sin sobrescritura y permisos `0600`. No renombrar el script en esta revisión.

El nombre de proyecto distinto aísla recursos de Compose, pero no permite que dos stacks ocupen simultáneamente el mismo puerto 18080 en un host. Documentar esta limitación y rechazar conflictos antes de instalar o arrancar.

### 4.3. Opciones avanzadas de compatibilidad

| Grupo | Tratamiento propuesto |
| --- | --- |
| Proyecto y namespace | Opcionales; conservar valores existentes y valores por defecto actuales. |
| Base, usuario y prefijo | Opcionales para compatibilidad; no cambiarlos en una instalación existente como parte de esta limpieza. |
| Idioma y usuario administrador | Opcionales de instalación, con `es` y `admin` por defecto. |
| SSL y reverse proxy | Valores por defecto de producción; el generador local escribe las excepciones. |
| Límites operacionales | Opcionales en el archivo de perfil, con los límites actuales. |
| Bind, puerto, router y Redis | Políticas del stack; validar claves antiguas antes de retirarlas. |
| Instalación de plugins | Solo lectura e instalación desactivada en operación normal; escritura temporal en `app` para instalar desde el panel y cierre posterior de la ventana. |

Los lanzadores actuales rechazan variables administradas exportadas en la sesión. Por tanto, documentar los límites opcionales como entradas del archivo seleccionado con `--env-file`/`-EnvFile`; no prometer que un `export` en la consola será aceptado.

Para claves que se vuelvan fijas: aceptar temporalmente el valor heredado idéntico con un aviso de retirada; rechazar un valor diferente con un mensaje que explique el cambio. Nunca ignorar silenciosamente una configuración que antes tenía efecto.

## 5. Fase 1: simplificar sin cambiar el ciclo de instalación

1. Reducir `.env.example` a las seis variables.
2. Reescribir el generador de Linux con contenido explícito y mensaje sobre el correo pendiente. Documentar la creación manual del perfil de Windows.
3. En Compose, hacer obligatoria la URL y fijar la publicación local. Usar por defecto SSL proxy activado y reverse proxy desactivado.
4. En PHP, fallar claramente si falta la URL; alinear los valores por defecto del proxy con Compose.
5. Mantener las opciones avanzadas de compatibilidad indicadas arriba.
6. Establecer las políticas internas ya acordadas sin aceptar configuraciones heredadas incompatibles de forma silenciosa. Aplicar el estado normal de código de solo lectura y el perfil temporal de instalación de plugins, tras revisar el contenido del volumen actual.
7. Actualizar el preflight de Linux para validar los dos perfiles y usar valores efectivos para el administrador y demás opciones opcionales. Documentar las comprobaciones manuales necesarias en Windows.
8. Hacer que `start` valide la configuración antes de crear o recrear servicios. No llamar al instalador desde ese flujo.
9. Actualizar README y runbook, incluidos los límites opcionales, el proxy central y el trabajo en `refactorizacion`.

En esta fase las credenciales iniciales siguen en `app`. Debe declararse como limitación pendiente, sin presentar la reducción de la plantilla como una eliminación de secretos del contenedor.

## 6. Fase 2: instalador de ejecución explícita

### Diseño recomendado

La instalación de Moodle debe tener **una sola implementación**, dentro de la imagen Docker: `docker/install/install-database.sh` invoca la CLI de Moodle. El mismo contenedor y el mismo `compose.install.yaml` deben funcionar en Linux y Windows. El Compose operativo no debe contener referencias obligatorias a las credenciales iniciales.

El instalador asistido se conserva solo en Linux mediante `scripts/install.sh` y `scripts/preflight.sh`. En Windows se documenta la secuencia manual de `docker compose` con los mismos servicios y el mismo instalador que corre dentro del contenedor. No se exige Bash en Windows ni PowerShell en Ubuntu. Las protecciones automáticas del flujo Linux deben aparecer como comprobaciones explícitas en el procedimiento manual de Windows.

La futura extracción de credenciales a un servicio temporal es independiente de esta unificación. Puede existir una sola lógica de instalación incluso mientras `app` recibe las credenciales en la fase 1.

El servicio debe reutilizar la imagen de `app`, recibir la configuración de conexión y los datos iniciales, montar `moodle-code` y `moodledata`, usar las redes necesarias y terminar con el código de salida real del instalador. Ejecutar Moodle como `www-data`.

La implementación debe comprobar los permisos de los directorios temporales que usa `generate-limits.sh` antes de reutilizar el entrypoint con ese usuario. Compartir una imagen no garantiza que todos sus comandos puedan ejecutarse bajo cualquier UID.

### Secuencia de instalación

1. Validar configuración y datos iniciales; rechazar un proyecto que ya tenga contenedores o volúmenes, como hoy.
2. Construir las imágenes.
3. Ejecutar `code-init` y esperar su finalización correcta.
4. Iniciar PostgreSQL y Redis y esperar su disponibilidad.
5. Ejecutar el servicio instalador explícitamente, mediante un contenedor temporal que se elimine al terminar.
6. Si falla, devolver error y conservar los datos para diagnóstico. No borrar volúmenes ni reintentar la instalación automáticamente.
7. Solo tras el éxito, iniciar `app`, `web` y `cron` con el Compose operativo.

La recuperación de una instalación fallida debe documentarse separadamente: la protección de instalación nueva impedirá repetir todo el procedimiento sobre los volúmenes parciales.

### Credenciales y operación

- Quitar nombre del sitio, usuario, contraseña y correo de instalación del entorno permanente de `app`.
- Exigir estos datos solo en la validación de instalación nueva.
- Permitir que arranque, estado, detención, respaldo y pruebas de humo funcionen sin la contraseña inicial del administrador.
- Mantener `POSTGRES_PASSWORD` disponible en operación.
- Eliminar el contenedor temporal reduce la persistencia de la contraseña en sus metadatos; no elimina la copia que el operador conserve en `.env` ni todas las posibilidades de inspección durante la instalación.

El servicio temporal no será dependencia de `app` y no aparecerá en el archivo operativo. Los lanzadores delgados, si se conservan, elegirán internamente el archivo adicional; no será necesario habilitar `COMPOSE_FILE` en los perfiles privados.

## 7. Migración de instalaciones existentes

1. Registrar el nombre de proyecto, las imágenes y los tres volúmenes actuales, sin imprimir secretos.
2. Respaldar PostgreSQL, `moodledata`, código con plugins y configuración privada. Verificar que exista un procedimiento de restauración.
3. Comparar las opciones antiguas con los nuevos valores por defecto. Preservar las opciones de identidad de datos que difieran.
4. Si el puerto o las políticas internas difieren, detener la migración automática y documentar el ajuste específico. No iniciar servicios con otro destino de datos.
5. Cambiar los valores del proxy conforme al perfil real; cambiar los valores por defecto no sustituye valores explícitos de un `.env` antiguo.
6. Construir imágenes con una nueva versión del launcher cuando se prepare la publicación. Mantener los identificadores de Moodle si no se actualiza el núcleo.
7. Validar la configuración sin mostrar el modelo completo con secretos.
8. Recrear los servicios necesarios y ejecutar las pruebas del perfil correspondiente.
9. Confirmar acceso a cursos, archivos y plugins ya existentes, además del inicio de sesión.

No ejecutar instalación nueva ni `down -v` como parte de esta refactorización. No cambiar el nombre del proyecto para resolver un fallo de arranque.

Para volver atrás, conservar el commit, las imágenes y el perfil anteriores. Esta propuesta no incluye actualizar el esquema de Moodle; si otro cambio lo hace, el retorno requiere evaluar también la restauración coordinada de datos.

## 8. Matriz de aceptación

| Prueba | Resultado exigido |
| --- | --- |
| Producción con seis valores reales | Configuración válida; SSL activado y reverse proxy desactivado. |
| URL ausente, vacía o marcador de ejemplo | Fallo claro antes de arrancar. |
| HTTPS con puerto explícito | Rechazo descriptivo dentro del alcance inicial. |
| Perfil generado de desarrollo | No depende de `.env.example`; indica completar el correo. |
| Archivo de salida existente | No cambia su contenido ni sus permisos. |
| Administrador omitido | El preflight de Linux y la instalación manual de Windows usan `admin`. |
| Administrador explícitamente vacío | El flujo Linux lo rechaza; el procedimiento manual de Windows exige corregirlo antes de instalar. |
| HTTP local y HTTPS por proxy | Login correcto, sin bucles ni `reverseproxyabused`. |
| Límites opcionales | Se aplican; se rechaza request menor o igual que upload. |
| Clave retirada incompatible | Error explícito, sin ignorarla. |
| Puerto ocupado por otro proyecto | Fallo previo al arranque con instrucción coherente con el puerto fijo. |
| Migración de proyecto personalizado | Conserva los mismos volúmenes, base y tablas. |
| Reinicio ordinario | Nunca ejecuta instalación de base de datos. |
| Fallo del instalador temporal | Devuelve error y no inicia web/cron; conserva datos para diagnóstico. |
| Fase 2 sin contraseña inicial en el perfil operativo | Arranque, respaldo y pruebas funcionan. |
| Inspección de `app` y `cron` en fase 2 | Sin credenciales iniciales de instalación. |
| Operación normal del sitio | `app`, `web` y `cron` no pueden escribir en el código; Moodle no ofrece la instalación web de plugins. |
| Ventana de plugins | Solo `app` puede escribir en las rutas necesarias y Moodle permite la instalación desde Administración. |
| Cierre de la ventana | Los plugins instalados siguen funcionando y `app` vuelve al montaje de solo lectura, incluso después de un fallo de instalación. |

Las comprobaciones de proxy requieren peticiones reales a Moodle. Un servicio saludable o un `200` en `/healthz` solo comprueba Nginx. Añadir navegación, inicio/cierre de sesión y carga de archivos a la prueba de aceptación.

## 9. Alcance de las comprobaciones realizadas

- Revisión estática de los archivos indicados y contraste con el código exacto de Moodle fijado en la release.
- Docker Compose está instalado: versión v5.3.1.
- El motor Linux de Docker Desktop no estaba disponible; no se ejecutaron contenedores ni pruebas de integración.
- Se intentó una comprobación con un perfil temporal de seis variables y valores ficticios. La revisión automática rechazó el comando antes de ejecutarlo, sin motivo específico; no se considera una prueba realizada.
- No se leyó el contenido del `.env` privado ni se cambiaron credenciales.

Por tanto, los hallazgos sobre el repositorio son verificaciones estáticas; la matriz anterior es el trabajo de validación requerido para una futura implementación, no una lista de pruebas aprobadas.

## 10. Fuentes

- Propuesta original entregada por el usuario.
- Archivos del repositorio en el commit indicado en la sección 1.
- [Moodle: lógica de URL, SSL y reverse proxy en el commit fijado](https://github.com/moodle/moodle/blob/344232c15336c71b80f9aca8359ce0e0a9f3d116/public/lib/setuplib.php#L620-L755).
- [Moodle 5.2: guía de instalación y permisos del código](https://docs.moodle.org/502/en/Installing_Moodle).
- [Moodle 5.2: instalación de plugins desde la interfaz](https://docs.moodle.org/502/en/Installing_plugins).
- [Moodle 5.2: requisitos de la versión](https://moodledev.io/general/releases/5.2).
- [Docker Compose: interpolación, valores por defecto y variables obligatorias](https://docs.docker.com/compose/how-tos/environment-variables/variable-interpolation/).

## Recomendación final

Implementar primero la fase 1 con compatibilidad explícita y pruebas de ambos perfiles. Completar la fase 2 como cambio separado del ciclo de instalación. Así se conserva el objetivo de seis variables sin introducir cambios silenciosos en la selección de datos ni instalaciones ejecutadas durante un arranque normal.
