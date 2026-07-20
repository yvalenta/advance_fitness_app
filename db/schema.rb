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

ActiveRecord::Schema[8.1].define(version: 2026_07_20_000000) do
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
  end

  create_table "action_text_rich_texts", force: :cascade do |t|
    t.text "body"
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.datetime "updated_at", null: false
    t.index ["record_type", "record_id", "name"], name: "index_action_text_rich_texts_uniqueness", unique: true
  end

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "detalle_entrenamientos", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "ejercicio_id", null: false
    t.text "notas"
    t.decimal "peso_kg", precision: 6, scale: 2
    t.bigint "registro_entrenamiento_id", null: false
    t.integer "repeticiones", null: false
    t.integer "rpe"
    t.integer "serie", null: false
    t.datetime "updated_at", null: false
    t.index ["ejercicio_id", "registro_entrenamiento_id"], name: "index_detalles_on_ejercicio_y_registro"
    t.index ["registro_entrenamiento_id", "ejercicio_id", "serie"], name: "index_detalles_unicos_por_serie", unique: true
  end

  create_table "ejercicios", force: :cascade do |t|
    t.string "atribucion", default: "© Gym visual", null: false
    t.string "categoria", null: false
    t.datetime "created_at", null: false
    t.string "dataset_id", null: false
    t.string "equipo"
    t.string "gif_ruta"
    t.string "imagen_ruta"
    t.jsonb "instrucciones", default: [], null: false
    t.string "musculo", null: false
    t.jsonb "musculos_secundarios", default: [], null: false
    t.string "nombre", null: false
    t.string "nombre_en", null: false
    t.string "nombre_normalizado", null: false
    t.string "objetivo"
    t.datetime "updated_at", null: false
    t.index ["dataset_id"], name: "index_ejercicios_on_dataset_id", unique: true
    t.index ["musculo"], name: "index_ejercicios_on_musculo"
    t.index ["nombre_normalizado"], name: "index_ejercicios_on_nombre_normalizado"
  end

  create_table "feedback_ia", force: :cascade do |t|
    t.text "accion_recomendada"
    t.text "analisis"
    t.datetime "created_at", null: false
    t.string "diagnostico"
    t.text "error"
    t.string "estado", default: "pendiente", null: false
    t.integer "intentos", default: 0, null: false
    t.string "modelo"
    t.string "origen", default: "manual", null: false
    t.bigint "registro_entrenamiento_id", null: false
    t.datetime "updated_at", null: false
    t.index ["registro_entrenamiento_id"], name: "index_feedback_ia_on_registro_entrenamiento_id", unique: true
  end

  create_table "mediciones", force: :cascade do |t|
    t.decimal "brazo_cm", precision: 5, scale: 1
    t.decimal "cadera_cm", precision: 5, scale: 1
    t.decimal "cintura_cm", precision: 5, scale: 1
    t.decimal "codo_cm", precision: 4, scale: 1
    t.datetime "created_at", null: false
    t.decimal "cuello_cm", precision: 5, scale: 1
    t.date "fecha", null: false
    t.decimal "grasa_pct", precision: 4, scale: 1
    t.virtual "imc", type: :decimal, precision: 4, scale: 1, as: "round((peso_kg / ((NULLIF(talla_cm, (0)::numeric) / 100.0) ^ (2)::numeric)), 1)", stored: true
    t.decimal "muneca_cm", precision: 4, scale: 1
    t.decimal "muslo_cm", precision: 5, scale: 1
    t.text "notas"
    t.decimal "pantorrilla_cm", precision: 5, scale: 1
    t.decimal "pecho_cm", precision: 5, scale: 1
    t.decimal "peso_kg", precision: 5, scale: 2
    t.decimal "pliegue_abdominal_mm", precision: 4, scale: 1
    t.decimal "pliegue_muslo_mm", precision: 4, scale: 1
    t.decimal "pliegue_subescapular_mm", precision: 4, scale: 1
    t.decimal "pliegue_suprailiaco_mm", precision: 4, scale: 1
    t.decimal "pliegue_tricipital_mm", precision: 4, scale: 1
    t.decimal "rodilla_cm", precision: 4, scale: 1
    t.decimal "talla_cm", precision: 5, scale: 1
    t.bigint "tomada_por_id"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["tomada_por_id"], name: "index_mediciones_on_tomada_por_id"
    t.index ["user_id", "fecha"], name: "index_mediciones_on_user_id_and_fecha", unique: true
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

  create_table "novedades", force: :cascade do |t|
    t.text "contenido", null: false
    t.datetime "created_at", null: false
    t.date "fecha_evento"
    t.boolean "publicado", default: false, null: false
    t.string "titulo", null: false
    t.datetime "updated_at", null: false
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
    t.datetime "anulado_en"
    t.bigint "anulado_por_id"
    t.datetime "created_at", null: false
    t.date "fecha_pago", null: false
    t.bigint "membresia_id", null: false
    t.string "metodo", null: false
    t.decimal "monto", precision: 10, null: false
    t.date "periodo_fin", null: false
    t.date "periodo_inicio", null: false
    t.bigint "registrado_por_id", null: false
    t.datetime "updated_at", null: false
    t.index ["anulado_por_id"], name: "index_pagos_on_anulado_por_id"
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
    t.text "error_generacion"
    t.string "estado", default: "borrador", null: false
    t.string "generado_por", default: "ia", null: false
    t.integer "intentos", default: 0, null: false
    t.string "modelo_generacion"
    t.jsonb "plan_nutricional", default: {}, null: false
    t.jsonb "rutina", default: {}, null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["aprobado_por_id"], name: "index_planes_personalizados_on_aprobado_por_id"
    t.index ["user_id", "estado"], name: "index_planes_personalizados_on_user_id_and_estado"
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

  create_table "plantillas_ejercicio", force: :cascade do |t|
    t.bigint "creado_por_id"
    t.datetime "created_at", null: false
    t.integer "descanso_seg", default: 60, null: false
    t.bigint "ejercicio_id"
    t.string "musculo", null: false
    t.string "nombre", null: false
    t.string "repeticiones", default: "10-12", null: false
    t.integer "series", default: 3, null: false
    t.datetime "updated_at", null: false
    t.index ["creado_por_id"], name: "index_plantillas_ejercicio_on_creado_por_id"
    t.index ["ejercicio_id"], name: "index_plantillas_ejercicio_on_ejercicio_id"
    t.index ["musculo", "nombre"], name: "index_plantillas_ejercicio_on_musculo_and_nombre", unique: true
  end

  create_table "posts", force: :cascade do |t|
    t.bigint "autor_id", null: false
    t.datetime "created_at", null: false
    t.boolean "publicado", default: false, null: false
    t.datetime "publicado_en"
    t.string "slug", null: false
    t.string "titulo", null: false
    t.datetime "updated_at", null: false
    t.index ["autor_id"], name: "index_posts_on_autor_id"
    t.index ["slug"], name: "index_posts_on_slug", unique: true
  end

  create_table "registros_calorias", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.jsonb "detalle", default: {}, null: false
    t.date "fecha", null: false
    t.integer "kcal_consumidas", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id", "fecha"], name: "index_registros_calorias_on_user_id_and_fecha", unique: true
  end

  create_table "registros_entrenamiento", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.jsonb "ejercicios", default: {}, null: false
    t.date "fecha", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id", "fecha"], name: "index_registros_entrenamiento_on_user_id_and_fecha", unique: true
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
    t.string "analisis_tier", default: "mensual", null: false
    t.datetime "created_at", null: false
    t.string "estado", default: "activa", null: false
    t.date "fecha_fin"
    t.date "fecha_inicio", null: false
    t.bigint "membresia_id"
    t.bigint "plan_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["membresia_id"], name: "index_suscripciones_on_membresia_id"
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
    t.boolean "vip", default: false, null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
    t.index ["rol"], name: "index_users_on_rol"
  end

  add_foreign_key "accesos", "users"
  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "detalle_entrenamientos", "ejercicios"
  add_foreign_key "detalle_entrenamientos", "registros_entrenamiento", on_delete: :cascade
  add_foreign_key "feedback_ia", "registros_entrenamiento", on_delete: :cascade
  add_foreign_key "mediciones", "users"
  add_foreign_key "mediciones", "users", column: "tomada_por_id"
  add_foreign_key "membresias", "users"
  add_foreign_key "objetivos_nutricionales", "users"
  add_foreign_key "pagos", "membresias"
  add_foreign_key "pagos", "users", column: "anulado_por_id"
  add_foreign_key "pagos", "users", column: "registrado_por_id"
  add_foreign_key "planes_personalizados", "users"
  add_foreign_key "planes_personalizados", "users", column: "aprobado_por_id"
  add_foreign_key "plantillas_comida", "users", column: "creado_por_id"
  add_foreign_key "plantillas_ejercicio", "ejercicios"
  add_foreign_key "plantillas_ejercicio", "users", column: "creado_por_id"
  add_foreign_key "posts", "users", column: "autor_id"
  add_foreign_key "registros_calorias", "users"
  add_foreign_key "registros_entrenamiento", "users"
  add_foreign_key "sessions", "users"
  add_foreign_key "suscripciones", "membresias"
  add_foreign_key "suscripciones", "planes"
  add_foreign_key "suscripciones", "users"
end
