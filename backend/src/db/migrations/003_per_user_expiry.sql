-- Cada participante tiene su propia fecha de caducidad sobre SU copia del mensaje.
-- La del emisor no afecta al receptor y viceversa.
ALTER TABLE messages
  ADD COLUMN IF NOT EXISTS sender_expires_at   TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS receiver_expires_at TIMESTAMPTZ;

-- Los mensajes que ya existen conservan su fecha para ambos lados
UPDATE messages
   SET sender_expires_at   = COALESCE(sender_expires_at, expires_at),
       receiver_expires_at = COALESCE(receiver_expires_at, expires_at);

ALTER TABLE messages
  ALTER COLUMN sender_expires_at   SET NOT NULL,
  ALTER COLUMN receiver_expires_at SET NOT NULL;

-- Al borrar la columna se elimina también idx_messages_expires_at
ALTER TABLE messages DROP COLUMN expires_at;

CREATE INDEX IF NOT EXISTS idx_messages_sender_expires   ON messages (sender_expires_at);
CREATE INDEX IF NOT EXISTS idx_messages_receiver_expires ON messages (receiver_expires_at);
