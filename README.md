# Advance Fitness

Aplicación web integral de gestión de gimnasio: membresías y control de accesos, seguimiento biométrico con estadísticas de progreso, calculadora nutricional (déficit / superávit calórico), planes personalizados generados con IA y catálogo visual de ejercicios.

> Documento rector: [`advance-fitness-sdd.md`](./advance-fitness-sdd.md) (Software Design Document v2.0). Reglas del repo: [`CLAUDE.md`](./CLAUDE.md).

---

## Stack

| Tecnología | Versión | Rol |
|---|---|---|
| **Ruby** | **4.0.5** | Lenguaje (imagen Docker `ruby:4.0.5-slim`) |
| **Rails** | **8.1.3** | Framework full-stack (monolito server-rendered) |
| **PostgreSQL** | 17 | Base de datos única (también para jobs, cache y cable) |
| **Hotwire** (Turbo + Stimulus) + importmap | — | Interactividad sin build de JS (sin Node) |
| **Propshaft** | — | Asset pipeline moderno (reemplaza Sprockets) |
| **Tailwind CSS** | v4.3.1 (gem tailwindcss-rails 4.6.0) | Estilos — binario standalone, tokens en `@theme` |
| **DaisyUI** | 5 | Componentes UI CSS-only (vendored, sin Node) — tema `advance` |
| **Auth nativa Rails 8** + Pundit 2.5.2 | — | Autenticación (bcrypt + sessions) y autorización por rol |
| **OmniAuth Google OAuth2** | ~1.2 | Login con Google (`/auth/google_oauth2`) |
| **Solid Queue / Cache / Cable** | 1.4.0 / 1.0.10 / 4.0.0 | Jobs, cache y websockets sobre Postgres (sin Redis) |
| **IA multi-proveedor** (Gemini · Claude) | — | `GenerarPlanJob` — gemini-2.5-flash-lite por defecto, fallback gemini-2.5-flash |
| **Faraday** | 2.14.3 | Cliente HTTP para los adaptadores de IA (`app/services/ia/`) |
| **Kamal** | 2.12.0 | Despliegue (Docker) |
| **Thruster** | — | Proxy HTTP con caché de assets + X-Sendfile |
| **Puma** | 8.0.2 | Servidor web |

### Variables de entorno clave (ver `.env.example`)

| Variable | Descripción |
|---|---|
| `IA_PROVEEDOR` | `gemini` (default) o `claude` |
| `GEMINI_API_KEY` | Clave Google AI Studio |
| `GEMINI_MODELO` | Modelo Gemini (default: `gemini-2.5-flash-lite`) |
| `GEMINI_MODELO_FALLBACK` | Modelo de respaldo (default: `gemini-2.5-flash`) |
| `ANTHROPIC_API_KEY` | Clave Anthropic para Claude |
| `GOOGLE_CLIENT_ID` / `GOOGLE_CLIENT_SECRET` | OAuth Google |

---

## Requisitos

Solo **Docker** y **dip** (`gem install dip`). No necesitas Ruby ni Postgres en tu máquina.  
El host puede correr Ruby 3.4.5 (solo para `dip`); la app vive en Ruby **4.0.5** dentro del contenedor.

---

## Primeros pasos

```bash
git clone git@github.com:yvalenta/advance_fitness_app.git
cd advance_fitness_app
cp .env.example .env          # editar claves reales
dip provision                 # build + bundle install + db:prepare (dev y test)
dip rails s                   # servidor en http://localhost:3000
```

---

## Comandos del día a día (dip)

| Comando | Descripción |
|---|---|
| `dip provision` | Levanta el entorno completo desde cero |
| `dip rails s` | Dev server en `http://localhost:3000` |
| `dip rails c` | Consola Rails en el contenedor |
| `dip rails db:migrate` | Ejecutar migraciones |
| `dip rails g …` | Generadores Rails |
| `dip test` | Suite minitest (Capybara + Selenium para system tests) |
| `dip rubocop` | Lint (rubocop-rails-omakase) |
| `dip brakeman` | Análisis estático de seguridad |
| `dip psql` | Consola Postgres de desarrollo |
| `dip bash` | Shell dentro del contenedor web |

