# Advance Fitness — Software Design Document · v2.0

> **Open Spec v2.0** · Aplicación web integral de gestión de gimnasio: membresías y accesos, biometría, nutrición, planes personalizados con IA y comunidad.
> Stack: Ruby on Rails 8.1 (monolito) · PostgreSQL · Hotwire (Turbo + Stimulus) · Tailwind CSS · Solid Queue/Cache/Cable · Pundit. Entorno local: **dip + Docker Compose**.

| Metadato | Valor |
|---|---|
| Versión | 2.0 — Open Spec (transición de stack: SPA React + Supabase → monolito Rails 8.1) |
| Estado | Definición inicial |
| Repositorio | `git@github.com:yvalenta/advance_fitness_app.git` — nuevo, construido de cero |
| Stack | Rails 8.1.3 · Ruby 3.4.5 · PostgreSQL 17 · Hotwire · Tailwind · Pundit · Solid stack |
| Entorno local | dip 8 + Docker Compose (`dip provision`, `dip rails s`, `dip test`) |
| Actualizado | Julio 2026 |
| Documento de referencia | Restaurante Resplandor POS — SDD v1.0 · [`docs/rails8_analysis.md`](./docs/rails8_analysis.md) |

> **Nota de transición (v2.0):** las versiones 1.x diseñaban una SPA React 19 + Supabase (Auth, RLS, Edge Functions). El proyecto pivotó a un monolito Rails 8.1: un solo lenguaje y framework para todo el dominio, autenticación y jobs nativos (sin BaaS), server-rendered con Hotwire. El modelo de dominio (§03, §07) y los flujos (§10) se conservan; cambia el plano de ejecución.

---

## 01 — Introducción

### ¿Qué construimos?

**Advance Fitness** es una aplicación web para gestionar el ciclo completo de un gimnasio: alta y renovación de membresías, control de accesos y horarios, seguimiento biométrico con estadísticas de progreso, calculadora nutricional (déficit / superávit calórico), monetización por planes (Free vs. Personalizado) y una capa de comunidad (blog + novedades).

El sistema es un **monolito Rails 8.1 server-rendered**: HTML generado en el servidor con ERB, interactividad con Hotwire (Turbo + Stimulus, sin build de JavaScript gracias a importmap), estilos con Tailwind CSS y PostgreSQL como única base de datos. La autenticación es la **nativa de Rails 8** (`has_secure_password` + sesiones), la autorización por rol la resuelve **Pundit**, y los trabajos en segundo plano (generación de planes con IA vía una capa multi-proveedor — Gemini activo, Claude disponible) corren en **Solid Queue** sobre el mismo Postgres — sin Redis, sin servicios externos. El despliegue es autocontenido con **Kamal + Thruster** (Docker).

> **Principio rector:** un solo framework, un solo lenguaje, una sola base de datos. Todo lo que requiere confianza (identidad, permisos, pagos, IA con API keys) vive en el servidor Rails; el navegador solo recibe HTML y pequeñas dosis de Stimulus.

---

## 02 — Alcance

### Qué entra y qué no

| En scope (MVP) | Out of scope (MVP) |
|---|---|
| Registro y login obligatorio (auth nativa Rails 8; Google OAuth como segundo método) | App nativa iOS / Android |
| Perfil del miembro: datos básicos, fecha de ingreso, tiempo activo | Pasarela de pago online (Stripe / Wompi) — el pago se registra manualmente |
| Membresías: fechas de pago, vencimiento mensual, renovación | Facturación electrónica (DIAN) |
| Historial de reingresos y check-ins al gimnasio | Torniquete / hardware de control de acceso físico |
| Horarios de acceso por membresía | Multi-sede / multi-gimnasio |
| Calculadora biométrica: peso, edad, talla → IMC, estado de peso, propensión a sobrepeso, somatotipo | Wearables / integración con Apple Health o Google Fit |
| Gráficas de progreso mensual (peso, IMC) | Chat en vivo entrenador ↔ miembro |
| Tabla de calorías: consumo diario, déficit y superávit calórico (TDEE) | Marketplace de suplementos |
| Catálogo de alimentos (kcal/macros por porción) y gustos del miembro: le gusta · lo tolera · no le gusta | Base de datos nutricional exhaustiva (se cura un seed colombiano, no se integra USDA/BEDCA) |
| Armador de comidas: componer el día con alimentos y porciones, kcal en vivo, y registrarlo como consumo | Escáner de código de barras de productos |
| Recetas generadas por IA en cada comida del plan premium, respetando los gustos | Fotos de comidas / registro por imagen |
| Plan Free: rutinas y guías básicas para subir o bajar de peso | Notificaciones push |
| Upgrade a Plan Personalizado: rutina + plan nutricional generados con IA y aprobados por entrenador | Editor WYSIWYG avanzado para el blog |
| Blog y panel de novedades del gimnasio | Comentarios y reacciones en el blog |
| Panel admin: gestión de miembros, membresías, contenidos | Reportes financieros avanzados |
| Responsive: móvil ≥ 375px, tablet y desktop | — |

---

## 03 — Módulos funcionales

Los requerimientos en bruto se organizan en cinco módulos. Cada requerimiento queda trazado a su entidad de datos (§07) y su flujo (§10).

### Módulo A — Membresías y Accesos

| Requerimiento | Solución | Entidad |
|---|---|---|
| Fecha de ingreso del usuario | `users.fecha_ingreso`, se fija en el registro | `users` |
| Fechas de pago | Historial en tabla de pagos, uno por período | `pagos` |
| Vencimiento mensual y renovación | `membresias.fecha_vencimiento`; renovar crea un pago y extiende la fecha | `membresias`, `pagos` |
| Historial de reingresos | Cada check-in se registra; un reingreso es un check-in tras membresía vencida y renovada | `accesos` |
| Control de tiempo activo ("hace cuánto entrena") | Calculado: `Date.current - user.fecha_ingreso`, descontando períodos inactivos según `accesos` | `users`, `accesos` |
| Horarios de acceso | `membresias.horario_acceso` (JSONB por día de semana); se valida en el check-in | `membresias` |

### Módulo B — Salud y Biometría

| Requerimiento | Solución | Entidad |
|---|---|---|
| Inputs básicos: peso, edad, talla | Formulario de medición; edad derivada de `users.fecha_nacimiento` | `mediciones` |
| Estado de peso actual (IMC / BMI) | Columna generada en Postgres: `imc = peso_kg / (talla_cm/100)^2`, clasificada según rangos OMS | `mediciones` |
| Indicador de propensión a sobrepeso | Servicio: tendencia del IMC en las últimas 3 mediciones + somatotipo | Derivado |
| Identificación del somatotipo | Cuestionario guiado en onboarding → `ectomorfo` · `mesomorfo` · `endomorfo` | `users.somatotipo` |
| Gráficas de progreso mensual | Serie temporal de `mediciones` renderizada como SVG inline en un partial (sin librería de charts) | `mediciones` |

Fórmulas estándar utilizadas (implementadas como POROs en `app/services`, puros y testeables):

| Fórmula | Expresión | Uso |
|---|---|---|
| IMC (OMS) | `peso_kg / talla_m²` | Estado de peso actual |
| Clasificación IMC | `<18.5` bajo peso · `18.5–24.9` normal · `25–29.9` sobrepeso · `≥30` obesidad | Indicador visual |
| TMB (Mifflin-St Jeor) | Hombre: `10·peso + 6.25·talla − 5·edad + 5` · Mujer: `… − 161` | Base del gasto calórico |
| TDEE | `TMB × factor de actividad (1.2 – 1.9)` | Calorías de mantenimiento |

