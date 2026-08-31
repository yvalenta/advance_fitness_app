#!/usr/bin/env bash
# Re-sincroniza el standby frio de Advance Fitness en el HOMELAB.
#
# Corre EN EL HOMELAB a proposito: los secretos (RAILS_MASTER_KEY, DATABASE_URL,
# las llaves de Google y VAPID) salen del contenedor viejo que ya vive aca y
# van al nuevo sin pasar por la red ni por la sesion de nadie.
#
# CREA EL CONTENEDOR DETENIDO (`docker create`, nunca `run`). Arrancarlo se come
# ~13 de las 15 conexiones del pooler de Supabase y tumba produccion: es el
# incidente del 2026-08-06 que documenta DEPLOY.md.
set -euo pipefail

VIEJO="${1:?falta el nombre del contenedor standby viejo}"
NUEVO_SHA="${2:?falta el sha de produccion}"
IMAGEN="localhost:5555/advance_fitness_app:${NUEVO_SHA}"
NUEVO="advance_fitness_app-web-${NUEVO_SHA}"

if ! docker image inspect "$IMAGEN" >/dev/null 2>&1; then
  echo "ERROR: la imagen $IMAGEN no esta en este host. Falta la transferencia."
  exit 1
fi

if docker container inspect "$NUEVO" >/dev/null 2>&1; then
  echo "ya existe el contenedor $NUEVO — no se toca nada"
  exit 0
fi

# Solo las variables que Kamal inyecta. Las del entorno de la imagen (PATH,
# RUBY_VERSION, BUNDLE_*, GEM_HOME, LANG, LD_PRELOAD) se dejan a la imagen
# NUEVA: heredarlas del contenedor viejo seria forzarle a una imagen nueva el
# ruby y las rutas de gems de la vieja.
CLAVES="RAILS_MASTER_KEY DATABASE_URL GOOGLE_CLIENT_ID GOOGLE_CLIENT_SECRET \
GEMINI_API_KEY IA_PROVEEDOR VAPID_PUBLIC_KEY VAPID_PRIVATE_KEY \
APP_HOST PGCONNECT_TIMEOUT SOLID_QUEUE_IN_PUMA RAILS_ENV RUBY_YJIT_ENABLE"

ENVFILE="$(mktemp)"
chmod 600 "$ENVFILE"
trap 'rm -f "$ENVFILE"' EXIT

# Un grep anclado y no un lazo: el `println` del template deja una linea vacia
# al final, y con `set -e` la ultima comparacion fallida del lazo mataba el
# script entero antes de crear nada.
PATRON="^($(echo $CLAVES | tr -s ' ' '|'))="

# CAMINO DIRECTO (2026-08-31): el contenedor viejo murio con el disco de la
# caja y no habia de donde clonar. Si VIEJO viene como usuario@host:contenedor,
# el env sale del contenedor de PRODUCCION por ssh caja->prod (agente
# reenviado con `ssh -A` al invocar): los secretos viajan directo entre los
# dos hosts y jamas pasan por la Mac ni por una sesion — el mismo patron que
# resolvio el standby de NomiCheck. Requiere el host key de prod ya conocido
# en la caja (BatchMode no pregunta; un keyscan previo lo siembra).
if [[ "$VIEJO" == *"@"*":"* ]]; then
  ORIGEN_SSH="${VIEJO%%:*}"
  ORIGEN_CONT="${VIEJO#*:}"
  ssh -o BatchMode=yes "$ORIGEN_SSH" \
    docker inspect "$ORIGEN_CONT" --format "'{{range .Config.Env}}{{println .}}{{end}}'" \
    | grep -E "$PATRON" > "$ENVFILE" || true
else
  docker inspect "$VIEJO" --format '{{range .Config.Env}}{{println .}}{{end}}' \
    | grep -E "$PATRON" > "$ENVFILE" || true
fi

faltan=""
for c in $CLAVES; do
  grep -q "^${c}=" "$ENVFILE" || faltan="$faltan $c"
done
# GUARDA (2026-08-31, pagada el mismo dia): la version warn-only creo un
# contenedor con CERO variables cuando el ssh al origen fallo — un standby
# que arrancaria roto es peor que ninguno, porque tranquiliza. Sin master
# key o sin base no hay standby: se aborta ANTES de crear.
case "$faltan" in
  *RAILS_MASTER_KEY*|*DATABASE_URL*)
    echo "ERROR: el origen no entrego las llaves criticas:$faltan" >&2
    echo "       (¿fallo el ssh al origen? ¿agente sin identidades?)" >&2
    exit 1;;
esac
[ -n "$faltan" ] && echo "aviso: sin valor en el origen:$faltan"

echo "creando $NUEVO (DETENIDO) con $(wc -l < "$ENVFILE") variables"

docker create \
  --name "$NUEVO" \
  --env-file "$ENVFILE" \
  --env "KAMAL_CONTAINER_NAME=$NUEVO" \
  --env "KAMAL_VERSION=$NUEVO_SHA" \
  --env "KAMAL_HOST=$(hostname -I | awk '{print $1}')" \
  --restart unless-stopped \
  --network docker-lab_proxy-network \
  --network-alias rails-app \
  --volume advance_fitness_app_storage:/rails/storage \
  --label service=advance_fitness_app \
  --label role=web \
  --label destination= \
  --log-driver json-file \
  "$IMAGEN" \
  ./bin/thrust ./bin/rails server >/dev/null

# La segunda red va aparte: `docker create` solo acepta una.
docker network connect --alias rails-app kamal "$NUEVO" 2>/dev/null \
  || echo "aviso: no se pudo unir a la red 'kamal' (¿no existe en este host?)"

echo "listo:"
docker ps -a --filter "name=$NUEVO" --format "  {{.Names}} | {{.Status}} | {{.Image}}"
