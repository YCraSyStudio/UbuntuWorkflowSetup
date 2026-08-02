# UbuntuWorkflowSetup

Instalador interactivo para preparar un equipo Ubuntu con aplicaciones de
desarrollo, productividad y extensiones de GNOME.

El script permite elegir qué componentes instalar y automatiza la actualización
del sistema, la configuración de repositorios, la instalación de paquetes y
algunas tareas posteriores de limpieza.

## Requisitos

- Ubuntu 24.04 o una versión posterior.
- Una cuenta con permisos de `sudo`.
- Conexión a Internet.
- Una terminal interactiva para poder utilizar el selector de aplicaciones.

El instalador solo admite Ubuntu. Antes de realizar cambios comprueba el sistema
operativo y detiene la ejecución si la versión no es compatible.

## Uso

Clona el repositorio y entra en su directorio:

```bash
git clone https://github.com/YarCrasy/UbuntuWorkflowSetup.git
cd UbuntuWorkflowSetup
```

Ejecuta el instalador:

```bash
bash main.sh
```

Al comenzar se solicitará la contraseña de `sudo` y aparecerá el selector de
aplicaciones.

## Controles del selector

| Tecla | Acción |
| --- | --- |
| `↑` / `↓` | Moverse por las opciones |
| Rueda del ratón | Moverse por las opciones |
| `Espacio` | Seleccionar o deseleccionar una opción |
| `T` | Seleccionar todo |
| `N` | Deseleccionar todo |
| `Enter` | Confirmar la selección y comenzar |

Todas las opciones aparecen seleccionadas inicialmente. Node.js y GNOME
Extension Manager incluyen opciones dependientes indentadas en el menú. Al
seleccionar una dependencia también se selecciona su componente principal.

Si se ejecuta sin una terminal interactiva, el instalador seleccionará todas las
aplicaciones automáticamente.

## Aplicaciones disponibles

### Herramientas de desarrollo

- Docker
- .NET SDK
- MySQL
- Unity Hub
- Visual Studio Code
- DBeaver
- Bruno, para explorar y probar APIs
- Node.js
  - npm
  - Angular CLI
  - npm-check-updates
- Codex CLI
- GitHub CLI
- Atlassian CLI

### Productividad

- yEd
- Chromium
- Google Chrome
- Telegram Desktop

### Otros

- GNOME Extension Manager
  - Copyous
  - Dash to Panel

## Qué hace el instalador

Después de confirmar la selección, el script:

1. Actualiza los paquetes de Ubuntu.
2. Elimina algunas aplicaciones preinstaladas no deseadas.
3. Instala las herramientas base necesarias.
4. Configura los repositorios externos de las aplicaciones seleccionadas.
5. Instala los paquetes APT y las aplicaciones Snap.
6. Instala y configura las herramientas de Node.js seleccionadas.
7. Instala Codex CLI, yEd y las extensiones de GNOME seleccionadas.
8. Activa los servicios de Docker y MySQL cuando corresponda.
9. Elimina paquetes que ya no sean necesarios.
10. Muestra las versiones instaladas y ofrece reiniciar el equipo.

## Avisos importantes

El script modifica el sistema y utiliza `sudo`. Antes de ejecutarlo, ten en
cuenta que:

- Actualiza todos los paquetes mediante `apt upgrade`.
- Elimina Firefox, la documentación de GNOME, Yelp y Vim si están instalados.
- Ejecuta `apt autoremove --purge` al finalizar.
- Si seleccionas Docker, añade el usuario actual al grupo `docker`.
- Descarga software y claves de repositorios desde sus proveedores oficiales.
- La instalación de NVM y Codex CLI ejecuta scripts descargados de Internet.

Revisa el código y guarda tu trabajo antes de usarlo en un equipo importante.
El instalador muestra una confirmación separada antes de reiniciar.

## Versiones configurables

Se pueden cambiar algunas versiones mediante variables de entorno. Por ejemplo:

```bash
DOTNET_VERSION=10.0 NODE_VERSION=24 bash main.sh
```

Variables disponibles:

| Variable | Valor predeterminado |
| --- | --- |
| `DOTNET_VERSION` | `10.0` |
| `NODE_VERSION` | `24` |
| `NVM_VERSION` | `v0.40.5` |
| `NPM_MAJOR_VERSION` | `12` |
| `ANGULAR_MAJOR_VERSION` | `22` |
| `NCU_MAJOR_VERSION` | `22` |
| `YED_VERSION` | `3.25.1` |

## Después de la instalación

Dependiendo de las opciones elegidas, puede ser necesario:

- Cerrar la sesión para aplicar la pertenencia al grupo de Docker y cargar las
  extensiones de GNOME.
- Comprobar en Extension Manager que las extensiones estén activadas.
- Iniciar sesión en Visual Studio Code para sincronizar su configuración.
- Ejecutar `codex --version` para comprobar Codex CLI.
- Instalar el editor de Unity desde Unity Hub.

## Solución de problemas

Si el proceso se interrumpe, corrige el error indicado y vuelve a ejecutar
`bash main.sh`. Las operaciones principales comprueban si ciertos componentes ya
están instalados o configurados, por lo que el script puede volver a ejecutarse.

Para revisar errores de sintaxis sin modificar el sistema:

```bash
bash -n main.sh src/*.sh
```