### Módulo C — Nutrición y Objetivos

| Requerimiento | Solución | Entidad |
|---|---|---|
| Registro de calorías consumidas | Registro diario simple: fecha + kcal totales | `registros_calorias` |
| Déficit calórico (bajar de peso) | Objetivo = `TDEE − 500 kcal`; la app muestra cuántas kcal faltan por quemar hoy | `objetivos_nutricionales` |
| Superávit calórico (masa muscular) | Objetivo = `TDEE + 300–500 kcal` según somatotipo | `objetivos_nutricionales` |
| Catálogo de alimentos | Seed curado de ~120–150 alimentos comunes en Colombia con kcal/macros por porción; CRUD del admin para mantenerlo | `alimentos` |
| Gustos del miembro | Selector interactivo por categorías: cada alimento se califica `le_gusta` · `lo_tolera` · `no_le_gusta`; editable siempre en "Mis gustos" | `preferencias_alimentarias` |
| Armador de comidas | El miembro compone desayuno/almuerzo/cena/snacks con alimentos y porciones, ve kcal y macros en vivo contra su objetivo, y al guardar el día queda registrado como su consumo | `registro_alimentos`, `registros_calorias` |
| Recetas personalizadas | Cada comida del plan premium trae receta generada por IA (ingredientes con cantidades + preparación) que usa los `le_gusta` y excluye los `no_le_gusta` | `planes_personalizados.plan_nutricional` |

### Módulo D — Planes y Monetización

| Requerimiento | Solución | Entidad |
|---|---|---|
| Plan Free | Acceso a rutinas y guías básicas (contenido estático por objetivo: subir / bajar de peso) | `planes`, `suscripciones` |
| Upgrade a Plan Personalizado | Compra registrada por admin → `GenerarPlanJob` (Solid Queue) genera con IA una rutina + plan nutricional a partir de la biometría y el objetivo; el entrenador revisa y aprueba antes de publicarse al miembro | `planes_personalizados` |

### Módulo E — Comunidad y Retención

| Requerimiento | Solución | Entidad |
|---|---|---|
| Sección de Blog | Posts con contenido enriquecido (**Action Text**, editor Trix nativo de Rails) creados por admin/entrenador, lectura para todo miembro autenticado | `posts` |
| Panel de novedades | Anuncios cortos con fecha de evento (clases, horarios especiales, retos) | `novedades` |

---

## 04 — Stack tecnológico

Monolito Rails con **cero dependencias de Node** (importmap + binario standalone de Tailwind) y **cero servicios externos en runtime** (el stack Solid corre sobre Postgres; no hay Redis).

| Tecnología | Versión | Rol | Notas |
|---|---|---|---|
| Ruby | 3.4.5 | Lenguaje | `.ruby-version`; YJIT + jemalloc en contenedores |
| Rails | 8.1.3 | Framework full-stack | `rails new … --database=postgresql --css=tailwind --asset-pipeline=propshaft --javascript=importmap` |
| PostgreSQL | 17 | Base de datos única | Docker Compose en desarrollo/test; datos anidados en JSONB |
| Propshaft | — | Asset pipeline | Sin transpilación; assets con digest |
| importmap-rails | — | JavaScript sin build | Los módulos JS se sirven tal cual; **no hay `package.json`** |
| Turbo + Stimulus (Hotwire) | — | Interactividad | Navegación SPA-like, frames/streams; JS mínimo y declarativo |
| tailwindcss-rails | v4 | Estilos | Binario standalone; tokens en `@theme` (`app/assets/tailwind/application.css`) |
| DaisyUI | 5 | Componentes UI | CSS-only sobre Tailwind (`daisyui.mjs` vendored, sin Node); tema `advance` mapeado a los tokens §06 |
| Auth nativa Rails 8 | — | Autenticación | `bin/rails generate authentication`: `has_secure_password`, sesiones firmadas, reset por email |
| Pundit | ~2.5 | Autorización por rol | Una policy por modelo; `authorize` en cada controller |
| Solid Queue | — | Jobs en background | `GenerarPlanJob` (IA), vencimiento diario de membresías; corre sobre Postgres |
| Solid Cache | — | Caché de fragmentos | Sobre Postgres; blog/novedades, catálogo de planes y métricas del dashboard (expiración corta) |
| Solid Cable + Turbo Streams | — | Tiempo real | Sobre Postgres; notificación al aprobarse un plan, check-in panel del admin en vivo |
| Action Text | — | Contenido rich del blog | Editor Trix + Active Storage (posts y novedades) |
| Capa de IA multi-proveedor | — | IA generativa | `GeneradorPlanIa` + adaptadores intercambiables (`Ia::ProveedorGemini` activo, `Ia::ProveedorClaude` disponible) elegidos por `IA_PROVEEDOR`; llamada HTTP desde el job; salida JSON estructurada; API keys en credentials/ENV |
| Minitest + Capybara | — | Tests | Unit, integration y system tests en cada fase |
| RuboCop (omakase) + Brakeman + bundler-audit | — | Calidad y seguridad | `dip rubocop` · `dip brakeman`; corren también en CI (`.github/workflows`) |
| dip + Docker Compose | 8.x | Entorno local | `dip provision` levanta todo; ver §13 |
| Kamal 2 + Thruster | — | Despliegue | `Dockerfile` de producción autocontenido |
| dotenv-rails | ~3.2 | Variables de entorno | Solo development/test; `.env` fuera de git |

### ¿Por qué Rails y no la SPA React + Supabase?

Las versiones 1.x delegaban identidad, permisos (RLS) y cómputo (Edge Functions) a Supabase, con una SPA React consumiendo la Data API. La revisión 2.0 lo reemplaza por un monolito Rails por tres razones. Primera: el dominio es **fuertemente server-side** — roles, pagos, membresías, aprobaciones de entrenador — y en Rails eso son modelos, policies y jobs en un solo lugar, testeables con minitest, sin repartir la lógica entre cliente TS, policies SQL y funciones Deno. Segunda: **sin vendor lock-in ni límites de plan free**: auth, jobs, cache y websockets son parte del framework (Rails 8 + Solid stack) y corren en cualquier VPS con Docker vía Kamal. Tercera: **menos JavaScript** — Hotwire cubre la interactividad requerida (formularios, tabs, gráficas server-rendered) sin build step ni Node, lo que reduce superficie de mantenimiento.

**Regla de oro:** el navegador recibe HTML. Si una interacción se puede resolver con Turbo (frames/streams) se resuelve ahí; Stimulus solo para comportamiento puntual (tabs, contadores). Si algo requiere secretos o confianza (API keys de IA, validación de compra), vive en el servidor — controller, service o job.

### ¿Por qué LangChain no?

El único flujo de IA del MVP es una llamada única y estructurada al proveedor configurado (biometría + objetivo → JSON de rutina y dieta) desde `GenerarPlanJob`. No hay cadenas multi-paso, ni RAG, ni memoria conversacional que justifiquen orquestación. Una clase Ruby con `Net::HTTP`/`faraday` y un prompt versionado en el repo es más simple, más barata y más fácil de depurar. La independencia de proveedor se logra con adaptadores propios (`app/services/ia/`): el prompt y el contrato JSON son compartidos y cada adaptador solo traduce la llamada HTTP — hoy **Gemini** (activo) y **Claude**; añadir otro proveedor es un archivo nuevo, elegido por `ENV["IA_PROVEEDOR"]`. Si en fases futuras aparece un coach conversacional, se reevalúa.

---

