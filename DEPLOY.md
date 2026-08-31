# Despliegue — Advance Fitness App

Guía del proceso real de despliegue a producción, usado desde la Fase 5.17.

## Arquitectura

- **Servidor:** AWS Lightsail Ubuntu 24.04, `18.191.129.33` (us-east-2, misma región que el pooler de Supabase), usuario `ynt` (grupo `docker`). Migrado desde el homelab el 2026-08-05.
  - **La IP es estática desde el 2026-08-06** (`ynt-lightsail-ip`, adjunta — no cobra mientras esté adjunta): no cambia con stop/start. Si algún día cambiara, la fila `produccion · host ssh` del auditor de `nomicheck_ops` sale roja y nombra este archivo.
  - **Fallback frío:** el homelab (`homelab.casa`, WiFi solo 2.4GHz) conserva el mismo stack con su `cloudflared-main` **y su contenedor Rails detenidos** (2026-08-06: el contenedor había quedado corriendo sin túnel y consumía ~13 de las 15 conexiones del pooler de Supabase — producción en Lightsail daba `EMAXCONNSESSION` bajo carga; por eso el fallback se apaga COMPLETO). Failover manual: `ssh ynt@homelab.casa "docker start advance_fitness_app-web-882dfc2a1b714684e699f7fef76295a908a9f057 && docker start cloudflared-main"` — el sha del nombre es el commit de producción sincronizado al homelab (**última sincronización: 2026-08-31, sha `882dfc2`**, ver «Re-sincronizar el fallback» abajo); si se re-sincroniza, actualizar este comando. Historia que este renglón pagó: el standby del 15-ago murió con el disco de la caja (24-ago) y nadie lo notó hasta el deploy del 31-ago — se recreó ese día con el **camino directo** (los secretos salieron del contenedor de PRODUCCIÓN por ssh caja→prod con agente reenviado, jamás por la Mac; el script ahora acepta `usuario@host:contenedor` como origen y ABORTA si faltan las llaves críticas, porque su versión warn-only llegó a crear un cascarón con cero variables) — (y detener el cloudflared **y el contenedor** de Lightsail: repartir tráfico entre versiones ya causó el bug del tenant perdido, y ambos contenedores arriba re-saturan el pooler).
- **Orquestador:** Kamal 2 + Thruster, build **remoto** en el propio servidor (`builder.remote: ssh://ynt@18.191.129.33`, arch `amd64`) para evitar emulación QEMU lenta desde una Mac `arm64`.
- **Registro de imágenes:** `localhost:5555` — registro local temporal en la Mac que ejecuta `bin/kamal`, con túnel SSH inverso para que el builder remoto y el servidor lo alcancen (patrón oficial de Kamal para build remoto).
- **Red / exposición pública:** sin puertos públicos ni `kamal-proxy` (`servers.web.proxy: false`). El contenedor se une a la red Docker `docker-lab_proxy-network` con `network-alias: rails-app`. Un túnel nombrado de Cloudflare (`docker-lab-cloudflared-1`, definido en `/home/ynt/docker-lab/docker-compose.yml`) apunta a `http://rails-app:80` en esa red y sirve `https://advance-fitness-app.ynt.codes`. Cloudflare termina el SSL.
- **Base de datos:** PostgreSQL en Supabase (pooler `aws-1-us-east-2.pooler.supabase.com`), vía `DATABASE_URL` en `.kamal/secrets`. Es la **misma base** que se usa en dev cuando `.env` define `DEV_DATABASE_URL`.
- **Almacenamiento persistente:** volumen Docker `advance_fitness_app_storage:/rails/storage` (incluye `storage/ejercicios_media`, caché de GIFs/imágenes del catálogo de ejercicios).
- **Config completa:** [`config/deploy.yml`](config/deploy.yml).

⚠️ **Ojo con el despliegue viejo:** existe un despliegue anterior por `docker-compose` (servicio `rails-app` en `docker-lab`) que quedó **detenido pero definido**. Si alguien corre `docker compose up` ahí, vuelve a levantarse y compite por el alias `rails-app` con el contenedor de Kamal. No tocar ese `docker-compose.yml` salvo que se sepa lo que se hace.

## Prerrequisitos en la máquina que despliega

