# Advance Fitness App — Reglas del repositorio

## Contexto del repositorio
- **Repositorio nuevo: se construye de cero.** No hay código heredado; todo nace de este repo y de su SDD.
- Remoto: `git@github.com:yvalenta/advance_fitness_app.git` (origin, rama principal `main`).
- **Documento rector:** `advance-fitness-sdd.md` (v2.0 — Rails). Toda decisión de alcance, entidades, seguridad o flujos se valida contra el SDD; si algo cambia, primero se actualiza el SDD.
- Proyectos de referencia (solo lectura, para adaptar funcionalidades, nunca copiar): landing en `/Users/yonatan/Developer/advance_fitness` y Resplandor POS en `/Users/yonatan/Developer/resplandor`.

## Stack (decisión cerrada — SDD §12)
- **Rails 8.1.3 · Ruby 3.4.5 · PostgreSQL 17** (monolito server-rendered).
- Frontend: Hotwire (Turbo + Stimulus) + importmap — **sin Node, sin package.json**. Estilos: `tailwindcss-rails` v4, tokens en `@theme` (`app/assets/tailwind/application.css`).
- Auth nativa de Rails 8 (`has_secure_password` + sesiones); Google OAuth como segundo método. Autorización: **Pundit** (una policy por modelo, `verify_authorized`).
- Background/cache/cable: **Solid Queue · Solid Cache · Solid Cable** sobre Postgres — **sin Redis**.
- IA: capa multi-proveedor propia (`GeneradorPlanIa` + adaptadores en `app/services/ia/` — Gemini activo, Claude disponible, `ENV["IA_PROVEEDOR"]`) solo desde `GenerarPlanJob` (server-side). **Sin LangChain.**
- Deploy: Kamal 2 + Thruster (`Dockerfile` de producción).

## Entorno local — dip, siempre
Todo comando corre en Docker vía dip; no se ejecuta `rails`/`bundle` en el host:
- Setup desde cero: `dip provision`
- Servidor: `dip rails s` → http://localhost:3000
- Consola / migraciones / generadores: `dip rails c` · `dip rails db:migrate` · `dip rails g …`
- Tests: `dip test` (minitest; base de test propia en el contenedor `db`)
- Lint y seguridad: `dip rubocop` · `dip brakeman`
- Postgres: `dip psql` · Shell: `dip bash`
- `Dockerfile.dev` + `docker-compose.yml` (web + db postgres:17-alpine) son el entorno dev; el `Dockerfile` raíz es solo producción.

## Convenciones de código
- Modelos y tablas de dominio en **español** (plurales en `config/initializers/inflections.rb`); `users`/`sessions` del generador de auth quedan en inglés.
- `app/services`: POROs puros (IMC, TDEE, somatotipo) — sin acceso a base ni a sesión. `app/policies`: Pundit. Controllers delgados.
- Seguridad: strong params siempre; `users.rol` jamás asignable por mass-assignment; historial de pagos inmutable.
- UI y datos en español; moneda COP sin decimales; fechas formato `es-CO`.
- Tests minitest en cada fase (models, policies, controllers, system); una fase se cierra con `dip test`, `dip rubocop` y `dip brakeman` en verde.
- Commits por fase de avance del proyecto (Fase 1: base + auth, Fase 2: membresías…, según SDD §11).