## 05 — Arquitectura

Monolito Rails clásico (MVC) con dos capas de apoyo: **services** (cálculo puro) y **jobs** (trabajo asíncrono). La separación es de responsabilidad, no de despliegue.

| Capa | Responsabilidad | Implementación | Prohibido |
|---|---|---|---|
| Rutas + Controllers | HTTP, strong params, `authenticate` + `authorize` (Pundit), redirecciones | `config/routes.rb` · `app/controllers` (skinny) | Lógica de negocio y queries complejas |
| Models | Validaciones, asociaciones, scopes, enums de dominio | `app/models` (ActiveRecord) | Llamadas HTTP externas |
| Policies | Autorización por rol y por registro | `app/policies` (Pundit, una por modelo) | Acceso a datos fuera del record/user |
| Services | Lógica pura: IMC, TDEE, déficit/superávit, propensión, horarios | `app/services` — POROs sin estado, testeables sin DB | Acceso a la base o a la sesión |
| Jobs | Trabajo asíncrono: generación de plan con IA, vencimiento de membresías | `app/jobs` (ActiveJob + Solid Queue) | Renderizado |
| Views | HTML server-rendered, partials reutilizables, Turbo Frames/Streams | `app/views` (ERB) + `app/javascript/controllers` (Stimulus) | Queries a la base |

### Diagrama de alto nivel

```
┌───────────────┐   HTTP    ┌─────────────────────────────────────────┐
│   Navegador    │◄────────►│  Rails 8.1 (Puma)                       │
│  HTML + Turbo  │           │  Controllers → Policies (Pundit)        │
│  + Stimulus    │           │      │                                  │
└───────────────┘           │  Models (AR) ── Services (IMC/TDEE)     │
                            │      │                                  │
                            │  Solid Queue ── GenerarPlanJob ─────────┼──→ IA (Gemini │ Claude)
                            └──────┼──────────────────────────────────┘
                                   ▼
                            ┌─────────────┐
                            │ PostgreSQL  │  datos + queue + cache + cable
                            └─────────────┘
```

### Principios de diseño

| Principio | Detalle |
|---|---|
| Convención sobre configuración | Se sigue el camino Rails por defecto (generadores, REST, minitest). Desviarse requiere justificación en este documento. |
| Pundit como única frontera de autorización | Ocultar un link en la vista es UX; el `authorize` del controller y la policy son la seguridad. Toda acción de controller pasa por Pundit (`verify_authorized`). |
| Controllers delgados | Un controller orquesta: autentica, autoriza, delega a modelo/servicio/job, responde. Nada de reglas de negocio inline. |
| Cálculos derivados no se persisten | IMC es columna generada en Postgres; TDEE, déficit y propensión se calculan en services. Solo se guardan los inputs. |
| IA en jobs, nunca en el request | `GenerarPlanJob` corre en Solid Queue: el request del usuario no espera a la IA. Las API keys viven en credentials/ENV, jamás en el cliente. |
| Todo comando local pasa por dip | `dip rails …`, `dip test`, `dip rubocop`, `dip psql`. Nadie necesita Ruby ni Postgres instalados en el host. |
| Tests en cada fase | Cada fase entrega sus models/policies/controllers con tests minitest verdes; los system tests cubren los flujos del §10. |

---

## 06 — Sistema de diseño

### Marca

El logo de Advance Fitness es un **fisicoculturista vectorial monocromo** (pose de doble bíceps frontal, estilo stencil). Por ser monocromo invierte limpiamente a blanco para fondos oscuros.

| Asset | Ruta | Uso |
|---|---|---|
| `logo.svg` (ideal) o `logo.png` | `app/assets/images/brand/` | Header/nav, pantalla de auth, correos |
| `logo-white.svg` | `app/assets/images/brand/` | Variante invertida para nav oscuro y footer |
| `favicon.svg` | `public/` | Favicon (recorte del torso) |

> El archivo fuente del logo lo aporta el cliente; queda pendiente de copiarse. Se referencia con `image_tag "brand/logo.svg"` — nunca embebido inline.

### Paleta de colores

| Token | Hex | Uso |
|---|---|---|
| Volt | `#B4F000` | Acción principal · progreso positivo · CTA de upgrade |
| Steel | `#1E293B` | Texto base · estructura · nav |
| Pulse | `#EF4444` | Alertas · membresía vencida · déficit no cumplido |
| Ocean | `#0EA5E9` | Datos biométricos · gráficas · información |
| Surface | `#F8FAFC` | Fondo de página |
| Card | `#FFFFFF` | Cards y paneles |

### Tipografía

| Fuente | Rol | Uso |
|---|---|---|
| Geist | Body / UI | Texto general, formularios, etiquetas — servida desde Google Fonts (vendored en `app/assets/fonts` como mejora futura) |
| Space Grotesk | Display | Métricas grandes (peso, IMC, kcal), títulos de sección, números de progreso — servida desde Google Fonts |

### Escala tipográfica

| Token | Tamaño | Peso | Uso |
|---|---|---|---|
| `text-display` | 2.8–3.4 rem | 700 | Métrica protagonista (peso actual, kcal restantes) |
| `text-h2` | 1.5 rem | 600 | Nombre de sección o pantalla |
| `text-h3` | 1.1 rem | 600 | Card header, título de post |
| `text-body` | 0.9375 rem (15px) | 400 | Texto general |
| `text-label` | 0.75 rem (12px) | 700 | Tags, estado de membresía, categorías |
| `text-micro` | 0.6875 rem (11px) | 700 | Metadatos, timestamps, ejes de gráficas |

### Design tokens — Tailwind v4 (`@theme` en `app/assets/tailwind/application.css`)

Tailwind v4 es CSS-first: los tokens se declaran en `@theme` y generan las utilidades (`bg-volt`, `text-steel-3`, `font-display`…).

```css
@import "tailwindcss";

@theme {
  /* ── Brand ── */
  --color-volt:    #B4F000;   /* Acción principal, progreso, CTA        */
  --color-volt-d:  #8FBF00;   /* Hover del volt                         */
  --color-pulse:   #EF4444;   /* Alertas, vencido, fuera de objetivo    */
  --color-ocean:   #0EA5E9;   /* Biometría, gráficas, info              */

  /* ── Neutros ── */
  --color-steel:   #1E293B;   /* Texto base                             */
  --color-steel-5: #475569;   /* Texto secundario                       */
  --color-steel-3: #94A3B8;   /* Muted / subtítulos                     */
  --color-steel-1: #CBD5E1;   /* Placeholders, metadatos                */
  --color-surface: #F8FAFC;   /* Fondo de página                        */
  --color-card:    #FFFFFF;   /* Cards y paneles                        */

  /* ── Tipografía ── */
  --font-body:    "Geist", sans-serif;
  --font-display: "Space Grotesk", sans-serif;
}
```

Los componentes visuales reutilizables son **partials ERB** (`app/views/shared/_metric_card.html.erb`, `_navbar.html.erb`…) construidos con clases de **DaisyUI 5** (`card`, `btn`, `input`, `alert`, `badge`…). DaisyUI se vendorea como plugin CSS (`daisyui.mjs` + `daisyui-theme.mjs` en `app/assets/tailwind/`), sin Node; el tema `advance` (declarado en `application.css`) mapea `primary→volt`, `error→pulse`, `accent/info→ocean`, `base-content→steel`.

---

## 07 — Entidades del dominio

