-- Tabelas da automação BairroVivo (RPA / n8n)
-- Rodar depois que o app criou a tabela "ocorrencias".

CREATE TABLE IF NOT EXISTS automacao_log (
    id             BIGSERIAL PRIMARY KEY,
    ocorrencia_id  INTEGER NOT NULL REFERENCES ocorrencias(id) ON DELETE CASCADE,
    execucao_id    TEXT,
    etapa          VARCHAR(30) NOT NULL,
    resultado      VARCHAR(20) NOT NULL
                   CHECK (resultado IN ('ok','pulado','duplicata','invalida','revisao','erro')),
    detalhe        JSONB,
    duracao_ms     INTEGER,
    tentativas     SMALLINT NOT NULL DEFAULT 1,
    criado_em      TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_log_ocorrencia ON automacao_log (ocorrencia_id);

CREATE TABLE IF NOT EXISTS automacao_falhas (
    id             BIGSERIAL PRIMARY KEY,
    ocorrencia_id  INTEGER NOT NULL REFERENCES ocorrencias(id) ON DELETE CASCADE,
    etapa          VARCHAR(30) NOT NULL,
    payload        JSONB,
    erro           TEXT,
    tentativas     SMALLINT NOT NULL DEFAULT 0,
    status         VARCHAR(15) NOT NULL DEFAULT 'pendente'
                   CHECK (status IN ('pendente','reprocessada','descartada')),
    criado_em      TIMESTAMPTZ NOT NULL DEFAULT now(),
    atualizado_em  TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_falhas_pendentes ON automacao_falhas (status) WHERE status = 'pendente';

CREATE TABLE IF NOT EXISTS automacao_notificacoes (
    id             BIGSERIAL PRIMARY KEY,
    ocorrencia_id  INTEGER NOT NULL REFERENCES ocorrencias(id) ON DELETE CASCADE,
    destinatario   VARCHAR(40) NOT NULL,
    canal          VARCHAR(20) NOT NULL DEFAULT 'email_mock',
    mensagem       TEXT NOT NULL,
    criado_em      TIMESTAMPTZ NOT NULL DEFAULT now()
);