---

## Estructura

```
app/
├── controllers/
│   ├── admin/                # checkins, mediciones, membresias, pagos,
│   │                         #   renovaciones, suscripciones, users
│   ├── entrenador/           # borradores, plantillas_comida, plantillas_ejercicio
│   ├── dashboard_controller.rb
│   ├── ejercicios_controller.rb
│   ├── gestion_comidas/dias/ejercicios/planes_controller.rb
│   ├── mediciones_controller.rb
│   ├── objetivos_controller.rb
│   ├── omniauth_sessions_controller.rb (Google OAuth)
│   ├── passwords_controller.rb
│   ├── perfiles_controller.rb
│   ├── planes_controller.rb
│   ├── planes_personalizados_controller.rb
│   ├── progresos_controller.rb
│   ├── registrations_controller.rb
│   ├── registros_calorias_controller.rb
│   ├── registros_entrenamiento_controller.rb
│   └── sessions_controller.rb
├── models/
│   ├── user.rb               # roles: admin / entrenador / miembro
│   ├── session.rb            # sesiones activas (auth nativa Rails 8)
│   ├── membresia.rb          # plan contratado + vencimiento
│   ├── pago.rb               # historial de pagos auditables
│   ├── acceso.rb             # check-ins con timestamp
│   ├── suscripcion.rb        # membresía ↔ plan
│   ├── plan.rb               # catálogo de planes del gimnasio
│   ├── plan_personalizado.rb # output del flujo de IA (JSONB)
│   ├── objetivo_nutricional.rb
│   ├── registro_caloria.rb
│   ├── registro_entrenamiento.rb
│   ├── medicion.rb           # antropometría (Fase 5.9)
│   ├── plantilla_comida.rb   # biblioteca del entrenador
│   ├── plantilla_ejercicio.rb
│   ├── ejercicio.rb          # catálogo de ejercicios (Fase 6.1)
│   └── current.rb            # CurrentAttributes (usuario autenticado)
├── policies/                 # Pundit — una policy por modelo
├── services/
│   ├── calculadora_tdee.rb   # TDEE, IMC, somatotipo
│   ├── objetivo_calorico.rb  # déficit/superávit calórico
│   ├── generador_plan_basico.rb
│   ├── generador_plan_ia.rb  # orquesta el proveedor IA activo
│   ├── grafica_svg.rb        # gráficas SVG server-rendered
│   ├── horario_acceso.rb
│   ├── mensaje_ia.rb
│   ├── negocio.rb            # config parametrizable del gimnasio
│   ├── ia/
│   │   ├── proveedor_gemini.rb  # adaptador Gemini (Faraday)
│   │   └── proveedor_claude.rb  # adaptador Claude (Faraday)
│   └── ejercicios/
│       ├── importador_dataset.rb  # importa el dataset MIT de ejercicios
│       └── media_cache.rb         # proxy con caché on-demand al volumen
├── jobs/
│   ├── generar_plan_job.rb      # genera plan con IA (Solid Queue)
│   └── vencer_membresias_job.rb # cron diario de vencimientos
├── views/
│   ├── layouts/               # application.html.erb
│   ├── shared/                # partials reutilizables
│   ├── dashboard/
│   ├── admin/
│   ├── entrenador/
│   ├── ejercicios/
│   ├── gestion_planes/
│   ├── mediciones/
│   ├── objetivos/
│   ├── perfiles/
│   ├── planes/ & planes_personalizados/
│   ├── progresos/
│   ├── registros_calorias/ & registros_entrenamiento/
│   └── sessions/ & registrations/ & passwords/
└── assets/
    └── tailwind/
        └── application.css    # design tokens (@theme), paleta de marca
```