Schema en **PostgreSQL** gestionado con **migraciones ActiveRecord** (snake_case, IDs `bigint` autoincrementales por convención Rails, `created_at`/`updated_at` en toda tabla). Los datos anidados de forma natural (horarios, rutinas, dietas) se guardan como **JSONB**. Los nombres de dominio van en español; los plurales se registran en `config/initializers/inflections.rb` (`medicion → mediciones`, etc.). `users` y `sessions` conservan el nombre del generador de auth de Rails.

### `users` — miembro, entrenador o admin (auth + perfil)

| Columna | Tipo | Notas |
|---|---|---|
| `id` | `bigint` PK | — |
| `email_address` | `string` | Unique, normalizado (generador de auth Rails 8) |
| `password_digest` | `string` | bcrypt (`has_secure_password`) |
| `nombre` | `string` | Obligatorio |
| `fecha_nacimiento` | `date` | La edad se deriva, nunca se guarda |
| `sexo` | `string` | `'M'` · `'F'` — requerido por Mifflin-St Jeor |
| `talla_cm` | `decimal(5,1)` | Talla base; cada medición puede actualizarla |
| `fecha_ingreso` | `date` | Fecha de alta en el gimnasio; default hoy |
| `somatotipo` | `string` | enum: `ectomorfo` · `mesomorfo` · `endomorfo` · `nil` |
| `nivel_actividad` | `decimal(2,1)` | Factor 1.2–1.9 para TDEE |
| `rol` | `string` | enum: `miembro` (default) · `entrenador` · `admin` |

### `sessions` — sesiones activas (generador de auth)

| Columna | Tipo | Notas |
|---|---|---|
| `id` | `bigint` PK | — |
| `user_id` | `bigint` | FK → `users` |
| `ip_address` / `user_agent` | `string` | Auditoría de sesión |

### `membresias`

| Columna | Tipo | Notas |
|---|---|---|
| `id` | `bigint` PK | — |
| `user_id` | `bigint` | FK → `users` |
| `fecha_inicio` | `date` | Inicio del período vigente |
| `fecha_vencimiento` | `date` | Vencimiento mensual; renovar la extiende |
| `estado` | `string` | enum: `activa` · `vencida` · `suspendida` (job diario la marca vencida) |
| `horario_acceso` | `jsonb` | `{ "lun": ["06:00","22:00"], … }` — validado en check-in |

### `pagos`

| Columna | Tipo | Notas |
|---|---|---|
| `id` | `bigint` PK | — |
| `membresia_id` | `bigint` | FK → `membresias` |
| `monto` | `decimal(10,0)` | COP, sin decimales |
| `fecha_pago` | `date` | Cuándo pagó |
| `periodo_inicio` / `periodo_fin` | `date` | Período que cubre |
| `metodo` | `string` | enum: `efectivo` · `transferencia` · `tarjeta` |
| `registrado_por_id` | `bigint` | FK → `users` (admin que registró) |

### `accesos` — check-ins e historial de reingresos

| Columna | Tipo | Notas |
|---|---|---|
| `id` | `bigint` PK | — |
| `user_id` | `bigint` | FK → `users` |
| `fecha_hora` | `datetime` | Momento del check-in |
| `tipo` | `string` | enum: `checkin` · `reingreso` (primer acceso tras renovar una membresía vencida) |
| `dentro_de_horario` | `boolean` | Resultado de validar contra `horario_acceso` |

### `mediciones`

| Columna | Tipo | Notas |
|---|---|---|
| `id` | `bigint` PK | — |
| `user_id` | `bigint` | FK → `users` |
| `fecha` | `date` | Una medición por fecha (índice unique `user_id + fecha`) |
| `peso_kg` | `decimal(5,2)` | Input |
| `talla_cm` | `decimal(5,1)` | Input (normalmente estable) |
| `imc` | `decimal(4,1)` | **Columna generada** en Postgres: `peso_kg / (talla_cm/100)^2` |
| `grasa_pct` | `decimal(4,1)` | Opcional |
| `notas` | `text` | Opcional |

### `objetivos_nutricionales`

| Columna | Tipo | Notas |
|---|---|---|
| `id` | `bigint` PK | — |
| `user_id` | `bigint` | FK → `users` |
| `tipo` | `string` | enum: `deficit` · `superavit` · `mantenimiento` |
| `peso_kg` | `decimal(5,2)` | Peso usado en el cálculo (snapshot del input; desde la Fase 3 se precarga de la última medición) |
| `tdee_kcal` | `integer` | TDEE calculado al crear el objetivo (snapshot de inputs) |
| `objetivo_kcal` | `integer` | `deficit: tdee−500` · `superavit: tdee+300..500` |
| `activo` | `boolean` | Solo un objetivo activo por usuario (índice unique parcial) |

### `registros_calorias`

| Columna | Tipo | Notas |
|---|---|---|
| `id` | `bigint` PK | — |
| `user_id` | `bigint` | FK → `users` |
| `fecha` | `date` | Índice unique `user_id + fecha` |
| `kcal_consumidas` | `integer` | Input diario del miembro; si el día se armó con el armador, se recalcula desde `registro_alimentos` al guardar |

### `alimentos` — catálogo nutricional

| Columna | Tipo | Notas |
|---|---|---|
| `id` | `bigint` PK | — |
| `nombre` | `string` | Unique (p. ej. "Arepa de maíz", "Pechuga de pollo") |
| `categoria` | `string` | enum: `proteina` · `carbohidrato` · `grasa` · `fruta_verdura` · `lacteo` · `bebida` · `snack` |
| `porcion` | `string` | Porción de referencia legible: "1 unidad mediana (75 g)", "1 taza cocida (150 g)" |
| `kcal` | `integer` | Por porción |
| `proteinas_g` / `carbohidratos_g` / `grasas_g` | `decimal(5,1)` | Macros por porción |
| `activo` | `boolean` | El admin retira alimentos sin borrar historial |

> Se puebla con un **seed curado de ~120–150 alimentos colombianos** (`db/seeds.rb`); el admin lo mantiene vía CRUD. No se integra ninguna base externa en el MVP.

### `preferencias_alimentarias` — gustos del miembro

| Columna | Tipo | Notas |
|---|---|---|
| `id` | `bigint` PK | — |
| `user_id` | `bigint` | FK → `users` |
| `alimento_id` | `bigint` | FK → `alimentos` |
| `calificacion` | `string` | enum: `le_gusta` · `lo_tolera` · `no_le_gusta` |

> Índice unique `user_id + alimento_id`. Un alimento sin fila = sin calificar (neutral). La IA usa los `le_gusta`, evita los `no_le_gusta` y solo recurre a `lo_tolera` si hace falta nutricionalmente.

### `registro_alimentos` — items del armador de comidas

| Columna | Tipo | Notas |
|---|---|---|
| `id` | `bigint` PK | — |
| `registro_caloria_id` | `bigint` | FK → `registros_calorias` (el día) |
| `alimento_id` | `bigint` | FK → `alimentos` |
| `comida` | `string` | enum: `desayuno` · `almuerzo` · `cena` · `snack` |
| `porciones` | `decimal(4,2)` | Multiplicador de la porción de referencia (0.5, 1, 2…) |

> Las kcal del item **no se persisten** (principio §05: derivados no se guardan): `alimento.kcal × porciones`. Al guardar el día, el total actualiza `registros_calorias.kcal_consumidas`, así las gráficas de `/progreso` siguen funcionando sin cambios.

### `planes` — catálogo de monetización

| Columna | Tipo | Notas |
|---|---|---|
| `id` | `bigint` PK | — |
| `codigo` | `string` | `free` · `personalizado` — unique |
| `nombre` | `string` | Nombre comercial |
| `precio` | `decimal(10,0)` | COP; `0` para free |
| `beneficios` | `jsonb` | Lista de features mostrada en la pantalla de upgrade |

