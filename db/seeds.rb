# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

# Admin inicial (idempotente). En producción cambia la contraseña de
# inmediato o crea el admin real y elimina este.
admin = User.find_or_create_by!(email_address: "admin@advancefitness.local") do |user|
  user.nombre = "Administrador"
  user.rol = "admin"
  user.password = ENV.fetch("SEED_ADMIN_PASSWORD", "cambiame-ya-123")
end
admin.update!(rol: "admin") unless admin.admin?

# Promueve a admin un correo existente (útil para tu usuario de Google):
#   ADMIN_EMAIL=tu@correo.com bin/rails db:seed
if ENV["ADMIN_EMAIL"].present?
  User.find_by(email_address: ENV["ADMIN_EMAIL"])&.update!(rol: "admin")
end

# Catálogo de planes (SDD §07 — monetización). Idempotente; los precios se
# sincronizan desde la config del negocio en cada corrida (update! no solo create).
Plan.find_or_initialize_by(codigo: "free").update!(
  nombre: "Free",
  precio: 0,
  beneficios: [
    "Control de membresía y check-in",
    "Objetivo calórico y registro diario",
    "Guías generales según tu meta",
    "Acceso al blog y novedades"
  ]
)

Plan.find_or_initialize_by(codigo: "personalizado").update!(
  nombre: "Personalizado",
  precio: Negocio.precio_personalizado,
  beneficios: [
    "Rutina de fuerza generada con IA para tu perfil",
    "Plan nutricional con comidas y macros",
    "Revisado y aprobado por tu entrenador",
    "No pagas mensualidad de gimnasio mientras esté activo",
    "Recalibración cuando cambia tu objetivo"
  ]
)

# Plantillas de comidas para el editor de planes del entrenador (SDD §07,
# Fase 5.5). Base curada con alimentos colombianos; crece con el uso.
# [tipo, nombre, descripcion, kcal, proteinas_g, carbohidratos_g, grasas_g]
[
  [ "desayuno", "Huevos con arepa", "2 huevos revueltos con tomate y cebolla, 1 arepa de maíz mediana y 1 taza de café con leche descremada.", 420, 22, 42, 18 ],
  [ "desayuno", "Avena con proteína", "1 taza de avena cocida con 1 scoop de proteína whey, 1 banano y 1 cucharada de mantequilla de maní.", 550, 35, 70, 15 ],
  [ "desayuno", "Calentado ligero", "1 taza de calentado de fríjoles con arroz, 1 huevo frito con poco aceite y jugo de naranja natural sin azúcar.", 480, 20, 65, 14 ],
  [ "desayuno", "Tostadas con aguacate", "2 tostadas integrales con 1/2 aguacate, 2 huevos cocidos y 1 taza de café negro.", 450, 20, 38, 24 ],
  [ "desayuno", "Yogur con granola", "1 vaso de yogur griego natural con 1/2 taza de granola, fresas y una cucharadita de miel.", 380, 22, 45, 12 ],
  [ "almuerzo", "Pollo con arroz integral", "Pechuga de pollo a la plancha (180 g), 1 taza de arroz integral, ensalada mixta con 1/4 de aguacate.", 650, 45, 75, 20 ],
  [ "almuerzo", "Bandeja fit", "Carne magra asada (150 g), 1/2 taza de fríjoles, 1/2 taza de arroz, 1 tajada de plátano al horno y ensalada.", 700, 42, 80, 22 ],
  [ "almuerzo", "Pescado con patacón", "Filete de tilapia al horno (180 g), 1 patacón grande, arroz con coco (1/2 taza) y ensalada de repollo.", 620, 40, 68, 20 ],
  [ "almuerzo", "Lentejas con pollo", "1 taza de lentejas guisadas, pechuga desmechada (120 g), 1/2 taza de arroz y aguacate (1/4).", 600, 45, 70, 15 ],
  [ "almuerzo", "Pasta con atún", "2 tazas de pasta integral con atún en agua (1 lata), tomate, espinaca y un chorrito de aceite de oliva.", 580, 38, 78, 12 ],
  [ "cena", "Salmón con camote", "Salmón al horno (150 g), 1 camote mediano asado y brócoli al vapor.", 500, 35, 40, 22 ],
  [ "cena", "Omelette de claras", "Omelette de 4 claras y 1 huevo con champiñones y espinaca, 1 tostada integral.", 320, 28, 20, 14 ],
  [ "cena", "Pollo salteado con verduras", "Tiras de pechuga (150 g) salteadas con pimentón, zucchini y cebolla; 1/2 taza de quinua.", 450, 40, 42, 12 ],
  [ "cena", "Crema de ahuyama con pollo", "1 tazón de crema de ahuyama sin crema de leche, pechuga a la plancha (120 g) y ensalada verde.", 380, 35, 30, 12 ],
  [ "cena", "Wrap ligero", "1 tortilla integral con pollo desmechado (100 g), lechuga, tomate y yogur natural como aderezo.", 400, 32, 38, 12 ],
  [ "snack", "Yogur con frutos rojos", "1 porción de yogur griego natural (200 g) con 1/2 taza de frutos rojos y almendras (30 g).", 300, 20, 25, 12 ],
  [ "snack", "Huevos y manzana", "2 huevos cocidos y 1 manzana.", 200, 12, 20, 10 ],
  [ "snack", "Batido de proteína", "1 scoop de proteína whey con agua o leche descremada y 1 banano pequeño.", 250, 27, 28, 3 ],
  [ "snack", "Mix de frutos secos", "Un puñado de maní y almendras sin sal (40 g) con 1 mandarina.", 280, 10, 18, 20 ],
  [ "snack", "Queso con galletas", "2 tajadas de queso campesino bajo en grasa con 4 galletas integrales.", 220, 14, 20, 9 ]
].each do |tipo, nombre, descripcion, kcal, proteinas, carbohidratos, grasas|
  PlantillaComida.find_or_create_by!(tipo: tipo, nombre: nombre) do |plantilla|
    plantilla.descripcion = descripcion
    plantilla.kcal = kcal
    plantilla.proteinas_g = proteinas
    plantilla.carbohidratos_g = carbohidratos
    plantilla.grasas_g = grasas
  end
