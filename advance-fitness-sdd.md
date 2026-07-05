# Advance Fitness — Software Design Document · v1.1

> **Open Spec v1.1** · Aplicación web integral de gestión de gimnasio: membresías y accesos, biometría, nutrición, planes personalizados con IA y comunidad.
> Stack: React 19.2.7 + Vite + TypeScript + Tailwind CSS v4 + shadcn/ui + Supabase (Postgres · Auth · RLS · Edge Functions). Empaquetador: **pnpm**.

| Metadato | Valor |
|---|---|
| Versión | 1.1 — Open Spec (stack revisado: Alpine single-file → React 19.2.7) |
| Estado | Definición inicial |
| Repositorio | `git@github.com:yvalenta/advance_fitness_app.git` — nuevo, construido de cero |
| Stack | React 19.2.7 · Vite 8 · Tailwind v4 · shadcn/ui · Supabase |
| Empaquetador | pnpm (siempre) |
| Actualizado | Julio 2026 |
| Documento de referencia | Restaurante Resplandor POS — SDD v1.0 · Landing Advance Fitness (repo padre) |

---

## 01 — Introducción

### ¿Qué construimos?

**Advance Fitness** es una aplicación web para gestionar el ciclo completo de un gimnasio: alta y renovación de membresías, control de accesos y horarios, seguimiento biométrico con estadísticas de progreso, calculadora nutricional (déficit / superávit calórico), monetización por planes (Free vs. Personalizado) y una capa de comunidad (blog + novedades).

El sistema se construye como una **SPA React 19.2.7 + Vite** que compila a un bundle estático (sin servidor propio), desplegable en cualquier hosting estático — el mismo stack ya validado por la landing del proyecto (repo padre `advance_fitness`). Los estilos son Tailwind CSS v4 con componentes shadcn/ui; la persistencia, autenticación y seguridad viven en **Supabase** (Postgres + Auth + Row Level Security). Los flujos de IA (generación de rutinas y planes nutricionales) se ejecutan en **Supabase Edge Functions** que llaman a la API de Claude — nunca desde el cliente. El gestor de paquetes es **pnpm**, sin excepción.

> **Principio rector:** todo lo que se puede resolver en el cliente, se resuelve en el cliente; todo lo que requiere confianza (identidad, permisos, pagos, IA con API keys) se resuelve en Supabase. No existe — ni existirá en el MVP — un servidor propio que mantener.

---

## 02 — Alcance

### Qué entra y qué no

| En scope (MVP) | Out of scope (MVP) |
|---|---|
| Registro y login obligatorio (Supabase Auth, email + password) | App nativa iOS / Android |
| Perfil del miembro: datos básicos, fecha de ingreso, tiempo activo | Pasarela de pago online (Stripe / Wompi) — el pago se registra manualmente |
| Membresías: fechas de pago, vencimiento mensual, renovación | Facturación electrónica (DIAN) |
| Historial de reingresos y check-ins al gimnasio | Torniquete / hardware de control de acceso físico |
| Horarios de acceso por membresía | Multi-sede / multi-gimnasio |
| Calculadora biométrica: peso, edad, talla → IMC, estado de peso, propensión a sobrepeso, somatotipo | Wearables / integración con Apple Health o Google Fit |
| Gráficas de progreso mensual (peso, IMC) | Chat en vivo entrenador ↔ miembro |
| Tabla de calorías: consumo diario, déficit y superávit calórico (TDEE) | Marketplace de suplementos |
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
| Fecha de ingreso del usuario | `perfiles.fecha_ingreso`, se fija en el registro | `perfiles` |
| Fechas de pago | Historial en tabla de pagos, uno por período | `pagos` |
| Vencimiento mensual y renovación | `membresias.fecha_vencimiento`; renovar crea un pago y extiende la fecha | `membresias`, `pagos` |
| Historial de reingresos | Cada check-in se registra; un reingreso es un check-in tras membresía vencida y renovada | `accesos` |
| Control de tiempo activo ("hace cuánto entrena") | Calculado: `now() - perfiles.fecha_ingreso`, descontando períodos inactivos según `accesos` | `perfiles`, `accesos` |
| Horarios de acceso | `membresias.horario_acceso` (JSONB por día de semana); se valida en el check-in | `membresias` |

### Módulo B — Salud y Biometría

| Requerimiento | Solución | Entidad |
|---|---|---|
| Inputs básicos: peso, edad, talla | Formulario de medición; edad derivada de `perfiles.fecha_nacimiento` | `mediciones_biometricas` |
| Estado de peso actual (IMC / BMI) | Columna generada: `imc = peso_kg / (talla_cm/100)^2`, clasificada según rangos OMS | `mediciones_biometricas` |
| Indicador de propensión a sobrepeso | Regla en cliente: tendencia del IMC en las últimas 3 mediciones + somatotipo | Derivado |
| Identificación del somatotipo | Cuestionario guiado en onboarding → `ectomorfo` · `mesomorfo` · `endomorfo` | `perfiles.somatotipo` |
| Gráficas de progreso mensual | Serie temporal de `mediciones_biometricas` renderizada como SVG inline (sin librería de charts) | `mediciones_biometricas` |

Fórmulas estándar utilizadas (implementadas como funciones JS puras en la capa Services):

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