### `suscripciones`

| Columna | Tipo | Notas |
|---|---|---|
| `id` | `bigint` PK | — |
| `user_id` | `bigint` | FK → `users` |
| `plan_id` | `bigint` | FK → `planes` |
| `estado` | `string` | enum: `activa` · `cancelada` · `expirada` |
| `fecha_inicio` / `fecha_fin` | `date` | `fecha_fin` nil para free |

### `planes_personalizados` — output del flujo de IA

| Columna | Tipo | Notas |
|---|---|---|
| `id` | `bigint` PK | — |
| `user_id` | `bigint` | FK → `users` |
| `rutina` | `jsonb` | Días → ejercicios → series/reps, generado por IA |
| `plan_nutricional` | `jsonb` | Comidas → macros → kcal, generado por IA; desde la fase de gustos cada comida incluye `receta: { ingredientes: [{alimento, cantidad}], preparacion }` |
| `generado_por` | `string` | enum: `ia` · `entrenador` |
| `estado` | `string` | enum: `borrador` · `aprobado` — el miembro solo ve aprobados |
| `aprobado_por_id` | `bigint` | FK → `users` (entrenador), nil en borrador |

### `plantillas_comida` — biblioteca del entrenador para el editor de planes

| Columna | Tipo | Notas |
|---|---|---|
| `id` | `bigint` PK | — |
| `tipo` | `string` | enum: `desayuno` · `almuerzo` · `cena` · `snack` — agrupa el picker |
| `nombre` | `string` | Descriptivo ("Desayuno alto en proteína"); unique por tipo |
| `descripcion` | `text` | El contenido de la comida, mismo texto que va al plan |
| `kcal` | `integer` | — |
| `proteinas_g` / `carbohidratos_g` / `grasas_g` | `decimal(5,1)` | — |
| `creado_por_id` | `bigint` | FK → `users`, nil para las del seed |

> Nace con un **seed de ~20 plantillas** (4-5 por tipo) y crece con el uso: en el editor del plan, el entrenador guarda cualquier comida ajustada como plantilla nueva ("guardar como plantilla").

### `posts`

| Columna | Tipo | Notas |
|---|---|---|
| `id` | `bigint` PK | — |
| `autor_id` | `bigint` | FK → `users` |
| `titulo` | `string` | — |
| `slug` | `string` | Unique |
| `contenido` | rich text | **Action Text** (`has_rich_text :contenido`) — editor Trix, sin parser Markdown |
| `publicado` | `boolean` | Los miembros solo ven publicados |
| `publicado_en` | `datetime` | — |

### `novedades`

| Columna | Tipo | Notas |
|---|---|---|
| `id` | `bigint` PK | — |
| `titulo` | `string` | — |
| `contenido` | `text` | Anuncio corto |
| `fecha_evento` | `date` | Fecha de la actividad (clase, reto, cierre) |
| `publicado` | `boolean` | — |

---

## 08 — Seguridad y autenticación

### Autenticación — nativa de Rails 8

| Regla | Detalle |
|---|---|
| Login obligatorio | `ApplicationController` exige sesión (`Authentication` concern del generador); solo login, registro y reset de contraseña son públicos (`allow_unauthenticated_access`). |
| Método principal | Email + password con `has_secure_password` (bcrypt). Sesión persistida en `sessions` con cookie firmada `httponly` + `same_site: :lax`. |
| Google OAuth | Segundo método vía `omniauth-google-oauth2` + `omniauth-rails_csrf_protection` (se agrega en la fase 1.5); crea/vincula el `user` por email verificado. |
| Recuperación | `PasswordsMailer` con token firmado de corta duración (generador de auth). |
| Rate limiting | `rate_limit` nativo de Rails 8 en login y reset (fuerza bruta). |

### Autorización — Pundit

Roles en `users.rol`: `miembro` · `entrenador` · `admin`. **Staff** = entrenador o admin. Cada modelo tiene su policy; los controllers usan `authorize` + `policy_scope` y `verify_authorized` está activo globalmente.

| Policy | Ver (show/index) | Crear | Editar | Eliminar |
|---|---|---|---|---|
| `UserPolicy` | propio, o staff ve todos | registro público | propio (campos de perfil; **nunca `rol`**), admin todo | nadie |
| `MembresiaPolicy` | propia, o staff todas | solo staff | solo staff | nadie |
| `PagoPolicy` | propios, o staff todos | solo staff | nadie (historial inmutable) | nadie |
| `AccesoPolicy` | propios, o staff todos | staff, o propio (self check-in) | nadie | nadie |
| `MedicionPolicy` | propias, o staff todas | propio | propia (mismo día) | propia (mismo día) |
| `ObjetivoNutricionalPolicy` | propios, o staff | propio | propio | propio |
| `RegistroCaloriasPolicy` | propios, o staff | propio | propio (mismo día) | propio (mismo día) |
| `PlanPolicy` | todos los autenticados | solo admin | solo admin | solo admin |
| `SuscripcionPolicy` | propia, o staff | solo staff | solo staff | nadie |
| `PlanPersonalizadoPolicy` | propio **solo si `aprobado`**; staff todos | job (sistema) / staff | staff (aprobar/editar) | staff |
| `PostPolicy` | autenticados si `publicado`, staff todos | staff | staff | admin |
| `NovedadPolicy` | autenticados si `publicado`, staff todas | staff | staff | admin |

El historial financiero (pagos) es inmutable a propósito: se corrige con un registro nuevo, no editando.

### Defensas del framework y secretos

| Regla | Detalle |
|---|---|
| Strong parameters | Ningún mass-assignment sin `params.expect/permit`; `rol` jamás es asignable desde formularios. |
| CSRF / XSS / SQLi | Protecciones por defecto de Rails: token CSRF, escape de ERB, queries parametrizadas de ActiveRecord. |
| API keys de IA | `GEMINI_API_KEY` / `ANTHROPIC_API_KEY` en ENV o `Rails.application.credentials` (`gemini_api_key` / `anthropic_api_key`; en producción vía Kamal secrets). Jamás llegan a una vista. |
| Validación server-side del upgrade | `GenerarPlanJob` verifica en la base (no en el request) que el usuario tenga suscripción `personalizado` activa antes de llamar a la IA. |
| Auditoría estática | `dip brakeman` y `bundler-audit` en cada fase y en CI; cero hallazgos altos para cerrar una fase. |

---

## 09 — Contrato de rutas (REST)

Rutas RESTful de Rails; los nombres siguen el dominio en español. Las de staff van bajo namespaces `admin` y `entrenador` (protegidos por Pundit, no solo por el namespace).

