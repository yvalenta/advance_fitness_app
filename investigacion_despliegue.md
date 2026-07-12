# Investigación de Despliegue: Advance Fitness App

## 1. Arquitectura de Despliegue Actual
Basado en la configuración del repositorio y la información proporcionada (Cloudflare y variables de entorno), la infraestructura se compone de la siguiente manera:

- **Servidor de Aplicación (Homelab):** La aplicación está desplegada en un servidor local (homelab) con la IP interna `192.168.0.1`, según se define en el archivo `config/deploy.yml`.
- **Exposición a Internet (Cloudflare Tunnel):** El tráfico público hacia `https://advance-fitness-app.ynt.codes/` es gestionado por Cloudflare. Utilizas un **Cloudflare Tunnel** llamado `homelab-tunnel` que conecta de forma segura tu servidor local con la red de Cloudflare (Origen IP `206.62.143.251`), lo que permite exponer la aplicación sin abrir puertos en el firewall/router de tu red local.
- **Base de Datos (Supabase):** La aplicación utiliza una base de datos PostgreSQL alojada externamente en Supabase. El archivo `.env` muestra que se conecta a través de su pooler de conexiones en AWS (`aws-1-us-east-2.pooler.supabase.com`).
- **Orquestador de Despliegues (Kamal):** Utilizas **Kamal** (previamente llamado MRSK, herramienta de Basecamp/37signals) para empaquetar la aplicación Rails en contenedores Docker y gestionar su ciclo de vida en el servidor.

## 2. Proceso de Despliegue Manual

Dado que el proyecto utiliza Kamal y el archivo `.github/workflows/ci.yml` está configurado únicamente para Integración Continua (testing y linting), el proceso de despliegue se realiza manualmente desde una máquina con acceso a la red local.

Para realizar un despliegue manual, debes seguir estos pasos:

### Prerrequisitos:
1. **Docker:** Debes tener Docker instalado y ejecutándose en la máquina desde la cual harás el despliegue (Kamal lo utiliza para construir la imagen Docker localmente).
2. **Acceso SSH:** Tu máquina debe tener acceso SSH al servidor de destino (`192.168.0.1`).
3. **Secretos de Kamal:** Debes asegurarte de tener el archivo `.kamal/secrets` correctamente configurado en tu máquina local con las credenciales necesarias (como el `RAILS_MASTER_KEY` o las contraseñas del registro de contenedores).
4. **Registro de Contenedores:** Según `deploy.yml`, estás apuntando a `localhost:5555` como registro de contenedores. Asegúrate de que ese registro esté accesible y configurado durante el proceso.

### Comandos Principales de Despliegue (usando Kamal):

1. **Despliegue de actualización (Deploy estándar):**
   Si has realizado cambios en tu código en la rama `main` y quieres aplicarlos en producción, debes ejecutar el siguiente comando desde la raíz del proyecto:
   ```bash
   kamal deploy
   ```
   *Kamal se encargará automáticamente de: construir la nueva imagen Docker, subirla al registro de contenedores, descargarla en el servidor (`192.168.0.1`), iniciar un nuevo contenedor de Rails, enrutar el tráfico al nuevo contenedor sin tiempo de inactividad, y detener el contenedor antiguo.*

2. **Despliegue inicial (Setup):**
   Si tuvieras que aprovisionar un servidor completamente nuevo, el comando a utilizar sería:
   ```bash
   kamal setup
   ```
   *Este comando instala Docker en el servidor remoto, configura los accesorios (si los hubiera) y luego realiza un despliegue completo.*

3. **Comandos Útiles de Kamal definidos en `deploy.yml`:**
   Tienes configurados algunos atajos (aliases) para facilitar tareas administrativas en producción:
   - **Ver logs de producción:** `kamal logs` (Equivale a `kamal app logs -f`)
   - **Abrir la consola de Rails en producción:** `kamal console`
   - **Abrir una terminal Bash en el contenedor de producción:** `kamal shell`
   - **Abrir la consola de base de datos:** `kamal dbc`

## 3. Resumen del Flujo de Peticiones
Para entender la topología completa:
1. Un usuario accede a `https://advance-fitness-app.ynt.codes/`.
2. Cloudflare recibe la petición y, gracias al **homelab-tunnel**, envía el tráfico de forma cifrada directamente a tu servidor local.
3. En el servidor local (`192.168.0.1`), el proxy inverso de Kamal recibe la petición y se la pasa al contenedor Docker de la aplicación Rails activo en ese momento.
4. El contenedor de Rails procesa la lógica y se comunica con la base de datos externa de Supabase para obtener o guardar datos.
