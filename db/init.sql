CREATE TABLE cuenta (
  id BIGSERIAL PRIMARY KEY,
  titular VARCHAR(100) NOT NULL,
  numero VARCHAR(20) NOT NULL UNIQUE,
  saldo NUMERIC(14,2) NOT NULL DEFAULT 0 CHECK (saldo >= 0),
  reservado NUMERIC(14,2) NOT NULL DEFAULT 0 CHECK (reservado >= 0),
  limite_por_pago NUMERIC(14,2) NOT NULL,
  limite_diario NUMERIC(14,2) NOT NULL,
  activa BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE pago (
  id BIGSERIAL PRIMARY KEY,
  cuenta_id BIGINT NOT NULL REFERENCES cuenta(id),
  monto NUMERIC(14,2) NOT NULL CHECK (monto > 0),
  moneda CHAR(3) NOT NULL DEFAULT 'USD',
  concepto VARCHAR(100),
  estado VARCHAR(12) NOT NULL CHECK (estado IN ('PENDIENTE','APROBADO','RECHAZADO','EN_PROCESO')),
  motivo VARCHAR(40),
  referencia_banco VARCHAR(60) NOT NULL UNIQUE,   -- se envía al banco para que también deduplique
  creado_en TIMESTAMPTZ NOT NULL DEFAULT now(),
  resuelto_en TIMESTAMPTZ,
  conciliado_en TIMESTAMPTZ
);
CREATE INDEX idx_pago_cuenta_fecha ON pago (cuenta_id, creado_en);
CREATE INDEX idx_pago_en_proceso ON pago (estado) WHERE estado = 'EN_PROCESO';

-- Idempotencia: la restricción única es lo que impide el cobro doble, incluso con dos reintentos simultáneos
CREATE TABLE idempotencia (
  cuenta_id BIGINT NOT NULL REFERENCES cuenta(id),
  clave VARCHAR(80) NOT NULL,
  hash_solicitud CHAR(64) NOT NULL,               -- SHA-256 de cuenta + monto + concepto
  pago_id BIGINT REFERENCES pago(id),
  respuesta JSONB,
  creada_en TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (cuenta_id, clave)
);

-- Auditoría append-only: un registro por cada intento y cada cambio de estado
CREATE TABLE auditoria (
  id BIGSERIAL PRIMARY KEY,
  correlacion_id UUID NOT NULL,
  pago_id BIGINT REFERENCES pago(id),
  evento VARCHAR(40) NOT NULL,
  detalle JSONB,                                  -- sin datos sensibles; cuenta enmascarada
  ocurrido_en TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_aud_pago ON auditoria (pago_id);

CREATE TABLE outbox (
  id BIGSERIAL PRIMARY KEY,
  tipo_evento VARCHAR(60) NOT NULL,
  payload JSONB NOT NULL,
  creado_en TIMESTAMPTZ NOT NULL DEFAULT now(),
  publicado_en TIMESTAMPTZ
);

CREATE TABLE conciliacion (
  id BIGSERIAL PRIMARY KEY,
  pago_id BIGINT REFERENCES pago(id),
  referencia_banco VARCHAR(60),
  estado_interno VARCHAR(12),
  estado_banco VARCHAR(12),
  resultado VARCHAR(20) NOT NULL CHECK (resultado IN ('COINCIDE','DIFERENCIA','FALTA_EN_BANCO','FALTA_INTERNO')),
  ejecutada_en TIMESTAMPTZ NOT NULL DEFAULT now()
);

INSERT INTO cuenta (titular, numero, saldo, limite_por_pago, limite_diario, activa) VALUES
 ('Ana Paredes','1000004821',500,200,400,TRUE),
 ('Luis Mora','1000007710',120,100,150,TRUE),
 ('Rosa Vera','1000000032',800,300,600,FALSE);