end

# Plantillas de ejercicios para el editor de rutina (SDD Fase 5.7b). Fuerza,
# agrupadas por músculo; "otro" para individuales sin categoría.
# [musculo, nombre, series, repeticiones, descanso_seg]
[
  [ "pecho", "Press de banca con barra", 4, "8-10", 90 ],
  [ "pecho", "Press inclinado con mancuernas", 3, "10-12", 75 ],
  [ "pecho", "Aperturas con mancuernas", 3, "12-15", 60 ],
  [ "pecho", "Fondos en paralelas", 3, "8-12", 75 ],
  [ "espalda", "Dominadas", 4, "6-10", 90 ],
  [ "espalda", "Remo con barra", 4, "8-10", 90 ],
  [ "espalda", "Jalón al pecho en polea", 3, "10-12", 75 ],
  [ "espalda", "Remo con mancuerna a una mano", 3, "10-12", 60 ],
  [ "pierna", "Sentadilla con barra", 4, "8-10", 120 ],
  [ "pierna", "Prensa de piernas", 4, "10-12", 90 ],
  [ "pierna", "Zancadas con mancuernas", 3, "10-12", 75 ],
  [ "pierna", "Peso muerto rumano", 4, "8-10", 120 ],
  [ "pierna", "Extensión de cuádriceps", 3, "12-15", 60 ],
  [ "pierna", "Curl femoral", 3, "12-15", 60 ],
  [ "hombro", "Press militar con barra", 4, "8-10", 90 ],
  [ "hombro", "Elevaciones laterales", 4, "12-15", 45 ],
  [ "hombro", "Pájaros (deltoide posterior)", 3, "12-15", 45 ],
  [ "hombro", "Press Arnold", 3, "10-12", 75 ],
  [ "biceps", "Curl con barra", 4, "8-12", 60 ],
  [ "biceps", "Curl con mancuernas alterno", 3, "10-12", 60 ],
  [ "biceps", "Curl martillo", 3, "10-12", 60 ],
  [ "triceps", "Extensiones en polea alta", 4, "10-12", 60 ],
  [ "triceps", "Press francés", 3, "10-12", 60 ],
  [ "triceps", "Fondos en banco", 3, "12-15", 60 ],
  [ "core", "Plancha abdominal", 3, "30-45 s", 45 ],
  [ "core", "Abdominales crunch", 3, "15-20", 45 ],
  [ "core", "Elevación de piernas colgado", 3, "12-15", 60 ],
  [ "core", "Giro ruso con peso", 3, "15-20 por lado", 45 ],
  [ "gluteo", "Hip thrust con barra", 4, "10-12", 90 ],
  [ "gluteo", "Patada de glúteo en polea", 3, "12-15", 45 ],
  [ "gluteo", "Puente de glúteo", 3, "15-20", 45 ],
  [ "otro", "Antebrazo con barra (curl de muñeca)", 3, "15-20", 45 ],
  [ "otro", "Encogimiento de trapecio", 3, "12-15", 60 ]
].each do |musculo, nombre, series, repeticiones, descanso|
  PlantillaEjercicio.find_or_create_by!(musculo: musculo, nombre: nombre) do |plantilla|
    plantilla.series = series
    plantilla.repeticiones = repeticiones
    plantilla.descanso_seg = descanso
  end