1. Docker instalado y corriendo (Kamal lo usa para orquestar el build remoto y el registro local).
2. Acceso SSH al servidor: `ssh ynt@18.191.129.33` (llave ya configurada).
3. Cualquier red con salida a internet (la restricción de WiFi 2.4GHz aplicaba al homelab y solo importa para el fallback).
4. `.kamal/secrets` presente y correcto en local (`RAILS_MASTER_KEY`, `DATABASE_URL`, `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET`, `GEMINI_API_KEY`, `IA_PROVEEDOR`).
5. Quality gate en verde antes de desplegar (ver siguiente sección).

## Paso a paso

### 1. Quality gate (obligatorio antes de cada despliegue)

```bash
dip test
dip rubocop
dip brakeman
```

Los tres deben terminar sin fallos. Si hay migraciones nuevas, asegurarse de que `db/schema.rb` esté limpio (sin extensiones de Supabase-pooler coladas — ver nota abajo) y comiteado.

### 2. Despliegue estándar (código nuevo en `main`)

Desde la raíz del proyecto, en la Mac (fuera de `dip`, Kamal corre en el host):

```bash
bin/kamal deploy
```

Esto: construye la imagen Docker en el servidor remoto (build `amd64`), la sube al registro local (`localhost:5555` vía túnel SSH), la descarga en `18.191.129.33`, corre `db:prepare`/migraciones, arranca el contenedor nuevo unido a `docker-lab_proxy-network` con alias `rails-app`, y apaga el contenedor anterior sin downtime (bridging de assets fingerprinted vía `asset_path`).

### 3. Setup inicial (solo si el servidor es nuevo o se reprovisiona desde cero)

```bash
bin/kamal setup
```

Instala Docker en el servidor si falta, prepara accesorios (no hay ninguno configurado) y hace el primer deploy completo.

### 4. Re-sincronizar el fallback frío del homelab

**Cuándo:** después de un deploy que valga la pena poder promover. Se hizo el
2026-08-15 tras encontrar que el standby llevaba **9 días atrás** de producción
(`cf374f11…` contra `a30140f5…`): el comando de failover de arriba habría
arrancado una versión vieja, y en el peor momento posible.

**Kamal no sirve para esto.** Agregar el homelab a `servers.web.hosts` haría que
`kamal deploy` lo despliegue *y lo arranque*, que es exactamente el incidente
del 2026-08-06 — dos copias saturando el pooler y sirviendo dos versiones.

El procedimiento es copiar la imagen y **crear el contenedor detenido**:

```bash
# 1. La imagen, de Lightsail al homelab (≈1 GB; el homelab está en WiFi 2.4 GHz,
#    así que tarda). Van comprimidos: son capas sin comprimir en el almacén local.
SHA=$(ssh ynt@18.191.129.33 'docker ps --format "{{.Names}}"' | grep advance_fitness | sed 's/.*-web-//')
IMG=localhost:5555/advance_fitness_app:$SHA
ssh ynt@18.191.129.33 "docker save $IMG | gzip -1" | ssh ynt@homelab.casa 'gunzip | docker load'
```

```bash
# 2. El contenedor, DETENIDO y clonando el env del standby anterior.
ssh ynt@homelab.casa "/tmp/sincronizar_standby.sh <contenedor-standby-viejo> $SHA"
```

El script vive en `ops/sincronizar_standby.sh` de este repo y **corre en el
homelab a propósito**: los secretos (`RAILS_MASTER_KEY`, `DATABASE_URL`, las
llaves de Google y VAPID) salen del contenedor viejo que ya está ahí y van al
nuevo sin cruzar la red ni la sesión de nadie.

Copia **solo las variables que inyecta Kamal**, no el env completo: `PATH`,
`RUBY_VERSION`, `BUNDLE_*` y `GEM_HOME` los pone la imagen, y heredarlos de la
vieja sería forzarle a la imagen nueva el Ruby y las rutas de gems de la
anterior.

**Verificar siempre las tres cosas**, en este orden:

```bash
ssh ynt@homelab.casa 'docker ps --format "{{.Names}}" | grep -c advance_fitness'   # DEBE ser 0
ssh ynt@homelab.casa 'docker ps -a --format "{{.Names}}|{{.Status}}" | grep advance_fitness'  # el nuevo, en Created
curl -s -o /dev/null -w "%{http_code}\n" https://advance-fitness-app.ynt.codes/     # producción intacta
```