### Módulo D — Planes y Monetización

| Requerimiento | Solución | Entidad |
|---|---|---|
| Plan Free | Acceso a rutinas y guías básicas (contenido estático por objetivo: subir / bajar de peso) | `planes`, `suscripciones` |
| Upgrade a Plan Personalizado | Compra registrada por admin → Edge Function genera con IA una rutina + plan nutricional a partir de la biometría y el objetivo; el entrenador revisa y aprueba antes de publicarse al miembro | `planes_personalizados` |

### Módulo E — Comunidad y Retención

| Requerimiento | Solución | Entidad |
|---|---|---|
| Sección de Blog | Posts en Markdown creados por admin/entrenador, lectura para todo miembro autenticado | `posts_blog` |
| Panel de novedades | Anuncios cortos con fecha de evento (clases, horarios especiales, retos) | `novedades` |

---

## 04 — Stack tecnológico

El stack compila a un **bundle estático sin servidor propio**. Todo el control vive en el cliente y en la base de datos. Es exactamente el stack ya probado en la landing del proyecto (repo padre): mismas versiones resueltas en su `pnpm-lock.yaml`.

| Tecnología | Versión | Rol | Notas |
|---|---|---|---|
| React | 19.2.7 | UI declarativa | Misma versión ya validada en la landing |
| Vite | ^8.1 | Build y dev server | `@vitejs/plugin-react`, build estático a `dist/` |
| TypeScript | ~6.0 | Tipado | `tsc -b` en el build; tipos generados desde Supabase |
| Tailwind CSS | ^4.3 | Estilos | Plugin `@tailwindcss/vite`, tokens en `@theme` (CSS-first) |
| shadcn/ui + Radix | — | Componentes base | Button, Card, Tabs, Select, Dialog… copiados al repo |
| react-router-dom | ^7 | Routing | Rutas protegidas por sesión y rol |
| lucide-react | — | Iconografía | Ya usada en la landing |
| pnpm | — | **Empaquetador (obligatorio)** | `pnpm install` / `pnpm add` / `pnpm dlx`; nunca npm ni yarn |
| @supabase/supabase-js | ^2 | Cliente de datos | Sin peer dependencies — agnóstico al framework, compatible con React 19 |
| Supabase Postgres | — | Base de datos | Fuente de verdad única, snake_case |
| Supabase Auth | — | Autenticación | Email + password, login obligatorio, sesión JWT |
| Supabase RLS | — | Autorización | Policies por fila: cada miembro solo ve lo suyo |
| Supabase Edge Functions | — | Cómputo confiable | Flujos de IA (Claude API) y validaciones server-side |
| Claude API (`claude-sonnet-5`) | — | IA generativa | Rutinas y planes nutricionales estructurados (JSON) |
| SVG inline (componente React) | — | Gráficas de progreso | Sin librería de charts en el MVP |
| localStorage | — | Caché de arranque | Última copia de sesión; Supabase manda |

### ¿Por qué React y no el single-file de la landing?

La v1.0 de este documento proponía el enfoque single-file HTML + Alpine (estilo Resplandor POS). Se revisó por tres razones. Primera: la app tiene ~12 vistas, 3 roles con rutas protegidas, paneles de admin y entrenador, y formularios complejos — en un solo archivo eso supera las 4.000 líneas y se vuelve inmantenible; la landing sí puede ser simple, la app no. Segunda: la landing ya validó React 19.2.7 + Vite 8 + Tailwind v4 + shadcn en este mismo workspace, con lockfile resuelto y build funcionando — no hay riesgo de compatibilidad y se reutilizan componentes y convenciones. Tercera: `supabase-js` no tiene peer dependencies, así que la capa Supabase del diseño (Auth, RLS, Edge Functions) no cambia en absoluto con este reemplazo.

**Regla de oro:** el estado de servidor vive en Supabase y se lee vía hooks; el estado de UI vive en el componente. Si algo requiere secretos o confianza (API key de Claude, validación de compra), va a una Edge Function — nunca al cliente.

### ¿Por qué LangChain no?

El único flujo de IA del MVP es una llamada única y estructurada a Claude (biometría + objetivo → JSON de rutina y dieta). No hay cadenas multi-paso, ni RAG, ni memoria conversacional que justifiquen orquestación. Una Edge Function con `fetch` directo a la API de Claude es más simple, más barata y más fácil de depurar. Si en fases futuras aparece un coach conversacional, se reevalúa.

---

## 05 — Arquitectura

La aplicación es una **SPA por features**: cada módulo funcional (§03) es una carpeta bajo `src/features/` con sus páginas, componentes y hooks, más Supabase como plano de datos y seguridad.

