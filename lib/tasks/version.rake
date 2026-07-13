namespace :version do
  desc "Muestra la versión actual"
  task :show do
    puts File.read(Rails.root.join("VERSION")).strip
  end

  namespace :bump do
    %w[major minor patch].each do |parte|
      desc "Incrementa la versión #{parte} (MAJOR.MINOR.PATCH)"
      task parte.to_sym do
        ruta = Rails.root.join("VERSION")
        mayor, menor, parche = File.read(ruta).strip.split(".").map(&:to_i)

        case parte
        when "major" then mayor, menor, parche = mayor + 1, 0, 0
        when "minor" then menor, parche = menor + 1, 0
        when "patch" then parche += 1
        end

        nueva_version = [ mayor, menor, parche ].join(".")
        File.write(ruta, "#{nueva_version}\n")
        puts "Versión actualizada a #{nueva_version}"
      end
    end
  end
end
