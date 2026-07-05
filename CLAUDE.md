# Advance Fitness App — Reglas del repositorio

## Contexto del repositorio
- **Repositorio nuevo: se construye de cero.** No hay código heredado; todo lo que se agregue nace de este repo y de su SDD.
- Remoto: `git@github.com:yvalenta/advance_fitness_app.git` (origin, rama principal `main`).
- **Documento rector:** `advance-fitness-sdd.md` (v1.1). Toda decisión de alcance, entidades, seguridad o flujos se valida contra el SDD; si algo cambia, primero se actualiza el SDD.

## Proyectos de referencia (solo lectura)
Sirven para **adaptar funcionalidades innovadoras**, nunca para copiar código tal cual ni para modificarlos:
- Landing Advance Fitness: `/Users/yonatan/Developer/advance_fitness` (repo padre) — valida las versiones del stack y la convención `features/*/pages/*`.
- Resplandor POS: `/Users/yonatan/Developer/resplandor` — patrones de Supabase (RLS, JSONB, migraciones idempotentes) y formato de documentación.
- Cualquier funcionalidad adaptada se rediseña según las entidades y RLS de este proyecto antes de implementarse.

## Stack (decisión cerrada — SDD §12)
- React 19.2.7 · Vite 8 · TypeScript · Tailwind CSS v4 (`@theme` en `src/index.css`) · shadcn/ui · react-router-dom 7.
- Backend sin servidor propio: Supabase (Postgres, Auth, RLS, Edge Functions).
- IA: API de Claude solo desde Edge Functions (secreto server-side). **Sin LangChain.**

## Empaquetador
- **pnpm, siempre.** `pnpm install` / `pnpm add` / `pnpm dlx` (nunca npm, npx ni yarn).

## Convenciones de código
- Postgres: snake_case. TypeScript: camelCase para variables/funciones, PascalCase para componentes.
- Estructura por features (SDD §13): `src/features/{auth,onboarding,dashboard,biometria,nutricion,planes,comunidad,admin,entrenador}`.
- `src/lib/gym-data.ts` es la **única** capa de acceso a datos; ningún componente importa `supabase-js` directo.
- `src/services/` son funciones puras (IMC, TDEE, somatotipo) sin acceso a datos ni al DOM.
- Seguridad: toda tabla con RLS activado y sin policies para `anon`; los guards de rutas por rol son UX, no seguridad.
- UI y datos en español; moneda COP sin decimales; fechas formato `es-CO`.

## Comandos del proyecto
- Dev server: `pnpm dev`
- Build: `pnpm build` (tsc + vite)
- Lint: `pnpm lint` (oxlint)
- Preview: `pnpm preview`
- Supabase CLI: `pnpm dlx supabase <cmd>` (migraciones en `supabase/migrations/`, tipos con `gen types typescript`)
