# El mismo agotamiento del pooler de Supabase que tumbaba GenerarPlanJob
# (ver app/jobs/application_job.rb) puede tumbar el análisis/variantes de un
# adjunto de Active Storage a mitad de un deploy — sin retry, el adjunto
# queda sin analizar/procesar para siempre.
Rails.application.config.to_prepare do
  ActiveStorage::AnalyzeJob.retry_on ActiveRecord::ConnectionNotEstablished, wait: :polynomially_longer, attempts: 5
  ActiveStorage::TransformJob.retry_on ActiveRecord::ConnectionNotEstablished, wait: :polynomially_longer, attempts: 5
end
