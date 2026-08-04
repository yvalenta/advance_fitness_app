# Plan de Estabilización y Maduración — Advance Fitness App

> **Versión:** 1.0 · **Fecha:** 22-jul-2026 · **Base:** app v1.4.2, multi-tenant row-level (SDD §16.6)
> **Inspiración:** NomiCheck SDD v2.3 (`/Users/yonatan/Developer/resplandor/nomicheck/SDD.md`) — checklist con verificación real por ítem, suites de casos extremos, errores tipados, QA gates, auditoría inmutable, rate limiting, y documentación de causa raíz de cada bug.
> **Regla de oro (adoptada de NomiCheck §13):** ningún ítem se marca `[x]` sin evidencia concreta (test en verde, comando ejecutado, verificación en navegador/producción). "Debería funcionar" no cierra nada.

## Índice

- [Diagnóstico: dónde estamos](#diagnóstico-dónde-estamos)
- [Etapa 0 — Higiene inmediata (½ día)](#etapa-0--higiene-inmediata-½-día)
- [Etapa 1 — Blindaje multi-tenant (~1 semana)](#etapa-1--blindaje-multi-tenant-1-semana)
- [Etapa 2 — Hardening de seguridad (~2-3 días)](#etapa-2--hardening-de-seguridad-2-3-días)
- [Etapa 3 — Observabilidad y operación (~3-4 días)](#etapa-3--observabilidad-y-operación-3-4-días)
- [Etapa 4 — Deuda de tests y calidad (~1 semana)](#etapa-4--deuda-de-tests-y-calidad-1-semana)
- [Etapa 5 — Madurez de dominio (~1 semana, priorizable)](#etapa-5--madurez-de-dominio-1-semana-priorizable)
- [Resumen: etapas × esfuerzo × riesgo](#resumen-etapas--esfuerzo--riesgo)
- [Regla de cierre por etapa](#regla-de-cierre-por-etapa)

---

## Diagnóstico: dónde estamos

### Fortalezas (no rehacer, solo mantener)

| Área | Evidencia |
|---|---|
| CI completo | `.github/workflows/ci.yml`: brakeman + bundler-audit, importmap audit, rubocop, RSpec sobre Postgres |
| Cobertura alta | SimpleCov **90.83%** (`coverage/.last_run.json`, 20-jul-2026) |
| Dependencias vigiladas | `dependabot.yml` (bundler + actions, semanal) |
| Resiliencia al pooler Supabase | `retry_on ConnectionNotEstablished` en `ApplicationJob`, `idle_timeout: 60`, `PGCONNECT_TIMEOUT=10` (Nota 13 del SDD) |
| Jobs autosanantes | `LiberarPlanesEstancadosJob` / `LiberarFeedbacksEstancadosJob` cada 5 min (`config/recurring.yml`) |
| Secretos fuera de git | `.env` y `master.key` no trackeados; `.env.example` solo placeholders |
| Pagos auditables | Append-only con `anulado_en`/`anulado_por` (regla del repo) |
| Health check | `/up` con logs silenciados |

### Brechas (lo que este plan ataca)

| # | Brecha | Riesgo | Etapa |
|---|---|---|---|
| 1 | Aislamiento multi-tenant depende 100% de disciplina en Pundit Scopes; `tenant_id` solo en `users`/`posts`/`novedades`; spec de aislamiento cubre solo 2 modelos | **Fuga de datos entre gimnasios** — el riesgo #1 del negocio white-label | 1 |
| 2 | Sin rate limiting (login, registro, reset, endpoints que disparan IA) | Fuerza bruta de credenciales; costo de IA inflado por abuso | 2 |
| 3 | CSP desactivada (`config/initializers/content_security_policy.rb` comentado entero) | XSS sin segunda barrera | 2 |
| 4 | Sin error tracking ni logging estructurado | Los errores de producción solo se descubren cuando un usuario reporta | 3 |
| 5 | Posible `schema.rb` desincronizado (migración `20260722000000` vs schema en `2026_07_21_000001`) | `dip provision` desde cero puede crear un esquema distinto al de producción | 0 |
| 6 | Huecos de cobertura concretos: 14 policies, todo `app/services/ia/`, 3 controllers, 2 jobs, 0 system specs | Regresiones silenciosas justo en autorización y en el código que llama APIs pagas | 4 |
| 7 | Backups: confianza tácita en Supabase, sin restore verificado ni segunda copia | Pérdida de datos = pérdida del negocio | 3 |
| 8 | PWA inconsistente: manifest/service worker existen pero rutas y `<link>` comentados (contradice SDD §16.5 Fase A) | Confusión de estado; la app no es instalable aunque el SDD dice que sí | 0 |
| 9 | N+1 candidatos: solo 8 archivos usan `includes`; listados admin y `/progreso` sin revisar | Latencia creciente con más miembros/tenants sobre el pooler de 15 conexiones | 4 |
| 10 | Residuo minitest en `test/mailers/` | Ruido; confunde a quien llega al repo | 0 |
| 11 | Sin rastro de auditoría en acciones sensibles no-pago (cambio de rol, precios/paleta de tenant, publicar plan) | Imposible responder "¿quién cambió esto y cuándo?" con N tenants | 5 |
| 12 | Errores/estados de IA como strings sueltos (`error_generacion`, matching por substring en `MensajeIa`) | Frágil ante cambios de redacción; sin métricas por tipo de fallo | 5 |

---

## Etapa 0 — Higiene inmediata (½ día)

Objetivo: eliminar inconsistencias que contaminan todo lo demás.

### 0.1 Schema al día

- [ ] Correr `dip compose run --rm -e RAILS_ENV=test web bin/rails db:migrate:status` (entorno test = base local, seguro aunque `DEV_DATABASE_URL` apunte a Supabase — regla del CLAUDE.md).
- [ ] Si `20260722000000_change_users_email_index_to_tenant_scoped` figura aplicada pero `db/schema.rb` sigue en `2026_07_21_000001`: regenerar con `dip compose run --rm -e RAILS_ENV=test web bin/rails db:migrate` y commitear el `schema.rb` resultante.
- [ ] Verificar que el schema regenerado incluye `index_users_on_email_address_and_tenant_id` (único compuesto) y NO el viejo `index_users_on_email_address`.

**Cierre:** `db:migrate:status` sin filas `down`; `schema.rb` con la versión `2026_07_22_000000`; `dip test` en verde.

### 0.2 Residuo minitest

- [x] Revisión: `test/mailers/previews/passwords_mailer_preview.rb` **NO es residuo** — los mailer previews son convención de Rails (`ActionMailer::Preview`) independiente del framework de test; renderizan en `/rails/mailers/`. Se conserva. `test/fixtures/` también se conserva (RSpec las usa).

**Cierre:** sin cambios; la brecha #10 del diagnóstico no aplicaba.

### 0.3 Decisión PWA

El manifest (`app/views/pwa/manifest.json.erb`) ya está parametrizado desde `Negocio` (SDD §16.5 Fase A), pero las rutas (`config/routes.rb:111-112`) y el `<link rel="manifest">` (`app/views/layouts/application.html.erb:19`) están comentados. Los miembros ya agregan la app a inicio (la Fase 6.9 arregló los confirm de iOS justamente por eso).

- [x] **Habilitada.** Rutas + `<link>` descomentados; `spec/requests/pwa_spec.rb` como regresión.
- [x] `Negocio.theme_color` tenant-aware (primary de la paleta si es hex válido, defensa contra CSS injection); manifest y `<meta theme-color>` usan ese helper.
- [ ] Pendiente futuro (bloqueado por `ruby-vips` en producción, commit `75628c9`): variant del logo del tenant a 512×512 para el icono del manifest.

**Cierre:** habilitado y verificado con specs (9/9); pendiente cosmético del icono anotado.

---

## Etapa 1 — Blindaje multi-tenant (~1 semana)

Objetivo: que una fuga cross-tenant sea **estructuralmente improbable**, no solo improbable por disciplina. Patrón de NomiCheck §05: doble capa — la lógica vive en las policies, pero existe una red de seguridad independiente que atrapa el bug cuando la lógica falla.

### 1.1 Suite de aislamiento total (la red)

Hoy `spec/policies/aislamiento_cross_tenant_spec.rb` cubre 2 modelos. Ampliarla a **todo el dominio**:

- [x] Sembrar en el spec dos tenants completos (helper compartido, p. ej. `spec/support/dos_tenants.rb`): cada uno con admin, entrenador, miembro, membresía, pago, suscripción, medición, plan personalizado, registros (calorías/entrenamiento), objetivo, acceso, post y novedad.
- [x] Para cada modelo con datos por-usuario, un ejemplo que verifique que `policy_scope` (o la query del controller) del staff del tenant A **no devuelve ninguna fila** del tenant B: `Membresia`, `Pago`, `Acceso`, `Suscripcion`, `Medicion`, `PlanPersonalizado`, `RegistroCaloria`, `RegistroEntrenamiento`, `DetalleEntrenamiento`, `ObjetivoNutricional`, `FeedbackIa`, `Post`, `Novedad`.
- [x] Casos negativos de acción directa (no solo scope): el admin del tenant A intenta `show`/`update` sobre un registro del tenant B por ID → `Pundit::NotAuthorizedError` o 404.
- [x] Documentar en el spec qué modelos son **catálogo global a propósito** (`Plan`, `Ejercicio`, `PlantillaComida`, `PlantillaEjercicio` — SDD §16.6) para que nadie los "arregle" por error.

**Cierre:** un solo comando (`dip test spec/policies/aislamiento_cross_tenant_spec.rb`) prueba el aislamiento de todo el dominio; romper cualquier scope lo pone en rojo.
**Evidencia (commit `874f336`, agosto 2026):** `spec/policies/aislamiento_cross_tenant_spec.rb`, 13 ejemplos en verde con el helper `expect_aislado`; catálogos globales documentados en la cabecera del spec.

### 1.2 Specs de las 14 policies sin cobertura

- [x] Crear specs para: `AccesoPolicy`, `EjercicioPolicy`, `MedicionPolicy`, `ObjetivoNutricionalPolicy`, `PagoPolicy`, `PlanPolicy`, `PlanPersonalizadoPolicy`, `PlantillaComidaPolicy`, `PlantillaEjercicioPolicy`, `ProgresoPolicy`, `RegistroCaloriaPolicy`, `RegistroEntrenamientoPolicy`, `SuscripcionPolicy`, `ApplicationPolicy`.
- [x] Plantilla mínima por policy: miembro sobre lo propio ✓, miembro sobre lo ajeno ✗, staff del mismo tenant ✓, **staff de otro tenant ✗** (el caso negativo cross-tenant siempre presente).

**Cierre:** `dip test spec/policies` en verde; 21/21 policies con spec.
**Evidencia (commit `d6eba80`, agosto 2026):** 21 archivos en `spec/policies/` cubriendo las 20 policies de `app/policies/` + la suite de aislamiento; ninguna policy sin spec.

### 1.3 ADR: `tenant_id` desnormalizado en tablas de dinero

Hoy el aislamiento de `membresias`/`pagos`/`suscripciones` se deriva por join a `users`. Un `where` mal armado en un controller nuevo filtra dinero de otro gimnasio.

- [x] Escribir el ADR en el SDD (nueva nota en §16): **recomendación — agregar `tenant_id` a `membresias`, `pagos` y `suscripciones`**, backfilleado desde `user.tenant_id`, con FK + índice compuesto `(tenant_id, ...)` en las columnas líder de los listados admin. Las demás tablas siguen por join (su volumen y sensibilidad no lo justifican aún).
- [x] Migración + backfill idempotente (patrón `multi_tenant:migrar`).
- [x] Callback/validación que garantice coherencia `registro.tenant_id == registro.user.tenant_id`.
- [x] Actualizar los Pundit Scopes de esos 3 modelos para filtrar directo por `tenant_id` (sin join).
- [x] Si se decide NO desnormalizar: dejarlo escrito en el ADR con el porqué, y la suite 1.1 queda como única defensa declarada. → **se decidió SÍ desnormalizar** (SDD §16.7).

**Cierre:** ADR en el SDD; migración aplicada en test y producción; suite 1.1 sigue en verde.
**Evidencia (agosto 2026):** ADR en **SDD §16.7** con el criterio de cuándo desnormalizar. Migración `20260803000000_add_tenant_a_tablas_de_dinero` con backfill `UPDATE … WHERE tenant_id IS NULL` (idempotente) y `down` verificado con `db:rollback STEP=1` + re-migrate. Coherencia en el concern `TenantDesnormalizado` (`hereda_tenant_de`), con `spec/models/tenant_desnormalizado_spec.rb` (8 ejemplos: herencia, rechazo de `tenant_id` inyectado, fail-closed del scope). Scopes vía el nuevo `ApplicationPolicy::Scope#del_tenant_directo`; `Admin::SuscripcionesController#index` deja de armar el join a mano y pasa a `policy_scope`. **Pendiente:** aplicar la migración en producción en el próximo deploy.

### 1.4 Request specs por subdominio

Hoy solo existe `spec/requests/tenant_scoping_spec.rb`.

- [x] Request specs que peguen a rutas reales con `host:` de distintos subdominios: admin del tenant A logueado en el subdominio del tenant B → expulsado (`terminate_session` + redirect con el mensaje de `tenant_scoping.rb`); superadmin en subdominio comercial ✓; slug inexistente → 404.
- [x] Un request spec del flujo de registro: mismo email en dos tenants → ambos se crean (regresión del fix `9f48ffc`).

**Cierre:** `dip test spec/requests` en verde con ≥4 escenarios de subdominio.
**Evidencia (agosto 2026):** `spec/requests/aislamiento_por_subdominio_spec.rb`, 6 ejemplos — expulsión con sesión terminada de verdad (`Session` vacío, no solo el redirect), ruta admin inalcanzable, los 3 listados de dinero sin filas del tenant vecino, y el mismo correo registrado en dos tenants.
**Bug encontrado y corregido de paso:** los escenarios de "otro tenant" firmaban sesión **antes** de cambiar de `host!`. Como la cookie es host-only (§16.6), el request llegaba sin sesión y el redirect lo producía `request_authentication`, **no** `verificar_pertenencia_al_tenant`: el test pasaba aunque el guard no existiera. Se invirtió el orden (`host!` primero, que es además el escenario real que el guard ataja — la cookie robada o replicada) y se afirma el `flash[:alert]`, que es lo único que distingue las dos rutas. Corregido también en `spec/requests/tenant_scoping_spec.rb`.

---

## Etapa 2 — Hardening de seguridad (~2-3 días)

### 2.1 Rate limiting (rack-attack)

NomiCheck limita todos los endpoints con costo (30 req/min en cálculo, límites en extracción/chat). Aquí no hay ninguno.

- [ ] Agregar gem `rack-attack` + `config/initializers/rack_attack.rb`.
- [ ] Throttles: `POST /session` (por IP y por email, ~5/min), registro (~3/min por IP), `POST /passwords` reset (~3/min por IP), acciones que encolan `GenerarPlanJob`/regeneración (~5/h por usuario — protegen el gasto de IA).
- [ ] Safelist: `/up` y las IPs del túnel Cloudflare si hiciera falta (verificar que la IP real llega vía `CF-Connecting-IP`/`X-Forwarded-For` y configurar `Rack::Attack.throttle` sobre esa — detrás del túnel, `request.ip` puede ser siempre el del túnel y el throttle por IP castigaría a todos).
- [ ] Respuesta 429 con vista amigable en español.
- [ ] Spec de request que verifica el 429 tras exceder el límite.

**Cierre:** ráfaga de logins en dev devuelve 429; specs en verde; verificado en producción con `curl` tras deploy.

### 2.2 Content Security Policy

- [ ] Reactivar `config/initializers/content_security_policy.rb` en modo **report-only** primero.
- [ ] Directivas mínimas: `default-src 'self'`; `font-src` + `style-src` para `fonts.googleapis.com`/`fonts.gstatic.com`; `script-src 'self'` (importmap es local); `img-src 'self' data:` (+ host del `Negocio.logo_url` si es externo).
- [ ] El `<style>` inline del theming por tenant (`app/views/layouts/application.html.erb:39-52`) necesita nonce: usar `csp_meta_tag` + `content_security_policy_nonce_generator` y agregar `nonce: true` al tag, o mover la paleta a atributo `style` en `:root` vía helper. Elegir e implementar una.
- [ ] Navegar la app completa (dashboard, planes, blog, superadmin) con la consola abierta buscando violaciones; corregir; pasar de report-only a enforce.

**Cierre:** CSP en enforce en producción; cero violaciones en la consola en los flujos principales.

### 2.3 Headers y brakeman.ignore

- [ ] Verificar en producción (curl -I): `X-Frame-Options`/`frame-ancestors`, `X-Content-Type-Options`, `Referrer-Policy`. Agregar lo que falte en un initializer.
- [ ] Revisar `config/brakeman.ignore`: cada entrada debe tener su campo `note` explicando por qué es falso positivo; eliminar las que ya no apliquen.

**Cierre:** `dip brakeman` en verde; cada ignore justificado por escrito.

---

## Etapa 3 — Observabilidad y operación (~3-4 días)

Objetivo: enterarse de los errores antes que los usuarios, y poder recuperar el negocio ante pérdida de datos.

### 3.1 Error tracking

- [ ] Adoptar Sentry (`sentry-ruby` + `sentry-rails`) — o GlitchTip self-hosted en el homelab si se prefiere no depender de SaaS; misma gem cliente.
- [ ] Tags por evento: `tenant` (slug de `Current.tenant`), `job` (para Solid Queue), versión de la app (`Rails.application.config.x.version`).
- [ ] Verificar captura desde jobs (Solid Queue corre in-Puma: `SOLID_QUEUE_IN_PUMA=true` — confirmar que las excepciones de jobs reportan y no solo las web).
- [ ] Los rescates caseros de `ApplicationController` (`ConnectionNotEstablished`) deben reportar antes de renderizar la página estática.
- [ ] Provocar un error de prueba en producción y verlo llegar con el tag de tenant.

**Cierre:** error de prueba visible en el panel con tenant y versión; DSN por ENV, no en repo.

### 3.2 Logs con contexto

- [ ] `config.log_tags = [:request_id, ->(req) { req.subdomain }]` en producción — cada línea de log queda atribuible a tenant y request. (lograge es opcional; los tags resuelven el 80% con cero dependencias.)
- [ ] Documentar en `DEPLOY.md` cómo seguir logs por tenant (`kamal app logs -f | grep <slug>`).

**Cierre:** logs de producción muestran `[request_id] [subdominio]` en cada request.

### 3.3 Panel de jobs

- [ ] Agregar `mission_control-jobs` (gem oficial para Solid Queue), montada bajo autenticación de superadmin (constraint de rutas, no solo Pundit — es un engine).
- [ ] Verificar en producción: ver la cola, reintentar un job fallido manualmente.

**Cierre:** `/superadmin/jobs` (o ruta elegida) accesible solo para superadmin; un job fallido se reintenta desde la UI.

### 3.4 Backups verificados

La base es Supabase (plan actual: revisar retención de backups del proyecto). "El proveedor hace backups" no es una estrategia hasta que un restore se probó.

- [ ] Documentar en `DEPLOY.md`: qué retención da el plan actual de Supabase, cómo se dispara un restore, y cuánto se perdería (RPO) en el peor caso.
- [ ] **Prueba de restauración real**: bajar un backup (o `pg_dump` del pooler) y levantarlo en el Postgres local del compose; abrir la app contra esa copia y verificar datos.
- [ ] Segunda copia independiente: `pg_dump` programado (cron en el homelab, fuera del contenedor de la app) hacia disco local, diario, con rotación de ~14 días. Script en `script/backup_db.sh` + entrada de cron documentada.
- [ ] El dump debe excluir/incluir conscientemente los schemas compartidos con la landing (`auth.*`, `storage.*`, `perfiles` — Nota 13: no se tocan desde este repo).

**Cierre:** restore de prueba ejecutado y anotado con fecha en `DEPLOY.md`; dump diario corriendo (verificar que el archivo de hoy existe y abre).

### 3.5 Vigilancia de recurring jobs

`VencerMembresiasJob` a las 4am es negocio-crítico: si no corre, miembros vencidos siguen entrando.

- [ ] Mecanismo simple de heartbeat: cada job recurrente escribe `Rails.cache.write("heartbeat/<job>", Time.current)` al terminar; un endpoint o el propio `/up` extendido (o un chequeo en el panel superadmin) muestra la última corrida de cada uno.
- [ ] Alerta pasiva mínima: si un heartbeat tiene >26h, el panel lo marca en rojo (y Sentry recibe un evento).

**Cierre:** panel/endpoint muestra la última corrida de los 5 recurring; simular un atraso lo pinta en rojo.

---

## Etapa 4 — Deuda de tests y calidad (~1 semana, paralelizable con 2-3)

### 4.1 Specs de la capa de IA (hoy: cero)

`app/services/ia/proveedor_gemini.rb` y `proveedor_claude.rb` llaman APIs pagas y no tienen ningún spec.

- [ ] Crear `spec/services/ia/` con WebMock: respuesta feliz (JSON del plan parseado), respuesta malformada, 429/503 del proveedor (¿se propaga el error correcto que `GenerarPlanJob` sabe rescatar?), timeout.
- [ ] Spec del switch `ENV["IA_PROVEEDOR"]` en `GeneradorPlanIa`: elige el adaptador correcto y el fallback de modelo (Fase 5.7) funciona.

**Cierre:** `dip test spec/services/ia` en verde sin tocar la red (WebMock bloquea conexiones reales).

### 4.2 Huecos restantes de cobertura

- [ ] Services: `progreso_usuario`, `historial_entrenamiento`.
- [ ] Jobs: `activar_suscripciones_programadas_job` (la lógica de solape/programada de la Nota 6 no tiene red), `liberar_feedbacks_estancados_job`.
- [ ] Controllers: `planes_controller`, `admin/renovaciones_controller`, `landing/campanas_controller`.

**Cierre:** SimpleCov ≥ 92% y sin archivos de `app/` con 0% de cobertura.

### 4.3 System specs de los flujos de dinero (hoy: cero)

Capybara/Selenium ya están en el Gemfile sin usar. El equivalente al "verificado en navegador real" que NomiCheck exige por checklist.

- [ ] `spec/system/alta_suscripcion_spec.rb`: admin crea suscripción → membresía incluida + medición + plan sugerido aparecen.
- [ ] `spec/system/checkin_spec.rb`: check-in valida membresía activa; miembro vencido rechazado.
- [ ] `spec/system/publicar_plan_spec.rb`: entrenador edita comida (autosave) y publica; el plan queda visible para el miembro.
- [ ] Configurar el driver headless en el contenedor (`dip test` debe correrlos; si Selenium complica el compose, evaluar `cuprite`).

**Cierre:** 3 system specs en verde dentro de `dip test` y en CI.

### 4.4 Convención request specs

- [ ] Los specs de `spec/controllers/` actuales se quedan (funcionan); **todo spec nuevo de controller se escribe como request spec** en `spec/requests/`. Anotar la convención en CLAUDE.md (ya lo insinúa) y migrar oportunísticamente cuando se toque un controller.

**Cierre:** convención escrita; ningún spec nuevo entra en `spec/controllers/`.

### 4.5 Pase de N+1

- [ ] Con datos de `demo:sembrar`, navegar con log en debug: `admin/suscripciones`, `admin/membresias`, `admin/pagos`, `admin/users` (buscador), `/progreso`, `/mi_plan`, cola de borradores del entrenador. Anotar queries repetidas.
- [ ] Agregar `includes`/`preload` donde falte; considerar `strict_loading!` en los listados admin para que el N+1 futuro explote en dev en vez de degradar producción.
- [ ] Los conteos de las gráficas (`ProgresoUsuario`) revisados con `EXPLAIN` si algún índice falta.

**Cierre:** los listados admin ejecutan un número de queries constante (no proporcional a las filas mostradas), verificado en logs antes/después.

### 4.6 Suite de casos extremos del dominio

Inspiración directa de `casosExtremos.test.ts` de NomiCheck: los bordes donde el negocio se rompe en silencio.

- [ ] `spec/models/casos_extremos_spec.rb` (o distribuidos por modelo): membresía que vence exactamente hoy (¿entra el check-in?), suscripción `programada` cuya fecha llega el mismo día que la activa vence, plan personalizado con `comidas: []` o macros en 0 (división por cero en los porcentajes de `_plan.html.erb`), medición con pliegues/peso en los límites, `registro_caloria` con kcal 0 y negativa (¿validación?), usuario sin objetivo activo en cada vista que lo asume (regresión del guard nil de `_panel_analisis`).

**Cierre:** suite en verde; cada caso que falló al escribirse queda anotado como bug corregido (con su fix) en el SDD.

---

## Etapa 5 — Madurez de dominio (~1 semana, priorizable ítem a ítem)

Lo que NomiCheck hace bien y aquí todavía no existe. Cada ítem es independiente; se pueden tomar en cualquier orden o posponer.

### 5.1 Errores de IA tipados

Hoy `error_generacion` es texto libre y `MensajeIa.amistoso` matchea substrings (mismo problema que NomiCheck documentó: "el semáforo tuvo que matchear substrings").

- [ ] Catálogo de códigos estables (constantes o enum): `proveedor_saturado`, `respuesta_invalida`, `sin_antropometria`, `timeout`, `desconocido`… El job guarda `{codigo, detalle}` (jsonb o dos columnas) en vez de solo el string.
- [ ] `MensajeIa` traduce por código, no por substring; el detalle crudo queda para el staff/Sentry.
- [ ] Migración suave: el string existente se conserva; los códigos aplican a fallos nuevos.

**Cierre:** un fallo simulado de cada tipo muestra su mensaje amable correcto; specs por código.

### 5.2 Auditoría de acciones sensibles

Los pagos ya son append-only. Falta el rastro para el resto de acciones con poder, clave con N tenants (inspiración: auditoría inmutable de NomiCheck §15, adaptada — sin triggers, a nivel de aplicación que es donde Rails tiene el actor).

- [ ] Tabla `auditorias`: `user_id` (actor), `tenant_id`, `accion`, `auditable` (polimórfico), `cambios` jsonb (antes/después), `created_at`. **Sin** `updated_at` ni endpoints de edición: append-only.
- [ ] Registrar en: cambio de `users.rol`, cambios de `Tenant` (precios, paleta, activo), anulación de pagos, publicar/despublicar plan, alta de staff.
- [ ] Vista de solo lectura en superadmin (y por tenant para el admin, si se quiere).

**Cierre:** cambiar un rol deja fila de auditoría con antes/después; no existe ruta que edite o borre auditorías.

### 5.3 QA gate de datos

Validaciones post-operación que atrapan estados incoherentes antes de que el usuario los vea (patrón `ResultadoQA` de NomiCheck, versión mínima).

- [ ] Al publicar un plan: verificar que `kcal` declaradas vs suma de macros (P×4 + C×4 + G×9) cuadran dentro de ±10% por comida; si no, advertencia visible al staff antes de publicar (no bloqueo duro).
- [ ] Al registrar un pago: la membresía resultante no puede quedar con vencimiento en el pasado.
- [ ] Al aprobar plan IA: el validador de rutina (`Ejercicios::ValidadorRutina`) ya existe — confirmar que corre siempre y agregar spec si falta.

**Cierre:** sembrar un plan con macros descuadradas muestra la advertencia; specs de los 3 gates.

### 5.4 Disciplina de causa raíz

- [ ] Adoptar como norma (anotarla en CLAUDE.md): todo bug de producción se documenta en el SDD con el formato de la Nota 13 / las "Correcciones" de NomiCheck — síntoma, causa raíz, fix, y test de regresión que lo fija. Sin excepción, incluso los vergonzosos (NomiCheck documenta hasta un SDD que prometía código inexistente).

**Cierre:** la norma está escrita; el próximo bug de producción la estrena.

---

## Resumen: etapas × esfuerzo × riesgo

| Etapa | Esfuerzo | Riesgo que mitiga | ¿Bloquea a otras? |
|---|---|---|---|
| 0 — Higiene | ½ día | Esquema divergente, estado confuso | Sí — hacer primero |
| 1 — Blindaje multi-tenant | ~1 semana | **Fuga de datos entre gimnasios** (el riesgo del negocio) | No |
| 2 — Hardening | 2-3 días | Fuerza bruta, XSS, abuso del gasto de IA | No |
| 3 — Observabilidad | 3-4 días | Errores invisibles, pérdida de datos irrecuperable | No |
| 4 — Tests y calidad | ~1 semana | Regresiones silenciosas, latencia con más tenants | No (paralelizable) |
| 5 — Madurez de dominio | ~1 semana | Deuda estructural antes de escalar el white-label | No (ítem a ítem) |

Orden recomendado: **0 → 1 → 2 → 3 → 4 → 5**. Si hay que elegir una sola, es la 1: todo el pivote SaaS (§17 del SDD) descansa sobre la promesa de aislamiento.

---

## Regla de cierre por etapa

Una etapa se declara cerrada solo cuando:

1. `dip test` · `dip rubocop` · `dip brakeman` en verde (regla existente del repo).
2. El criterio de **Cierre** de cada ítem tiene su evidencia (test nombrado, comando ejecutado, captura o verificación en producción).
3. El SDD (`advance-fitness-sdd.md`) recibe una **Nota** nueva describiendo qué se hizo y qué decisiones se tomaron (formato de las Notas 6-13) — el SDD es el documento rector: primero se actualiza, luego se ejecuta lo que cambie el alcance.
4. Commit por etapa (o sub-etapa coherente), siguiendo la convención de commits por fase.
