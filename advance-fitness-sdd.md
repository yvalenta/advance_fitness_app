# Advance Fitness — Software Design Document · v2.0

> **Open Spec v2.0** · Aplicación web integral de gestión de gimnasio: membresías y accesos, biometría, nutrición, planes personalizados con IA y comunidad.
> Stack: Ruby on Rails 8.1 (monolito) · PostgreSQL · Hotwire (Turbo + Stimulus) · Tailwind CSS · Solid Queue/Cache/Cable · Pundit. Entorno local: **dip + Docker Compose**.

| Metadato | Valor |
|---|---|
| Versión | 2.0 — Open Spec (transición de stack: SPA React + Supabase → monolito Rails 8.1) |
| Estado | Definición inicial |
| Repositorio | `git@github.com:yvalenta/advance_fitness_app.git` — nuevo, construido de cero |
| Stack | Rails 8.1.3 · Ruby 4.0.5 · PostgreSQL 17 · Hotwire · Tailwind · Pundit · Solid stack |
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
| Plan Free: rutinas y guías básicas para subir o bajar de peso | ~~Notificaciones push~~ → revertido en agosto 2026: **Web Push del navegador** entra como Fase 15 (recordatorio de racha; ver Nota 20). Sigue excluido el push nativo (APNs/FCM vía app de tienda) |
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
| Plan sugerido incluido con la membresía | Rutina de fuerza armada **por reglas** (sin IA) según el **objetivo** del miembro desde `plantillas_ejercicio`; desde la Fase 5.11 se **persiste** como `plan_personalizado` (`generado_por: reglas`, aprobado de una vez) al crear la membresía — si el miembro no tiene objetivo, se le pregunta en "Mi plan" y ahí se genera. **Editable por el miembro y el staff** (músculos del día y ejercicios, popup con buscador y sesiones por músculo) | `planes_personalizados`, `plantillas_ejercicio` |
| Membresía incluida con la suscripción | El alta de una suscripción personalizada **crea o reactiva** la membresía automáticamente, sin pago aparte (va incluida en el precio del plan) — Fase 5.11 | `membresias`, `suscripciones` |

### Módulo B — Salud y Biometría

| Requerimiento | Solución | Entidad |
|---|---|---|
| Inputs básicos: peso, edad, talla | Formulario de medición; edad derivada de `users.fecha_nacimiento` | `mediciones` |
| Estado de peso actual (IMC / BMI) | Columna generada en Postgres: `imc = peso_kg / (talla_cm/100)^2`, clasificada según rangos OMS | `mediciones` |
| Indicador de propensión a sobrepeso | Servicio: tendencia del IMC en las últimas 3 mediciones + somatotipo | Derivado |
| Identificación del somatotipo | Cuestionario guiado en onboarding → `ectomorfo` · `mesomorfo` · `endomorfo` | `users.somatotipo` |
| Gráficas de progreso mensual | Serie temporal de `mediciones` renderizada como SVG inline en un partial (sin librería de charts) | `mediciones` |
| Auto-registro de peso del miembro | Formulario ligero solo-peso (Fase 5.9) → crea una `medicion` del propio miembro; alimenta la serie de peso de `/progreso`. Desde la Fase 5.12 el miembro también **agrega pesos de fechas pasadas y corrige** los existentes (upsert por fecha, sin días futuros) | `mediciones` |

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
| Registro de calorías consumidas | Registro diario simple: fecha + kcal totales; desde la Fase 5.11 las kcal de **días pasados** también son editables ("Últimos días") y hay **alertas en vivo** cuando lo editado se sube o se baja del objetivo (no alineado) | `registros_calorias` |
| Objetivo diario ajustable | El miembro puede **editar manualmente** su `objetivo_kcal` activo (además del cálculo TDEE±) — Fase 5.11 | `objetivos_nutricionales` |
| Déficit calórico (bajar de peso) | Objetivo = `TDEE − 500 kcal`; la app muestra cuántas kcal faltan por quemar hoy | `objetivos_nutricionales` |
| Superávit calórico (masa muscular) | Objetivo = `TDEE + 300–500 kcal` según somatotipo | `objetivos_nutricionales` |
| Catálogo de alimentos | Seed curado de ~120–150 alimentos comunes en Colombia con kcal/macros por porción; CRUD del admin para mantenerlo | `alimentos` |
| Gustos del miembro | Selector interactivo por categorías: cada alimento se califica `le_gusta` · `lo_tolera` · `no_le_gusta`; editable siempre en "Mis gustos" | `preferencias_alimentarias` |
| Armador de comidas | El miembro compone desayuno/almuerzo/cena/snacks con alimentos y porciones, ve kcal y macros en vivo contra su objetivo, y al guardar el día queda registrado como su consumo | `registro_alimentos`, `registros_calorias` |
| Recetas personalizadas | Cada comida del plan premium trae receta generada por IA (ingredientes con cantidades + preparación) que usa los `le_gusta` y excluye los `no_le_gusta` | `planes_personalizados.plan_nutricional` |

### Módulo D — Planes y Monetización

| Requerimiento | Solución | Entidad |
|---|---|---|
| Plan Free / básico | Miembro sin membresía: guías estáticas por objetivo. Miembro con membresía activa: **plan básico de entrenamiento por reglas** (§03 Módulo A) además de las guías | `planes`, `plantillas_ejercicio` |
| Upgrade a Plan Personalizado | Compra registrada por admin → se toma una **medición antropométrica** (obligatoria) → `GenerarPlanJob` (Solid Queue) genera con IA una rutina + plan nutricional a partir de la **antropometría**, la biometría y el objetivo; el entrenador revisa y aprueba antes de publicarse al miembro | `planes_personalizados`, `mediciones` |
| Seguimiento de entrenamiento | El miembro marca **Hecho/Pendiente + nota** por ejercicio del día (hoy o días pasados) en "Mi plan", autosave dinámico sin recargar (Fase 5.10) | `registros_entrenamiento` |
| Rutina editable por el miembro | El miembro **edita la rutina de su propio plan publicado** (sugerido o de IA): músculos del día, ejercicios y sesiones desde el popup. La **nutrición** sigue siendo solo del staff (Fase 5.12) | `planes_personalizados` |

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
| Ruby | 4.0.5 | Lenguaje | `.ruby-version`; YJIT + jemalloc en contenedores (ZJIT disponible pero experimental — se activará en 4.1) |
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
| Capa de IA multi-proveedor | — | IA generativa | `GeneradorPlanIa` + adaptadores intercambiables (`Ia::ProveedorGemini` activo con **fallback de modelo** ante 503, `Ia::ProveedorClaude` disponible) elegidos por `IA_PROVEEDOR`; llamada HTTP desde el job; salida JSON estructurada; API keys en credentials/ENV |
| Config `Negocio` | — | Parámetros del negocio | `config/negocio.yml` + overrides por ENV (precios, duración de membresía, nombre) leídos por `app/services/negocio.rb`; permite clonar la app a otro gimnasio sin tocar código |
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

### Paleta de colores — dos temas (rev. Fase 16)

Desde la Fase 16 el sistema tiene **dos temas**: `advance` (oscuro, el default del producto desde la
Fase 13.3) y `advance-claro` (opcional, hueso + tinta con el MISMO volt — referencia "Pulse"). La
preferencia vive en `users.tema` (`oscuro` · `claro` · `sistema`, default `oscuro`) y se elige en
el perfil; `sistema` sigue al SO en CSS puro, sin JS ni flash.

| Token | Oscuro `advance` | Claro `advance-claro` | Uso |
|---|---|---|---|
| Volt | `#B4F000` | `#B4F000` (chips) / `volt-d` para texto | Acción principal · progreso · CTA — constante de marca |
| base-200 (fondo) | `#0C1322` | `#F1EFE8` hueso cálido | Fondo de página |
| base-100 (card) | `#111827` | `#FAF9F5` | Cards y paneles |
| base-300 | `#1E2D42` | `#E0DCD1` | Bordes, divisores |
| base-content | `#E2E8F0` | `#1C1917` tinta | Texto base |
| steel-3 / steel-5 | escala texto-sobre-oscuro | espejo texto-sobre-claro | Texto secundario / terciario |
| Pulse | `#EF4444` | `#DC2626` | Alertas · vencido |
| Ocean | `#0EA5E9` | `#0284C7` | Biometría · info |

**Regla de identidad:** las superficies hero (`.gradient-hero`: navbar, auth, cabeceras, landing de
campañas) permanecen en **tinta oscura en ambos temas** — son el sello de marca (chips tinta de la
referencia); por eso sus `text-white/*` son legítimos y no se migran.

### Tipografía

| Fuente | Rol | Uso |
|---|---|---|
| Geist | Body / UI | Texto general, formularios, etiquetas — **self-hosted** en `app/assets/fonts` (woff2 400–700, `font-display: swap`; Google Fonts eliminado en Fase 16 por render-blocking) |
| Space Grotesk | Display | Métricas grandes (peso, IMC, kcal), títulos, números de progreso — self-hosted (500–700) |

### Escala tipográfica

| Token | Tamaño | Peso | Uso |
|---|---|---|---|
| `text-display` | 2.8–3.4 rem | 700 | Métrica protagonista (peso actual, kcal restantes) |
| `text-h2` | 1.5 rem | 600 | Nombre de sección o pantalla |
| `text-h3` | 1.1 rem | 600 | Card header, título de post |
| `text-body` | 0.9375 rem (15px) | 400 | Texto general |
| `text-label` | 0.75 rem (12px) | 700 | Tags, estado de membresía, categorías |
| `text-micro` | 0.6875 rem (11px) | 700 | Metadatos, timestamps, ejes de gráficas |

### Arquitectura de tokens — Tailwind v4 + daisyUI por tema (rev. Fase 16)

Tailwind v4 es CSS-first y compila cada utilidad a `var(--color-*)`, lo que hace el theming barato:
**las vistas no saben de temas**, solo usan utilidades (`text-steel-3`, `bg-volt`).

División de responsabilidades en `app/assets/tailwind/application.css`:

- **`@theme`** — REGISTRO de utilidades y fallback (valores oscuros). Aquí nacen `bg-volt`,
  `text-steel-N`, `font-display`… Nunca es la fuente de los valores por tema.
- **Bloques `@plugin "./daisyui-theme.mjs"`** — los VALORES por tema. `advance-claro` lleva
  `default: true` + `color-scheme: light`; `advance` lleva `prefersdark: true`. Cada bloque define
  los 20 tokens daisyUI **y además los tokens de marca** (`--color-steel-*`, `--color-volt-d`…),
  que el plugin pasa al selector del tema. Así `sistema` (sin `data-theme`) resuelve en CSS puro:
  default claro + media query oscura.
- **`data-theme` vive en `<body>`, no en `<html>`** — Turbo (replace y morph) solo actualiza el
  body: con el atributo en `<html>` cambiar el tema exigiría F5.
- **Paleta por tenant** (§16.6): un solo partial `shared/_paleta_tenant` inyecta los overrides con
  selector `:root, [data-theme]` — especificidad suficiente para ganarle a ambos temas y que el
  volt del tenant tiña también gradientes (parametrizados con `var()`, ya sin hex quemados).

Los componentes visuales reutilizables son **partials ERB** (`app/views/shared/_metric_card.html.erb`, `_navbar.html.erb`…) construidos con clases de **DaisyUI 5** (`card`, `btn`, `input`, `alert`, `badge`…). DaisyUI se vendorea como plugin CSS (`daisyui.mjs` + `daisyui-theme.mjs` en `app/assets/tailwind/`), sin Node; ambos temas mapean `primary→volt`, `error→pulse`, `accent/info→ocean`.

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
| `anulado_en` / `anulado_por_id` | `datetime` / `bigint` | Fase 5.11 — "eliminar" un pago lo **anula** (figura como eliminado, con quién y cuándo); nunca se borra físico. Monto siempre **> $1.000 COP**. El admin puede **corregir** monto/método de un pago vigente; uno anulado ya no se toca |

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
| `user_id` | `bigint` | FK → `users` (el miembro medido) |
| `tomada_por_id` | `bigint` | FK → `users` — el staff que tomó la medición (Fase 5.9) |
| `fecha` | `date` | Una medición por fecha (índice unique `user_id + fecha`) |
| `peso_kg` | `decimal(5,2)` | Input |
| `talla_cm` | `decimal(5,1)` | Input (normalmente estable) |
| `imc` | `decimal(4,1)` | **Columna generada** en Postgres: `peso_kg / (talla_cm/100)^2` |
| `grasa_pct` | `decimal(4,1)` | Opcional |
| Perímetros (cm) | `decimal(5,1)` | `cuello · pecho · cintura · cadera · brazo · muslo · pantorrilla` — todos opcionales (Fase 5.9) |
| Diámetros óseos (cm) | `decimal(4,1)` | `muneca · codo · rodilla` — todos opcionales (Fase 5.9) |
| Pliegues (mm) | `decimal(4,1)` | `tricipital · subescapular · suprailiaco · abdominal · muslo` — todos opcionales (Fase 5.9) |
| `notas` | `text` | Opcional |

> **Fase 5.9:** la tabla se implementa como **antropometría completa** capturada por el **staff con historial**. Alimenta el prompt de la IA en el alta de suscripción (Flujo B) y la serie de peso de `/progreso`.

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
| `detalle` | `jsonb` | Fase 5.8: lo que el miembro dice que comió por comida `{ "comidas": [{ nombre, kcal, nota }] }` |

### `registros_entrenamiento` — seguimiento de ejercicios del miembro (Fase 5.10)

| Columna | Tipo | Notas |
|---|---|---|
| `id` | `bigint` PK | — |
| `user_id` | `bigint` | FK → `users` |
| `fecha` | `date` | Una por día (índice unique `user_id + fecha`); el día de semana mapea a la rutina del plan |
| `ejercicios` | `jsonb` | `{ "<indice>": { hecho: true, nota: "subí peso", nombre: "Press banca" } }` — ausente = pendiente |

