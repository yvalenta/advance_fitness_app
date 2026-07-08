# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_07_07_200001) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "accesos", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.boolean "dentro_de_horario", default: true, null: false
    t.datetime "fecha_hora", null: false
    t.string "tipo", default: "checkin", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id", "fecha_hora"], name: "index_accesos_on_user_id_and_fecha_hora"
    t.index ["user_id"], name: "index_accesos_on_user_id"
  end

  create_table "membresias", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "estado", default: "activa", null: false
    t.date "fecha_inicio", null: false
    t.date "fecha_vencimiento", null: false
    t.jsonb "horario_acceso"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["estado"], name: "index_membresias_on_estado"
    t.index ["user_id"], name: "index_membresias_on_user_id", unique: true
  end

  create_table "objetivos_nutricionales", force: :cascade do |t|
    t.boolean "activo", default: true, null: false
    t.datetime "created_at", null: false
    t.integer "objetivo_kcal", null: false
    t.decimal "peso_kg", precision: 5, scale: 2, null: false
    t.integer "tdee_kcal", null: false
    t.string "tipo", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_objetivos_nutricionales_on_user_id"
    t.index ["user_id"], name: "index_objetivos_nutricionales_un_activo_por_user", unique: true, where: "activo"
  end

  create_table "pagos", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.date "fecha_pago", null: false
    t.bigint "membresia_id", null: false
    t.string "metodo", null: false
    t.decimal "monto", precision: 10, null: false
    t.date "periodo_fin", null: false
    t.date "periodo_inicio", null: false
    t.bigint "registrado_por_id", null: false
    t.datetime "updated_at", null: false
    t.index ["membresia_id"], name: "index_pagos_on_membresia_id"
    t.index ["registrado_por_id"], name: "index_pagos_on_registrado_por_id"
  end

  create_table "planes", force: :cascade do |t|
    t.jsonb "beneficios", default: [], null: false
    t.string "codigo", null: false
    t.datetime "created_at", null: false
    t.string "nombre", null: false
    t.decimal "precio", precision: 10, default: "0", null: false
    t.datetime "updated_at", null: false
    t.index ["codigo"], name: "index_planes_on_codigo", unique: true
  end

  create_table "planes_personalizados", force: :cascade do |t|
    t.bigint "aprobado_por_id"
    t.datetime "created_at", null: false
    t.string "estado", default: "borrador", null: false
    t.string "generado_por", default: "ia", null: false
    t.jsonb "plan_nutricional", default: {}, null: false
    t.jsonb "rutina", default: {}, null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["aprobado_por_id"], name: "index_planes_personalizados_on_aprobado_por_id"
    t.index ["user_id", "estado"], name: "index_planes_personalizados_on_user_id_and_estado"
    t.index ["user_id"], name: "index_planes_personalizados_on_user_id"
  end

  create_table "plantillas_comida", force: :cascade do |t|
    t.decimal "carbohidratos_g", precision: 5, scale: 1, default: "0.0", null: false
    t.bigint "creado_por_id"
    t.datetime "created_at", null: false
    t.text "descripcion", null: false
    t.decimal "grasas_g", precision: 5, scale: 1, default: "0.0", null: false
    t.integer "kcal", null: false
    t.string "nombre", null: false
    t.decimal "proteinas_g", precision: 5, scale: 1, default: "0.0", null: false
    t.string "tipo", null: false
    t.datetime "updated_at", null: false
    t.index ["creado_por_id"], name: "index_plantillas_comida_on_creado_por_id"
    t.index ["tipo", "nombre"], name: "index_plantillas_comida_on_tipo_and_nombre", unique: true
  end

  create_table "registros_calorias", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.date "fecha", null: false
    t.integer "kcal_consumidas", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id", "fecha"], name: "index_registros_calorias_on_user_id_and_fecha", unique: true
    t.index ["user_id"], name: "index_registros_calorias_on_user_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "suscripciones", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "estado", default: "activa", null: false
    t.date "fecha_fin"
    t.date "fecha_inicio", null: false
    t.bigint "plan_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["plan_id"], name: "index_suscripciones_on_plan_id"
    t.index ["user_id"], name: "index_suscripciones_on_user_id"
    t.index ["user_id"], name: "index_suscripciones_una_activa_por_user", unique: true, where: "((estado)::text = 'activa'::text)"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email_address", null: false
    t.date "fecha_ingreso", default: -> { "CURRENT_DATE" }, null: false
    t.date "fecha_nacimiento"
    t.decimal "nivel_actividad", precision: 2, scale: 1
    t.string "nombre", default: "", null: false
    t.string "password_digest", null: false
    t.string "rol", default: "miembro", null: false
    t.string "sexo"
    t.string "somatotipo"
    t.decimal "talla_cm", precision: 5, scale: 1
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
    t.index ["rol"], name: "index_users_on_rol"
  end

  add_foreign_key "accesos", "users"
  add_foreign_key "membresias", "users"
  add_foreign_key "objetivos_nutricionales", "users"
  add_foreign_key "pagos", "membresias"
  add_foreign_key "pagos", "users", column: "registrado_por_id"
  add_foreign_key "planes_personalizados", "users"
  add_foreign_key "planes_personalizados", "users", column: "aprobado_por_id"
  add_foreign_key "plantillas_comida", "users", column: "creado_por_id"
  add_foreign_key "registros_calorias", "users"
  add_foreign_key "sessions", "users"
  add_foreign_key "suscripciones", "planes"
  add_foreign_key "suscripciones", "users"
end