---

## Dominio y base de datos

Las migraciones (en orden de creación) reflejan la evolución del proyecto:

| Migración | Tabla / cambio |
|---|---|
| `create_users` | Autenticación + perfil (rol, nombre, email) |
| `create_sessions` | Sesiones activas Rails 8 |
| `add_perfil_to_users` | Campos biométricos en users |
| `create_membresias` | Plan contratado + fechas |
| `create_pagos` | Historial de pagos |
| `create_accesos` | Check-ins |
| `create_objetivos_nutricionales` | Meta calórica del miembro |
| `create_registros_calorias` | Diario de alimentos |
| `create_planes` | Catálogo de planes del gimnasio |
| `create_suscripciones` | Relación miembro ↔ plan |
| `create_planes_personalizados` | Output IA (JSONB de rutina + comidas) |
| `create_plantillas_comida` | Biblioteca del entrenador |
| `add_generacion_a_planes_personalizados` | Metadata de generación IA |
| `create_plantillas_ejercicio` | Ejercicios plantilla del entrenador |
| `add_detalle_a_registros_calorias` | Desglose de macros |
| `create_mediciones` | Antropometría (Fase 5.9) |
| `create_registros_entrenamiento` | Seguimiento de entrenamientos |
| `add_anulacion_a_pagos` | Auditoría de anulaciones |
| `create_ejercicios` | Catálogo de ejercicios (Fase 6.1) |
| `add_ejercicio_a_plantillas_ejercicio` | FK opcional catálogo ↔ plantilla |

---

## Roadmap

| Fase | Nombre | Estado |
|---|---|---|
| **0** | Entorno de desarrollo (Docker + dip) | ✅ Completa |
| **1** | Base Rails 8 & Auth nativa + Google OAuth | ✅ Completa |
| **2** | Membresías, Pagos, Accesos & Panel admin | ✅ Completa |
| **3** | Biometría & Progreso | Progreso ✅ · Biometría aplazada (SDD §11) |
| **4** | Nutrición & Objetivos calóricos | ✅ Completa |
| **5** | Planes & IA | ✅ Completa |
| **5.6** | Editor de plan inline (entrenador + admin) con autosave | ✅ Completa |
| **5.7** | Fallos de IA observables + negocio parametrizable | ✅ Completa |
| **5.7b** | Editor de rutina inline + plantillas de ejercicios por músculo | ✅ Completa |
| **5.8** | Plan del miembro en vivo + edición de consumo + UX | ✅ Completa |
| **5.9** | Antropometría + plan básico con membresía + peso del miembro | ✅ Completa |
| **5.10** | Seguimiento de entrenamiento del miembro | ✅ Completa |
| **5.11** | Suscripción con membresía, plan sugerido editable, kcal y pagos auditables | ✅ Completa |
| **5.12** | Dev sobre Supabase + datos demo + pesos y rutina editables por el miembro | ✅ Completa |
| **5.13** | Fix de tildes, responsive de check-in y popup de resumen del miembro | ✅ Completa |
| **5.14** | Quita "IA" del copy de cara al negocio | ✅ Completa |
| **5.15** | Upgrade a Ruby 4.0.5 | ✅ Completa |
| **5.16** | Fix medición duplicada, validación de monto y popups | ✅ Completa |
| **5.17** | Kamal configurado para deploy + fix DATABASE_URL en multi-db | ✅ Completa |
| **6.1** | Catálogo de ejercicios — modelo, importador idempotente y rake | ✅ Completa |
| **6.2** | Media del catálogo por proxy con caché en el volumen | ✅ Completa |
| **6.x** | Integración del catálogo en el editor de rutina (UI + IA con catálogo cerrado) | 🔜 Próxima |
| **7** | Nutrición personalizada & Gustos alimentarios | Pendiente (SDD §11 nota 3) |
| **8** | Comunidad & Cierre | Pendiente |

---

## Historial de commits por fase