> El miembro marca **Hecho/Pendiente + nota** por ejercicio del día (hoy o días pasados) en "Mi plan"; autosave dinámico (upsert por `fecha`+índice), sin recargar. No muta el plan del coach.

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
| `generado_por` | `string` | enum: `ia` · `entrenador` · `reglas` (plan sugerido de la membresía, Fase 5.11 — sin nutrición y aprobado sin revisor) |
| `estado` | `string` | enum: `generando` · `borrador` · `aprobado` · `fallido` — el miembro solo ve aprobados; `generando`/`fallido` son la generación con IA (§10) |
| `error_generacion` · `modelo_generacion` · `intentos` | `text`/`string`/`int` | Diagnóstico de la generación con IA (mensaje crudo, modelo que respondió, reintentos) — solo staff |
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
| 2 | Pagar + medir en recepción | MVP sin pasarela: el admin registra el pago, **toma la medición antropométrica** (obligatoria: peso, perímetros, diámetros, pliegues) y crea la `suscripcion` al plan personalizado en una sola transacción. La **membresía va incluida**: se crea o reactiva automáticamente, sin pago aparte (Fase 5.11). |
| 3 | Generar con IA | Al crearse la suscripción se encola `GenerarPlanJob`: revalida la suscripción, arma el prompt con la **antropometría reciente**, biometría, somatotipo, objetivo y restricciones, y pide al proveedor de IA configurado un JSON de rutina semanal + plan nutricional. |
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
| 2 | Validar | Se permite el acceso si la membresía está `activa` **o** el miembro tiene **plan personalizado activo** (reemplaza la mensualidad, §04). Sin ninguno → aviso de crear/renovar; fuera de horario → se registra con `dentro_de_horario: false` y alerta. |
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
| 5.7 | Fallos de IA + negocio parametrizable | ~1 semana | Generación con IA observable (estados `generando`/`fallido`, **Turbo Streams** en vivo, reintento manual, **fallback de modelo** si está ocupado, mensajes amables), config central `Negocio` (precios/duración/nombre por `config/negocio.yml`+ENV), rutina IA **sin cardio**, membresías a **30 días** fijos, **acceso premium sin mensualidad**, sin horario de acceso | Un fallo de la IA se ve en la cola con mensaje amable + Reintentar y estado en vivo; un premium entra sin membresía; los precios se cambian por config |
| 5.7b | Editor de rutina + plantillas de ejercicio | ~0.5 semana | Rutina editable por día/ejercicio con autosave, plantillas de ejercicio por músculo (modal + "guardar como plantilla"), logo de marca parametrizable | El staff edita ejercicios inline y aplica plantillas; el miembro ve la rutina publicada |
| 5.8 | Plan en vivo + UX del plan | ~1 semana | `/mi_plan` **en vivo** (Turbo Streams al editar el staff), miembro **registra qué comió** (kcal aprox + nota por comida → `registros_calorias.detalle`), **plantillas buscables**, **rediseño de la rutina semanal**, **navbar/menú responsive y profesional** | El miembro ve los cambios del staff sin recargar; registra su consumo por comida; el menú se ve cómodo en móvil |
| 5.9 | Antropometría + plan básico con membresía | ~1 semana | Entidad **`mediciones`** completa (perímetros/diámetros/pliegues/% grasa) capturada por staff con historial; **medición obligatoria** en el alta de suscripción que alimenta el prompt de IA; **plan básico por reglas** incluido con la membresía (`GeneradorPlanBasico`, sin IA); **auto-registro de peso** del miembro (medición ligera solo-peso) que alimenta `/progreso` | El staff toma la medición y sin ella no genera; el plan IA usa la antropometría; un miembro con membresía ve su plan básico; el miembro registra su peso y lo ve en progreso |
| 5.10 | Seguimiento de entrenamiento del miembro | ~1 semana | Entidad **`registros_entrenamiento`** (una por día): el miembro marca **Hecho/Pendiente + nota** por ejercicio en "Mi plan" con **selector de fecha** (hoy y días pasados), autosave dinámico sin recargar; sigue recibiendo en vivo los cambios del plan (5.8) | El miembro marca qué ejecutó/cambió por día, edita días pasados sin recargar y el seguimiento persiste |
| 5.12 | Dev sobre Supabase + datos demo + pesos y rutina del miembro | ~0.5 semana | Entorno dev apuntando opcionalmente a **Supabase** (`DEV_DATABASE_URL`, tests siempre locales); tarea **`demo:sembrar`** (objetivos, pesos y check-ins idempotentes para usuarios reales); el miembro **agrega/corrige sus pesos** por fecha y **edita la rutina** de su plan publicado (reglas o IA) | Local corre contra Supabase sin romper tests; los usuarios reales tienen datos coherentes; el miembro corrige un peso pasado y ajusta su rutina |
| 5.13 | Pulido de check-in: tildes, responsive y resumen del miembro | ~0.3 semana | Fix de **tildes corrompidas** en eyebrows con default (el valor por defecto salía de la firma de *strict locals*, que corrompe literales no-ASCII); badges (`badge_estado`, "en/fuera de horario") ya no se parten en dos líneas en móvil (`whitespace-nowrap`); **popup de resumen** al hacer click/tab en un miembro en Check-in (membresía, **peso rápido editable/upsert**, botón de check-in, link directo a su ficha); ficha del miembro (`admin/users/show`) suma una card de **Plan** | "Administración" se ve bien en cualquier navegador; el badge de horario no se corta en pantallas angostas; clic en un miembro abre su resumen sin salir de Check-in y desde ahí se llega a su plan |
| 5.14 | Copy sin "IA" de cara al negocio | ~0.1 semana | El copy de cara al miembro y al staff deja de decir "generado/generación con IA" — se habla de plan **analizado y diseñado** según el perfil/información del miembro (marca, dashboard, Mi plan, editor de staff, cola de borradores, alta de suscripción, mediciones). Nuevo helper `origen_plan(plan)` traduce `generado_por` (`ia`→"análisis automático", `reglas`→"plan de membresía", `entrenador`→"entrenador") para las 4 vistas de staff que antes imprimían el valor crudo | Ningún texto de cara al usuario menciona "IA"; el origen del plan se lee en lenguaje natural en las vistas de staff |
| 5.15 | Upgrade a Ruby 4.0.5 | ~0.2 semana | `.ruby-version` y las imágenes Docker (dev y producción) suben de 3.4.5 a **4.0.5**; verificación completa de compatibilidad (sin uso de Ractor/CGI/IO.popen con pipes que 4.0 removió; `logger`/`ostruct` ya resueltos como gemas reales vía Bundler, no default gems; Puma 8 y Bundler 4 ya cumplían el mínimo) — sin necesidad de ajustes de código; `.tool-versions` fija Ruby 3.4.5 solo para `dip` (herramienta del host, no de la app); **YJIT habilitado de verdad en producción** (`RUBY_YJIT_ENABLE=1` en el `Dockerfile`, la mención previa en el SDD era aspiracional) | `dip test` · `dip rubocop` · `dip brakeman` en verde sobre Ruby 4.0.5; ambos `Dockerfile`s compilan limpio (incluida `assets:precompile`); CI (`ruby/setup-ruby`) toma la versión de `.ruby-version` automáticamente |
| 5.16 | Fixes: medición duplicada, validación de monto y popups | ~0.2 semana | Alta de suscripción hace **upsert** de la medición por fecha (como el resto de flujos) — reintentar el mismo día ya no choca con "Fecha ya está en uso" y aborta la membresía automática; `min` del input de Monto alineado a `Pago::MONTO_MINIMO` (evita que el navegador rechace valores redondos válidos como 80.000); los tres `<dialog>` de la app (resumen de miembro, biblioteca de ejercicios, biblioteca de comidas) cambian su cierre por click-en-fondo de `<form method="dialog">` a un cierre manual por JS — el submit del formulario dejaba "filtrar" el click al elemento que quedaba debajo al cerrarse (p. ej. el menú "Gestión" del navbar) | Reintentar un alta el mismo día corrige la medición y crea la suscripción con membresía incluida; el monto 80.000 no dispara el error nativo del navegador; cerrar un popup haciendo click fuera no deja foco/click residual en la página de atrás (verificado en vivo con Browser MCP) |
| 5.11 | Suscripción con membresía + plan sugerido editable + kcal | ~1 semana | `Plan.free/personalizado` **autocreados** sin seeds (hotfix "Plan debe existir"); la suscripción **crea/reactiva la membresía** (incluida); plan sugerido **persistido** (`generado_por: reglas`, 6 días según objetivo, semana repetida el mes) creado con la membresía o al fijar el objetivo, **editable por miembro y staff** con popup Stimulus (buscador + chips por músculo + **sesión completa**); **alertas de kcal** arriba/abajo del objetivo; **objetivo diario editable** y **historial de consumo editable** | Crear suscripción sin membresía funciona y la incluye; todo miembro con membresía ve su plan sugerido y lo edita; las alertas avisan cuando lo editado no se alinea con el objetivo |
| 6 | Catálogo visual de ejercicios & IA con catálogo cerrado | ~1.5 semanas | Tabla **`ejercicios`** importada del dataset abierto [hasaneyldrm/exercises-dataset](https://github.com/hasaneyldrm/exercises-dataset) (1.324 ejercicios con instrucciones en español y GIF/imagen 180×180 © Gym Visual, **atribución visible obligatoria**); media servida por **proxy con caché on-demand** en el volumen `/rails/storage` (no engorda la imagen Docker ni expone al miembro a GitHub); en la rutina del miembro, **tap en el ejercicio abre un popup** (dialog + turbo-frame perezoso, patrón 5.16) con el GIF de ejecución e instrucciones, sin recargar ni perder los checks; la biblioteca del editor gana **thumbnails y catálogo buscable**; el prompt de IA pasa a **catálogo cerrado** (`ejercicio_id` obligatorio de una lista curada por músculo, validador server-side anti-alucinación) y devuelve además `peso_sugerido_kg` y `nota_tecnica` personalizados; **retroalimentación por adherencia** (los registros de entrenamiento de las últimas semanas se resumen en el prompt al regenerar); nombres traducidos al español con IA en lote (rake). Sub-fases 6.1–6.7 | El miembro toca un ejercicio de su rutina y ve el GIF + instrucciones en español sin perder sus checks; la IA solo usa ejercicios existentes del catálogo y los planes regenerados reaccionan a la adherencia real; `dip rails ejercicios:importar` es idempotente |
| 7 | Nutrición personalizada & Gustos | ~2 semanas | Catálogo `alimentos` (seed colombiano + CRUD admin), calificación de gustos (`/gustos`), armador de comidas con registro del día (`/armador`), gustos + recetas en el prompt de IA, benchmark de modelo Gemini | El miembro califica alimentos y arma su día viendo kcal en vivo; el registro alimenta `/progreso`; el plan IA de un premium no incluye ningún alimento `no_le_gusta` y cada comida trae receta |
| 8 | Comunidad & Cierre | ~1 semana | Blog, novedades, pulido responsive, checklist MVP completo | Un miembro lee posts y novedades publicadas; todo el checklist §15 en verde |
| 9 | Multi-gimnasio: preparación técnica | ~1 semana | Parametrización de branding (títulos, `_auth_brand`, manifest PWA) desde `Negocio.nombre`; `default_url_options`/`config.hosts` resueltos por `APP_HOST` en vez del placeholder `example.com`; plantilla de deploy multi-destino (`config/deploy.<tenant>.yml`, Kamal destinations) — corresponde a las Fases A y B de §16.5. Ya adelantado: seed de arranque de tenant (`db/seeds.rb`) y `bin/rails tenant:preparar` (Nota 9) | Ningún texto de cara al usuario dice "Advance Fitness" fuera de `config/negocio.yml`; los correos de reset apuntan al dominio real; `kamal deploy -d <tenant>` funciona con un tenant de staging siguiendo el runbook de §16.4 |
| 10 | Multi-gimnasio: piloto y escala | ~1 semana + operación continua | Segundo tenant real (o staging permanente) conviviendo con Advance Fitness en el mismo homelab, siguiendo el runbook §16.4 de punta a punta (base, secrets, deploy, túnel, OAuth); métricas de RAM/conexiones/latencia con dos tenants activos; decisión de consolidación al superar ~10–15 tenants — corresponde a las Fases C y D de §16.5 | Un segundo gimnasio opera de forma aislada (su propia base, su propio subdominio) sin degradar a Advance Fitness; hay métricas reales que informan cuándo consolidar |
| 11 | IA analítica de entrenamiento | ~1.5 semanas | UI de captura de series/reps/peso/RPE sobre **`detalle_entrenamientos`** (tabla y modelo ya implementados — Nota 11); tabla `feedback_ia` + **`AnalizarEntrenamientoJob`** (Solid Queue, adaptadores IA existentes) con el prompt del Analista de Performance (§18.4): progresión de volumen, detección de plateaus (>3 sesiones sin subir carga), alerta de fatiga por RPE; feedback visible para el miembro y el entrenador — ver §18 | El miembro registra sus series reales desde la rutina; tras la sesión recibe un análisis Estado/Análisis/Acción basado en su historial cuantitativo; el sistema detecta un estancamiento sembrado a propósito en datos de prueba |
| 12 | Pivote SaaS white-label: negocio (12a/12b implementadas, agosto 2026 — landings de autoservicio por audiencia, cobro manual, ver Notas 24 y 25) | por definir (post-piloto) | Modelo de Escalada (§17.2): tiers Starter/Pro con límites y contadores de uso de IA por tenant, pasarela de pagos online, tier Partnership con revenue share y medición de ventas por tenant; tácticas go-to-market de §17.3 según mercado (gimnasios, influencers, agencias white-label) | Un tenant contrata y paga online un tier; los límites de IA del tier Starter se aplican de verdad; existe al menos un tenant Partnership con liquidación de revenue share verificable |
| 13 | Multi-tenancy row-level + portal comercial (implementada, julio 2026 — ver §16.6; ejecutada como "Fase 13.x" en commits, formalizada aquí a posteriori) | — | Tenant + resolución por subdominio, aislamiento Pundit, superadmin, branding por tenant (paleta/logo), landing de campañas `join.ynt.codes/:slug`, tema dark 13.3 | Dos tenants conviven sin cruzarse; theming por tenant activo |
| 14 | Experiencia móvil y motivación (implementada, agosto 2026 — plan en Nota 16, cierre en Nota 19; Release 1.5.0) | ~4-6 semanas | Bloque A: tab bar + PWA real + tarjetas visuales (referencias Gymnax/sandow); Bloque B: uid estable + mesociclo por semanas con progresión; Bloque C: consentimientos + gamificación (ledger de puntos, rachas, logros, ranking opt-in por tenant); Bloque D: perfil femenino + ciclo menstrual con consentimiento en dos niveles | El miembro navega todo a 1 tap desde la tab bar; el seguimiento sobrevive a ediciones del plan (uid); los puntos son idempotentes ante reintentos de jobs; el ranking jamás cruza tenants |
| 15 | Notificaciones Web Push: recordatorio de racha (agosto 2026 — decisiones en Nota 20) | ~0.5 semana | Gema `web-push` + llaves VAPID por ENV; tabla **`suscripciones_push`** (endpoint único por dispositivo, solo-dueño); listeners `push`/`notificationclick` en el service worker; opt-in explícito desde la card de racha (Stimulus, permiso pedido desde un gesto del usuario; iOS 16.4+ exige la PWA instalada en inicio); `Notificaciones::EnviadorPush` (borra endpoints muertos 410/404); **`RecordatorioRachaJob`** recurrente 6pm America/Bogota, idempotente por `perfiles_juego.racha_recordada_en` | Un miembro con racha viva que aún no entrena hoy recibe a las 6pm un único push de recordatorio; desactivar borra el endpoint del servidor; un reintento del job no duplica avisos; el payload jamás lleva datos de salud |
| 16 | Temas, contraste y performance percibida (agosto 2026 — decisiones en Nota 21) | ~1-1.5 semanas | **Tema claro opcional** `advance-claro` (hueso+tinta+volt) con `users.tema` y selector en perfil; fix de contraste dark (steel-5) y gradientes parametrizados con `var()` (la dona respeta la paleta del tenant); dona contenida en desktop; biblioteca de comidas como bottom-sheet móvil; tira de 7 días en la card de racha; perfil con stats; `lazyLoadControllersFrom` + trix bajo demanda + fuentes self-host + `prefers-reduced-motion`; `/progreso` con gráficas en turbo-frames lazy por scroll | Cambiar el tema en el perfil aplica al instante sin F5 y sobrevive Turbo; "sistema" sigue al SO sin JS; el tenant coral ve su dona coral; las descripciones de comidas son legibles (AA); las gráficas de progreso cargan al hacer scroll; sin requests a Google Fonts |
| 17 | Cuenta y perfil personalizado (agosto 2026 — decisiones en Nota 22) | ~0.5 semana | El perfil se vuelve **hub de cuenta** (referencia Pulse): cabecera avatar+nombre+correo+chip de plan, tile edad/peso/talla, secciones Mi cuenta / Ajustes / Privacidad en filas y acordeones; **cambio de correo y contraseña** (`CuentasController`, `password_challenge` SIEMPRE obligatorio); Apariencia y notificaciones push del dispositivo centralizadas; accesos a ranking y ciclo; cerrar sesión desde el hub | El miembro cambia su contraseña solo probando la actual; un challenge equivocado no cambia nada; el correo duplicado en el tenant se rechaza; toda su configuración se alcanza desde /perfil en un tap |
| 18 | Fricción cero y features por tenant (agosto 2026 — petición del cliente, decisiones en Nota 23) | ~1-1.5 semanas | Bloque A — menos digitación: prellenado de kg/reps en el registro de series con "la vez pasada" (`ultimos_por_ejercicio`), botón **"Cumplí mi plan de hoy"** en Nutrición (registra kcal+macros del plan aprobado en un tap), mini-formulario de perfil nutricional inline en `objetivos/new` (solo los campos faltantes, sin salir del flujo). Bloque B — **panel Admin → Funcionalidades**: `Tenant#feature?` generalizado sobre `features_habilitadas` (llaves `membresias`/`blog`/`novedades`/`nutricion`/`ciclo`/`gamificacion`), toggles para el admin del tenant, gating en navbar/tab bar y `before_action` en los controllers de cada módulo. Bloque C — **muro de la comunidad**: `/novedades` pasa a feed del tenant con anuncios del staff + celebraciones automáticas de PRs y logros de miembros con consentimiento `logros_comunidad` (opt-in auditable en la misma página); fix previo de aislamiento: `Novedad`/`Post` scoped por tenant vía `policy_scope` (la Scope existía y los controllers no la usaban) | El miembro registra una serie sin digitar lo que ya digitó la sesión pasada y su consumo del día en un tap; Cesar apaga Blog desde su panel y el link desaparece para todo su tenant (la ruta redirige); un PR de un miembro con opt-in aparece celebrado en `/novedades` de SU tenant y jamás en otro; sin opt-in no aparece nada |
| 19 | Ideas adoptadas de openGym (agosto 2026 — decisiones en Nota 26) | ~1 semana | Cinco mejoras de la capa de entrenamiento, evaluadas contra [openGym](https://github.com/DuarteSantos8/openGym) y adaptadas al modelo de datos existente (nunca copiadas): **1RM estimado** (`CalculadoraUnaRepMax`, fórmula de Epley, service puro) sobre la mejor serie 1-12 reps de cada ejercicio; **heatmap de actividad** (`Juego::Heatmap`) del último año, mismo criterio "cumplido" que la racha; **mapa muscular** (`Juego::MapaMuscular`) con volumen por grupo sobre dos siluetas esquemáticas frente/espalda, por semana/mes/todo; **wake lock** en modo sesión (pantalla activa mientras entrenas, toggle en Ajustes); **reprogramar un día** del plan sin editar la plantilla semanal. Las tres primeras viven como secciones perezosas nuevas de `/progreso` (mismo patrón `progreso_grafica/:tipo` de la Fase 16.6) | El miembro ve su 1RM estimado por ejercicio, su heatmap del año y qué músculos entrenó esta semana en `/progreso`; la pantalla no se apaga durante una sesión activa; el miembro mueve el entrenamiento de hoy a otro día sin tocar su rutina base |

> **Nota (julio 2026):** la Fase 3 se **aplaza** y la Fase 4 se adelanta. Mientras no existan mediciones, los inputs del TDEE se capturan así: fecha de nacimiento, sexo, talla y nivel de actividad en un formulario de **"Completar perfil"** (columnas ya existentes en `users`), y el **peso** como snapshot en `objetivos_nutricionales.peso_kg` al fijar el objetivo. Cuando la Fase 3 llegue, el peso se precargará de la última medición y la recalibración seguirá el Flujo C.
>
> **Nota 3 (julio 2026):** se inserta la fase **Nutrición personalizada & Gustos** antes de Comunidad. Decisiones cerradas con el cliente: catálogo por **seed curado colombiano** (no base externa); gustos y armador **para todos los miembros** (el plan IA sigue siendo premium); el armador **registra el consumo del día** (reemplaza el input manual de kcal cuando se usa); recetas **dentro del plan premium** (JSONB), no como biblioteca aparte. Durante la fase se hace un **benchmark de modelos Gemini** (`gemini-2.5-flash-lite` actual vs. `gemini-3.1-flash-lite`) con la misma petición real; el ganador queda como default de `GEMINI_MODELO`. La fase incluye además el **voto de menú del miembro** con el modelo **"alternativas por comida"** (cada comida ofrece 2-3 opciones y el miembro marca su favorita 👍), que se apoya en el editor de la Fase 5.6.
>
> **Nota 5 (julio 2026):** se inserta la **Fase 6 — Catálogo visual de ejercicios & IA con catálogo cerrado** antes de Nutrición (que pasa a Fase 7; Comunidad pasa a Fase 8). Reemplaza las "animaciones SVG" que la antigua Fase 6 planeaba para el editor de rutina: en su lugar se integra el dataset [hasaneyldrm/exercises-dataset](https://github.com/hasaneyldrm/exercises-dataset) (MIT; media © Gym Visual usada con permiso del autor del dataset — la atribución debe permanecer visible en la UI). Decisiones cerradas: media por **proxy con caché on-demand** al volumen (descartado el hotlink a GitHub por privacidad/latencia y la descarga total por peso); **nombres traducidos al español con IA** en lote (editables por el staff después); apertura de la ayuda por **tap en el bloque del nombre** del ejercicio. La vinculación español↔inglés se resuelve con `nombre`/`nombre_en`/`nombre_normalizado` en `ejercicios`, FK opcional `plantillas_ejercicio.ejercicio_id` y el campo opcional `ejercicio_id` dentro del JSONB de rutina (fallback por nombre normalizado para planes viejos).
>
> **Nota 2:** de la Fase 3 se **adelanta la mitad "Progreso"** (`GET /progreso`, gráficas SVG server-rendered §14) alimentada con los datos que ya existen: tendencia de **peso** desde los snapshots de `objetivos_nutricionales`, **calorías diarias vs. objetivo** desde `registros_calorias` y **asistencia** desde `accesos`. La mitad "Biometría" (tabla `mediciones` con IMC generado, clasificación OMS y wizard de onboarding) sigue aplazada; al llegar, la gráfica de peso pasará a leer de `mediciones`.
>
> **Nota 4 (julio 2026):** la **Fase 5.9** adelanta la tabla **`mediciones`** (con IMC generado) para la **antropometría de las suscripciones**, capturada por el **staff** (no el wizard de onboarding del miembro, que sigue aplazado). El peso pasa a derivarse de la última medición cuando exista (con fallback a `objetivos_nutricionales.peso_kg`).
>
> **Nota 6 (julio 2026, Fase 6.8-6.10):** correcciones de producción y una decisión de negocio nueva, sin abrir fase aparte. (1) Se unifica la tarjeta "Rutina semanal" del miembro y el editor del staff en un solo componente con botón Editar, eliminando la duplicación de tabs. (2) Se corrige `config/database.yml` (clave `pool`, no `max_connections`, que Rails ignoraba) — con 4 bases lógicas sobre el mismo Supabase, el pool por defecto llegaba a 20 conexiones y superaba el límite de 15 del pooler en modo sesión, dejando `GenerarPlanJob` atascado en "generando" sin poder ni registrar el fallo. (3) Agregar/eliminar ejercicio o comida responde turbo_stream en vez de recargar la página. (4) Se reemplaza `window.confirm`/`data-turbo-confirm` (rotos en iOS con la app agregada a inicio) por un diálogo de confirmación propio. (5) **Decisión de negocio:** una membresía cuyo pago cubra el precio del plan Personalizado ($350.000, "combo") incluye automáticamente una `Suscripcion` a $0 enlazada a esa membresía; si el miembro ya tiene una suscripción activa con fecha de fin, la nueva se programa para el día siguiente (estado `programada`) en vez de duplicarla o cortarla, y un job diario la activa cuando llega su turno.
>
> **Nota 7 (julio 2026, Fase 6.11):** el admin puede **buscar miembros** por nombre o correo en `admin/users` y **editar cualquier medición pasada** (antes solo se podía corregir la de hoy vía upsert). Al guardar una medición, un checkbox opcional "Actualizar el plan de entrenamiento con estas medidas" reencola `GenerarPlanJob` para el plan Personalizado vigente del miembro (no aplica al plan sugerido por reglas, que no usa antropometría) — sin marcarlo, el plan actual queda intacto.
>
> **Nota 8 (julio 2026, Fase 6.13):** buscador en vivo (mientras se escribe, sin recargar) en Suscripciones/Membresías/Pagos/Miembros, con un componente Stimulus reutilizable (`buscador-en-vivo`) sobre un turbo-frame; Pagos interpreta un solo campo de texto como usuario, fecha, valor o método. Clic en un miembro desde cualquiera de esas listas lleva a su ficha (`admin/users/:id`), ahora ampliada con las mismas gráficas de progreso (peso/calorías/asistencia) que ve el propio miembro en `/progreso` (extraídas a `ProgresoUsuario` + partials `shared/_grafica_*`, con un local `editable:` que decide si se muestran los enlaces de autoservicio) y una card de edición de perfil (nombre, correo, fecha de nacimiento, sexo, nivel de actividad, somatotipo) accesible a todo el staff; el **rol** sigue exclusivo del admin, verificado en el controller — nunca mass-asignado.
>
> **Nota 9 (julio 2026):** se adopta la **visión multi-gimnasio** (ver §16): misma app en N subdominios, cada tenant con su base independiente, servida por una instancia Kamal propia. Como primer artefacto se reorganiza `db/seeds.rb` como **seed de arranque de tenant** (documentado, idempotente, parametrizable por `SEED_ADMIN_EMAIL`/`SEED_ADMIN_PASSWORD`) y se agrega `bin/rails tenant:preparar` (`lib/tasks/tenant.rake`) que orquesta schema + seed + catálogo de ejercicios + reporte con los pasos manuales pendientes. La arquitectura completa NO se implementa aún; §16 documenta la recomendación, el inventario de acoplamientos y el plan de mejoras por fases (A–D).
>
> **Nota 10 (julio 2026):** la visión multi-gimnasio de §16 se formaliza en la tabla de fases como **Fase 9** (preparación técnica: branding parametrizable, host canónico, plantilla de deploy — Fases A/B de §16.5) y **Fase 10** (piloto con un segundo tenant real y decisión de escala/consolidación — Fases C/D de §16.5), después de Comunidad & Cierre (Fase 8). Son fases **posteriores al MVP funcional**: no bloquean el checklist de §15 y arrancan solo cuando exista demanda real de un segundo gimnasio/marca.
>
> **Nota 11 (julio 2026):** se adopta la visión de **pivote SaaS white-label** (§17: tiers de pricing, revenue share, go-to-market) y de **IA analítica de entrenamiento** (§18: Analista de Performance), formalizadas como **Fase 11** (IA analítica) y **Fase 12** (negocio SaaS). Nacen de una auditoría externa del esquema contrastada contra la realidad (rastro completo en §18.6): de ella solo aplicó la necesidad de datos cuantitativos de entrenamiento — se implementa ya la tabla **`detalle_entrenamientos`** + modelo `DetalleEntrenamiento` (una fila por serie: reps, peso, RPE; único por registro+ejercicio+serie) como único artefacto de código; `tenant_id`/RLS se descartó (contradice §16.2), el `imc` generado y los índices compuestos ya existían. Igual que las Fases 9–10, son **posteriores al MVP funcional** y no bloquean el checklist de §15.
>
> **Nota 12 (julio 2026):** se cierra la **Fase 8 — Comunidad**: `posts` (Action Text/Trix, autor, slug autogenerado, `publicar!`) y `novedades` (texto plano + fecha de evento opcional) con CRUD en `/admin/posts`/`/admin/novedades` (staff) y lectura pública en `/blog`, `/blog/:slug`, `/novedades` (todo miembro autenticado, solo contenido publicado — el staff además puede previsualizar borradores). Requirió instalar **Active Storage** y **Action Text** (no estaban en el proyecto). Queda pendiente de esta fase, sin bloquear el checklist: el pulido responsive general mencionado en la tabla de fases (§15 ya cubre la mayoría vía el sistema de diseño existente).

> **Nota 14 (julio 2026) — Etapa 0 del Plan de Estabilización:** cerrada la higiene inmediata previa al blindaje multi-tenant. **(a) Schema al día:** la migración `20260722000000_change_users_email_index_to_tenant_scoped` (índice compuesto `(email_address, tenant_id)`) estaba `up` en producción pero `down` en la base local; se aplicó en test → `schema.rb` regenerado a `2026_07_22_000000` con el índice compuesto correcto. **(b) PWA habilitada:** rutas (`config/routes.rb`) y `<link rel="manifest">` (`layouts/application.html.erb`) descomentados; el manifest ya era tenant-aware vía `Negocio.nombre` (SDD §16.5 Fase A). Nuevo `spec/requests/pwa_spec.rb` como regresión. `theme_color` (manifest + `<meta theme-color>`) ahora sale de `Negocio.theme_color` = `Current.tenant.paleta_colores["primary"]` si es hex válido (mismo guard anti-CSS-injection del §16.6), sino el midnight de marca. El icono del manifest sigue global — cuadrar el logo del tenant a 512×512 requiere `variant` de `ruby-vips`, no disponible en producción (commit `75628c9`); queda como pendiente para cuando se resuelva esa dependencia. **(c) Sin residuo minitest real:** revisión descartó la brecha #10 del plan — `test/mailers/previews/` es convención de Rails (`ActionMailer::Preview`) independiente del framework de test, se conserva. Ver `docs/plan-estabilizacion.md` para el plan completo (Etapas 1–5).
>
> **Nota 19 (agosto 2026) — Fase 14.16, composición ciclo × mesociclo (cierra la Fase 14):** la fase del ciclo se compone con el ajuste de la semana SOLO donde la prescripción se consume. **(a) Modo sesión con números efectivos:** `SesionesController` resuelve la semana de la fecha (`Calendario.semana_de` con fallback a la semana en curso) y pasa el ajuste de fase como `extra:` a `Rutina::Resolutor.dias` — el `componer` clampea el factor compuesto a 0.7..1.25 (spec: descarga 0.8 × menstrual 0.85 = 0.68 → piso 0.7). Verificado en navegador: fase menstrual baja 3 series → 2 con su mensaje en pantalla. **(b) El panel del día NO compone números, solo informa:** ese panel es editable y un ajuste temporal de fase se hornearía al materializar la semana; muestra el mensaje de fase (solo en el panel de HOY — una query máximo) con los valores en base/mesociclo. **(c) Nutrición:** `kcal_delta` de la fase (lútea +150) suma al presupuesto de la dona con su leyenda. **(d) Prompt de IA doblemente filtrado:** `GenerarPlanJob` solo envía la fase con el consentimiento de segundo nivel (`ciclo_menstrual_ia`); el bloque redacta "la fase puede bajar la intensidad inicial, nunca subirla". Specs de ambos lados (viaja con consentimiento IA, NO viaja con solo el de registro). **(e) Énfasis del perfil femenino en el plan por reglas:** para `sexo == "F"` el día de pierna de cada split prioriza glúteo (`ENFASIS_F`) — default editable, no candado; el volumen del día no cambia; la meta de proteína se mantiene igual para todos (no hay base sólida para diferenciarla y se evita un target arbitrario por género). **Gotcha operativo anotado:** las inflections son initializer — el server dev no las recarga; tras un deploy con modelos nuevos el restart es obligatorio (en Kamal lo es por diseño). Cierre: 750 ejemplos / 0 fallos, rubocop y brakeman limpios. **Con esto las etapas 14.1–14.17 del plan de la Fase 14 quedan completas**; pendientes operativos sin cambios (migraciones en el próximo deploy, push/Web Push como decisión de §02 aún abierta).
>
> **Nota 20 (agosto 2026) — Fase 15, Web Push para recordatorios de racha:** se **revierte la exclusión de §02** solo para **Web Push del navegador** (VAPID estándar, sin Firebase ni servicios de terceros con SDK); el push nativo de tienda sigue excluido. Justificación: la racha (Fase 14.12) pierde buena parte de su efecto sin recordatorio — era la deuda explícita del plan de la Fase 14. Decisiones: **(a) Llaves VAPID por ENV** (`VAPID_PUBLIC_KEY`/`VAPID_PRIVATE_KEY`, mismo patrón que `GEMINI_API_KEY`), gema `web-push`. **(b) Opt-in explícito sin fila en `consentimientos`:** el permiso del navegador ES el opt-in (revocable desde el propio navegador) y no hay procesamiento de dato sensible por terceros — el criterio de 14.11 (prueba auditable) aplica a ranking y ciclo, no aquí; desactivar desde la app borra el endpoint del servidor. **(c) Payload mínimo y sin datos de salud:** título/cuerpo/URL de motivación; el ciclo menstrual **jamás** viaja en un push (el transporte pasa por FCM/Mozilla/APNs como relay cifrado, pero la regla es de producto, no técnica). **(d) `suscripciones_push` es solo-dueño** (como el ciclo: la policy no tiene rama de staff — los dispositivos de un miembro no son asunto del staff). **(e) Idempotencia del recordatorio** por `perfiles_juego.racha_recordada_en` (date): un reintento del job recurrente no duplica el aviso; elegible = `ultima_fecha_racha == ayer` con `racha_actual >= 1` (quien ya entrenó hoy no se molesta; quien ya la perdió no recibe culpa). **(f) iOS 16.4+** solo soporta push con la PWA instalada en pantalla de inicio: la card lo detecta y guía a instalar en vez de fallar. **(g) Endpoints muertos** (410 Gone / 404) se borran al enviar — el parque de suscripciones se auto-depura.
>
> **Nota 21 (agosto 2026) — Fase 16, sistema de temas y decisiones de arquitectura visual:** **(a) `users.tema`** (`oscuro`/`claro`/`sistema`, default `oscuro`): preferencia del MIEMBRO, no del tenant — el branding del tenant (paleta) es ortogonal al tema y funciona en ambos. **(b) `data-theme` en `<body>`**: Turbo (replace y morph) jamás actualiza atributos de `<html>`; en `<html>` el cambio de tema no aplicaría hasta F5. **(c) "Sistema" en CSS puro**: `advance-claro` es el default daisyUI y `advance` lleva `prefersdark` — sin atributo, el SO decide vía media query; con atributo, gana el explícito. Cero JS, cero flash. **(d) Tenant gana al tema**: el partial único `shared/_paleta_tenant` (unifica los dos bloques inline que divergían — landing no generaba `volt-d`/`volt-l`) emite con selector `:root, [data-theme]`. **(e) Gradientes por `var()`**: `.gradient-volt`/`.divider-volt`/`pulse-volt` dejan los hex quemados — el bug visible era la dona VERDE en el tenant coral (Vital Fitness). **(f) Fix de contraste dark**: `--color-steel-5` oscuro sube de #475569 (≈1.8:1 sobre card, ilegible — reporte del usuario con capturas) a un valor AA. **(g) El manifest PWA queda oscuro** en ambos temas (se cachea al instalar; cambiarlo por tema daría íconos/splash inconsistentes). **(h) Fuera de alcance**: páginas de error standalone (hex propios, sin layout) y fragment caching en dashboard/progreso (datos por-usuario diarios; 6-8 queries acotadas no pagan la invalidación). **(i) Performance**: `lazyLoadControllersFrom` exige `pin_all_from ... preload: false` (si no, el modulepreload descarga los 21 controllers igual); trix/actiontext salen del bundle global (solo blog/admin); fuentes self-host; `prefers-reduced-motion` apaga las animaciones FIJANDO estados finales explícitos (varias parten de `opacity: 0` — apagarlas a secas dejaría contenido invisible). **(j) View transitions activadas** (`meta view-transition same-origin`): cross-fade nativo en visitas de página completa, progresivo (sin soporte, nada) y sin competir con el morph de los refreshes — spike verificado sin errores de consola en navegación real. **(k) Rediseño de la tab bar** (referencia Pulse): píldora tinta flotante (`bg-neutral`) con el destino activo en chip volt — la tinta es la firma de marca en ambos temas.
>
> **Nota 22 (agosto 2026) — Fase 17, cuenta y perfil personalizado:** el perfil pasa de formulario suelto a **hub de cuenta** con toda la configuración del miembro a un tap. Decisiones: **(a) `password_challenge` SIEMPRE obligatorio** para cambiar correo o contraseña (`CuentasController` separado de Perfiles — credenciales y datos corporales no comparten strong params ni riesgo); `has_secure_password` valida el challenge nativamente y un challenge en blanco falla. **(b) Usuarios de Google OAuth** no conocen su contraseña interna: el hub les ofrece el flujo existente de restablecer por correo (`passwords`) en vez del challenge — no se debilita la regla. **(c) Avatar de iniciales, sin foto**: subir fotos exigiría variants de Active Storage y `ruby-vips` no está disponible en producción (restricción documentada en Nota 14b); cuando se resuelva, la cabecera ya tiene el hueco. **(d) La configuración se CENTRALIZA, no se duplica**: el opt-in de push se extrae a un partial compartido (`shared/_push_optin`) que viven la card de racha y el hub; ranking y ciclo se enlazan a sus páginas (el consentimiento auditable sigue viviendo donde se otorga). **(e) El rol y el correo entre tenants** siguen intocables: rol jamás en strong params; unicidad de correo scoped al tenant (índice compuesto de Fase 13). **(f) Acento personal** (`users.acento`: volt/ámbar/azul, default volt = marca del tenant): con los gradientes ya en `var()` (16.2), cada acento son overrides de `--color-volt*`/`--color-primary` bajo `body[data-acento]` — FUERA de `@layer` a propósito, porque el `<style>` inline del tenant es sin capa y las reglas en capa perderían contra él; con (0,1,1) de especificidad el acento del miembro gana en SU sesión. El azul usa un tono claro adrede (#60a5fa): los chips llevan tinta encima en ambos temas. **(g) Gotcha operativo (pareja de la Nota 19):** una COLUMNA nueva con el server dev corriendo no se ve — el schema cache de Active Record no se invalida con el reload de código y el UPDATE descarta el atributo en silencio (visto con `acento`: params correctos, 302, y solo `updated_at` en el SET). Migración nueva ⇒ reiniciar el server dev; en producción no aplica (Kamal bootea fresco).
>
> **Nota 23 (agosto 2026) — Fase 18, fricción cero y features por tenant (petición explícita del cliente):** Cesar reporta que el miembro "se satura" digitando datos; la fase ataca la digitación, no las features. Decisiones: **(a) Prellenar antes que preguntar:** el formulario de series precarga reps y kg desde la última serie del MISMO ejercicio (`DetalleEntrenamiento.ultimos_por_ejercicio`, la query DISTINCT ON que ya alimenta el "Anterior:" de la Fase 14.2 — cero queries nuevas de patrón); el peso corporal ya se precargaba (Fase 5.12) y se conserva. **(b) "Cumplí mi plan de hoy":** si el plan aprobado trae comidas con kcal, Nutrición ofrece un botón que registra de un tap el total kcal+macros del plan como consumo del día (POST normal a `registros_calorias`, sin JS); el input manual queda como corrección, no como camino principal. **(c) Perfil nutricional sin salir del flujo:** `objetivos/new` con perfil incompleto ya no expulsa al hub de cuenta — muestra inline SOLO los campos faltantes (fecha de nacimiento, sexo, talla, nivel de actividad) y vuelve al objetivo al guardar (destino por whitelist, jamás param abierto). **(d) `Tenant#feature?`:** generaliza `membresias_habilitadas?` sobre el jsonb existente; default = encendido para todo excepto `membresias` (que conserva su default por `tipo_entidad`). El **admin del tenant** gana `admin/funcionalidades` (singular resource, toggles con descripción); el superadmin conserva su form (generalizado a todas las llaves). Gating en tres capas: link (navbar/tab bar), `before_action :exigir_feature` (redirect con aviso), y las policies existentes intactas — apagar una feature esconde y bloquea, JAMÁS borra datos. **(e) Muro de la comunidad en `/novedades`:** feed del tenant que mezcla anuncios del staff (lo existente) con celebraciones derivadas — PRs (`records_personales`) y logros (`logros_obtenidos`) recientes de miembros del tenant con consentimiento vigente `logros_comunidad` (tipo nuevo en `consentimientos`, mismo patrón auditable del ranking; el opt-in vive en la propia página del muro, coherente con Nota 22d). Las celebraciones se DERIVAN en lectura (sin tabla nueva, sin job): los datos ya existen, solo se muestran; nombre visible = apodo del ranking o primer nombre. **(f) Fix de aislamiento previo (bug):** §16.6 declaró `posts`/`novedades` aislados por tenant y sus Policy Scopes existían, pero NINGÚN controller los usaba — cualquier tenant veía novedades/posts de todos y las nuevas nacían con `tenant_id` nil. Fix: `policy_scope` en `NovedadesController`/`BlogController`/`Admin::*`, tenant heredado al crear, y ambos modelos entran a la suite de aislamiento cross-tenant (Etapa 1.1). **(g) Alcance de `gamificacion` apagada:** esconde ranking y cards de racha/puntos; el ledger sigue acumulando en background (apagar es presentación, no borrado — reencender no pierde historial). **(h) Listados responsive (reporte del cliente con captura, agosto 2026):** todos los listados admin/superadmin adoptan el patrón "primera celda = tarjeta" en móvil — identidad + badges + dato clave apilados, columnas secundarias solo desde `md:`/`lg:` (`hidden md:table-cell`), acciones siempre visibles; el `overflow-x-auto` queda de red de seguridad, no de UX principal. **(i) Mínimo dato, precisión progresiva:** el peso de `objetivos/new` se precarga de la última medición (cierra el pendiente de la Nota de Fase 4) con fallback al snapshot del objetivo previo, y la UI comunica el principio del cliente: la app funciona con lo mínimo y mejora con cada dato extra que el miembro registre. **(l) La sesión captura las series sola (petición del cliente, agosto 2026):** cada tap en el chip "Serie N" del modo sesión registra el `DetalleEntrenamiento` (premium) con las reps del plan (límite inferior del rango, criterio de `registrar_cumplido!`) y el kg de la vez pasada — o el sugerido del plan de estreno. El POST lleva `serie` explícita y es **idempotente** (find_by antes de crear, índice único por serie de respaldo); la re-visita del día pinta los chips ya registrados desde `series_registradas` y best-effort: un fallo de red jamás interrumpe el entrenamiento. Con la captura viva en el flujo natural, el botón "Registrar" y su dialog salen de la tarjeta del plan — queda solo el check de seguimiento, distribuyendo el contenido como pidió el cliente. El dialog completo se ELIMINÓ un día después en la limpieza de deuda (Fase 18n): era superficie sin entrada de UI — sus 4 vistas, 2 controllers Stimulus, el GET y el DELETE murieron; el feedback IA del miembro ya vivía en Progreso, y la celebración de PRs se mudó al modo sesión (el create de series appendea el toast fixed a `#celebraciones_sesion` y el fetch de la sesión renderiza el stream). La corrección de series llegará como pantalla propia cuando alguien la pida — no como código muerto esperándola. En la misma pasada, la query "quemadas" de `objetivos/show` volvió al controller (patrón query-desde-vista, prohibido). Auditoría de índices: NO se agregaron — las tablas calientes ya están cubiertas (higiene de la Fase de Calidad + compuestos de 16.7); la media de ejercicios va por PK + caché de 1 año, y la lentitud de imágenes reportada fue el pooler saturado por el contenedor huérfano del homelab (resuelto, ver DEPLOY.md).
>
> **Nota 18 (agosto 2026) — Fase 14.17, pulido visual contra las referencias:** ejecutado inline (sin agentes: el CSS es una sola superficie y la coherencia de diseño se pierde repartida), iterando cada cambio contra el navegador a 375px. **(a) Card volt sólida de nutrición** — la firma visual de la referencia: la dona pasa de card oscura a `gradient-volt` con texto steel-9 y anillo blanco; excedido voltea a oscuro+pulse (rojo sobre lima no se lee). Barras de macros en blanco sobre volt, con su color de macro solo en la variante oscura. **(b) Ilustración por tipo de comida** — tile `size-12` con emoji (☕🥗🍲🍌) junto al badge del tipo; verificado que el DOM lleva los codepoints correctos — el Chromium headless del preview no tiene fuente de emoji, en iOS/Android renderizan nativos. **(c) Hero media del día** (referencia Gymnax): el GIF del primer ejercicio en grande con play en volt y nombre sobre gradiente, tap = su guía de ejecución; solo en el seguimiento del miembro, el editor del staff no lo carga. **(d) Sesión**: chips de serie a 48px (`h-12`, tap con sudor y sin mirar) y celebración PR con `pop-celebracion` (rebote cubic-bezier). **(e) Bug real cazado de paso** (disciplina de causa raíz): `_dia_editor` llamaba `Current.user.premium?` — en un broadcast Turbo no hay `Current.user` (nil.premium? reventaba el `after_update_commit` de `difundir_a_miembro` cuando el caller no venía de un request de staff) y, peor, cuando renderizaba el staff el gate premium usaba el premium DEL STAFF, no el del miembro dueño. Fix: local `premium:` con el premium del dueño, enhebrado desde `_semana`; fallback a `Current.user&.premium?`. **Verificación:** flujo completo en navegador — dona volt, comidas con tile, hero del día con su lista, cronómetro de descanso corriendo tras marcar Serie 1 ("Sigue: Serie 2 de 3", +30s/Saltar) — y cierre con 740 ejemplos / 0 fallos, rubocop y brakeman limpios.
>
> **Nota 17 (agosto 2026) — Fase 14, segunda ola (14.3, 14.4, 14.5, 14.7, 14.8, 14.9, 14.10, 14.13, 14.14, 14.15):** diez etapas desarrolladas en paralelo (worktrees aislados, base de test propia por agente, rangos de timestamps de migración reservados) e integradas en serie con la suite en verde tras cada merge. **Entregas:** (a) **mesociclo real** — contrato `rutina` v2 con semanas copy-on-write (`Rutina::{Calendario,Resolutor}`, mutadores con `semana:`, lectura tolerante v1, `mesociclo:migrar` dry-run), la IA emite base + metadatos (nunca semanas materializadas; `parsear` sintetiza y el validador clampea ajustes alucinados), UI de eje de semanas con frames perezosos (solo la activa en el DOM) y chips de día estilo referencia, adherencia/historial por semana del ciclo con `contexto_ciclo` en el prompt de regeneración; (b) **modo sesión** (`/sesion`) — un ejercicio a la vez, cronómetro de descanso que por fin consume `descanso_seg`, resumen de duración/series/volumen; (c) **nutrición** — dona SVG server-rendered Consumidas/Restantes/Quemadas con interfaz reutilizable, comidas por `tipo` en grid 2×2 con "Recomendado", macros del consumo real en `registros_calorias`; (d) **dashboard "Hoy"** — qué toca hoy con avance bi-formato, racha con llama, explorador del catálogo por músculo con conteo (política ya era global desde F6); (e) **récords personales** — histórico estilo `pagos` (`superado_en`), detector con baseline (el primer registro es la vara, no un récord), celebración por turbo_stream conviviendo con el top layer del modal; (f) **ranking opt-in** (`/ranking`) — podio + posición propia con 3 queries fijas, lista borrosa para no participantes (reciprocidad), consentimiento auditable, y el spec de subdominio que fija que un miembro visible del tenant B jamás asoma en el tenant A; (g) **ciclo menstrual** — fases derivadas jamás persistidas, la única policy del repo sin rama de staff (blindada con spec que falla si alguien la agrega), consentimiento en dos niveles (registro vs. envío a IA), revocación transaccional con borrado. **Las tres derivas de interfaz que la integración cazó** (valor del contract-first con placeholders): (1) el modelo reconocía v2 solo por `version>=2` mientras el validador usaba el predicado amplio — unificado: v2 = `version`/`mesociclo`/`semanas` presentes, completando piezas en memoria; (2) `Calendario.semana_de` devuelve enteros sin clamp donde el placeholder devolvía nil — normalizado en los consumidores: fuera de 1..total es `fuera_de_ciclo`, nunca una semana fantasma; (3) `semana_actual` clampea a propósito, así que el "ya terminó" narrativo sale de `mesociclo_completado?`. Además dos llamadas posicionales pre-14.6 a `estado_de` en las vistas de A3 pasaron a keywords con uid, y un spec de contrato asertaba el detalle del placeholder (semana materializada) en vez del contrato real (herencia `dias: nil`) — corregido y documentado inline. **Verificación:** 740 ejemplos / 0 fallos (~92.9%), rubocop y brakeman limpios; recorrido visual a 375px contra la base local: dashboard Hoy → "Empezar entrenamiento" → programa de 4 semanas (ADAPTACIÓN 0/24 con chips) → dona de nutrición → opt-in del ranking. Gotcha de entorno anotado: `bin/rails server` a secas no compila Tailwind — clases nuevas exigen `tailwindcss:build` o `bin/dev`. **Pendiente operativo:** migraciones `20260805010000`–`20260805030000` en el próximo deploy (además de las de la Nota 16); `mesociclo:migrar` es opcional y opt-in; el botón "volver a heredar" de semanas materializadas y la composición ciclo×mesociclo en la UI quedan para la ola siguiente.
>
> **Nota 16 (agosto 2026) — Fase 14, primeras entregas (14.1, 14.2, 14.6, 14.11, 14.12):** desarrolladas en tres carriles paralelos (worktrees aislados con base de test propia) e integradas en serie. **(a) 14.1 — Tab bar + PWA real:** navegación inferior de 5 destinos con safe-area (`env(safe-area-inset-bottom)`, primero del repo), service worker funcional (network-first en navegación con fallback offline, cache-first en `/assets/`; no intercepta POST/streams — Turbo no se entera), página offline, íconos 192/512, shortcuts, y `public/icon.svg` deja de ser el círculo rojo placeholder de Rails. El menú hamburguesa móvil queda solo para staff. **(b) 14.2 — Tarjeta de ejercicio (referencia Gymnax):** miniatura del catálogo visual vía el proxy de media (por fin expuesto al miembro), línea densa `3 × 12-15 · ≈60 kg · 90 s`, check circular a la derecha, y "Anterior: X kg × N" desde `DetalleEntrenamiento` — precargado con una query `DISTINCT ON` (spec anti-N+1). **(c) 14.6 — uid estable:** cada entrada de ejercicio de la rutina lleva `uid` (generado en las 4 rutas de alta; la IA no lo ve, el validador lo estrena) y `registros_entrenamiento.ejercicios` pasa a v2 anclado por uid (`items`), con lectura tolerante: los registros v1 se leen intactos por índice y al re-marcarse archivan sus claves bajo `legacy`. Arregla el bug del anclaje posicional que re-atribuía historial si el plan cambiaba. Sin migración de datos: un registro es un hecho histórico. **(d) 14.11 — `consentimientos`:** append-only (tipo, acción, versión del texto, ip/user_agent), vigencia = última fila; tipos `tabla_posiciones`/`ciclo_menstrual`/`ciclo_menstrual_ia`. **(e) 14.12 — Motor de juego sin UI:** ledger `registros_puntos` (fuente de verdad, índice único parcial por origen — los reintentos de jobs en ventana de deploy no pueden duplicar puntos, spec que ejecuta el job dos veces y verifica una fila), proyección `perfiles_juego` reconstruible (tenant_id desnormalizado según el criterio de §16.7 — se lista entre usuarios), catálogo `logros` global-o-por-tenant, `Juego::{Otorgador,Racha,Recalculador}` como POROs, jobs desde controllers (jamás callbacks: check-in sensible a latencia, `demo:sembrar` dispararía miles), un job por día de entrenamiento. `visible_en_tabla` default false y solo el propio miembro puede activarlo. **(f) Bug de integración cazado por la suite combinada:** `algun_ejercicio_hecho?` (14.12) se escribió contra el JSONB v1 mientras `marcar!` (14.6) ya escribía v2 — encolaba un job por cada marca en vez de uno por día; corregido bi-formato. **Verificación:** 538 ejemplos / 0 fallos (90.95%), rubocop y brakeman limpios, y flujo end-to-end en navegador a 375px contra la base local: login → dashboard con tab bar → Mi plan con miniaturas y "Anterior" → check → JSONB v2 por uid real en la base → 15 puntos en el ledger y proyección con racha 1. **Pendiente operativo:** migraciones `20260803000000`–`20260804000002` en el próximo deploy; backfill perezoso de uids en planes pre-14.6 (hoy usan clave sintética posicional `i<indice>`, statu quo conservado).
>
> **Nota 15 (agosto 2026) — Etapa 1 del Plan de Estabilización (blindaje multi-tenant):** cerrada la etapa que convierte una fuga cross-tenant en estructuralmente improbable, no solo improbable por disciplina. **(a) Red de aislamiento (1.1-1.2):** `spec/policies/aislamiento_cross_tenant_spec.rb` cubre 13 modelos con el helper `expect_aislado`, y las 20 policies tienen spec propio con el caso negativo cross-tenant siempre presente. **(b) `tenant_id` desnormalizado (1.3):** ADR en §16.7 — `membresias`, `pagos` y `suscripciones` ganan columna propia (migración `20260803000000`, backfill idempotente dentro de la migración, `down` verificado); el concern `TenantDesnormalizado` hereda el tenant del dueño y **rechaza cualquier fila cuyo `tenant_id` no coincida**, así que ya no se puede persistir una incoherencia aunque el controller lo intente; los Scopes filtran por columna vía `del_tenant_directo` y `Admin::SuscripcionesController#index` deja de armar el join a mano. Las demás tablas por-usuario siguen por join, con el criterio de cuándo desnormalizar escrito en el ADR. **(c) Request specs por subdominio (1.4):** `spec/requests/aislamiento_por_subdominio_spec.rb`. Al escribirlo se descubrió que los tests de "otro tenant" existentes **pasaban por la razón equivocada**: firmaban sesión antes de cambiar de `host!`, y como la cookie es host-only el redirect lo producía la falta de sesión, no `verificar_pertenencia_al_tenant` — habrían seguido en verde con el guard borrado. Corregido invirtiendo el orden (que además es el escenario real: la cookie replicada a otro subdominio) y afirmando el `flash`. **(d) `dip test` estaba roto con Supabase activo:** el `environment: RAILS_ENV: test` a nivel de comando no ganaba sobre el `RAILS_ENV: development` global de `dip.yml`, así que `db:test:prepare` corría en development — cuya config es `url: ENV["DATABASE_URL"]`, es decir **Supabase producción** — y abortaba con `ProtectedEnvironmentError`. Solo el guard de Rails evitaba el destrozo; la promesa de CLAUDE.md ("los tests SIEMPRE van a la base local") era cierta por accidente, no por construcción. Arreglado poniendo `RAILS_ENV=test` inline en el comando de `dip.yml`. Cierre: **455 ejemplos en verde, cobertura 90.45%**, `dip rubocop` (276 archivos) y `dip brakeman` (0 warnings) limpios. Pendiente operativo: aplicar la migración `20260803000000` en producción en el próximo deploy.
>
> **Nota 13 (julio 2026) — Fase de Calidad (v1.1.0):** auditoría de estabilidad/performance sobre código + base real. **(a) Causa raíz de los fallos de producción:** el pooler de Supabase en modo sesión limita a **15 clientes**; cada contenedor consume hasta 13 (pools primary 3 + cache 2 + queue 6 + cable 2) y en la ventana de deploy conviven dos contenedores → `ConnectionNotEstablished` en jobs (19 fallos acumulados) y el cuelgue de `db:prepare` en arranques en frío. Mitigado con `retry_on ConnectionNotEstablished` en `ApplicationJob` (re-lanzado desde los rescues de los jobs de IA), `idle_timeout: 60` en los pools de producción y `PGCONNECT_TIMEOUT=10` en el deploy (falla rápido en vez de colgarse; el restart policy + hook post-deploy recuperan). El límite del pooler queda como **restricción operativa**: subir `pool_size` en el dashboard de Supabase da margen extra. **(b) Caché (primera adopción de Solid Cache):** fragment cache en catálogo de ejercicios (resultados por búsqueda + popup de ayuda por ejercicio), blog y novedades públicos; `fresh_when` (ETag/304) en `/blog/:slug`; morphing de Turbo 8 (`method: :morph, scroll: :preserve`) en el layout. **(c) Bug corregido:** `/novedades` (pública) no tenía vista — MissingExactTemplate desde el release de la Fase 8; se añadió vista + spec de regresión. **(d) Depuración de base:** se eliminaron 7 índices single-column redundantes (cubiertos por compuestos con la misma columna líder; `suscripciones.user_id` se conserva porque su compuesto es parcial). La base física se comparte con la landing (tablas `perfiles`, `auth.*`, `storage.*`, función `rol_actual()`): **nada de eso se toca desde este repo**. RLS habilitado sin policies en las tablas de Rails es correcto: bloquea PostgREST y Rails (owner) lo bypasea.
>
> **Nota 24 (agosto 2026) — Fase 12a, landing de autoservicio en `join.ynt.codes` (cobro manual):** primera pieza de negocio del pivote SaaS (§17.5), a pedido explícito de Cesar de vender directo a entrenadores y separar a las personas individuales del tenant de un gimnasio. Se prioriza validar demanda barato: sin pasarela de pago, un formulario que crea `SolicitudAutoservicio` (nombre/correo/teléfono/segmento, `negocio_nombre` obligatorio solo si `entrenador`) y una bandeja en el portal comercial (`Superadmin::SolicitudesAutoservicioController`) para que superadmin/comercializador la trabajen a mano — el alta real del tenant sigue el runbook de siempre (§16.4) por `Superadmin::TenantsController`. Precios de lanzamiento fijados contra mercado real (SmartFit, Spinning Center, TrueCoach, Fitbod, Strong — fuentes y números en §17.5): **$49.900 COP/mes** (promo 3 meses, luego $99.900) para entrenadores, **$29.900 COP/mes** para individuales — ninguno toca `Negocio`/`config/negocio.yml`, son solo copy de la landing. De paso se encontraron y corrigieron dos bugs latentes en producción, ninguno introducido por esta fase: `Landing::CampanasController` (Fase 13) nunca estuvo exento de `verify_authorized`, y `layouts/landing.html.erb` renderizaba un partial `shared/_toast` que nunca existió (reventaba `MissingTemplate` en cualquier render de esa landing). Cierre: 824 ejemplos / 0 fallos, `dip rubocop` limpio; `dip brakeman` reporta 0 warnings de seguridad reales — el binstub falla solo por `--ensure-latest` (gem 8.0.5 instalada vs. 8.0.6 publicada, sin relación con este cambio). El mismo día, revisando la landing en el celular, apareció un tercer bug latente: `layouts/landing.html.erb` no cargaba el stylesheet `"tailwind"` (solo el manifiesto vacío de Propshaft) — cualquier landing pública se veía sin estilos. Corregido en un commit aparte (`4d4238f`).
>
> **Nota 25 (agosto 2026) — Fase 12b, un dominio por audiencia (`trainer.ynt.codes` / `entrena.ynt.codes`):** un día después de la Nota 24, Cesar preguntó si el toggle "Soy entrenador"/"Es para mí" de una sola página no debería ser dos campañas independientes, ya que `join`/`unete` se habían reservado justo para identificar audiencias. Se está de acuerdo: mejor atribución de Meta Ads (un anuncio por dominio, sin UTMs) y copy 100% dedicado sin genérico de por medio. Pero `join`/`unete` **no** se reutilizan para esto — ya tenían dueño (Fase 13, landing de campaña por tenant) y mezclar los dos propósitos en el mismo dominio habría sido confuso. Dos dominios nuevos, decididos con el cliente en una segunda vuelta (la primera propuesta, "ynt.labs", resultó ser un lapsus): **`trainer.ynt.codes`** (entrenadores, término directo tipo SaaS de coaching) y **`entrena.ynt.codes`** (personas individuales, imperativo motivacional — el cliente lo prefirió sobre "solo"/"vos"/"arranca"). Ambos bajo `ynt.codes`: cero DNS/TLS/túnel nuevo, el wildcard existente ya los cubre. Cambios: `TenantScoping::SUBDOMINIOS_AUTOSERVICIO` nuevo (sin esto, `resolver_tenant` — que corre para toda la app, independiente de las rutas — habría tratado "trainer"/"entrena" como slugs de tenant desconocidos y devuelto 404 antes de llegar al controller); ambos slugs suman a `Tenant::SUBDOMINIOS_RESERVADOS`; el segmento ya no sale de `params[:segmento]` sino de `request.subdomain` vía un hash fijo en el controller — más simple que el toggle y sin depender de un valor que el cliente pudiera mandar. `join`/`unete` vuelven a servir solo `/:slug`, intactos. Cierre: 829 ejemplos / 0 fallos, rubocop y brakeman (real) limpios.
>
> **Nota 26 (agosto 2026) — Fase 19, ideas adoptadas de [openGym](https://github.com/DuarteSantos8/openGym):** revisión del proyecto open-source openGym (tracker personal self-hosted) buscando ideas de UX de entrenamiento que faltaran en Advance Fitness — nunca copiado, solo adaptado al modelo de datos existente. Se descartaron explícitamente passkeys (chocaría con la decisión cerrada de auth nativa Rails 8 + Google OAuth, §04), cardio en el plan de IA (se sacó a propósito en la Fase 5.7), 12 idiomas (la UI en español es decisión de producto, CLAUDE.md), import de Apple Health/otras apps (fuera de alcance explícito, §02) y app Android standalone (ya resuelto con la PWA de la Fase 14). Cinco sí entraron: **(a) 1RM estimado** — `CalculadoraUnaRepMax` (Epley, PORO puro, sin estimar sobre 12 reps) sobre `DetalleEntrenamiento.mejores_sets_para_una_rm` (mismo patrón `DISTINCT ON` de `ultimos_por_ejercicio`, pero rankeado por 1RM estimado y no por peso — una serie de menos peso y más reps puede estimar más), con calculadora de series hipotéticas en el cliente (aritmética, no IA). **(b) Heatmap de actividad** — `Juego::Heatmap`, año completo, mismo criterio "cumplido" que `Juego::Racha` y la tira de 7 días del dashboard (check-in O ejercicio marcado); `.en_columnas` agrupa en semanas lunes-domingo para la cuadrícula estilo GitHub. **(c) Mapa muscular** — `Juego::MapaMuscular` suma `volumen_kg` agrupado por `Ejercicio.musculo` (join a `DetalleEntrenamiento`, el músculo vive en el catálogo visual, NUNCA en el JSONB de la rutina) por semana/mes/todo, normalizado 0..1 contra el músculo con más volumen; siluetas esquemáticas frente/espalda (geometría en `ApplicationHelper#zonas_mapa_muscular_frente/_espalda`, coherente con el estilo stencil de la marca §06, no anatómicas). Las tres viven como secciones perezosas nuevas de `/progreso` (`progreso_grafica/:tipo` ampliado, mismo patrón turbo-frame de la Fase 16.6) — se evaluó gatearlas por `Tenant::FEATURES` y se descartó: son mejoras del núcleo de progreso/plan, no un módulo de negocio opt-in como nutrición o ciclo. **(d) Wake Lock** — pantalla activa durante `/sesion`, pedida en `connect()` y liberada en `disconnect()` del nuevo `wake_lock_controller.js` (mismo ciclo de vida que el cronómetro de descanso de `sesion_controller.js`, con el que convive en el mismo `data-controller`), reintentada al volver de segundo plano (`visibilitychange`) porque el navegador la libera solo al perder visibilidad; feature-detection (`"wakeLock" in navigator`) con el mismo idioma que `push_controller.js`. Toggle en Ajustes del perfil (`users.wake_lock_activo`, default encendido, mismo patrón booleano que `vip`). **(e) Reprogramar un día** — la pieza de mayor diseño: mover el entrenamiento de una fecha a otra SIN tocar `rutina.dias` (la plantilla semanal), porque el contrato de mesociclo (Fase 14.7) resuelve fechas por `(mesociclo.inicio, semana, nombre-de-día→DIAS_OFFSET)` sin ningún slot de excepción por ocurrencia — insertar el cambio ahí habría corrido la semana completa, no un solo día. Se optó por una tabla aparte, `reprogramaciones_dia` (`ReprogramacionDia`, belongs_to `plan_personalizado`), con índices únicos por `(plan, fecha_original)` y `(plan, fecha_destino)` — un origen se mueve una sola vez (reintentar actualiza el destino, upsert) y un destino recibe un solo origen (sin ambigüedad de qué día se muestra); validación adicional contra encadenar (mover A→B y luego B→C). `SesionesController#show` la consulta ANTES de tocar rutina/ciclo: `movido_hacia` (la fecha vista perdió su contenido, se movió a otra — pantalla `sesiones/movido` con link a la nueva fecha y "Deshacer") y `movido_desde` (la fecha vista muestra el contenido de OTRA fecha movida hacia aquí — banner con "Deshacer", sin ofrecer reprogramar de nuevo). La fase del ciclo menstrual se sigue leyendo de la fecha REAL que se está viendo (el cuerpo no se movió); el contenido (qué ejercicios) sí viene de la fecha original. Self-service puro — sin rama de staff en `ReprogramacionDiaPolicy`, mismo criterio de alcance que `CicloMenstrualPolicy` (no es un dato sensible como el ciclo, es simplemente una decisión que no requirió abrir el alcance a que el staff reprograme por el miembro). Verificación: recorrido completo crear → ver origen (movido) → ver destino (contenido recibido) → deshacer → vuelta al estado normal, contra el navegador con datos reales. Cierre: 873 ejemplos / 0 fallos, `dip rubocop` (389 archivos) y `dip brakeman` (0 warnings reales, mismo `--ensure-latest` inocuo de siempre) limpios.

---

## 12 — Decisiones fijas

Estas decisiones están cerradas. Reabrirlas durante el MVP genera deuda técnica sin retorno.

| Decisión | Valor | Por qué |
|---|---|---|
| Framework | Rails 8.1 monolito (Ruby 4.0.5) | Un solo lenguaje para dominio server-side; auth, jobs, cache y cable incluidos |
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

---

## 16 — Visión a futuro: plataforma multi-gimnasio (white-label)

> Estado: **documentada, no implementada** (julio 2026). Único artefacto en código: el seed de arranque de tenant (`db/seeds.rb`) y `bin/rails tenant:preparar` (Nota 9, §11). Formalizada en la tabla de fases (§11) como **Fase 9** (preparación técnica) y **Fase 10** (piloto y escala) — ver Nota 10. Esta sección es la fuente de verdad para el salto y queda abierta a mejoras. La continuación de negocio de esta visión (pricing por tiers, white-label, go-to-market) está en §17.

### 16.1 — La visión

Misma aplicación para N marcas, cada una en su subdominio y con su **base de datos independiente**:

| Tenant | Subdominio | Base |
|---|---|---|
| Advance Fitness | `advance-fitness-app.ynt.codes` | propia |
| Vital Fitness | `vital-fitness-app.ynt.codes` | propia |
| Influencer 1 | `influencer1.ynt.codes` | propia |

### 16.2 — Arquitectura elegida: multi-instancia (una imagen, un despliegue por tenant)

Cada gimnasio corre como **un contenedor propio** de la **misma imagen Docker**, con su `DATABASE_URL`, sus ENV de `Negocio`, su alias de red y su entrada en el túnel Cloudflare. Kamal lo soporta nativamente con *destinations* (`config/deploy.<tenant>.yml` + `kamal deploy -d <tenant>`).

**Por qué encaja con este stack:**
- **Aislamiento absoluto por construcción**: imposible que un query cruce gimnasios; no hay `WHERE gimnasio_id` que olvidar.
- **Cero refactor del núcleo**: los jobs recurrentes (`VencerMembresiasJob`, etc.), Solid Queue/Cache/Cable y los Turbo Streams operan sobre la conexión del proceso — cada instancia atiende su base y queda correcta sin tocar código.
- **Chat y tiempo real (Fase 8 Comunidad) escalan por-gimnasio**: Solid Cable por tenant = sin contención entre marcas; la carga de un gimnasio grande no afecta a los demás.
- **`Negocio` ya existe para esto** (§04): nombre, logo, precios y duración por ENV por instancia.
- **Fallos aislados**: un tenant caído o migrando no toca a los otros.

**Alternativas descartadas:**
- *Row-level tenancy* (`gimnasio_id` en cada tabla): refactor total de modelos/policies/queries y un bug = fuga de datos entre gimnasios. Contradice además el requisito de bases independientes.
- *Un solo proceso con sharding por subdominio* (`connected_to` por request): exige middleware host→shard, `Current.tenant`, jobs iterando N bases y multiplica el pool de conexiones (contra el límite de 15 del pooler de Supabase). Solo se justificaría con decenas de tenants.

**Costo asumido**: ~400–600 MB de RAM por contenedor en el homelab y operación ×N (mitigada por la plantilla de deploy y el runbook). Con **>10–15 tenants** se reevalúa consolidación con métricas reales (RAM, conexiones, tráfico).

**¿Es difícil el salto desde hoy? No.** El inventario (16.3) muestra que el trabajo restante es sobre todo configuración y parametrización de branding, no reescritura.

### 16.3 — Inventario de acoplamientos single-tenant (auditoría julio 2026)

| # | Categoría | Estado | Veredicto |
|---|---|---|---|
| 1 | Branding | `_logo`/`_navbar`, títulos (`content_for :title`), `shared/_auth_brand` y manifest PWA ya leen de `Negocio` (nombre, ciudad, colores del tema) | Resuelto (Fase A, julio 2026) |
| 2 | Valores de negocio | Centralizados en `Negocio` + `config/negocio.yml` con override por ENV (`NEGOCIO_NOMBRE`, `PRECIO_*`, `MEMBRESIA_DURACION_DIAS`); horarios de acceso son dato por membresía | Ya listo |
| 3 | Base de datos | Un solo `DATABASE_URL` por proceso; cache/queue/cable comparten la base física; sin `connected_to`/shards | Neutral en multi-instancia (cada contenedor trae el suyo) |
| 4 | URLs y host | `default_url_options`/`config.hosts` resueltos por `APP_HOST` (ENV) desde PR #14 — los correos de reset ya apuntan al dominio real | Resuelto (Fase A) |
| 5 | Sesiones / OAuth | Cookie host-only (aislada por subdominio, ideal); OAuth de Google requiere registrar el redirect URI de cada subdominio en Google Cloud y decidir client_id compartido o por tenant (`GOOGLE_CLIENT_ID/SECRET` ya son ENV) | Cookie lista · OAuth = config externa por tenant |
| 6 | Estado global | `Current` sin tenant (correcto en multi-instancia); `Ejercicios::MediaCache` cachea a volumen propio (contenido inmutable, inofensivo); catálogo `ejercicios` se importa por base (`tenant:preparar`) | Neutral |
| 7 | Jobs recurrentes | Operan sobre la conexión del proceso (`config/recurring.yml` corre en cada instancia contra su base) | Correcto por construcción |
| 8 | Deploy | `service`/`image`/`network-alias: rails-app`/volumen con nombres fijos en `config/deploy.yml`; secrets únicos | Requiere plantilla por tenant (Fase B) |

### 16.4 — Runbook de alta de un tenant

1. **Base**: crear la base independiente (proyecto Supabase propio, o Postgres self-hosted en el homelab si el costo/límite de proyectos aprieta). Anotar el `DATABASE_URL` (pooler en modo sesión: recordar el límite de conexiones — ver la lección de la Nota 6 sobre `pool`).
2. **Secrets/ENV del tenant**: `DATABASE_URL`, `SEED_ADMIN_EMAIL`/`SEED_ADMIN_PASSWORD`, `NEGOCIO_NOMBRE`, `NEGOCIO_LOGO_URL`, `PRECIO_MENSUALIDAD`, `PRECIO_PERSONALIZADO`, `MEMBRESIA_DURACION_DIAS`, `GEMINI_API_KEY`/`IA_PROVEEDOR`, `GOOGLE_CLIENT_ID/SECRET`, `APP_HOST` (cuando exista, Fase A).
3. **Deploy**: `config/deploy.<tenant>.yml` con `service`, `image` (o tag), `network-alias` y `volumes` propios → `kamal deploy -d <tenant>`.
4. **Túnel Cloudflare**: agregar el ingress `https://<subdominio>.ynt.codes → http://<alias>:80` en el compose del túnel (recordar el bug conocido del alias de red post-deploy, DEPLOY.md).
5. **OAuth**: registrar `https://<subdominio>.ynt.codes/auth/google_oauth2/callback` en Google Cloud.
6. **Datos**: `bin/rails tenant:preparar` dentro del contenedor — schema + seed + catálogo de ejercicios + reporte de pendientes.
7. **Smoke test**: login del admin sembrado, alta de una membresía de prueba, check-in, y cambio inmediato de la contraseña del admin.

### 16.5 — Plan de mejoras por fases

- **Fase A — Branding y host (completada, julio 2026):** `default_url_options` → `APP_HOST` por ENV (arregló los links de correo rotos, PR #14); títulos de vistas compuestos desde `Negocio.nombre` (los ~26 literales `"… — Advance Fitness"` pasaron a `"… — #{Negocio.nombre}"`, más `<title>`/`<meta application-name>` del layout); `_auth_brand` (nombre de marca y `©`) y manifest PWA (`name`/`description`/`theme_color`/`background_color`, antes con placeholder `"red"`) parametrizados desde `Negocio` (+ nuevo `Negocio.ciudad`). Pendiente de decisión futura (Fase D): el tema DaisyUI `advance` y el logo vectorial siguen siendo únicos — un tenant white-label con paleta propia necesitaría su propio tema o un `logo_url` (ya soportado por `Negocio.logo_url`).
- **Fase B — Plantilla de deploy multi-destino:** `config/deploy.<tenant>.yml` + secrets por destino; probar el runbook 16.4 de punta a punta con un tenant de staging.
- **Fase C — Piloto:** segundo tenant real (o staging permanente) conviviendo con Advance Fitness en el mismo host; medir RAM/conexiones/latencia.
- **Fase D — Escala:** a >10–15 tenants, decidir con métricas si se consolida (sharding, más hardware, o mover tenants grandes a su propio host). Tema de color por marca (hoy el tema DaisyUI `advance` es único) se decide aquí si algún tenant lo pide.

### 16.6 — ADR revertido: multi-tenancy row-level por subdominio (julio 2026, v1.4.0)

**Reversa explícita de §16.2.** Se reemplaza "una base independiente por tenant" por row-level tenancy en una sola base Postgres, resuelto por subdominio (`{slug}.ynt.codes`). Motivos: (a) permitir venta directa por un rol comercializador voz-a-voz desde un solo despliegue; (b) parametrizar precios/marca por tenant sin duplicar infra; (c) el costo operativo real de N despliegues Kamal + N bases Supabase superaba el riesgo de una fuga de datos bien acotada por Pundit.

**Alcance del PR (rama `feature/multi-tenant-superadmin`):**
- Nuevo modelo `Tenant` (nombre, `slug` único con normalización + subdominios reservados, `tipo_entidad` gimnasio/entrenador/influencer, `email_contacto`, `paleta_colores` jsonb, `features_habilitadas` jsonb, precios opcionales por tenant, `logo` vía Active Storage).
- `users` gana `tenant_id` (nullable — `superadmin`/`comercializador` son globales, validado en el modelo). Igual `posts` y `novedades` (aislados por tenant).
- **Catálogos globales**: `Plan`, `Ejercicio`, `PlantillaComida`, `PlantillaEjercicio` NO se aíslan (evita duplicar el catálogo visual de ~1.324 ejercicios y romper la unicidad de `Plan.codigo`).
- Resolución por subdominio: nuevo concern `TenantScoping` con `prepend_before_action :resolver_tenant`. `comercial`/`app` → modo portal comercial (`Current.tenant = nil`); `www`/`advance-fitness-app` y apex → tenant AF (back-compat); slug conocido → tenant respectivo; slug desconocido/inactivo → 404. `verificar_pertenencia_al_tenant` post-auth rechaza a usuarios que no pertenezcan al tenant del subdominio (defensa en profundidad).
- **Cookie de sesión sigue host-only** (sin `domain`): cada `{slug}.ynt.codes` tiene su propia sesión aislada. Sin SSO cross-subdominio en esta fase.
- **Google OAuth solo en subdominio central**: se mantiene el callback ya registrado (`advance-fitness-app.ynt.codes` para back-compat, `app.ynt.codes` a registrar para el portal); los subdominios de tenant nuevos usan solo login por contraseña.
- `Negocio.*` ahora consulta `Current.tenant` primero (precios, `nombre`); si no hay tenant o el campo es nulo, cae al ENV/YAML global — ningún call-site existente cambia.
- Pundit: `ApplicationPolicy::Scope#del_tenant` reemplaza los `scope.all` de las ramas de staff en `UserPolicy`/`MembresiaPolicy`/`AccesoPolicy`/`PagoPolicy`. `Admin::SuscripcionesController#index` (que listaba sin `policy_scope`) filtra explícitamente por `users.tenant_id`. Nuevo `TenantPolicy` solo autoriza superadmin.
- Portal comercial: `namespace :superadmin` con CRUD de tenants, form para el admin inicial que dispara el flujo de "reset de contraseña" existente. Navbar reducido para `superadmin`/`comercializador`.
- Theming: `<style>` inline en el `<head>` inyecta `--color-{volt,primary,accent}` desde `Tenant#paleta_colores` (solo acepta hex para evitar CSS injection); `shared/_logo` prefiere `Current.tenant.logo` si está attached, con fallback al `Negocio.logo_url` y luego al vector de marca.
- Backfill: `bin/rails multi_tenant:migrar` (rake task idempotente): crea el tenant AF si no existe, asocia todos los `User`/`Post`/`Novedad` sin tenant a AF, crea superadmin (`SUPERADMIN_EMAIL`) y comercializador semilla (`COMERCIALIZADOR_EMAIL`). Se corre a mano en producción con confirmación explícita, mismo ritual que `demo:sembrar`.
- Tests: 27 specs nuevos (Tenant, User global vs tenant, `Negocio` tenant-aware, aislamiento cross-tenant en 4 policies, TenantPolicy, resolución por subdominio, CRUD superadmin). 398/398 en verde.

**Fuera del PR (runbook de infra, responsabilidad del usuario):**
1. Wildcard DNS `*.ynt.codes` → túnel Cloudflare.
2. Ingress `*.ynt.codes` en el compose del túnel.
3. TLS wildcard (Cloudflare Universal SSL cubre un nivel).
4. `config.hosts` ya acepta `.ynt.codes` en producción; `APP_HOST` sigue apuntando a `advance-fitness-app.ynt.codes` para no romper links de correo/back-compat.
5. En Google Cloud: agregar `https://app.ynt.codes/auth/google_oauth2/callback` cuando se active el portal comercial con Google login.
6. Post-deploy: correr `bin/kamal app exec --interactive --reuse "bin/rails multi_tenant:migrar"` para el backfill (una sola vez).

**Qué queda pendiente para fases futuras:** SSO cross-subdominio (bootstrap por token firmado), Google login en subdominios de tenant nuevos, catálogos por tenant si algún cliente lo pide, plan de superadmin para desactivar/pausar tenants desde la UI (hoy solo activo/inactivo).

### 16.7 — ADR: `tenant_id` desnormalizado en las tablas de dinero (agosto 2026, Etapa 1.3)

**Contexto.** Tras §16.6, el aislamiento de `membresias`, `pagos` y `suscripciones` se deriva por **join a `users`**. Funciona, pero descansa por completo en que cada Pundit Scope arme bien su join. `PagoPolicy::Scope` necesita **dos saltos** (`joins(membresia: :user)`) para llegar al tenant: es la cadena más larga del dominio y está justo sobre la tabla de dinero. Un `where` mal armado en un controller nuevo —o un `scope.all` copiado de otra policy— filtra el historial financiero de otro gimnasio. Es el riesgo #1 del negocio white-label (§17) y la brecha #1 del plan de estabilización.

**Decisión: se desnormaliza.** `membresias`, `pagos` y `suscripciones` ganan `tenant_id` propio (FK a `tenants`), y sus Pundit Scopes filtran **directo por la columna**, sin join. Las demás tablas por-usuario (`mediciones`, `accesos`, `objetivos_nutricionales`, `registros_calorias`, `registros_entrenamiento`, `detalle_entrenamientos`, `planes_personalizados`, `feedback_ia`) **siguen por join a `users`**: su cadena es de un solo salto, su sensibilidad es menor y la suite de aislamiento (§Etapa 1.1) ya las cubre. Desnormalizar todo el dominio agregaría 8 columnas redundantes más sin reducir riesgo proporcionalmente.

**Criterio de cuándo desnormalizar** (para no repetir la discusión en cada tabla nueva): se desnormaliza si se cumple alguna de las dos — (a) la cadena al `User` dueño tiene **más de un salto**, o (b) la tabla se **lista u ordena entre usuarios** (no filtrada a un único dueño). `pagos` cumple (a); una futura tabla de posiciones/ranking cumpliría (b).

**Consecuencias.**
- **Fail-closed por diseño:** los Scopes usan `return scope.none if user.tenant_id.blank?` y filtran por `tenant_id`. Una fila con `tenant_id` nulo es invisible para el staff en vez de visible para todos — el modo de falla correcto en un control de seguridad.
- **Coherencia garantizada en el modelo, no por disciplina:** `before_validation` hereda el `tenant_id` del dueño (`user` en membresías/suscripciones, `membresia.user` en pagos) y una validación rechaza cualquier fila cuyo `tenant_id` no coincida con el de su dueño. No se puede crear una fila incoherente aunque el controller lo intente.
- **Backfill dentro de la migración, no en un rake aparte** — se aparta a propósito del ritual de `multi_tenant:migrar` (§16.6). Allí el backfill necesitaba decisiones de negocio (qué tenant, crear superadmin y comercializador) y por eso corría a mano. Aquí el valor es **derivable y determinista** (`user.tenant_id`), el volumen es pequeño, y un rake aparte abriría una ventana entre el deploy y su ejecución en la que los Scopes fail-closed dejarían al staff sin ver nada. El `UPDATE ... FROM` es idempotente (`WHERE tenant_id IS NULL`) y la migración es reversible.
- La columna queda **nullable a nivel de base** (igual que `users.tenant_id`) para que un rollback no falle; la presencia se exige en el modelo.
- Índices compuestos con `tenant_id` como columna líder en los listados admin, de modo que el filtro por tenant no degrade las consultas que ya existen.

**Alternativa descartada:** Row Level Security de Postgres. Ya se descartó en §18.6 por §16.2, y sigue sin aplicar: Rails se conecta como owner y bypasea RLS, así que sería una segunda barrera solo frente a PostgREST — que este repo no expone. El costo (policies SQL duplicando la lógica de Pundit) supera el beneficio mientras el acceso sea exclusivamente por Rails.

---

## 17 — Pivote SaaS white-label: modelo de negocio y go-to-market

> Estado: **visión documentada, no implementada** (julio 2026). Sin artefactos en código. La arquitectura multi-instancia de §16 es el habilitador técnico de todo lo descrito aquí: marca, base y dominio propios por tenant = white-label por construcción. Formalizada en la tabla de fases (§11) como **Fase 12** — ver Nota 11.

### 17.1 — Los tres mercados del pivote

La misma plataforma puede venderse a tres perfiles, sin bifurcar el producto:

1. **Gimnasios** (el mercado actual): gestión + IA como valor agregado. Sensibles a la estabilidad.
2. **Influencers fitness**: su marca en su subdominio, la IA como "gemelo digital" que atiende a sus seguidores. Sensibles al riesgo inicial (poca inversión upfront).
3. **Agencias de marketing fitness (white-label)**: la agencia pone su marca, cobra a sus clientes y contrata licencias por volumen — un solo canal comercial trae N tenants sin gestionar usuarios finales uno a uno.

### 17.2 — Pricing: el "Modelo de Escalada" (híbrido suscripción + revenue share)

No elegir un solo modelo: capturar valor en etapas distintas del cliente.

| Tier | Para quién | Cobro | Incluye |
|---|---|---|---|
| **Starter** | Gimnasios pequeños / influencers emergentes | Fee mensual fijo bajo (ref. ~USD 99/mes — placeholder a validar; COP para gimnasios locales) | Gestión completa + IA con **límites de generación** (planes/mensajes por mes) |
| **Pro** | Operaciones en escala | Fee mensual mayor (ref. ~USD 299/mes — placeholder) | IA ilimitada + automatización Meta API (posts/stories, §18.5) |
| **Partnership** | Influencers/gimnasios con ventas propias en la plataforma | Fee reducido + **5–10 % revenue share** de ventas brutas de programas/servicios vendidos vía la plataforma | Todo Pro; el éxito del SaaS queda alineado con el del tenant |

**Dependencias hoy inexistentes (explícitas, sin diseño aún):** pasarela de pagos online (hoy el pago es presencial y auditable, §"pagos"), medición de ventas por tenant (para liquidar el revenue share), y contadores de uso de IA por tenant (para los límites de Starter). Nada de esto bloquea Fases 9–11.

**Nota sobre `pagos` ↔ `suscripciones`:** hoy `pagos` referencia `membresia_id` — decisión deliberada para el flujo presencial (el pago ejecuta el contrato de membresía, con anulación auditable). Si el pivote introduce cobro recurrente online, se evaluará modelar el cobro sobre `suscripciones` como contrato (pago = ejecución del contrato); se registra aquí para no perder la observación, sin cambiar nada mientras el flujo siga siendo presencial.

### 17.3 — Cinco tácticas go-to-market

1. **Lead magnet de conversión instantánea — "Prueba de Clonación":** landing donde el influencer sube una foto y un audio de 30 s; la plataforma devuelve un video corto de su "clon" invitando a sus seguidores. Tangible → conversión alta. (Depende de un proveedor de clonación de voz/video, fuera del stack actual — decisión de proveedor pendiente.)
2. **"Shadow Coach" en gimnasios:** pantalla/iPad en el piso del gimnasio con consejos de la IA sobre los equipos del lugar; QR → "rutina personalizada del día" por WhatsApp. Captura leads para el gimnasio y valida el SaaS en campo.
3. **Certificación "Creadores IA":** curso breve cuyo cierre es el acceso a la plataforma; convierte a los influencers en evangelistas y garantiza onboarding correcto.
4. **Funnel de 24 horas:** webhook al detectar un Reel nuevo del influencer → DM automatizado del "gemelo digital" a los comentaristas invitándolos a la app. (Sujeto a las políticas de automatización de Meta — riesgo regulatorio anotado en §18.5.)
5. **White-label para agencias:** venta B2B2C por volumen; la agencia opera la relación con el cliente final, el SaaS opera los tenants (runbook §16.4 ya lo soporta operativamente).

### 17.4 — Decisión: no bifurcar el producto hasta el primer cliente real de otra vertical (julio 2026)

**Contexto de la decisión:** hoy hay dos clientes fijos, ambos gimnasios, con el producto tal cual funciona (check-in, membresías, catálogo de ejercicios, IA de plan y de análisis). Cero clientes influencer o entrenador personal — la vía de adquisición para ese segmento (Meta Ads) todavía no arrancó. Surgió la pregunta de si conviene, desde ya, (a) clonar el repo en un segundo software recortado para influencers/entrenadores (sin check-in ni membresía) o (b) generalizar el rol de staff (`gimnasio | entrenador | influencer`) en el mismo código para que un tenant "apague" las features que no necesita.

**Decisión: ninguna de las dos, todavía.**

- **No al fork ahora.** Es la operación barata cuando llegue el momento — la arquitectura multi-instancia de §16.2 (misma imagen, base y branding por tenant vía Kamal destinations) ya resuelve el aislamiento; forkear el repo hoy solo compraría dos bases de código para mantener en paralelo, duplicando cada bugfix, sin tener aún un cliente que valide qué necesita ese producto recortado.
- **No a generalizar el rol de staff ahora.** Añadir `tipo_negocio`/`rol_staff: influencer|entrenador|gimnasio` sin un cliente real de esas verticales es diseñar una abstracción sobre una suposición: no se sabe todavía si un influencer quiere algo parecido a check-in (¿asistencia a un reto?, ¿sesiones en vivo?), un chat, o directamente nada de lo que hoy existe. Construir esa flexibilidad ahora es casi seguro que haya que rehacerla cuando aparezca el primer cliente de verdad, y mientras tanto añade complejidad al código que sirve a los dos gimnasios que sí pagan hoy.
- **Camino cuando llegue el primer cliente influencer/entrenador:** levantar su instancia con el mismo mecanismo de §16.4 (base y branding propios) y resolver lo específico de esa vertical con **flags de visibilidad condicionales** por tenant (ocultar check-in/membresía si no aplican), no con un sistema de roles nuevo. Recién con 2-3 clientes de esa vertical, con necesidades reales observadas, se evalúa si conviene formalizar un concepto de "vertical de negocio" — la Fase 12 (§11) ya está marcada como posterior al MVP y condicionada a demanda real; esta nota extiende ese mismo criterio a la pregunta de bifurcar el producto.

**Cómo revisar esta decisión:** cuando exista el primer contrato firmado (o piloto pagado) de un influencer/entrenador, releer esta nota antes de decidir — la respuesta la da la necesidad real observada en ese cliente, no la que se anticipa aquí.

### 17.5 — Autoservicio: entrenadores y personas individuales (agosto 2026)

> Estado: **dos landings de autoservicio implementadas con cobro manual, una por audiencia** (agosto 2026, Fase 12a/12b — ver Notas 24 y 25): `trainer.ynt.codes` (entrenadores) y `entrena.ynt.codes` (personas individuales). El resto de la visión (pasarela de pago online, aprovisionamiento automático) sigue documentado, no implementado. Responde a la idea de Cesar de vender el sistema directo a entrenadores y separar a las personas individuales — refina §17.1 con dos canales *product-led* (autoservicio, sin comercializador humano) que complementan la venta asistida, para escalar ingreso sin escalar headcount.

**El hallazgo — el código ya reservó el terreno.** `Tenant::SUBDOMINIOS_RESERVADOS` (§16.6) aparta `join`/`unete` junto a `comercial`/`app`, y `TenantScoping` ya resuelve `comercial`/`app` como el **portal comercial** (venta asistida: superadmin/comercializador da de alta un tenant a mano tras hablar con el cliente, §16.6). `join`/`unete` están reservados en código pero **sin narrativa ni flujo detrás** hasta esta nota: son el canal de **autoservicio** que falta. Los dos dominios apartados para campañas de Meta Ads (`join.ynt.codes`, `comercial.ynt.codes`) encajan exactamente con esta separación: un anuncio a un gimnasio grande aterriza en `comercial` (quiere hablar con alguien); un anuncio a un entrenador o a un usuario final aterriza en `join` (quiere entrar ya, sin llamada de ventas). Las tácticas de §17.3 (funnel de 24h, DM del gemelo digital) alimentan ambos.

**Dos segmentos nuevos, un solo flujo con bifurcación en `join.ynt.codes`:**

| Segmento | Qué compra | Tenant resultante | Precio |
|---|---|---|---|
| **Entrenador personal (autoservicio)** | Su propia marca, su propio subdominio, gestiona a sus clientes | Tenant nuevo `tipo_entidad: entrenador` (ya existe en `Tenant::TIPOS`), slug elegido por el entrenador | Tier Starter (§17.2, ref. ~USD 99/mes) cobrado online desde el alta — sin comercializador de por medio |
| **Persona individual (B2C directo)** | Usar la app para sí mismo, sin gimnasio ni entrenador detrás | **No crea tenant propio** — se une a un único tenant compartido nuevo (`tipo_entidad: individual`, a agregar a `Tenant::TIPOS`; ej. slug `tu` → `tu.ynt.codes`) | Freemium ya existente (Módulo D): Free / Personalizado. **No es un tier nuevo** — es el modelo de `planes` que ya existe, desacoplado de un gimnasio anfitrión |

**Por qué agrupar a las personas individuales en un solo tenant y no darles subdominio propio:** el subdominio propio protege *marca* (§16.1) — un gimnasio o entrenador lo necesita porque sus clientes ven SU marca. Una persona sin negocio detrás no tiene marca que proteger; darle subdominio propio multiplicaría filas en `tenants` sin motivo (el aislamiento de datos ya es por `tenant_id`, no por subdominio — §16.6/§16.7). El tenant compartido es, en efecto, la versión pública y autoservicio de la plataforma. Se mantiene separado del tenant real de Advance Fitness (Cesar) para no mezclar su marca con tráfico frío de Meta Ads — sus features de gimnasio (`membresias`, `accesos`) quedan apagadas por default vía la misma regla de `membresias_habilitadas?` (§Fase 18d) que ya distingue gimnasio de no-gimnasio.

**La pieza que bloquea a los dos segmentos: cobro online.** Ya señalada como dependencia pendiente en §17.2, hasta ahora sin dueño ni fecha. Sin pasarela de pago, ningún flujo de autoservicio puede cobrar sin un humano de por medio — y eliminar a ese humano es el punto entero del canal. Es la pieza #1 a resolver antes de construir cualquier UI en `join.ynt.codes`.

**Fricción oculta en el segmento individual — revisión de plan sin entrenador:** el flujo de Personalizado (Módulo D) asume que un entrenador humano **revisa y aprueba** el plan de IA antes de publicarlo. Un tenant individual no tiene entrenador propio asignado. Dos salidas, a decidir explícitamente antes de anunciar el segmento — no dejar que sea un default accidental:
- **(a) Auto-publicar** el plan de IA sin revisión humana en el tenant individual: velocidad total, pierde la red de seguridad de calidad que sí tienen los gimnasios.
- **(b) Cola de revisión centralizada**: el propio equipo de Advance Fitness revisa los planes del tenant individual. Conserva el control de calidad, no escala tan barato como (a) — vuelve a meter un humano justo en el canal que se diseñó para no necesitarlo.

**Camino de menor esfuerzo, en orden:**
1. Pasarela de pago online (bloquea todo lo demás).
2. Sembrar el tenant individual: un solo registro `tipo_entidad: individual`, features de gimnasio apagadas por default.
3. Landing + form de autoservicio en `join.ynt.codes`, con bifurcación: "quiero mi propio negocio" (crea tenant `entrenador`, cobra Starter) vs. "quiero usarlo para mí" (une el usuario al tenant individual, entra gratis, IA de pago vía `planes` existente).
4. Job de aprovisionamiento automático que reemplaza, **solo para este camino**, el paso manual de `tenant:preparar` del runbook §16.4 — gimnasios y agencias (venta asistida, bajo volumen, alto contacto) siguen el runbook a mano; no hay razón para automatizarlo ahí.
5. Resolver la fricción de revisión de plan (punto anterior) antes de abrir el segmento individual al público.

**Por qué esto es la palanca correcta hacia ganancias:** hoy el único canal de ingreso es venta asistida (comercializador, cara a cara, tope de headcount). `join.ynt.codes` no lo reemplaza — lo complementa con dos canales que escalan sin agregar personas: Starter recurrente por entrenador (ticket bajo, volumen alto) e individual freemium con upgrade a Personalizado (ticket bajo, volumen potencialmente alto vía Meta Ads). Ambos corren sobre el 100% del código existente (§17.4 — no bifurcar el producto): el costo marginal de cada tenant o usuario nuevo es casi cero, así que cada uno que paga es casi todo margen.

**Cómo revisar esta decisión:** antes de construir, confirmar con Cesar el orden de prioridad (¿pasarela de pago primero, o vale más validar demanda con un formulario manual/WhatsApp antes de automatizar el cobro?) y la decisión de revisión de plan del segmento individual — ambas son de negocio, no técnicas, y no deberían decidirse por default en el código.

**Respuesta (agosto 2026):** se valida demanda primero. Se implementa la opción más barata: landing en `join.ynt.codes` con **cobro manual** (formulario, sin pasarela) — ver Fase 12a abajo. La revisión de plan del segmento individual queda sin resolver hasta que existan los primeros leads reales.

#### Fase 12a (implementada, agosto 2026) — precios de lanzamiento y landing de autoservicio

**Precios fijados contra el mercado real** (reemplazan el placeholder USD de §17.2 para este canal — ese placeholder seguía calibrado para el tier Pro/agencias, no para autoservicio):

| Referencia de mercado | Precio | Fuente |
|---|---|---|
| SmartFit (plan Fit), Colombia | $69.900 COP/mes | [Pulzo, tarifas 2026](https://www.pulzo.com/economia/cuanto-vale-inscribirse-gimnasio-colombia-2026-tarifas-para-sudar-exceso-PP4981370) |
| Spinning Center, Colombia | $99.000 COP/mes | [El Tiempo, tarifas 2026](https://www.eltiempo.com/cultura/gente/cuanto-vale-inscribirse-al-gimnasio-en-2026-estas-son-las-tarifas-de-bodytech-spinning-center-y-smartfit-3522055) |
| TrueCoach (software de coaching, tier más barato) | USD 29.98/mes (~$126.000 COP) | [QuickCoach, Trainerize/TrueCoach pricing 2026](https://www.quickcoach.fit/trainerize-pricing-2026.html) |
| Fitbod (app de entrenamiento con IA) | USD 15.99/mes (~$67.000 COP) | [SensAI, Fitbod review 2026](https://www.sensai.fit/blog/fitbod-review-2026) |
| Strong (tracker, sin IA de programación) | USD 9.99/mes (~$42.000 COP) | [SensAI, fitness app pricing comparison](https://www.sensai.fit/blog/fitness-app-pricing-free-tier-comparison) |

**Decisión de precio** (conversión ref. ~4.200 COP/USD, agosto 2026):
- **Entrenador (Starter, autoservicio):** **$49.900 COP/mes** los primeros 3 meses, luego **$99.900 COP/mes** de lista — por debajo de TrueCoach incluso en su tier de lista, y el precio promo queda bajo cualquier mensualidad de gimnasio de la tabla. El copy de venta lo usa literal: "menos que tu propia mensualidad de gimnasio".
- **Individual (Personalizado, autoservicio):** **$29.900 COP/mes** — por debajo de Strong (solo tracker, sin IA) y muy por debajo de Fitbod. Deliberadamente **desacoplado** del `precio_personalizado` global (350.000 COP, `config/negocio.yml`): ese precio incluye combo con membresía de gimnasio (Nota 6) y no aplica a alguien sin gimnasio detrás.
- Ninguno de los dos toca `Negocio`/`config/negocio.yml` — son precios de **copy de marketing** en la landing, no un precio cobrado automáticamente (no hay pasarela); el comercializador cierra el valor real a mano por WhatsApp/llamada, con estos números como ancla.

**Qué se construyó (superado por Fase 12b abajo — el dominio compartido con toggle duró un día):**
- `join.ynt.codes` (y `unete.ynt.codes`) en su raíz — antes solo servía `/:slug` (landing de campaña de un tenant existente, Fase 13). Ahora bifurca: `/` es la landing de autoservicio nueva; `/:slug` sigue intacta.
- `SolicitudAutoservicio` (`solicitudes_autoservicio`): nombre, correo, teléfono, `segmento` (`entrenador`/`individual`), `negocio_nombre` (obligatorio solo si `entrenador`), mensaje opcional. Nunca se borra — es el historial de leads del canal, mismo criterio que `pagos`/`consentimientos`.
- `Landing::AutoserviciosController` (`new`/`create`/`gracias`): pública, sin sesión, sin `Current.tenant` — mismo patrón que `Landing::CampanasController` (§16.6). **Sin CTA de WhatsApp saliente**: el formulario ya captura el teléfono, así que el comercializador contacta al lead con SU propio WhatsApp — cero dependencia de un número de negocio configurado.
- `Superadmin::SolicitudesAutoservicioController` (`index`/`update`): la bandeja de entrada del portal comercial (`comercial`/`app.ynt.codes`) — superadmin y comercializador ven los leads y los marcan `atendida_en`/`atendida_por` al cerrar (o descartar) a mano. El alta real del tenant/usuario sigue el camino de siempre por `Superadmin::TenantsController` — esta bandeja no crea nada automáticamente.
- `SolicitudAutoservicioPolicy`: solo superadmin/comercializador (`index?`/`update?`); sin Scope — es una colección global, no aislada por tenant.

**Tres bugs latentes encontrados de paso (ninguno introducido por esta fase, los tres en producción antes de este cambio):**
1. `Landing::CampanasController` (Fase 13, `join.ynt.codes/:slug`) nunca estuvo exento de `verify_authorized` (`ApplicationController::SIN_PUNDIT`) — no tenía specs y nunca se cazó. Se agrega junto con `autoservicios` al mismo exento, mismo motivo: son páginas públicas sin record que autorizar.
2. `layouts/landing.html.erb` renderizaba `shared/toast`, un partial que **nunca existió** — cualquier render de esa landing (incluida la de campañas ya en producción) reventaba con `MissingTemplate`. Se extrae el partial real desde `layouts/application.html.erb` (antes inline) a `shared/_toast.html.erb`, compartido por los dos layouts.
3. **Encontrado al revisar la landing en el celular** (mismo día): `layouts/landing.html.erb` solo pedía `stylesheet_link_tag "application"` (el manifiesto vacío de Propshaft) — le faltaba `"tailwind"`, que es donde vive todo el CSS real (`layouts/application.html.erb` sí pedía los dos). Cualquier landing pública se veía sin estilos, texto plano sobre blanco. Un solo `git commit` (`4d4238f`), mismo patrón que los otros dos: el layout de las landings públicas nunca tuvo un review visual real hasta esta fase.

#### Fase 12b (implementada, agosto 2026) — un dominio por audiencia, sin toggle

**Por qué cambiar:** la Fase 12a puso `/soy-entrenador` / `/es-para-mí` como un toggle dentro de una sola página en `join`/`unete`. Cesar señaló que ya existían dos dominios reservados pensados justo para separar audiencias (§17.5, hallazgo de `Tenant::SUBDOMINIOS_RESERVADOS`) — mejor usarlos como **dos landings dedicadas**, cada una hablándole solo a su audiencia, sin toggle ni copy genérico. Mejor también para atribución de Meta Ads: un anuncio a entrenadores aterriza directo en su dominio, sin UTMs.

**Dominios elegidos:** `trainer.ynt.codes` (entrenadores) y `entrena.ynt.codes` (personas individuales) — **no** `join`/`unete`, que se devuelven íntegros a su propósito original de Fase 13 (`/:slug`, landing de campaña de un tenant existente). Nombres decididos con el cliente: `trainer` en inglés (registro directo, como el resto de SaaS de coaching) y `entrena` en español con tono motivacional (imperativo, sin ambigüedad de qué es la página) — ambos bajo `ynt.codes`, cero DNS/TLS/túnel nuevo (el wildcard `*.ynt.codes` ya los cubre).

**Cambios:**
- `TenantScoping::SUBDOMINIOS_AUTOSERVICIO = %w[trainer entrena]` — nueva rama en `resolver_tenant`, mismo tratamiento que el portal comercial (`Current.tenant = nil`). Sin esto, `resolver_tenant` habría tratado "trainer"/"entrena" como un slug de tenant desconocido y respondido 404 **antes** de que la ruta del controller corriera — el `prepend_before_action` de `TenantScoping` corre para toda la app, independiente de las `constraints(subdomain:)` de `routes.rb`.
- `Tenant::SUBDOMINIOS_RESERVADOS` gana `trainer`/`entrena` — nadie puede crear un tenant real con esos slugs.
- `routes.rb`: nuevo bloque `constraints(subdomain: /\A(trainer|entrena)\z/)` con `/`, `/gracias` y el POST — el bloque de `join`/`unete` vuelve a tener solo `/:slug`.
- `Landing::AutoserviciosController#segmento_del_subdominio`: el segmento sale de `request.subdomain` vía un hash fijo (`{"trainer"=>"entrenador", "entrena"=>"individual"}`), **nunca de un param del cliente** — más simple que el toggle anterior y cierra de paso un vector menor de spoofing (antes `params[:segmento]` decidía qué precio mostraba el formulario, aunque el `create` original tampoco confiaba en él para nada sensible).
- Vista `new.html.erb` reescrita: un solo hash de copy por segmento (hero, precio, beneficios, FAQ final), una sola tarjeta de precio (no dos lado a lado), sin los botones "Soy entrenador"/"Es para mí". El campo `negocio_nombre` solo aparece en `trainer.ynt.codes`.

**Pendiente, sin cambios:** pasarela de pago online, aprovisionamiento automático, decisión de revisión de plan del segmento individual (§17.5 arriba).

---

## 18 — IA analítica de entrenamiento (Analista de Performance)

> Estado: **base de datos implementada** — tabla `detalle_entrenamientos` + modelo `DetalleEntrenamiento` (julio 2026); el resto (UI de captura, `feedback_ia`, `AnalizarEntrenamientoJob`) es diseño documentado, formalizado en §11 como **Fase 11** — ver Nota 11.

Hoy la IA solo genera planes one-shot (`GenerarPlanJob` → `GeneradorPlanIa` → adaptadores `app/services/ia/`). El salto de valor es que la IA **analice** lo que el usuario realmente hace: progresión de cargas, récords personales (PRs) y detección de estancamiento. Eso exige datos cuantitativos que el JSONB de `registros_entrenamiento.ejercicios` no tiene (solo guarda checkboxes `{hecho, nota, nombre}` + `novedad` — es el tracker cualitativo de la UI del plan, y se conserva tal cual).

### 18.1 — Base de datos (implementada)

`detalle_entrenamientos` — una fila por **serie ejecutada** de un ejercicio en una sesión:

- `registro_entrenamiento_id` (FK, `ON DELETE CASCADE`) · `ejercicio_id` (FK al catálogo)
- `serie`, `repeticiones` (NOT NULL, ≥1) · `peso_kg` decimal(6,2) **nullable** (NULL = peso corporal/calistenia) · `rpe` (1–10 opcional) · `notas`
- Índice `(ejercicio_id, registro_entrenamiento_id)` para consultas de progresión; único `(registro, ejercicio, serie)` → registro idempotente.
- `DetalleEntrenamiento#volumen_kg` = `repeticiones × peso_kg` (la métrica base del análisis; peso corporal aporta 0 porque el volumen mide carga externa).

**No fue una migración de datos**: no existían series/reps/pesos en el JSON; es una capacidad nueva. Sin doble escritura ni script de backfill.

### 18.2 — Tabla `feedback_ia` (diseño, no creada)

Guarda el análisis devuelto por la IA tras cada sesión: `registro_entrenamiento_id` (FK), `estado` (`progreso`/`estancado`/`alerta`), `analisis` (text), `accion_recomendada` (text), `modelo` (proveedor/modelo usado), timestamps. Se crea en la Fase 11 junto con el job.

### 18.3 — Flujo técnico (diseño)

Al cerrar la sesión de entrenamiento (o en digest diario) → **`AnalizarEntrenamientoJob`** (Solid Queue, mismo patrón de `GenerarPlanJob`: revalidar premium, tolerar fallos con estado, reusar los adaptadores `app/services/ia/`) → toma los últimos ~20 `detalle_entrenamientos` del usuario → prompt §18.4 → persiste en `feedback_ia`. **Sin orquestadores externos** (la sugerencia original usaba n8n; queda fuera del stack — Solid Queue cubre el caso de forma nativa).

### 18.4 — Prompts (fuente de verdad)

**System Prompt — Analista de Performance:**

> Actúa como un Entrenador Físico de Élite con especialización en Ciencias del Deporte y Análisis de Datos. Tu objetivo es interpretar la data de entrenamiento del usuario para optimizar su progreso.
> Contexto de entrada: resumen histórico de los últimos entrenamientos (series, repeticiones, pesos, RPE y fecha).
> Metodología: (1) **Progresión** — ¿el volumen total de carga (series × reps × peso) asciende, se estanca o desciende? (2) **Plateaus** — ¿lleva más de 3 sesiones sin subir peso o calidad técnica en un ejercicio? (3) **Fatiga** — ¿RPE alto constante sin aumento de carga sugiere sobreentrenamiento? (4) **Ajuste prescriptivo** — consejo técnico de máximo 3 líneas para la próxima sesión.
> Reglas: directo, técnico pero motivador; nunca sugieras aumento de carga si la técnica fue inconsistente; lenguaje de coaching premium; si hay mejora notable, felicita mencionando el peso específico batido.
> Formato: **Estado** [Progreso/Estancado/Alerta] · **Análisis** · **Acción Recomendada**.

**Prompt de Selección Dinámica** (evolución del prompt de `GeneradorPlanIa`, que ya recibe perfil + medición + objetivo + catálogo):

> Actúa como fisiólogo del ejercicio. Genera la rutina según: somatotipo (ecto/meso/endomorfo), nivel (principiante/intermedio/avanzado) y equipo disponible. Principiantes: multiarticulares con alta frecuencia de control motor (12–15 reps). Avanzados: sobrecarga progresiva en rangos de hipertrofia (6–10) y técnicas de intensidad. Poco tiempo: full body de alta densidad. En déficit calórico: limitar aislamiento pesado para evitar fatiga excesiva.

**Prompt de validación para el entrenador** (gancho en el flujo de aprobación de planes existente):

> Antes de aprobar este plan verifica: ¿el volumen semanal total es seguro para el somatotipo del usuario? Si detectas riesgo de sobreentrenamiento, ajusta las series antes de notificar "Plan Aprobado".

### 18.5 — Viralidad Meta: "logros que venden" (visión, sin fase asignada)

Flujo: usuario bate un PR → la IA genera el insight de felicitación → se compone una imagen de logro (estética del tenant + dato dinámico: "Nuevo PR en press de banca: 80 kg") → Meta Graph API (`/{ig-user-id}/media`) la publica como IG Story con enlace a la app → lead nuevo. Dependencias: generador de imágenes (servicio externo o ERB→imagen propio), tokens Meta **por tenant**, y revisión de las políticas de la API de Meta (la publicación y los DMs automatizados del "funnel 24h" de §17.3 tienen riesgo de política/baneo — validar antes de construir).

### 18.6 — Auditoría externa del esquema: qué aplica y qué no (julio 2026)

Se recibió una auditoría externa del esquema; se contrastó contra el esquema real y las decisiones del SDD. Rastro:

| Sugerencia externa | Realidad | Veredicto |
|---|---|---|
| "`imc` con DEFAULT estático queda desfasado al corregir talla/peso" | `mediciones.imc` es **columna generada `STORED`** — Postgres la recalcula sola | No aplica |
| "Faltan índices compuestos `(user_id, fecha)`" | Ya existen en `mediciones`, `accesos` (`fecha_hora`) y `registros_calorias` | Ya resuelto |
| "Añadir `tenant_id` + Row Level Security" | Contradice §16.2: multi-instancia con base por tenant, row-level tenancy descartado. RLS solo se reconsideraría si algún día se consolida (Fase D) | Descartado |
| "`ejercicios` necesita `tenant_id` para catálogos privados" | Con base por tenant, cada gimnasio ya tiene su catálogo. "Ejercicios personalizados del gimnasio junto al dataset" queda como mejora futura | No aplica |
| "Migrar el JSON de `registros_entrenamiento` a tabla normalizada" | El JSON no tiene series/reps/pesos que migrar; se implementó `detalle_entrenamientos` como **feature nueva** (§18.1) | Aplicado, redefinido |
| "Conectar `pagos` a `suscripciones`" | Decisión deliberada del flujo presencial; se reevalúa si llega cobro online (§17.2) | Documentado |
| "Orquestar con n8n" | Fuera del stack; Solid Queue nativo (§18.3) | Adaptado |

### 18.7 — Fase 12: Analista de Performance v2 (implementado, julio 2026)

Rediseño tras la primera prueba real del flujo de la Fase 11-B:

- **Alcance del análisis**: ya no toma las últimas ~20 series globales del usuario; analiza la **sesión completa del día** (`registro.detalles`, todos los ejercicios) como unidad. El contexto de tendencia (progreso/estancamiento) se aporta aparte vía `HistorialEntrenamiento.resumen_semanal` (volumen por semana, últimas 4 semanas) — separado en el prompt de la sesión a analizar.
- **Captura simplificada (mobile-first)**: el dialog de registro de series ofrece un checkbox "Cumplido tal cual" (marcado por defecto) que registra de una sola vez las series planeadas del día con el objetivo del plan (`DetalleEntrenamiento.registrar_cumplido!`); al desmarcarlo aparecen los campos manuales de reps/peso/RPE para registrar una variación.
- **Solo staff dispara el análisis**: `DetalleEntrenamientoPolicy#analizar?` pasó de "dueño premium" a `user.staff?` — el miembro solo ve el resultado (lectura), nunca el botón. El staff analiza desde un panel en `admin/users/:id` (`registro_entrenamiento_id` explícito, no ligado a un ejercicio puntual).
- **Niveles de análisis (asignación manual por staff)**: `suscripciones.analisis_tier` (`mensual` gratis/default, `semanal`, `diario`) — sin pasarela nueva, el staff lo cambia desde `admin/suscripciones` al registrar el pago extra, igual que el resto de flujos de cobro presencial del proyecto. `User#puede_analizar?` aplica la ventana del tier (30/7/1 días) contra el último análisis completado.
- **Mínimo de datos**: `User#datos_suficientes_para_analisis?` exige al menos 3 semanas distintas con series registradas en las últimas 3 semanas — evita analizar con una sola sesión sin tendencia real.
- **Historial**: `ProgresoUsuario.para` expone `feedbacks_ia` (últimos 10 análisis completados); se muestra de solo lectura tanto en `/progreso` (miembro) como en la ficha de staff, vía el partial compartido `shared/historial_analisis`.
- **Trazabilidad**: `feedback_ia.origen` (`manual`/`automatico`, default `manual`) — hoy todo disparo es manual por staff; el campo queda reservado para un futuro disparador sin intervención humana.

### 18.8 — Fase 12.2: acceso VIP (implementado, julio 2026)

Membresías y suscripciones siempre se crean manualmente en recepción (SDD flujos B/D) y duran un período fijo (`Negocio.duracion_dias`, 30 días por defecto): al vencer, el miembro cae a acceso básico (sin las funciones que habilita la membresía/suscripción) hasta que el staff registre una renovación.

- **`users.vip`** (boolean, default `false`): flag asignado a mano por un **admin** (no un entrenador) desde `admin/users/:id`, mismo patrón de protección que `rol` — nunca se mass-asigna, y el checkbox pide una confirmación explícita (vía el `<dialog>` global de `confirmacion_controller.js`) antes de aplicarse, dado que otorga acceso gratuito indefinido.
- **Nunca vence**: `Membresia#activa?` y `Suscripcion#activa?` devuelven `true` para un usuario VIP sin importar el estado/fecha guardados; `Membresia.para_vencer` y `Suscripcion.para_vencer` excluyen a los usuarios VIP, así que `VencerMembresiasJob`/`VencerSuscripcionesJob` (diarios, `config/recurring.yml`) nunca los tocan.
- **`User#premium?`** es `true` para cualquier VIP, tenga o no una suscripción al plan Personalizado — desbloquea las mismas funciones que un premium pago (incluida la elegibilidad para el Analista de Performance, sujeta igual al mínimo de datos del §18.7).
- **Suscripciones con vencimiento real**: antes de esta fase una suscripción sin `fecha_fin` se consideraba indefinida y nunca vencía (comportamiento no documentado). Ahora `Suscripcion` fija `fecha_fin` a `fecha_inicio + Negocio.duracion_dias` por defecto si el staff no la especifica al crearla, y `VencerSuscripcionesJob` la expira igual que a una membresía — el único acceso verdaderamente indefinido es el VIP.