end

# Enlace de la biblioteca curada con el catálogo visual (Fase 6.4): cada
# plantilla apunta a su ejercicio del dataset (GIF + instrucciones). Lista de
# candidatos por nombre_en (el primero que exista gana); solo fija el enlace
# si aún no lo tiene, así el staff puede re-vincular sin que el seed lo pise.
{
  "Press de banca con barra" => [ "barbell bench press" ],
  "Press inclinado con mancuernas" => [ "dumbbell incline bench press", "dumbbell incline press" ],
  "Aperturas con mancuernas" => [ "dumbbell fly" ],
  "Fondos en paralelas" => [ "chest dip" ],
  "Dominadas" => [ "pull-up", "pull up (neutral grip)" ],
  "Remo con barra" => [ "barbell bent over row" ],
  "Jalón al pecho en polea" => [ "cable pulldown", "cable lat pulldown full range of motion" ],
  "Remo con mancuerna a una mano" => [ "dumbbell one arm row", "dumbbell bent over row" ],
  "Sentadilla con barra" => [ "barbell full squat" ],
  "Prensa de piernas" => [ "sled 45° leg press (side pov)", "lever alternate leg press" ],
  "Zancadas con mancuernas" => [ "dumbbell lunge", "barbell lunge" ],
  "Peso muerto rumano" => [ "barbell romanian deadlift" ],
  "Extensión de cuádriceps" => [ "lever leg extension" ],
  "Curl femoral" => [ "lever lying leg curl" ],
  "Press militar con barra" => [ "barbell standing wide military press", "barbell seated overhead press" ],
  "Elevaciones laterales" => [ "dumbbell lateral raise" ],
  "Pájaros (deltoide posterior)" => [ "dumbbell rear lateral raise", "barbell rear delt raise" ],
  "Press Arnold" => [ "dumbbell arnold press" ],
  "Curl con barra" => [ "barbell curl" ],
  "Curl con mancuernas alterno" => [ "dumbbell alternate biceps curl" ],
  "Curl martillo" => [ "dumbbell hammer curl" ],
  "Extensiones en polea alta" => [ "cable pushdown" ],
  "Press francés" => [ "ez bar standing french press", "barbell lying triceps extension skull crusher" ],
  "Fondos en banco" => [ "bench dip (knees bent)", "bench dip on floor" ],
  "Plancha abdominal" => [ "weighted front plank", "front plank with twist" ],
  "Abdominales crunch" => [ "crunch floor" ],
  "Elevación de piernas colgado" => [ "hanging leg raise" ],
  "Giro ruso con peso" => [ "weighted russian twist", "russian twist" ],
  "Hip thrust con barra" => [ "barbell hip thrust", "barbell glute bridge" ],
  "Patada de glúteo en polea" => [ "cable standing hip extension", "cable kickback" ],
  "Puente de glúteo" => [ "low glute bridge on floor", "glute bridge march" ],
  "Antebrazo con barra (curl de muñeca)" => [ "barbell wrist curl" ],
  "Encogimiento de trapecio" => [ "barbell shrug" ]
}.each do |nombre_plantilla, candidatos|
  plantilla = PlantillaEjercicio.find_by(nombre: nombre_plantilla)
  next if plantilla.nil? || plantilla.ejercicio_id.present?

  ejercicio = candidatos.lazy.filter_map { |n| Ejercicio.where("LOWER(nombre_en) = ?", n).first }.first
  plantilla.update!(ejercicio: ejercicio) if ejercicio
end