| Capa | Responsabilidad | Implementación | Prohibido |
|---|---|---|---|
| Config | Design tokens, constantes (rangos IMC, factores de actividad) | `@theme` en `src/index.css` + `src/config/constants.ts` | Lógica de UI |
| UI | Componentes base reutilizables (Button, Card, Dialog, Tabs…) | `src/components/ui/` (shadcn/ui) | Llamadas a Supabase |
| Features | Páginas y componentes por módulo, estado de UI local | `src/features/{auth,membresias,biometria,nutricion,planes,comunidad,admin}` | Lógica de negocio inline |
| Hooks | Estado de servidor: sesión, perfil, mediciones, membresía, plan | `src/hooks/` (`useSession`, `usePerfil`, `useMediciones`…) sobre GymData | Renderizado |
| Services | Lógica de negocio pura: IMC, TDEE, déficit/superávit, formateo | `src/services/` — funciones TS puras, testeables sin DOM | Acceso a datos o al DOM |
| Data | Lecturas/escrituras vía `supabase-js`: `select`, `insert`, `update`, RPC | `src/lib/gym-data.ts` (wrapper único del cliente Supabase) | Lógica de presentación |
| Backend (BaaS) | Identidad, permisos por fila, triggers, IA | Supabase Auth · RLS · Edge Functions | Lógica de UI |

### Diagrama de alto nivel

```
┌────────────────────────────────┐      ┌─────────────────────────────────┐
│  SPA React 19 (bundle Vite)    │      │  Supabase                       │
│  ┌────────┐  ┌─────────────┐   │ JWT  │  ┌──────┐ ┌──────────────────┐  │
│  │Features│←→│ hooks +     │───┼─────→│  │ Auth │ │ Postgres + RLS   │  │
│  │+ ui    │  │ GymData     │   │      │  └──────┘ └──────────────────┘  │
│  └────────┘  │(supabase-js)│───┼─────→│  ┌──────────────────────────┐   │
│  ┌────────┐  └─────────────┘   │      │  │ Edge Fn: generar-plan    │───┼──→ Claude API
│  │Services│ (IMC/TDEE puras)   │      │  │ (service_role + secreto) │   │
│  └────────┘                    │      │  └──────────────────────────┘   │
└────────────────────────────────┘      └─────────────────────────────────┘
```

### Principios de diseño

| Principio | Detalle |
|---|---|
| Supabase es la fuente de verdad | Los hooks se hidratan desde Postgres al iniciar sesión; localStorage es solo caché de arranque. Nunca se decide un permiso en el cliente. |
| RLS como única frontera de seguridad | El cliente puede tener bugs; las policies no. Toda tabla tiene RLS activado y sin policy para `anon`. Las rutas protegidas por rol son UX, no seguridad. |
| Un solo punto de acceso a datos | Ningún componente importa `supabase-js` directo: todo pasa por `GymData` (`src/lib/gym-data.ts`). Cambiar una query es tocar un solo archivo. |
| Features como módulos | Cada módulo del §03 es una carpeta autocontenida bajo `src/features/`; lo compartido vive en `components/ui`, `hooks`, `services`, `lib`. |
| Cálculos derivados no se persisten | IMC se genera en Postgres (columna generada); TDEE, déficit y propensión se calculan en Services. Solo se guardan los inputs. |
| IA detrás de Edge Functions | La API key de Claude vive como secreto de la función. El cliente jamás llama a Claude directo. |
| Tipos desde la base | `pnpm dlx supabase gen types typescript` genera `src/lib/database.types.ts`; GymData queda tipado contra el schema real. |

---

## 06 — Sistema de diseño

### Marca

El logo de Advance Fitness es un **fisicoculturista vectorial monocromo** (pose de doble bíceps frontal, estilo stencil). Por ser monocromo invierte limpiamente a blanco para fondos oscuros.

| Asset | Ruta | Uso |
|---|---|---|
| `logo.svg` (ideal) o `logo.png` | `public/brand/` | Header/nav, pantalla de auth, pantalla de carga |
| `logo-white.svg` | `public/brand/` | Variante invertida para nav oscuro y footer |
| `favicon.svg` | `public/` | Favicon (recorte del torso) |

> El archivo fuente del logo lo aporta el cliente; queda pendiente de copiarse a `public/brand/`. Ningún componente lo embebe inline: siempre se referencia por ruta.

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
| Geist Variable (`@fontsource-variable/geist`) | Body / UI | Texto general, formularios, etiquetas — la misma de la landing |
| Space Grotesk | Display | Métricas grandes (peso, IMC, kcal), títulos de sección, números de progreso |

### Escala tipográfica

| Token | Tamaño | Peso | Uso |
|---|---|---|---|
| `text-display` | 2.8–3.4 rem | 700 | Métrica protagonista (peso actual, kcal restantes) |
| `text-h2` | 1.5 rem | 600 | Nombre de sección o pantalla |
| `text-h3` | 1.1 rem | 600 | Card header, título de post |
| `text-body` | 0.9375 rem (15px) | 400 | Texto general |
| `text-label` | 0.75 rem (12px) | 700 | Tags, estado de membresía, categorías |
| `text-micro` | 0.6875 rem (11px) | 700 | Metadatos, timestamps, ejes de gráficas |

### Design tokens — Tailwind v4 (`@theme` en `src/index.css`)

