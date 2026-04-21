CREATE TABLE IF NOT EXISTS product_sessions (
    id TEXT PRIMARY KEY,
    account_id TEXT NOT NULL,
    auth_session_id TEXT NOT NULL,
    entitlement_id TEXT NOT NULL,
    issued_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    expires_at TEXT NOT NULL,
    last_seen_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    revoked_at TEXT,
    FOREIGN KEY (account_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (auth_session_id) REFERENCES sessions(id) ON DELETE CASCADE,
    FOREIGN KEY (entitlement_id) REFERENCES entitlements(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_product_sessions_account_id ON product_sessions(account_id);
CREATE INDEX IF NOT EXISTS idx_product_sessions_auth_session_id ON product_sessions(auth_session_id);
CREATE INDEX IF NOT EXISTS idx_product_sessions_entitlement_id ON product_sessions(entitlement_id);
CREATE INDEX IF NOT EXISTS idx_product_sessions_expires_at ON product_sessions(expires_at);
CREATE INDEX IF NOT EXISTS idx_product_sessions_revoked_at ON product_sessions(revoked_at);

CREATE TABLE IF NOT EXISTS route_sessions (
    id TEXT PRIMARY KEY,
    product_session_id TEXT,
    user_id TEXT NOT NULL,
    auth_session_id TEXT NOT NULL,
    route_kind TEXT NOT NULL,
    transport_kind TEXT NOT NULL,
    control_plane_kind TEXT NOT NULL,
    access_token TEXT NOT NULL,
    issued_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    last_refreshed_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    expires_at TEXT NOT NULL,
    revoked_at TEXT,
    revoke_reason TEXT,
    refresh_count INTEGER NOT NULL DEFAULT 0,
    UNIQUE (access_token),
    FOREIGN KEY (product_session_id) REFERENCES product_sessions(id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (auth_session_id) REFERENCES sessions(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_route_sessions_product_session_id ON route_sessions(product_session_id);
CREATE INDEX IF NOT EXISTS idx_route_sessions_user_id ON route_sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_route_sessions_auth_session_id ON route_sessions(auth_session_id);
CREATE INDEX IF NOT EXISTS idx_route_sessions_access_token ON route_sessions(access_token);
CREATE INDEX IF NOT EXISTS idx_route_sessions_expires_at ON route_sessions(expires_at);
CREATE INDEX IF NOT EXISTS idx_route_sessions_revoked_at ON route_sessions(revoked_at);

CREATE TABLE IF NOT EXISTS ops_operator_sessions (
    id TEXT PRIMARY KEY,
    operator_id TEXT NOT NULL,
    environment TEXT NOT NULL,
    auth_method TEXT NOT NULL,
    issued_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    expires_at TEXT NOT NULL,
    last_seen_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    revoked_at TEXT
);

CREATE INDEX IF NOT EXISTS idx_ops_operator_sessions_operator_id ON ops_operator_sessions(operator_id);
CREATE INDEX IF NOT EXISTS idx_ops_operator_sessions_environment ON ops_operator_sessions(environment);
CREATE INDEX IF NOT EXISTS idx_ops_operator_sessions_expires_at ON ops_operator_sessions(expires_at);

CREATE TABLE IF NOT EXISTS protected_session_ops_events (
    event_id TEXT PRIMARY KEY,
    environment TEXT NOT NULL,
    occurred_at TEXT NOT NULL,
    event_type TEXT NOT NULL,
    session_id TEXT,
    user_id TEXT,
    domain TEXT,
    worker_id TEXT,
    reason_code TEXT,
    state TEXT,
    disposition TEXT,
    budget_tier TEXT,
    metric_value INTEGER,
    duration_ms INTEGER
);

CREATE INDEX IF NOT EXISTS idx_protected_session_ops_events_environment
    ON protected_session_ops_events(environment);
CREATE INDEX IF NOT EXISTS idx_protected_session_ops_events_occurred_at
    ON protected_session_ops_events(occurred_at);
CREATE INDEX IF NOT EXISTS idx_protected_session_ops_events_event_type
    ON protected_session_ops_events(event_type);
CREATE INDEX IF NOT EXISTS idx_protected_session_ops_events_session_id
    ON protected_session_ops_events(session_id);
CREATE INDEX IF NOT EXISTS idx_protected_session_ops_events_user_id
    ON protected_session_ops_events(user_id);
CREATE INDEX IF NOT EXISTS idx_protected_session_ops_events_domain
    ON protected_session_ops_events(domain);
CREATE INDEX IF NOT EXISTS idx_protected_session_ops_events_worker_id
    ON protected_session_ops_events(worker_id);
CREATE INDEX IF NOT EXISTS idx_protected_session_ops_events_reason_code
    ON protected_session_ops_events(reason_code);

CREATE TABLE IF NOT EXISTS protected_session_ops_snapshots (
    id TEXT PRIMARY KEY,
    environment TEXT NOT NULL,
    recorded_at TEXT NOT NULL,
    total_sessions INTEGER NOT NULL DEFAULT 0,
    active_sessions INTEGER NOT NULL DEFAULT 0,
    active_streams INTEGER NOT NULL DEFAULT 0,
    users_with_active_sessions INTEGER NOT NULL DEFAULT 0,
    users_with_live_streams INTEGER NOT NULL DEFAULT 0,
    total_workers INTEGER NOT NULL DEFAULT 0,
    healthy_workers INTEGER NOT NULL DEFAULT 0,
    degraded_workers INTEGER NOT NULL DEFAULT 0,
    total_worker_capacity INTEGER NOT NULL DEFAULT 0,
    total_worker_stream_capacity INTEGER NOT NULL DEFAULT 0,
    total_assigned_sessions INTEGER NOT NULL DEFAULT 0,
    quota_rejections_total INTEGER NOT NULL DEFAULT 0,
    protocol_errors_total INTEGER NOT NULL DEFAULT 0,
    heartbeat_timeouts_total INTEGER NOT NULL DEFAULT 0,
    dropped_events_total INTEGER NOT NULL DEFAULT 0
);

CREATE INDEX IF NOT EXISTS idx_protected_session_ops_snapshots_environment
    ON protected_session_ops_snapshots(environment);
CREATE INDEX IF NOT EXISTS idx_protected_session_ops_snapshots_recorded_at
    ON protected_session_ops_snapshots(recorded_at);
