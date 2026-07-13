# Valida la rutina que devuelve la IA contra el catálogo real (Fase 6.5):
# la IA debe usar ejercicio_id del CATÁLOGO PERMITIDO, pero puede alucinar.
# Reglas: id válido → se pisa el nombre con el del catálogo (consistencia);
# id inválido → rescate por nombre; sin match → se elimina el id pero el
# ejercicio sobrevive. NUNCA tumba el plan; devuelve el conteo de arreglos.
module Ejercicios
  module ValidadorRutina
    def self.corregir!(rutina)
      correcciones = 0
      dias = Array(rutina.is_a?(Hash) ? rutina["dias"] : nil)

      dias.each do |dia|
        Array(dia["ejercicios"]).each do |ejercicio|
          correcciones += 1 unless corregir_ejercicio(ejercicio)
        end
      end

      { rutina: rutina, correcciones: correcciones }
    end

    # true si el ejercicio quedó bien referenciado sin necesidad de arreglo
    def self.corregir_ejercicio(ejercicio)
      encontrado = Ejercicio.find_by(id: ejercicio["ejercicio_id"])

      if encontrado
        return true if ejercicio["nombre"] == encontrado.nombre

        ejercicio["nombre"] = encontrado.nombre
      elsif (rescatado = Ejercicio.buscar_por_nombre(ejercicio["nombre"]))
        ejercicio["ejercicio_id"] = rescatado.id
      else
        ejercicio.delete("ejercicio_id")
      end
      false
    end
  end
end
