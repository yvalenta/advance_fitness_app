# Investigación de Despliegue: Advance Fitness App

> **Guía operativa autoritativa: [`DEPLOY.md`](DEPLOY.md).** Este documento es el contexto de topología/infraestructura y el historial de decisiones; para el paso a paso de un despliegue real, comandos, troubleshooting y notas de producción, usa `DEPLOY.md`. Se mantiene aquí lo que no cambia con cada deploy (arquitectura, flujo de una petición) y lo que sí cambia (comandos, IPs, bugs conocidos) se referencia sin duplicar, para no volver a desincronizarse.

## 1. Arquitectura de Despliegue Actual

- **Servidor de Aplicación (Homelab):** Ubuntu, IP interna `192.168.40.253`, usuario `ynt` (grupo `docker`, sin sudo sin contraseña), definido en [`config/deploy.yml`](config/deploy.yml). Su WiFi solo soporta 2.4GHz — desplegar desde una Mac en 5GHz no rutea.
- **Exposición a Internet (Cloudflare Tunnel):** `https://advance-fitness-app.ynt.codes/` se sirve por un túnel nombrado de Cloudflare (contenedor `docker-lab-cloudflared-1`, definido en `/home/ynt/docker-lab/docker-compose.yml`) que apunta a `http://rails-app:80` en la red Docker `docker-lab_proxy-network`. Sin puertos públicos ni `kamal-proxy` (`servers.web.proxy: false`); Cloudflare termina el SSL.
- **Base de Datos (Supabase):** PostgreSQL externo, vía el pooler de conexiones en AWS (`aws-1-us-east-2.pooler.supabase.com`), `DATABASE_URL` en `.kamal/secrets`. **Es la misma base que usa dev cuando `.env` define `DEV_DATABASE_URL`** — no son entornos aislados (ver `CLAUDE.md` y `DEPLOY.md` para las precauciones).
- **Orquestador de Despliegues (Kamal 2 + Thruster):** empaqueta la app en contenedores Docker. **Build remoto** (`builder.remote: ssh://ynt@192.168.40.253`, arch `amd64`): compila en el propio servidor x86_64 en vez de en la Mac arm64, evitando emulación QEMU lenta. Registro de imágenes: `localhost:5555` (registro local temporal en la Mac que ejecuta `bin/kamal`, con túnel SSH inverso).
- **Almacenamiento persistente:** volumen Docker `advance_fitness_app_storage:/rails/storage` (incluye la caché de GIFs/imágenes del catálogo de ejercicios).
- **Versionamiento:** `VERSION` en la raíz (semántico `MAJOR.MINOR.PATCH`), expuesto como `Rails.application.config.x.version` y visible en el footer de cada página. `dip rails version:bump:patch|minor|major` para incrementarlo antes de un release.

## 2. Flujo de ramas y CI (antes de desplegar)

Desde la estabilización del proyecto, `main` está **protegida** en GitHub: sin push directo, requiere Pull Request con 1 aprobación y los checks de CI (`lint`, `test` — jobs de `.github/workflows/ci.yml`, que corre RuboCop y la suite RSpec) en verde. `develop` es la rama de integración, sin protección, donde se mergea cada feature branch.

Flujo de un release:
```
feature/x → PR → develop            (integración continua, checks corren pero no bloquean)
develop → PR → main                 (requiere 1 aprobación + lint/test en verde)
main → bin/kamal deploy             (deploy manual, ver §3 y DEPLOY.md)
```
El CI (`test test/system`) tiene un job `system-test` que hoy falla siempre (no hay `test/system`, la suite es RSpec desde julio 2026) — no es un check requerido por la protección de `main`, así que no bloquea merges; queda como deuda menor a limpiar del workflow.

## 3. Proceso de Despliegue Manual

El despliegue sigue siendo manual (no hay CD automático desde CI). Ver **[`DEPLOY.md`](DEPLOY.md)** para: prerrequisitos completos, el quality gate obligatorio (`dip test && dip rubocop && dip brakeman` antes de cada deploy), el comando (`bin/kamal deploy`, con `bin/` — es una gem vendorizada, no un binario global), `bin/kamal setup` para un servidor nuevo, los aliases (`logs`/`console`/`shell`/`dbc`), y el **troubleshooting del bug conocido de red**: tras casi todo deploy exitoso, el contenedor nuevo no hereda el `network-alias: rails-app` en `docker-lab_proxy-network` (solo en la red `kamal`), causando 502 hasta corregirlo a mano con `docker network disconnect`/`connect`.

Nota de configuración relevante para el timing del deploy: `drain_timeout: 130` en `config/deploy.yml` (default de Kamal: 30s) — el margen se subió porque una generación de plan con IA puede tardar hasta 120s (`read_timeout` de los adaptadores en `app/services/ia/`); con el default, un deploy a mitad de una generación mataba el contenedor viejo antes de que el job terminara, dejando el plan atascado en "generando" para siempre. `LiberarPlanesEstancadosJob` (recurrente cada 5 min) es la red de seguridad adicional para cualquier caso que igual se escape.

## 4. Resumen del Flujo de Peticiones

1. Un usuario accede a `https://advance-fitness-app.ynt.codes/`.
2. Cloudflare recibe la petición y, por el túnel nombrado, la envía cifrada directamente al servidor local, sin exponer puertos.
3. En `192.168.40.253`, el túnel entrega el tráfico a `http://rails-app:80` dentro de `docker-lab_proxy-network` — el alias del contenedor Rails activo desplegado por Kamal.
4. El contenedor procesa la lógica y se comunica con Postgres en Supabase para leer/escribir datos.
