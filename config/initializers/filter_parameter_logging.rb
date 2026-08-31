# Be sure to restart your server when you modify this file.

# Configure parameters to be partially matched (e.g. passw matches password) and filtered from the log file.
# Use this to limit dissemination of sensitive information.
# See the ActiveSupport::ParameterFilter documentation for supported notations and behaviors.
Rails.application.config.filter_parameters += [
  :passw, :email, :secret, :token, :_key, :crypt, :salt, :certificate, :otp, :ssn, :cvv, :cvc
]

# `filter_parameters` cubre el "Started GET …?token=[FILTERED]" del DESTINO,
# pero NO la línea "Redirected to https://…?token=…" que loguea el ORIGEN al
# emitir el pase de cambio de organización: los destinos de redirect tienen su
# propio filtro. Sin esto, el pase firmado (15 s de vida, un solo uso) quedaba
# completo en los logs de producción.
Rails.application.config.filter_redirect += [ /token=/ ]
