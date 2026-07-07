# Advance Fitness

Aplicación web integral de gestión de gimnasio: membresías y control de accesos, seguimiento biométrico con estadísticas de progreso, calculadora nutricional (déficit / superávit calórico), planes personalizados generados con IA y comunidad (blog + novedades).

> Documento rector: [`advance-fitness-sdd.md`](./advance-fitness-sdd.md) (Software Design Document v2.0). Reglas del repo: [`CLAUDE.md`](./CLAUDE.md).

## Stack

| Tecnología | Versión | Rol |
|---|---|---|
| Ruby | 3.4.5 | Lenguaje |
| Rails | 8.1.3 | Framework full-stack (monolito server-rendered) |
| PostgreSQL | 17 | Base de datos única |
| Hotwire (Turbo + Stimulus) + importmap | — | Interactividad sin build de JS (sin Node) |
| Tailwind CSS | v4 | Estilos (binario standalone, tokens en `@theme`) |
| DaisyUI | 5 | Componentes UI CSS-only (vendored, sin Node) — tema `advance` |
| Auth nativa Rails 8 + Pundit | — | Autenticación y autorización por rol |
| Solid Queue / Cache / Cable | — | Jobs, cache y websockets sobre Postgres (sin Redis) |
| IA multi-proveedor (Gemini · Claude) | — | Generación de rutinas y planes nutricionales (`GenerarPlanJob`); proveedor por `IA_PROVEEDOR`, Gemini por defecto |
| Kamal 2 + Thruster | — | Despliegue (Docker) |

## Requisitos

Solo **Docker** y **dip** (`gem install dip`). No necesitas Ruby ni Postgres en tu máquina.

## Primeros pasos

```bash
git clone git@github.com:yvalenta/advance_fitness_app.git
cd advance_fitness_app
dip provision     # build + bundle install + db:prepare (dev y test)
dip rails s       # servidor en http://localhost:3000
```

## Comandos del día a día (dip)

| Comando | Descripción |
|---|---|
| `dip provision` | Levanta el entorno completo desde cero |
| `dip rails s` | Dev server en `http://localhost:3000` |
| `dip rails c` / `dip rails db:migrate` / `dip rails g …` | Cualquier comando Rails en el contenedor |
| `dip test` | Suite minitest (base de test propia) |
| `dip rubocop` | Lint (rubocop-rails-omakase) |
| `dip brakeman` | Análisis estático de seguridad |
| `dip psql` | Consola Postgres de desarrollo |
| `dip bash` | Shell dentro del contenedor web |

## Estructura

```
app/
├── controllers/       REST + namespaces admin/ y entrenador/
├── models/            user, membresia, pago, acceso, medicion…
├── policies/          Pundit (una por modelo)
├── services/          POROs puros: IMC, TDEE, somatotipo
├── jobs/              GenerarPlanJob (IA) · VencerMembresiasJob
├── views/             ERB + partials compartidos (shared/)
└── assets/tailwind/   application.css con los design tokens
```

## Roadmap (SDD §11)

| Fase | Nombre | Estado |
|---|---|---|
| 1 | Base Rails & Auth | ✅ Completa |
| 2 | Membresías & Accesos | ✅ Completa |
| 3 | Biometría & Progreso | Progreso ✅ · Biometría aplazada (nota SDD §11) |
| 4 | Nutrición & Objetivos | ✅ Completa |
| 5 | Planes & IA | ✅ Completa |
| 6 | Comunidad & Cierre | Pendiente |

## Marca

El logo (fisicoculturista vectorial monocromo) va en `app/assets/images/brand/` como `logo.svg` / `logo-white.svg` — ver SDD §06. Asset pendiente de agregarse.
