# Llaves VAPID dummy solo para la suite: los specs de push (EnviadorPush,
# NotificarDescansoJob, RecordatorioRachaJob) exigen su presencia y WebPush va
# mockeado, jamás se envía nada. Viven acá y no en docker-compose.yml porque
# ese environment lo comparte dev: con una llave dummy el opt-in se pintaría y
# los jobs intentarían firmar pushes reales (y dev puede apuntar a Supabase).
# `||=` respeta las que ya defina CI (.github/workflows/ci.yml).
ENV["VAPID_PUBLIC_KEY"] ||= "llave-pub-test"
ENV["VAPID_PRIVATE_KEY"] ||= "llave-priv-test"
