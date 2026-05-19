-- ============================================================================
-- Architecture de base de données PostgreSQL hautement performante et scalable
-- Pour plateforme SaaS SMS multi-entreprises (B2B)
-- ============================================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================================
-- 1. TRIGGERS POUR LA GESTION DES TIMESTAMPS
-- ============================================================================
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- 2. TABLES PRINCIPALES (MULTI-TENANT & AUTH)
-- ============================================================================

-- Table Entreprise (Multi-tenant principal)
CREATE TABLE companies (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(150) NOT NULL,
    api_key VARCHAR(64) UNIQUE,
    webhook_url TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TRIGGER trigger_update_companies_timestamp
BEFORE UPDATE ON companies
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Table Utilisateurs (Rattachés à une Entreprise)
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    company_id UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    role VARCHAR(50) NOT NULL DEFAULT 'user', -- 'admin', 'user', 'developer'
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_users_company ON users(company_id);

CREATE TRIGGER trigger_update_users_timestamp
BEFORE UPDATE ON users
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================================================
-- 3. FACTURATION & CRÉDITS (PORTES-MONNAIES ET COMPTABILITÉ DOUBLE ENTRÉE)
-- ============================================================================

-- Table Porte-monnaie (Un par entreprise, évite la corruption de données)
CREATE TABLE wallets (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    company_id UUID UNIQUE NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    balance NUMERIC(12, 4) NOT NULL DEFAULT 0.0000 CONSTRAINT chk_positive_balance CHECK (balance >= 0.0000),
    currency VARCHAR(3) NOT NULL DEFAULT 'EUR',
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TRIGGER trigger_update_wallets_timestamp
BEFORE UPDATE ON wallets
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Table de transactions (Ledger immuable de tous les débits/crédits)
CREATE TABLE wallet_transactions (
    id BIGSERIAL PRIMARY KEY,
    wallet_id UUID NOT NULL REFERENCES wallets(id) ON DELETE RESTRICT,
    amount NUMERIC(12, 4) NOT NULL, -- Positif pour les recharges, négatif pour les débits SMS
    type VARCHAR(20) NOT NULL, -- 'DEPOSIT', 'DEBIT_SMS', 'REFUND'
    reference_id VARCHAR(100), -- ID externe Stripe, ou ID du lot SMS
    description TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_wallet_transactions_wallet ON wallet_transactions(wallet_id);
CREATE INDEX idx_wallet_transactions_created ON wallet_transactions(created_at);

-- ============================================================================
-- 4. GESTION DES ENVOIS (SENDER IDS & CAMPAGNES)
-- ============================================================================

-- Table Sender ID (Noms d'expéditeur approuvés)
CREATE TABLE sender_ids (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    company_id UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    name VARCHAR(11) NOT NULL CONSTRAINT chk_sender_id_length CHECK (char_length(name) >= 3 AND char_length(name) <= 11),
    status VARCHAR(20) NOT NULL DEFAULT 'PENDING', -- 'PENDING', 'APPROVED', 'REJECTED'
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_company_sender_name UNIQUE (company_id, name)
);

CREATE TRIGGER trigger_update_sender_ids_timestamp
BEFORE UPDATE ON sender_ids
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Table des Campagnes de SMS
CREATE TABLE campaigns (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    company_id UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    sender_id UUID REFERENCES sender_ids(id) ON DELETE SET NULL,
    name VARCHAR(255) NOT NULL,
    message_body TEXT NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'DRAFT', -- 'DRAFT', 'SCHEDULED', 'SENDING', 'COMPLETED', 'PAUSED', 'CANCELLED'
    scheduled_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_campaigns_company ON campaigns(company_id);
CREATE INDEX idx_campaigns_status ON campaigns(status);

CREATE TRIGGER trigger_update_campaigns_timestamp
BEFORE UPDATE ON campaigns
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================================================
-- 5. HISTORIQUE DES SMS (HAUTE PERFORMANCE & CONCEPTION POUR PARTITIONNEMENT)
-- ============================================================================

-- Séquence pour générer les IDs de SMS uniques à travers toutes les partitions
CREATE SEQUENCE sms_logs_id_seq;

-- Table SMS Logs (Définie pour le partitionnement par date)
CREATE TABLE sms_logs (
    id BIGINT NOT NULL DEFAULT nextval('sms_logs_id_seq'),
    company_id UUID NOT NULL,
    campaign_id UUID,
    sender_id_name VARCHAR(11) NOT NULL,
    recipient VARCHAR(20) NOT NULL,
    message TEXT NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'PENDING', -- 'PENDING', 'SENT', 'DELIVERED', 'FAILED', 'EXPIRED'
    cost NUMERIC(8, 4) NOT NULL DEFAULT 0.0000,
    external_id VARCHAR(100), -- ID opérateur (Twilio, Infobip)
    error_code VARCHAR(20),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (id, created_at)
) PARTITION BY RANGE (created_at);

-- Exemples de partitions mensuelles (PostgreSQL requiert de créer les partitions explicitement)
CREATE TABLE sms_logs_y2026m05 PARTITION OF sms_logs
    FOR VALUES FROM ('2026-05-01 00:00:00+00') TO ('2026-06-01 00:00:00+00');

CREATE TABLE sms_logs_y2026m06 PARTITION OF sms_logs
    FOR VALUES FROM ('2026-06-01 00:00:00+00') TO ('2026-07-01 00:00:00+00');

-- Index sur la table partitionnée (se répercutent automatiquement sur les partitions existantes et futures)
CREATE INDEX idx_sms_logs_company_created ON sms_logs(company_id, created_at DESC);
CREATE INDEX idx_sms_logs_recipient ON sms_logs(recipient);
CREATE INDEX idx_sms_logs_external_id ON sms_logs(external_id);
CREATE INDEX idx_sms_logs_status_pending ON sms_logs(status) WHERE status = 'PENDING';

-- ============================================================================
-- 6. SYSTEM LOGS & AUDIT (SÉCURITÉ ET MONITORING)
-- ============================================================================
CREATE TABLE system_logs (
    id BIGSERIAL PRIMARY KEY,
    level VARCHAR(10) NOT NULL, -- 'INFO', 'WARN', 'ERROR', 'FATAL'
    context VARCHAR(100) NOT NULL, -- 'AUTH', 'SMS_GATEWAY', 'BILLING'
    message TEXT NOT NULL,
    metadata JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_system_logs_level_created ON system_logs(level, created_at DESC);
CREATE INDEX idx_system_logs_context ON system_logs(context);