| Ruta | Verbo | Rol mínimo | Descripción |
|---|---|---|---|
| `/session` · `/registro` · `/passwords` | — | público | Login/logout, registro, reset (generador auth) |
| `/dashboard` | GET | miembro | Métricas del día: membresía, última medición, kcal restantes |
| `/onboarding` | GET/PATCH | miembro | Wizard: perfil → somatotipo → primera medición → objetivo |
| `/mediciones` | GET/POST | miembro | Historial + nueva medición; `GET /progreso` para las gráficas |
| `/registros_calorias` | POST/PATCH | miembro | Upsert del registro diario de calorías |
| `/objetivo` | GET/POST | miembro | Ver y fijar objetivo (déficit/superávit/mantenimiento) |
| `/gustos` | GET/PATCH | miembro | Selector interactivo por categorías; califica alimentos (le gusta / lo tolera / no le gusta) |
| `/armador` | GET/POST | miembro | Componer las comidas del día con kcal/macros en vivo; guardar registra el consumo |
| `/admin/alimentos` | CRUD | admin | Mantenimiento del catálogo nutricional (seed inicial curado) |
| `/mi_plan` | GET | miembro | Plan free o personalizado aprobado |
| `/upgrade` | GET | miembro | Comparación Free vs. Personalizado |
| `/blog` · `/blog/:slug` · `/novedades` | GET | miembro | Comunidad (solo publicados) |
| `/admin/users` · `/admin/membresias` · `/admin/pagos` | CRUD | admin | Gestión de miembros, membresías y pagos |
| `/admin/checkins` | GET/POST | staff | Búsqueda de miembro + registro de acceso (valida horario) |
| `/admin/membresias/:id/renovacion` | POST | admin | Transacción: crea pago + extiende vencimiento |
| `/admin/suscripciones` | CRUD | admin | Alta del plan personalizado (dispara `GenerarPlanJob`) |
| `/entrenador/borradores` | GET | entrenador | Cola de planes generados por IA pendientes de revisión; cada fila abre el editor |
| `/planes_personalizados/:id` | GET/PATCH | staff | Editor compartido (entrenador + admin): comidas editables, historial del miembro; PATCH = modo avanzado JSON |
| `/planes_personalizados/:id/publicar` | POST | staff | Da visibilidad al miembro (`estado→aprobado`, fija `aprobado_por`) |
| `/planes_personalizados/:id/comidas[/:i]` | POST/PATCH/DELETE | staff | Autosave por comida (índice del array jsonb); responde JSON con el total recalculado |
| `/entrenador/plantillas_comida` | POST/DELETE | staff | Guardar una comida del editor como plantilla · retirar plantillas |
| `/admin/posts` · `/admin/novedades` | CRUD | staff | Contenido de comunidad |

> **Jobs (sin ruta):** `GenerarPlanJob` (Solid Queue, disparado al crear la suscripción premium) y `VencerMembresiasJob` (recurrente diario vía `config/recurring.yml`) — marca `vencida` toda membresía con `fecha_vencimiento < hoy`.

---

## 10 — Flujos principales

### Flujo A — Registro inicial de biometría (onboarding)

| Paso | Acción | Detalle |
|---|---|---|
| 1 | Crear cuenta | Email + password (o Google). Se crea el `user` con `rol: miembro` y `fecha_ingreso: hoy`. |
| 2 | Completar perfil | Nombre, fecha de nacimiento, sexo, talla, nivel de actividad (wizard de onboarding). |
| 3 | Cuestionario de somatotipo | 5 preguntas guiadas → clasifica ectomorfo / mesomorfo / endomorfo y lo guarda en el user. |
| 4 | Primera medición | Peso (talla precargada). Postgres genera el IMC; la vista muestra el estado de peso (OMS) y la propensión a sobrepeso. |
| 5 | Fijar objetivo | El miembro elige bajar de peso / ganar masa / mantener. El service calcula TDEE y el objetivo kcal (déficit −500 o superávit +300..500). |
| 6 | Aterrizar en el dashboard | Métricas del día, plan free con guías según su objetivo, y CTA de upgrade. |

### Flujo B — Compra de plan personalizado (upgrade)

| Paso | Acción | Detalle |
|---|---|---|
| 1 | Ver oferta | El miembro abre "Mejorar plan": comparación Free vs. Personalizado desde `planes.beneficios`. |
| 2 | Pagar en recepción | MVP sin pasarela: el admin registra el pago y crea la `suscripcion` al plan personalizado. |
| 3 | Generar con IA | Al crearse la suscripción se encola `GenerarPlanJob`: revalida la suscripción, arma el prompt con biometría reciente, somatotipo, objetivo y restricciones, y pide al proveedor de IA configurado un JSON de rutina semanal + plan nutricional. |
| 4 | Revisión del entrenador | El plan queda en `borrador`. El entrenador lo edita en un **editor por comida con autosave**: nombre/descripción/kcal/macros se guardan al instante (estados guardando/guardado/error+reintentar), aplica `plantillas_comida` desde un **modal** o guarda comidas como plantillas nuevas. El JSON crudo queda como modo avanzado. |
| 4b | Publicación y edición continua | **Publicar** (botón desacoplado de la edición) da visibilidad al miembro. Tras publicar, el **admin** puede seguir editando el plan desde Suscripciones —con el **historial** de planes del miembro— y los cambios se reflejan en vivo. |
| 5 | Publicación | Al pasar a `aprobado`, la policy lo hace visible para el miembro, que lo ve en "Mi plan" con rutina por día y comidas con macros. |

### Flujo C — Actualización de progreso mensual

| Paso | Acción | Detalle |
|---|---|---|
| 1 | Recordatorio | El dashboard marca "medición pendiente" si la última tiene más de 30 días. |
| 2 | Nueva medición | El miembro registra peso (y grasa % opcional). Se agrega el punto a la serie. |
| 3 | Ver progreso | Gráficas SVG de peso e IMC por mes (partial server-rendered); delta contra la medición anterior y contra la inicial. |
| 4 | Recalibrar | Si el objetivo sigue activo, el service recalcula TDEE con el peso nuevo y actualiza el objetivo kcal. |
| 5 | Señal al entrenador | Si el miembro es premium y su tendencia se aleja del objetivo 2 meses seguidos, el panel del entrenador lo destaca para regenerar el plan (repite Flujo B paso 3). |

### Flujo D — Check-in y control de acceso

| Paso | Acción | Detalle |
|---|---|---|
| 1 | Identificar | Recepción busca al miembro (nombre / email) en `/admin/checkins`, o el miembro se auto-identifica en la tablet de entrada. |
| 2 | Validar | Membresía `activa` + hora dentro de `horario_acceso`. Vencida → aviso de renovación; fuera de horario → se registra con `dentro_de_horario: false` y alerta. |
| 3 | Registrar | Crea el `acceso`. Si es el primer acceso tras una renovación de membresía vencida, `tipo: reingreso` — esto alimenta el historial de reingresos. |
| 4 | Renovar (si aplica) | El admin registra el pago; la renovación extiende el vencimiento dentro de una transacción. |

### Flujo E — Gustos y armador de comidas

| Paso | Acción | Detalle |
|---|---|---|
| 1 | Calificar gustos | En `/gustos`, cards de alimentos agrupadas por categoría; un tap cicla 💚 le gusta → 😐 lo tolera → ❌ no le gusta (Stimulus + Turbo, sin recargar). Editable siempre. |
| 2 | Armar el día | En `/armador`, el miembro agrega alimentos a desayuno/almuerzo/cena/snacks con porciones ajustables. Los 💚 aparecen primero; los ❌ ocultos por defecto. Kcal y macros suman en vivo contra `objetivo_kcal`. |
| 3 | Registrar | Guardar hace upsert del `registro_caloria` del día + sus `registro_alimentos`, y recalcula `kcal_consumidas`. Las gráficas de `/progreso` y la adherencia se alimentan igual que hoy. |
| 4 | IA personalizada | `GenerarPlanJob` añade al prompt los gustos del miembro: el plan usa `le_gusta`, excluye `no_le_gusta`, y cada comida trae `receta` (ingredientes con cantidades + preparación). |
| 5 | Revisión | El entrenador revisa el plan con recetas en su panel igual que en el Flujo B (nada cambia en la aprobación). |

---

## 11 — Fases

