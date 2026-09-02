CREATE TABLE IF NOT EXISTS users (
  id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  username                TEXT UNIQUE NOT NULL,
  password_hash           TEXT NOT NULL,
  public_key              BYTEA NOT NULL,
  default_expiry_seconds  INTEGER NOT NULL DEFAULT 86400,
  created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