```
6fc7260  Fase 6.2: media del catálogo por proxy con caché en el volumen
c39820e  Fase 6.1: catálogo de ejercicios — modelo, importador idempotente y rake
fcfb6f1  Fase 5.17: configura Kamal para deploy desde la Mac y arregla DATABASE_URL en multi-db
f3a4d1a  Fase 5.16: fix medición duplicada, validación de monto y popups que filtran clicks
858288a  Fase 5.15: upgrade a Ruby 4.0.5
da2294d  Fase 5.14: quita "IA" del copy de cara al negocio
157a562  Fase 5.13: fix de tildes, responsive de check-in y popup de resumen del miembro
243d0e5  Fase 5.12: dev sobre Supabase + datos demo + pesos y rutina editables por el miembro
b62e511  Fase 5.11: suscripción con membresía, plan sugerido editable, kcal y pagos auditables
3ad308b  Fase 5.10: seguimiento de entrenamiento del miembro
4f0b55a  Fase 5.9: antropometría + plan básico con membresía + peso del miembro
45171ca  Fase 5.8: plan del miembro en vivo + edición de consumo + UX
081f81b  Fase 5.7b: editor de rutina inline + plantillas de ejercicios por músculo
950d242  Logo de marca (fisicoculturista SVG) + fallback IA a gemini-2.5-flash
3fff034  Fase 5.7: fallos de IA observables + config de negocio + reglas de acceso
9458763  Fase 5.6: editor de plan inline (entrenador + admin) con autosave
b0e14d0  SDD: Fase 6 — Nutrición personalizada & Gustos (definición completa)
3713654  IA: modelo Gemini por defecto → gemini-2.5-flash-lite (+ maxOutputTokens 16k)
7b52549  IA multi-proveedor: adaptadores Gemini (activo) y Claude en app/services/ia
e03127b  UI: drill-down en las gráficas de progreso (click → fuente de la métrica)
23d0fa8  UI: gráficas de progreso compactas, animadas e interactivas
88ac316  Progreso: gráficas SVG server-rendered (mitad adelantada de la Fase 3)
b192494  UI: plan nutricional interactivo (checklist + macros animados, Stimulus)
fed6171  Fase 5: planes, suscripciones y generación con IA
24cf730  UI: formulario de objetivo dinámico con vista previa en vivo (Stimulus)
47600d3  Fase 4: nutrición y objetivos calóricos (Fase 3 aplazada)
5f9101c  UI: rediseño visual completo con sistema de diseño de marca
915a2e7  Fase 2: membresías, pagos, accesos y panel admin
61d04c1  Fase 1: perfil y rol en users, Pundit, registro y UI DaisyUI
0f83765  Fase 1: login con Google (OmniAuth)
5dbd402  chore: ignorar artefactos locales de tooling
0d06127  docs: incorporar rails8_analysis.md y alinear SDD con sus recomendaciones
e595edd  docs: SDD v2.0 — transición del stack a Rails 8.1
4b236ba  Fase 1: autenticación nativa + dashboard raíz
60cdb15  Fase 0: entorno de desarrollo con dip + Docker Compose
c473bde  Fase 0: base Rails 8.1.3 (Propshaft, importmap, Tailwind v4, Solid stack, Kamal)
f63dd7a  Initial commit
```

---

## Marca

El logo (fisicoculturista vectorial monocromo) está en `app/assets/images/brand/` como `logo.svg` / `logo-white.svg` — ver SDD §06. La paleta de colores y los design tokens Tailwind v4 están documentados en `advance-fitness-sdd.md §06` y en `app/assets/tailwind/application.css`.

---

## Despliegue

El proyecto usa **Kamal 2** con configuración en `.kamal/`. Para producción se requiere un servidor con Docker, las variables de entorno de `.env.example` y el `RAILS_MASTER_KEY`. Ver [`investigacion_despliegue.md`](./investigacion_despliegue.md) para notas de infraestructura.