| Fase | Nombre | Duración | Entregable | Criterio de aceptación |
|---|---|---|---|---|
| 1 | Base Rails & Auth | ~1 semana | App Rails 8.1 + dip/Docker, auth nativa (login/registro/reset), campos de perfil + rol en `users`, Pundit instalado, layout con tokens §06 | `dip provision && dip test` en verde; puedo registrarme e iniciar sesión; sin sesión todo redirige a login |
| 2 | Membresías & Accesos | ~1.5 semanas | Modelos membresías/pagos/accesos + policies, panel admin, check-in con validación de horario, `VencerMembresiasJob` | El admin da de alta una membresía, registra un pago y el check-in valida estado y horario; tests de policies verdes |
| 3 | Biometría & Progreso | ~1.5 semanas | Mediciones (IMC generado), somatotipo, wizard de onboarding, gráficas SVG mensuales | Registro 3 mediciones y veo la gráfica con clasificación OMS y propensión correctas |
| 4 | Nutrición & Objetivos | ~1 semana | Services TDEE, objetivos déficit/superávit, registro diario de calorías | Al fijar "bajar de peso" veo mi objetivo kcal y el faltante del día se actualiza al registrar consumo |
| 5 | Planes & IA | ~1.5 semanas | Catálogo de planes, suscripciones, `GenerarPlanJob` (IA multi-proveedor), panel de aprobación del entrenador | Un miembro premium recibe un plan generado por IA solo después de la aprobación del entrenador |
| 5.6 | Editor de plan inline (entrenador + admin) | ~1 semana | Editor por comida con **autosave tolerante a fallos** (estados guardando/guardado/error+reintentar), **modal** de plantillas (`plantillas_comida`, seed + "guardar como plantilla"), botón Publicar desacoplado, editable también por el **admin desde Suscripciones** con **historial del miembro**, JSON como modo avanzado; vista del miembro con macros por comida | El staff edita comidas inline y ven guardado en vivo; una falla de red no pierde datos y ofrece reintentar; el miembro ve el plan solo tras publicar |
| 6 | Nutrición personalizada & Gustos | ~2 semanas | Catálogo `alimentos` (seed colombiano + CRUD admin), calificación de gustos (`/gustos`), armador de comidas con registro del día (`/armador`), gustos + recetas en el prompt de IA, benchmark de modelo Gemini | El miembro califica alimentos y arma su día viendo kcal en vivo; el registro alimenta `/progreso`; el plan IA de un premium no incluye ningún alimento `no_le_gusta` y cada comida trae receta |
| 7 | Comunidad & Cierre | ~1 semana | Blog, novedades, pulido responsive, checklist MVP completo | Un miembro lee posts y novedades publicadas; todo el checklist §15 en verde |

> **Nota (julio 2026):** la Fase 3 se **aplaza** y la Fase 4 se adelanta. Mientras no existan mediciones, los inputs del TDEE se capturan así: fecha de nacimiento, sexo, talla y nivel de actividad en un formulario de **"Completar perfil"** (columnas ya existentes en `users`), y el **peso** como snapshot en `objetivos_nutricionales.peso_kg` al fijar el objetivo. Cuando la Fase 3 llegue, el peso se precargará de la última medición y la recalibración seguirá el Flujo C.
>
> **Nota 3 (julio 2026):** se inserta la **Fase 6 — Nutrición personalizada & Gustos** antes de Comunidad (que pasa a Fase 7). Decisiones cerradas con el cliente: catálogo por **seed curado colombiano** (no base externa); gustos y armador **para todos los miembros** (el plan IA sigue siendo premium); el armador **registra el consumo del día** (reemplaza el input manual de kcal cuando se usa); recetas **dentro del plan premium** (JSONB), no como biblioteca aparte. Durante la fase se hace un **benchmark de modelos Gemini** (`gemini-2.5-flash-lite` actual vs. `gemini-3.1-flash-lite`) con la misma petición real; el ganador queda como default de `GEMINI_MODELO`. La Fase 6 incluye además el **voto de menú del miembro** con el modelo **"alternativas por comida"** (cada comida ofrece 2-3 opciones y el miembro marca su favorita 👍), que se apoya en el editor de la Fase 5.6.
>
> **Nota 2:** de la Fase 3 se **adelanta la mitad "Progreso"** (`GET /progreso`, gráficas SVG server-rendered §14) alimentada con los datos que ya existen: tendencia de **peso** desde los snapshots de `objetivos_nutricionales`, **calorías diarias vs. objetivo** desde `registros_calorias` y **asistencia** desde `accesos`. La mitad "Biometría" (tabla `mediciones` con IMC generado, clasificación OMS y wizard de onboarding) sigue aplazada; al llegar, la gráfica de peso pasará a leer de `mediciones`.

---

## 12 — Decisiones fijas

Estas decisiones están cerradas. Reabrirlas durante el MVP genera deuda técnica sin retorno.

| Decisión | Valor | Por qué |
|---|---|---|
| Framework | Rails 8.1 monolito (Ruby 3.4.5) | Un solo lenguaje para dominio server-side; auth, jobs, cache y cable incluidos |
| Frontend | Hotwire (Turbo + Stimulus) + importmap — **sin Node, sin bundler JS** | Server-rendered; cero build step de JavaScript |
| Estilos | Tailwind CSS v4 (`tailwindcss-rails`, binario standalone) | Tokens CSS-first en `@theme`; mismos tokens de la v1.x |
| Componentes UI | DaisyUI 5 (CSS-only, vendored — sin Node) | Look tipo shadcn en clases CSS puras; Stimulus cubre el rol de Alpine.js y ActiveModel el de zod |
| Base de datos | PostgreSQL 17 | JSONB para datos anidados, columnas generadas (IMC) |
| Background / cache / websockets | Solid Queue · Solid Cache · Solid Cable | Todo sobre Postgres; **sin Redis ni servicios extra** |
| Autenticación | Nativa Rails 8 (`has_secure_password` + sesiones) · Google OAuth como segundo método | Sin dependencia de BaaS; el generador oficial es auditable |
| Autorización | Pundit, una policy por modelo, `verify_authorized` global | El servidor decide permisos; las vistas solo ocultan UX |
| IA | Capa multi-proveedor (`GeneradorPlanIa` + adaptadores Gemini/Claude, `IA_PROVEEDOR`) desde `GenerarPlanJob` (Solid Queue), salida JSON estructurada | API keys server-side; humano (entrenador) aprueba antes de publicar |
| Orquestación IA | Llamada HTTP directa, sin LangChain | Un solo paso de IA no justifica un framework de orquestación |
| Contenido del blog | Action Text (Trix + Active Storage) | Editor rich nativo de Rails; sin parser Markdown que mantener |
| Tiempo real | Turbo Streams sobre Solid Cable | Aprobación de plan y check-ins en vivo sin polling ni Redis |
| Entorno local | dip 8 + Docker Compose (`Dockerfile.dev`, Postgres 17 en contenedor) | Nadie instala Ruby/Postgres en el host; onboarding = `dip provision` |
| Despliegue | Kamal 2 + Thruster (`Dockerfile` de producción del generador) | Autocontenido, cualquier VPS con Docker |
| Tests | Minitest + fixtures + Capybara (system) | Stack por defecto de Rails; corre con `dip test` |
| Calidad | RuboCop omakase · Brakeman · bundler-audit | Ya vienen con Rails 8.1; corren en CI |
| Gráficas | SVG inline en partials ERB | Cero dependencias de charts; suficiente para series mensuales |
| Fórmulas | OMS (IMC) + Mifflin-St Jeor (TMB/TDEE) | Estándares documentados y auditables |
| Datos anidados | JSONB (`horario_acceso`, `rutina`, `plan_nutricional`) | Evita joins innecesarios; misma forma que en memoria |
| Nombres | Dominio en español (con `inflections.rb`); `users`/`sessions` del generador quedan en inglés | UI y datos en español; no se pelea contra el generador |
| Moneda | COP — sin decimales | El gimnasio no maneja centavos |