Después, **actualizar el sha del comando de failover** de la sección de
arquitectura. Ese sha escrito a mano es la única parte del procedimiento que
nada verifica sola, y es la que se quedó vieja nueve días.

### 5. Comandos útiles post-deploy

| Alias | Equivale a | Uso |
|---|---|---|
| `bin/kamal logs` | `app logs -f` | Seguir logs de producción en vivo |
| `bin/kamal console` | `app exec --interactive --reuse "bin/rails console"` | Consola Rails en el contenedor de producción |
| `bin/kamal shell` | `app exec --interactive --reuse "bash"` | Bash dentro del contenedor |
| `bin/kamal dbc` | `app exec --interactive --reuse "bin/rails dbconsole --include-password"` | Consola de la base de datos (Supabase) |

Otros comandos Kamal directos:

```bash
bin/kamal app details     # estado del contenedor activo
bin/kamal rollback        # volver a la versión anterior si algo falla
```

## Flujo de una petición en producción

1. Usuario entra a `https://advance-fitness-app.ynt.codes/`.
2. Cloudflare recibe la petición y la enruta cifrada por el túnel nombrado (`homelab-tunnel`) hasta el servidor local, sin exponer puertos en el router/firewall.
3. El túnel entrega el tráfico a `http://rails-app:80` dentro de `docker-lab_proxy-network` — ese es justamente el alias del contenedor Rails desplegado por Kamal.
4. El contenedor Rails procesa la petición y habla con Postgres en Supabase para leer/escribir datos.

## Notas y precauciones

- **`DATABASE_URL` de producción = misma base que `DEV_DATABASE_URL` de dev.** Cualquier prueba manual contra dev (`dip rails s/c` con `DEV_DATABASE_URL` activo) toca datos reales de producción — no son entornos aislados.
- **`db/schema.rb` puede contaminarse** si se migra localmente contra Supabase (`dip rails db:migrate` con `DEV_DATABASE_URL`): aparecen `enable_extension` de extensiones propias del pooler (`extensions.pgcrypto`, `extensions.uuid-ossp`, `extensions.pg_stat_statements`) que no existen en el schema real y rompen `db:test:load_schema`. Si aparecen, quitarlas a mano antes de comitear — debe quedar solo `enable_extension "pg_catalog.plpgsql"`.
- **No correr `db:drop`/`db:reset`/`dip provision`** mientras `DEV_DATABASE_URL` esté activo en `.env` — apuntaría a destruir datos de producción.
- El push a `main` es responsabilidad del usuario; Kamal despliega lo que esté craneado en el working tree local en el momento de `bin/kamal deploy` (no necesariamente lo último pusheado a GitHub), así que conviene desplegar siempre desde un working tree limpio y actualizado.

## Troubleshooting: 502 después de un deploy exitoso

Puede pasar que `bin/kamal deploy` termine "Finished... successful" y el contenedor salga `healthy`, pero `https://advance-fitness-app.ynt.codes/` responda **502** ("connection refused" a `192.168.40.1:80` en los logs de `docker-lab-cloudflared-1`). Causa observada (julio 2026): Kamal ejecuta `docker run` con dos `--network` (la red por defecto `kamal` y la custom `docker-lab_proxy-network`), pero el flag `--network-alias rails-app` a veces solo queda aplicado a la red `kamal`, no a `docker-lab_proxy-network` — el túnel de Cloudflare, que vive en esa segunda red, no puede resolver el alias y cae al gateway.

Diagnóstico rápido:
```bash
ssh ynt@18.191.129.33 "docker inspect <container> --format '{{json .NetworkSettings.Networks}}'"
```
Si `docker-lab_proxy-network` aparece con `"Aliases": null` (y sí lo tiene la red `kamal`), es este bug.

Arreglo inmediato (no requiere redeploy):
```bash
ssh ynt@18.191.129.33 "docker network disconnect docker-lab_proxy-network <container> && docker network connect --alias rails-app docker-lab_proxy-network <container>"
```
Verificar con `curl -I https://advance-fitness-app.ynt.codes/up` (debe dar 200).