Tailwind v4 es CSS-first: los tokens se declaran en `@theme` y generan las utilidades (`bg-volt`, `text-steel-3`, `font-display`…). Conviven con las variables de shadcn/ui.

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
  --font-body:    "Geist Variable", sans-serif;
  --font-display: "Space Grotesk", sans-serif;
}
```

---

## 07 — Entidades del dominio

Schema de datos en **Supabase Postgres** (snake_case). Toda tabla tiene `id uuid primary key default gen_random_uuid()`, `creado_en timestamptz default now()` y **RLS activado**. Los datos anidados de forma natural (horarios, rutinas, dietas) se guardan como JSONB — misma convención del proyecto de referencia — para evitar joins innecesarios.

### `perfiles` — extiende `auth.users` (1:1)

| Columna | Tipo | Notas |
|---|---|---|
| `id` | `uuid` PK | FK → `auth.users.id`, creado por trigger al registrarse |
| `nombre` | `text` | Obligatorio |
| `fecha_nacimiento` | `date` | La edad se deriva, nunca se guarda |
| `sexo` | `text` | `'M'` · `'F'` — requerido por Mifflin-St Jeor |
| `talla_cm` | `numeric(5,1)` | Talla base; cada medición puede actualizarla |
| `fecha_ingreso` | `date` | Fecha de alta en el gimnasio |
| `somatotipo` | `text` | `'ectomorfo'` · `'mesomorfo'` · `'endomorfo'` · `null` |
| `nivel_actividad` | `numeric(2,1)` | Factor 1.2–1.9 para TDEE |
| `rol` | `text` | `'miembro'` · `'entrenador'` · `'admin'` — default `'miembro'` |

### `membresias`

| Columna | Tipo | Notas |
|---|---|---|
| `id` | `uuid` PK | — |
| `perfil_id` | `uuid` | FK → `perfiles.id` |
| `fecha_inicio` | `date` | Inicio del período vigente |
| `fecha_vencimiento` | `date` | Vencimiento mensual; renovar la extiende |
| `estado` | `text` | `'activa'` · `'vencida'` · `'suspendida'` (job diario la marca vencida) |
| `horario_acceso` | `jsonb` | `{ "lun": ["06:00","22:00"], … }` — validado en check-in |

### `pagos`

| Columna | Tipo | Notas |
|---|---|---|
| `id` | `uuid` PK | — |
| `membresia_id` | `uuid` | FK → `membresias.id` |
| `monto` | `numeric(10,0)` | COP, sin decimales |
| `fecha_pago` | `date` | Cuándo pagó |
| `periodo_inicio` | `date` | Período que cubre |
| `periodo_fin` | `date` | — |
| `metodo` | `text` | `'efectivo'` · `'transferencia'` · `'tarjeta'` |
| `registrado_por` | `uuid` | FK → `perfiles.id` (admin que registró) |

### `accesos` — check-ins e historial de reingresos

| Columna | Tipo | Notas |
|---|---|---|
| `id` | `uuid` PK | — |
| `perfil_id` | `uuid` | FK → `perfiles.id` |
| `fecha_hora` | `timestamptz` | Momento del check-in |
| `tipo` | `text` | `'checkin'` · `'reingreso'` (primer acceso tras renovar una membresía vencida) |
| `dentro_de_horario` | `boolean` | Resultado de validar contra `horario_acceso` |

### `mediciones_biometricas`

| Columna | Tipo | Notas |
|---|---|---|
| `id` | `uuid` PK | — |
| `perfil_id` | `uuid` | FK → `perfiles.id` |
| `fecha` | `date` | Una medición por fecha (unique `perfil_id + fecha`) |
| `peso_kg` | `numeric(5,2)` | Input |
| `talla_cm` | `numeric(5,1)` | Input (normalmente estable) |
| `imc` | `numeric(4,1)` | **Columna generada**: `peso_kg / (talla_cm/100)^2` |
| `grasa_pct` | `numeric(4,1)` | Opcional |
| `notas` | `text` | Opcional |

### `objetivos_nutricionales`

| Columna | Tipo | Notas |
|---|---|---|
| `id` | `uuid` PK | — |
| `perfil_id` | `uuid` | FK → `perfiles.id` |
| `tipo` | `text` | `'deficit'` · `'superavit'` · `'mantenimiento'` |
| `tdee_kcal` | `integer` | TDEE calculado al crear el objetivo (snapshot de inputs) |
| `objetivo_kcal` | `integer` | `deficit: tdee−500` · `superavit: tdee+300..500` |
| `activo` | `boolean` | Solo un objetivo activo por perfil |

### `registros_calorias`

| Columna | Tipo | Notas |
|---|---|---|
| `id` | `uuid` PK | — |
| `perfil_id` | `uuid` | FK → `perfiles.id` |
| `fecha` | `date` | Unique `perfil_id + fecha` |
| `kcal_consumidas` | `integer` | Input diario del miembro |

### `planes` — catálogo de monetización

| Columna | Tipo | Notas |
|---|---|---|
| `id` | `uuid` PK | — |
| `codigo` | `text` | `'free'` · `'personalizado'` — unique |
| `nombre` | `text` | Nombre comercial |
| `precio` | `numeric(10,0)` | COP; `0` para free |
| `beneficios` | `jsonb` | Lista de features mostrada en la pantalla de upgrade |

### `suscripciones`

| Columna | Tipo | Notas |
|---|---|---|
| `id` | `uuid` PK | — |
| `perfil_id` | `uuid` | FK → `perfiles.id` |
| `plan_id` | `uuid` | FK → `planes.id` |
| `estado` | `text` | `'activa'` · `'cancelada'` · `'expirada'` |
| `fecha_inicio` | `date` | — |
| `fecha_fin` | `date` | `null` para free |

### `planes_personalizados` — output del flujo de IA

| Columna | Tipo | Notas |
|---|---|---|
| `id` | `uuid` PK | — |
| `perfil_id` | `uuid` | FK → `perfiles.id` |
| `rutina` | `jsonb` | Días → ejercicios → series/reps, generado por IA |
| `plan_nutricional` | `jsonb` | Comidas → macros → kcal, generado por IA |
| `generado_por` | `text` | `'ia'` · `'entrenador'` |
| `estado` | `text` | `'borrador'` · `'aprobado'` — el miembro solo ve aprobados |
| `aprobado_por` | `uuid` | FK → `perfiles.id` (entrenador), `null` en borrador |

### `posts_blog`

| Columna | Tipo | Notas |
|---|---|---|
| `id` | `uuid` PK | — |
| `autor_id` | `uuid` | FK → `perfiles.id` |
| `titulo` | `text` | — |
| `slug` | `text` | Unique |
| `contenido_md` | `text` | Markdown renderizado en cliente |
| `publicado` | `boolean` | Los miembros solo ven publicados |
| `publicado_en` | `timestamptz` | — |

### `novedades`

| Columna | Tipo | Notas |
|---|---|---|
| `id` | `uuid` PK | — |
| `titulo` | `text` | — |
| `contenido` | `text` | Anuncio corto |
| `fecha_evento` | `date` | Fecha de la actividad (clase, reto, cierre) |
| `publicado` | `boolean` | — |

---

## 08 — Seguridad y autenticación

### Autenticación — Supabase Auth

| Regla | Detalle |
|---|---|
| Login obligatorio | No existe vista anónima más allá de la pantalla de login/registro. El rol `anon` no tiene ninguna policy en ninguna tabla. |
| Método | Email + password (Supabase Auth). Magic link como recuperación. |
| Sesión | JWT gestionado por `supabase-js`; auto-refresh activado. Al expirar sin refresh → redirect a login. |
| Alta de perfil | Trigger `on auth.users insert` crea la fila en `perfiles` con `rol = 'miembro'` y `fecha_ingreso = today()`. |
| Roles | `miembro` · `entrenador` · `admin` en `perfiles.rol`. El rol se lee vía la función SQL `rol_actual()` (`security definer`) dentro de las policies — nunca se confía en el cliente. |

### Autorización — Row Level Security

RLS activado en **todas** las tablas. Resumen de policies (`auth.uid()` = usuario autenticado):

| Tabla | SELECT | INSERT | UPDATE | DELETE |
|---|---|---|---|---|
| `perfiles` | propio, o staff* ve todos | trigger (nadie directo) | propio (campos de perfil), staff todos | nadie |
| `membresias` | propia, o staff todas | solo staff | solo staff | nadie |
| `pagos` | propios (vía membresía), o staff todos | solo staff | nadie | nadie |
| `accesos` | propios, o staff todos | staff, o propio (self check-in) | nadie | nadie |
| `mediciones_biometricas` | propias, o staff todas | propio | propia (mismo día) | propia (mismo día) |
| `objetivos_nutricionales` | propios, o staff | propio | propio | propio |
| `registros_calorias` | propios, o staff | propio | propio (mismo día) | propio (mismo día) |
| `planes` | todos los autenticados | solo admin | solo admin | solo admin |
| `suscripciones` | propia, o staff | solo staff | solo staff | nadie |
| `planes_personalizados` | propio **solo si `estado='aprobado'`**; staff todos | solo `service_role` (Edge Function) | solo staff (aprobar/editar) | solo staff |
| `posts_blog` | autenticados si `publicado`, staff todos | staff | staff | admin |
| `novedades` | autenticados si `publicado`, staff todas | staff | staff | admin |

\* *staff* = `rol_actual() in ('entrenador','admin')`. Los pagos y membresías son inmutables o de solo-staff a propósito: el historial financiero no se edita, se corrige con un registro nuevo.

### Secretos y Edge Functions

| Regla | Detalle |
|---|---|
| API key de Claude | Secreto de la Edge Function (`supabase secrets set`). Jamás en el HTML. |
| `service_role` | Solo dentro de Edge Functions. El cliente usa únicamente la publishable key. |
| Validación server-side | `generar-plan` verifica en la base (no en el request) que el perfil tenga suscripción `personalizado` activa antes de llamar a Claude. |

---

## 09 — Contrato de datos

No hay API HTTP propia. Las operaciones son llamadas de `supabase-js` envueltas en `GymData`, más una Edge Function. Se documentan con el mismo contrato que tendría un backend.

| Operación | Tipo | Descripción |
|---|---|---|
| `GymData.miPerfil()` | READ | `perfiles` + `membresias` + suscripción activa del usuario |
| `GymData.registrarMedicion({ peso_kg, talla_cm, grasa_pct? })` | ACTION | Inserta medición del día; el IMC lo genera Postgres |
| `GymData.misMediciones(rango)` | READ | Serie para las gráficas de progreso mensual |
| `GymData.registrarCalorias({ fecha, kcal })` | ACTION | Upsert del registro diario de calorías |
| `GymData.fijarObjetivo({ tipo })` | ACTION | Calcula TDEE en Services, desactiva el anterior, inserta el nuevo |
| `GymData.checkin(perfilId)` | ACTION | Valida membresía activa + horario; inserta en `accesos` con `tipo` correcto |
| `GymData.renovarMembresia({ perfilId, monto, metodo })` | ACTION (staff) | Inserta pago + extiende `fecha_vencimiento` (RPC transaccional) |
| `GymData.miPlanPersonalizado()` | READ | Último `planes_personalizados` con `estado='aprobado'` |
| `GymData.blog()` / `GymData.novedades()` | READ | Contenido publicado |
| `POST /functions/v1/generar-plan` | EDGE FN | Valida suscripción → arma prompt con biometría + objetivo + somatotipo → Claude API (JSON estructurado) → inserta `planes_personalizados` en `'borrador'` |
| `GymData.aprobarPlan(planId)` | ACTION (staff) | Entrenador revisa el borrador y lo pasa a `'aprobado'` |

> **Migración futura:** si algún flujo exige más cómputo (p. ej. reportes pesados), se agrega otra Edge Function con el mismo nombre de operación. Los componentes no cambian: solo la implementación dentro de `GymData`.

---

## 10 — Flujos principales

### Flujo A — Registro inicial de biometría (onboarding)

| Paso | Acción | Detalle |
|---|---|---|
| 1 | Crear cuenta | Email + password en Supabase Auth. El trigger crea `perfiles` con `fecha_ingreso = hoy`. |
| 2 | Completar perfil | Nombre, fecha de nacimiento, sexo, talla, nivel de actividad. |
| 3 | Cuestionario de somatotipo | 5 preguntas guiadas → clasifica ectomorfo / mesomorfo / endomorfo y lo guarda en el perfil. |
| 4 | Primera medición | Peso (talla precargada). Postgres genera el IMC; la app muestra el estado de peso (OMS) y el indicador de propensión a sobrepeso. |
| 5 | Fijar objetivo | El miembro elige bajar de peso / ganar masa / mantener. Services calcula TDEE y el objetivo kcal (déficit −500 o superávit +300..500). |
| 6 | Aterrizar en el dashboard | Métricas del día, plan free con guías según su objetivo, y CTA de upgrade. |

### Flujo B — Compra de plan personalizado (upgrade)

| Paso | Acción | Detalle |
|---|---|---|
| 1 | Ver oferta | El miembro abre "Mejorar plan": comparación Free vs. Personalizado desde `planes.beneficios`. |
| 2 | Pagar en recepción | MVP sin pasarela: el admin registra el pago y crea la `suscripcion` al plan personalizado. |
| 3 | Generar con IA | El cliente invoca la Edge Function `generar-plan`. Esta revalida la suscripción en la base, arma el prompt con biometría reciente, somatotipo, objetivo y restricciones, y pide a Claude un JSON de rutina semanal + plan nutricional. |
| 4 | Revisión del entrenador | El plan queda en `'borrador'`. El entrenador lo revisa en su panel, ajusta el JSONB si hace falta y lo aprueba. |
| 5 | Publicación | Al pasar a `'aprobado'`, la RLS lo hace visible para el miembro, que lo ve en "Mi plan" con rutina por día y comidas con macros. |

### Flujo C — Actualización de progreso mensual

| Paso | Acción | Detalle |
|---|---|---|
| 1 | Recordatorio | El dashboard marca "medición pendiente" si la última tiene más de 30 días. |
| 2 | Nueva medición | El miembro registra peso (y grasa % opcional). Se agrega el punto a la serie. |
| 3 | Ver progreso | Gráficas SVG de peso e IMC por mes; delta contra la medición anterior y contra la inicial. |
| 4 | Recalibrar | Si el objetivo sigue activo, Services recalcula TDEE con el peso nuevo y actualiza el objetivo kcal. |
| 5 | Señal al entrenador | Si el miembro es premium y su tendencia se aleja del objetivo 2 meses seguidos, el panel del entrenador lo destaca para regenerar el plan (repite Flujo B paso 3). |

### Flujo D — Check-in y control de acceso

| Paso | Acción | Detalle |
|---|---|---|
| 1 | Identificar | Recepción busca al miembro (nombre / documento) o el miembro se auto-identifica en la tablet de entrada. |
| 2 | Validar | `GymData.checkin()`: membresía `activa` + hora dentro de `horario_acceso`. Vencida → aviso de renovación; fuera de horario → se registra con `dentro_de_horario = false` y alerta. |
| 3 | Registrar | Inserta en `accesos`. Si es el primer acceso tras una renovación de membresía vencida, `tipo = 'reingreso'` — esto alimenta el historial de reingresos. |
| 4 | Renovar (si aplica) | El admin registra el pago; `renovarMembresia` extiende el vencimiento en una transacción. |

---

## 11 — Fases

| Fase | Nombre | Duración | Entregable | Criterio de aceptación |
|---|---|---|---|---|
| 1 | UI Kit & Auth | ~1 semana | Design tokens, componentes base, login/registro con Supabase Auth, trigger de perfiles | Puedo registrarme, iniciar sesión y ver mi perfil vacío; sin sesión no se ve nada |
| 2 | Membresías & Accesos | ~1.5 semanas | Schema + RLS de membresías/pagos/accesos, panel admin, check-in con validación de horario | El admin da de alta una membresía, registra un pago y el check-in valida estado y horario |
| 3 | Biometría & Progreso | ~1.5 semanas | Mediciones, IMC generado, somatotipo, gráficas SVG mensuales | Registro 3 mediciones y veo la gráfica con clasificación OMS y propensión correctas |
| 4 | Nutrición & Objetivos | ~1 semana | TDEE, objetivos déficit/superávit, registro diario de calorías | Al fijar "bajar de peso" veo mi objetivo kcal y el faltante del día se actualiza al registrar consumo |
| 5 | Planes & IA | ~1.5 semanas | Catálogo de planes, suscripciones, Edge Function `generar-plan`, panel de aprobación del entrenador | Un miembro premium recibe un plan generado por IA solo después de la aprobación del entrenador |
| 6 | Comunidad & Cierre | ~1 semana | Blog, novedades, pulido responsive, checklist MVP completo | Un miembro lee posts y novedades publicadas; todo el checklist §14 en verde |

---

## 12 — Decisiones fijas

Estas decisiones están cerradas. Reabrirlas durante el MVP genera deuda técnica sin retorno.

| Decisión | Valor | Por qué |
|---|---|---|
| Framework | React 19.2.7 + Vite 8 + TypeScript | Versión exacta ya validada por la landing; build estático sin servidor propio |
| Empaquetador | **pnpm — siempre** | Estándar del proyecto; nunca npm ni yarn (`pnpm dlx` en vez de npx) |
| Estilos | Tailwind CSS v4 + shadcn/ui | Tokens CSS-first en `@theme`; componentes accesibles (Radix) copiados al repo |
| Routing | react-router-dom 7 | Rutas protegidas por sesión y rol; ya usada en la landing |
| Backend | Supabase (Postgres + Auth + RLS + Edge Functions) | Elimina el servidor propio; la seguridad vive en la base |
| Autenticación | Email + password, login obligatorio | Sin policies para `anon`; datos de salud jamás públicos |
| Autorización | RLS por fila + `perfiles.rol` | El cliente nunca decide permisos |
| IA | Claude API vía Edge Function, salida JSON estructurada | API key protegida; humano (entrenador) aprueba antes de publicar |
| Orquestación IA | `fetch` directo, sin LangChain | Un solo paso de IA no justifica un framework de orquestación |
| Gráficas | SVG inline en un componente React propio | Cero dependencias de charts; suficiente para series mensuales |
| Fórmulas | OMS (IMC) + Mifflin-St Jeor (TMB/TDEE) | Estándares documentados y auditables |
| Datos anidados | JSONB (`horario_acceso`, `rutina`, `plan_nutricional`) | Misma forma que en memoria; evita joins innecesarios |
| IDs | `gen_random_uuid()` en Postgres | Nativo, consistente entre tablas |
| Moneda | COP — sin decimales | El gimnasio no maneja centavos |
| Idioma | UI y datos en español | Público objetivo local |

---

## 13 — Estructura del proyecto

Proyecto Vite + React scaffoldeado con `pnpm create vite` (template `react-ts`), organizado por features — la misma convención que ya usaba la landing (`features/*/pages/*`).

```
advance_fitness_app/
│
├── public/
│   ├── brand/                     ← logo.svg · logo-white.svg (§06 Marca)
│   └── favicon.svg
│
├── supabase/
│   ├── migrations/                ← schema, RLS policies, triggers, seed
│   └── functions/generar-plan/    ← Edge Function (Claude API)
│
├── src/
│   ├── main.tsx                   ← BrowserRouter + providers
│   ├── App.tsx                    ← rutas (públicas / miembro / staff)
│   ├── index.css                  ← @import tailwindcss + @theme (§06)
│   ├── config/constants.ts        ← rangos IMC, factores actividad, kcal
│   ├── lib/
│   │   ├── supabase.ts            ← createClient (URL + publishable key)
│   │   ├── database.types.ts      ← tipos generados desde el schema
│   │   └── gym-data.ts            ← GymData: única capa de acceso a datos
│   ├── services/                  ← imc.ts · tdee.ts · somatotipo.ts (puras)
│   ├── hooks/                     ← useSession · usePerfil · useMediciones…
│   ├── components/
│   │   ├── ui/                    ← shadcn/ui (Button, Card, Dialog, Tabs…)
│   │   └── layout/                ← AppLayout (nav + logo), RequireRole
│   └── features/
│       ├── auth/                  ← AuthPage (login/registro)
│       ├── onboarding/            ← perfil + somatotipo + 1ª medición
│       ├── dashboard/             ← métricas del día, kcal, avisos
│       ├── biometria/             ← MedicionForm, ProgresoChart, historial
│       ├── nutricion/             ← objetivo, CaloriasTracker
│       ├── planes/                ← PlanViewer, PlanComparador (upgrade)
│       ├── comunidad/             ← BlogList, PostView, NovedadesBoard
│       ├── admin/                 ← miembros, membresías, pagos, check-in
│       └── entrenador/            ← borradores de IA + aprobación
│
├── package.json                   ← scripts: dev · build · lint · preview
├── vite.config.ts                 ← @vitejs/plugin-react + @tailwindcss/vite
└── pnpm-lock.yaml                 ← pnpm, siempre
```

> **Principio de navegación:** react-router-dom 7. Rutas públicas: `/auth`. Rutas de miembro bajo `AppLayout` (redirect a `/auth` sin sesión). Rutas de staff bajo `RequireRole` (`/admin/*`, `/entrenador/*`) — el guard de rutas es UX; la protección real es la RLS.

---

## 14 — Componentes

Cada componente vive en su feature (§13); los datos entran por hooks y las acciones salen por `GymData`. Los primitivos de UI son shadcn/ui.

| Componente | Datos (hook) | Descripción | Fase |
|---|---|---|---|
| `AuthPage` | `useSession()` | Login / registro contra Supabase Auth, manejo de errores | F1 |
| `MembresiaCard` | `useMembresia()` | Estado (activa/vencida), vencimiento, días restantes, tiempo activo | F2 |
| `CheckinPanel` | `useBusquedaMiembros()` | Búsqueda de miembro + validación de horario + registro de acceso | F2 |
| `MedicionForm` | `useMediciones()` | Formulario de medición; muestra IMC y clasificación al guardar | F3 |
| `ProgresoChart` | `useMediciones(rango)` | Gráfica SVG de peso/IMC mensual con deltas | F3 |
| `SomatotipoQuiz` | estado local (`useState`) | Cuestionario de 5 pasos que clasifica el somatotipo | F3 |
| `CaloriasTracker` | `useObjetivoActivo()` | Kcal objetivo vs. consumidas del día, barra de progreso | F4 |
| `ObjetivoSelector` | `usePerfil()` | Elegir déficit / superávit / mantenimiento; muestra el TDEE calculado | F4 |
| `PlanComparador` | `usePlanes()` | Tabla Free vs. Personalizado desde `planes.beneficios` | F5 |
| `PlanViewer` | `useMiPlan()` | Render de la rutina (tabs por día) y plan nutricional (comidas + macros) | F5 |
| `AprobacionPanel` | `useBorradores()` | Panel del entrenador: revisar/editar JSONB del borrador de IA, aprobar | F5 |
| `BlogList` / `PostView` | `usePosts()` | Lista de posts publicados + render Markdown del contenido | F6 |
| `NovedadesBoard` | `useNovedades()` | Tarjetas de anuncios ordenadas por `fecha_evento` | F6 |
| `AdminTable` | props genéricas | Tabla genérica de administración (miembros, pagos, membresías) | F2 |

### Patrón de componente

```tsx
// src/features/biometria/components/MetricaPeso.tsx
import { useMediciones } from '@/hooks/use-mediciones'
import { clasificarIMC } from '@/services/imc'
import { ProgresoChart } from './ProgresoChart'

export function MetricaPeso() {
  const { ultima, serie } = useMediciones()
  if (!ultima) return null

  const clasificacion = clasificarIMC(ultima.imc)
  return (
    <section className="space-y-4">
      <div className="rounded-xl bg-card p-6 shadow-sm">
        <span className="text-label text-steel-3">Peso actual</span>
        <span className="font-display text-display">{ultima.peso_kg} kg</span>
        <span className={clasificacion === 'normal' ? 'text-volt-d' : 'text-pulse'}>
          {clasificacion}
        </span>
      </div>
      <ProgresoChart serie={serie} />
    </section>
  )
}
```

---

## 15 — Checklist MVP

El sistema está listo para uso real cuando todos estos puntos estén en verde.

| Funcional | Calidad y seguridad |
|---|---|
| Registro + login funcionan; sin sesión no se ve ningún dato | RLS activado en el 100% de las tablas; `anon` sin policies |
| El trigger crea el perfil con fecha de ingreso al registrarse | Un miembro no puede leer datos de otro (verificado con dos cuentas) |
| Renovar membresía registra el pago y extiende el vencimiento | La API key de Claude no aparece en ninguna parte del cliente |
| El check-in valida estado y horario, y clasifica reingresos | `generar-plan` rechaza perfiles sin suscripción premium |
| La medición calcula IMC, clasificación OMS y propensión | Responsive en móvil 375px, tablet y desktop |
| Las gráficas muestran el progreso mensual con deltas correctos | Sin errores en consola en Chrome / Safari |
| Déficit y superávit se calculan con Mifflin-St Jeor + factor de actividad | `pnpm build` y `pnpm lint` pasan sin errores; bundle inicial < 300 KB gzip |
| El plan free muestra guías según el objetivo elegido | El estado se rehidrata al recargar (localStorage → Supabase) |
| El plan IA solo es visible tras aprobación del entrenador | Fechas y moneda en formato es-CO |
| Blog y novedades muestran solo contenido publicado | El JSONB de rutina/dieta valida su forma antes de guardarse |

> **Siguiente paso recomendado:** construir la Fase 1 (UI Kit & Auth): scaffolding con `pnpm create vite` (react-ts) + Tailwind v4 + shadcn/ui siguiendo la estructura del §13, tokens `@theme` del §06, logo en `public/brand/`, y el flujo de login/registro contra Supabase. Validar autenticación y RLS con dos cuentas reales antes de añadir lógica de negocio.