---

## 13 — Estructura del proyecto y entorno dip

Estructura estándar de Rails; lo específico del proyecto son `app/services`, `app/policies` y el entorno dockerizado.

```
advance_fitness_app/
│
├── app/
│   ├── controllers/               ← REST + namespaces admin/ y entrenador/
│   ├── models/                    ← user, membresia, pago, acceso, medicion…
│   ├── policies/                  ← Pundit (una por modelo, §08)
│   ├── services/                  ← calculadora_imc.rb · calculadora_tdee.rb ·
│   │                                clasificador_somatotipo.rb · generador_prompt_plan.rb
│   ├── jobs/                      ← generar_plan_job.rb · vencer_membresias_job.rb
│   ├── views/                     ← ERB + partials compartidos en views/shared/
│   ├── javascript/controllers/    ← Stimulus (tabs, quiz de somatotipo…)
│   └── assets/
│       ├── tailwind/application.css   ← @theme con los tokens §06
│       └── images/brand/              ← logo.svg · logo-white.svg
│
├── config/
│   ├── routes.rb                  ← contrato §09
│   ├── recurring.yml              ← VencerMembresiasJob diario (Solid Queue)
│   └── initializers/inflections.rb ← plurales en español
│
├── db/migrate/                    ← migraciones ActiveRecord (schema §07)
├── test/                          ← minitest: models, policies, controllers, system
│
├── Dockerfile                     ← PRODUCCIÓN (Kamal + Thruster)
├── Dockerfile.dev                 ← desarrollo (usado por docker-compose)
├── docker-compose.yml             ← web (bin/dev) + db (postgres:17-alpine)
├── dip.yml                        ← comandos: rails · test · rubocop · brakeman · psql
└── Procfile.dev                   ← web (puma -b 0.0.0.0) + css (tailwind watch)
```

### Flujo de trabajo con dip

| Comando | Qué hace |
|---|---|
| `dip provision` | Levanta todo desde cero: build de la imagen dev, `bundle install` (volumen `bundle`), `db:prepare` en development y test |
| `dip rails s` | Servidor en `http://localhost:3000` (publica puertos) |
| `dip rails c` · `dip rails db:migrate` · `dip rails g …` | Cualquier comando Rails dentro del contenedor |
| `dip test` | Suite minitest completa (RAILS_ENV=test, base de test propia) |
| `dip rubocop` · `dip brakeman` | Lint y análisis de seguridad |
| `dip psql` | Consola Postgres de desarrollo |
| `dip bash` | Shell dentro del contenedor web |

> **Bases de datos:** dentro de Docker, `DATABASE_URL` y `TEST_DATABASE_URL` apuntan al servicio `db` del compose (desarrollo y test separadas). El `DATABASE_URL` de Supabase que quede en `.env` **no aplica dentro de los contenedores** — queda reservado para un uso futuro (p. ej. producción gestionada) o se elimina.

---

## 14 — Vistas y componentes

Los "componentes" son **partials ERB** (datos vía locals) más controladores **Stimulus** cuando hay comportamiento en el cliente. Nada consulta la base desde la vista: el controller pasa lo necesario.

| Componente | Tipo | Descripción | Fase |
|---|---|---|---|
| `shared/_metric_card` | Partial | Card de métrica del dashboard (título, valor display, badge de estado) | F1 |
| `shared/_badge_estado` | Partial | Badge activa/vencida/borrador/aprobado con colores §06 | F1 |
| `sessions/new` · `registrations/new` | Vista | Login / registro (auth nativa + botón Google) | F1 |
| `membresias/_resumen` | Partial | Vencimiento, días restantes, tiempo activo | F2 |
| `admin/checkins/index` | Vista + Turbo | Búsqueda de miembro y registro de acceso sin recargar (Turbo Frame) | F2 |
| `mediciones/_form` | Partial | Formulario de medición; al guardar muestra IMC y clasificación (Turbo Stream) | F3 |
| `mediciones/_grafica_progreso` | Partial SVG | Serie mensual de peso/IMC con deltas, generada en el servidor | F3 |
| `onboarding/quiz_somatotipo` | Stimulus | Cuestionario de 5 pasos que clasifica el somatotipo | F3 |
| `nutricion/_tracker_calorias` | Partial + Turbo | Kcal objetivo vs. consumidas del día, barra de progreso | F4 |
| `planes/_comparador` | Partial | Tabla Free vs. Personalizado desde `planes.beneficios` | F5 |
| `planes_personalizados/_plan` | Partial | Rutina por día (tabs Stimulus) y comidas con macros | F5 |
| `entrenador/borradores/show` | Vista | Revisión/edición del JSONB del borrador de IA + botón aprobar | F5 |
| `posts/index` · `posts/show` | Vista | Blog (contenido Action Text; fragmentos cacheados con Solid Cache) | F6 |
| `novedades/_board` | Partial | Tarjetas de anuncios ordenadas por `fecha_evento` | F6 |

### Patrón de partial

```erb
<%# app/views/shared/_metric_card.html.erb %>
<%# locals: (titulo:, valor:, estado: nil) %>
<div class="rounded-xl bg-card p-6 shadow-sm">
  <span class="text-label text-steel-3"><%= titulo %></span>
  <span class="font-display text-display"><%= valor %></span>
  <% if estado %>
    <%= render "shared/badge_estado", estado: estado %>
  <% end %>
</div>
```

---

## 15 — Checklist MVP

El sistema está listo para uso real cuando todos estos puntos estén en verde.

| Funcional | Calidad y seguridad |
|---|---|
| Registro + login funcionan; sin sesión todo redirige a login | `dip test` completo en verde (models, policies, controllers, system) |
| El registro fija `fecha_ingreso` y `rol: miembro` | Toda acción de controller pasa por Pundit (`verify_authorized` sin excepciones) |
| Renovar membresía registra el pago y extiende el vencimiento (transacción) | Un miembro no puede leer datos de otro (tests de policy con dos usuarios) |
| El check-in valida estado y horario, y clasifica reingresos | `rol` no es asignable por mass-assignment (test explícito) |
| La medición calcula IMC (columna generada), clasificación OMS y propensión | Brakeman y bundler-audit sin hallazgos altos |
| Las gráficas muestran el progreso mensual con deltas correctos | Las API keys de IA no aparecen en código ni en vistas (solo credentials/ENV) |
| Déficit y superávit se calculan con Mifflin-St Jeor + factor de actividad | `GenerarPlanJob` rechaza usuarios sin suscripción premium activa |
| El plan free muestra guías según el objetivo elegido | Sin N+1 en dashboards y paneles (verificado con logs) |
| El plan IA solo es visible tras aprobación del entrenador | Responsive en móvil 375px, tablet y desktop |
| Blog y novedades muestran solo contenido publicado | Fechas y moneda en formato es-CO; `dip provision` funciona desde cero |

> **Siguiente paso recomendado:** cerrar la Fase 1: campos de perfil + rol en `users` (migración), Pundit con `ApplicationPolicy` y `verify_authorized`, layout base con tokens §06 y logo, y vista de registro (el generador de auth solo trae login/reset). Después, Fase 2 (Membresías & Accesos).
