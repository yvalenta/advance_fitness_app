# Despliegue — Advance Fitness App

Guía del proceso real de despliegue a producción, usado desde la Fase 5.17.

## Arquitectura

- **Servidor:** homelab Ubuntu, `192.168.40.253`, usuario `ynt` (grupo `docker`, sin sudo sin contraseña). Su WiFi solo soporta **2.4GHz** — si se despliega desde una Mac conectada a 5GHz, cambiar de red primero o la IP no ruteará.
- **Orquestador:** Kamal 2 + Thruster, build **remoto** en el propio servidor (`builder.remote: ssh://ynt@192.168.40.253`, arch `amd64`) para evitar emulación QEMU lenta desde una Mac `arm64`.
- **Registro de imágenes:** `localhost:5555` — registro local temporal en la Mac que ejecuta `bin/kamal`, con túnel SSH inverso para que el builder remoto y el servidor lo alcancen (patrón oficial de Kamal para build remoto).
- **Red / exposición pública:** sin puertos públicos ni `kamal-proxy` (`servers.web.proxy: false`). El contenedor se une a la red Docker `docker-lab_proxy-network` con `network-alias: rails-app`. Un túnel nombrado de Cloudflare (`docker-lab-cloudflared-1`, definido en `/home/ynt/docker-lab/docker-compose.yml`) apunta a `http://rails-app:80` en esa red y sirve `https://advance-fitness-app.ynt.codes`. Cloudflare termina el SSL.
- **Base de datos:** PostgreSQL en Supabase (pooler `aws-1-us-east-2.pooler.supabase.com`), vía `DATABASE_URL` en `.kamal/secrets`. Es la **misma base** que se usa en dev cuando `.env` define `DEV_DATABASE_URL`.
- **Almacenamiento persistente:** volumen Docker `advance_fitness_app_storage:/rails/storage` (incluye `storage/ejercicios_media`, caché de GIFs/imágenes del catálogo de ejercicios).
- **Config completa:** [`config/deploy.yml`](config/deploy.yml).

⚠️ **Ojo con el despliegue viejo:** existe un despliegue anterior por `docker-compose` (servicio `rails-app` en `docker-lab`) que quedó **detenido pero definido**. Si alguien corre `docker compose up` ahí, vuelve a levantarse y compite por el alias `rails-app` con el contenedor de Kamal. No tocar ese `docker-compose.yml` salvo que se sepa lo que se hace.

## Prerrequisitos en la máquina que despliega

1. Docker instalado y corriendo (Kamal lo usa para orquestar el build remoto y el registro local).
2. Acceso SSH al servidor: `ssh ynt@192.168.40.253` (llave ya configurada).
3. Conectado a la red WiFi de 2.4GHz del homelab (o a una red desde la que esa IP rutee).
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

Esto: construye la imagen Docker en el servidor remoto (build `amd64`), la sube al registro local (`localhost:5555` vía túnel SSH), la descarga en `192.168.40.253`, corre `db:prepare`/migraciones, arranca el contenedor nuevo unido a `docker-lab_proxy-network` con alias `rails-app`, y apaga el contenedor anterior sin downtime (bridging de assets fingerprinted vía `asset_path`).

### 3. Setup inicial (solo si el servidor es nuevo o se reprovisiona desde cero)

```bash
bin/kamal setup
```

Instala Docker en el servidor si falta, prepara accesorios (no hay ninguno configurado) y hace el primer deploy completo.

### 4. Comandos útiles post-deploy

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
ssh ynt@192.168.40.253 "docker inspect <container> --format '{{json .NetworkSettings.Networks}}'"
```
Si `docker-lab_proxy-network` aparece con `"Aliases": null` (y sí lo tiene la red `kamal`), es este bug.

Arreglo inmediato (no requiere redeploy):
```bash
ssh ynt@192.168.40.253 "docker network disconnect docker-lab_proxy-network <container> && docker network connect --alias rails-app docker-lab_proxy-network <container>"
```
Verificar con `curl -I https://advance-fitness-app.ynt.codes/up` (debe dar 200).
