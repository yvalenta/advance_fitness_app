# Análisis: ¿Puede Advance Fitness migrar a Rails 8?

> Documento de decisión aportado por el propietario del proyecto (julio 2026).
> Fundamenta la transición del stack v1.x (React + Supabase) al v2.0 (Rails 8.1) del SDD.

## TL;DR — Veredicto

**Sí, deberías hacerlo — y es el momento perfecto.**
El proyecto está en etapa de definición / pre-construcción (SDD v1.1, sin código de aplicación todavía). Arrancar en Rails 8.1.x desde cero es mucho mejor que migrar después. Tu experiencia en Rails es la ventaja decisiva: todo lo que el SDD delega a Supabase Edge Functions, RLS y React lo resuelves de forma más natural y mantenible con el stack Rails nativo.

## Estado actual del proyecto

| Dimensión | Estado |
|---|---|
| Fase de construcción | Pre-construcción — solo SDD + scaffolding Vite |
| Código de negocio | 0 líneas (src/ vacío más allá de boilerplate) |
| Base de datos | Schema diseñado, sin migraciones ejecutadas |
| Auth | Decidida (Supabase Auth) pero no implementada |
| Backend | Supabase BaaS (sin servidor propio) |
| Stack actual | React 19 + Vite 8 + TypeScript + Tailwind v4 + Supabase |

**Conclusión de estado:** el costo de cambiar el stack ahora es mínimo — reescribir la arquitectura del SDD y redireccionar el repo. No hay código que tirar.

## Lo que Rails 8 trae que encaja directamente con Advance Fitness

### 1. Authentication Generator (Rails 8.0)

```bash
bin/rails generate authentication
```

Genera sesión segura con `has_secure_password`, password resets, rate limiting y metadata de sesión. Reemplaza Supabase Auth sin necesidad de Devise. Para una app de gimnasio con roles miembro / entrenador / admin, este generador da exactamente lo que el SDD define en §08.

Mapeo directo al SDD:
- `perfiles.rol` → columna en el modelo User
- Trigger de creación de perfil → `after_create` callback o concern
- Google OAuth → gem `omniauth-google-oauth2` (un archivo de initializer)

### 2. Solid Queue — Jobs sin Redis (Rails 8.0)

```ruby
# Gemfile — ya incluido por defecto
gem "solid_queue"
```

Solid Queue usa Postgres o SQLite como backend de jobs. Reemplaza Redis + Sidekiq.

Casos de uso en Advance Fitness:
- Job diario que marca membresías vencidas (`membresias.estado = 'vencida'`) — el SDD menciona un "job diario"
- Generación del plan IA en background (llamada a Claude API asíncrona)
- Recordatorio de "medición pendiente" (el dashboard la muestra, un job la podría enviar por email)

### 3. Solid Cache — Caché sin Redis (Rails 8.0)

```ruby
config.cache_store = :solid_cache_store
```

Almacena fragmentos HTML y resultados de queries en Postgres. Zero dependencias externas.

Uso en Advance Fitness:
- Cachear blog y novedades (contenido raramente cambiado, lectura intensiva)
- Cachear el catálogo de planes y sus beneficios JSONB
- Cachear métricas del dashboard por usuario con expiración corta

### 4. Solid Cable — Action Cable sin Redis (Rails 8.0)

```ruby
config.cable = { adapter: "solid_cable" }
```

WebSockets sobre Postgres/SQLite, sin Redis.

Uso en Advance Fitness:
- Notificación en tiempo real cuando el entrenador aprueba un plan personalizado
- Actualización live del check-in panel del admin
- Alertas de membresía vencida en tiempo real

### 5. Kamal 2 — Deploy sin Docker Compose (Rails 8.0)

```bash
kamal setup
kamal deploy
```

Despliega en cualquier VPS (DigitalOcean, Hetzner, etc.) con un comando. Kamal Proxy maneja SSL y routing automáticamente.

Para Advance Fitness: un servidor de ~$6/mes en Hetzner corre toda la app (Rails + Postgres + jobs). Sin Supabase, sin Firebase, sin complejidad de BaaS.

### 6. Propshaft — Asset Pipeline moderno (Rails 8.0)

Reemplaza Sprockets. Simple, rápido, orientado a HTTP/2. Para un proyecto nuevo con Tailwind CSS (vía `cssbundling-rails` o `tailwindcss-rails`) es la opción correcta.

### 7. SQLite en producción (Rails 8.0+)

Rails 8 adopta SQLite como motor de producción legítimo para apps de bajo-medio tráfico, con litestream para backup en tiempo real a S3.

Para Advance Fitness en MVP: SQLite es más que suficiente para un gimnasio local. Cero setup de Postgres hasta que crezcas.

## Comparación de stacks: Actual vs. Rails 8

| Componente | Stack actual (SDD) | Rails 8 equivalente |
|---|---|---|
| Auth | Supabase Auth + JWT | `rails generate authentication` |
| Base de datos | Supabase Postgres + RLS | Postgres o SQLite + Pundit |
| Jobs en background | Supabase Edge Functions (workaround) | Solid Queue (nativo) |
| Caché | Sin cache definida | Solid Cache (nativo) |
| WebSockets | No contemplado en SDD | Solid Cable → Turbo Streams |
| IA generativa | Edge Function → Claude API | ActiveJob → llamada a Claude |
| UI interactiva | React 19 + Vite (SPA completa) | Hotwire (Turbo + Stimulus) + ERB |
| Deploy | Sin definir | Kamal 2 (un VPS, un comando) |
| Seguridad por filas | RLS (SQL policies) | Pundit o Action Policy (Ruby puro) |
| Frontend build | pnpm + Vite 8 | Propshaft + Tailwind CSS gem |
| Tipos de datos | TypeScript generado desde Supabase | ActiveRecord + Strong Parameters |

## Módulos del SDD mapeados a Rails 8

| Módulo SDD | Rails 8 implementación |
|---|---|
| A — Membresías y Accesos | Modelos `Membresia`, `Pago`, `Acceso` + `before_action :verificar_horario` en el controller de check-in |
| B — Salud y Biometría | Modelo de medición + columna IMC; gráficas con Chartkick o SVG con Turbo Frames |
| C — Nutrición | Modelo `ObjetivoNutricional` + servicio `TdeeCalculator` (clase Ruby pura) |
| D — Planes e IA | ActiveJob que llama a Claude API + callback de aprobación del entrenador. Turbo Stream actualiza el dashboard cuando se aprueba |
| E — Blog y Novedades | ActionText para el contenido rich (reemplaza el `contenido_md` Markdown del SDD) + Turbo para carga sin recarga de página |

## Dónde React todavía tiene sentido

- **Opción A (recomendada):** Hotwire (Turbo + Stimulus) para todo. Cero JS custom para la mayoría de los módulos.
- **Opción B (híbrida):** Rails API mode + React SPA solo para el dashboard de métricas y las gráficas. El resto en ERB.
- **Opción C (actual):** React SPA + Supabase. Funciona, pero introduce complejidad de BaaS evitable.

Para un desarrollador con experiencia en Rails, la Opción A es la más productiva.

## Riesgos y consideraciones

| Riesgo | Severidad | Mitigación |
|---|---|---|
| Curva de aprendizaje de Hotwire vs React | Baja (si conoces Rails) | Turbo Drive es Rails "que siempre fue", solo HTML + headers |
| RLS vs Pundit para autorización | Baja | Pundit es más expresivo y testeable que SQL policies |
| SQLite en producción para datos sensibles (salud) | Media | Usar Postgres si ya tienes experiencia; SQLite es válido en MVP con Litestream |
| Abandono del lockfile de pnpm ya resuelto | Nula (no hay código real) | El SDD se actualiza, no hay migración de código |
| Google OAuth | Baja | `omniauth-google-oauth2` + `omniauth-rails_csrf_protection` — 2 gems, 1 initializer |

## Plan de arranque recomendado

```bash
# Crear la app Rails 8 con el stack completo
rails new advance_fitness_app \
  --database=postgresql \
  --css=tailwind \
  --asset-pipeline=propshaft \
  --javascript=importmap

# Generar autenticación nativa
bin/rails generate authentication

# Agregar Pundit para autorización por rol
bundle add pundit

# Agregar solid_queue (ya incluido en Rails 8)
bin/rails solid_queue:install

# Agregar solid_cache
bin/rails solid_cache:install
```

Después, el SDD de §07 (entidades) se convierte directamente en migraciones Rails — el diseño de datos no cambia.

## Conclusión final

| Pregunta | Respuesta |
|---|---|
| ¿Es el momento correcto para cambiar? | ✅ Sí — estás en día 0, sin código de negocio |
| ¿Rails 8 cubre todos los módulos del SDD? | ✅ Sí — nativo o con gems estándar |
| ¿Pierde features importantes? | ❌ No — ganas Solid Queue, Solid Cache, Solid Cable, Kamal, auth nativa |
| ¿Vale si tu expertise es Rails? | ✅ Absolutamente — mantendrás el 100% del código tú solo |
| ¿Qué pierdes del stack actual? | TypeScript (puedes agregar typescript a importmap), React (reemplazado por Hotwire) |

**Recomendación:** actualiza el SDD a Rails 8.1 + Hotwire + Pundit + Solid Stack. El schema de datos del §07 es sólido y se convierte 1:1 a migraciones ActiveRecord. Kamal 2 da un deploy reproducible desde el día 1 sin costos de BaaS.
