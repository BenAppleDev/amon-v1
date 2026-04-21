ALTER TABLE route_sessions ADD COLUMN product_session_id TEXT;

CREATE INDEX IF NOT EXISTS idx_route_sessions_product_session_id ON route_sessions(product_session_id);

UPDATE route_sessions
SET product_session_id = (
    SELECT ps.id
    FROM product_sessions ps
    WHERE ps.account_id = route_sessions.user_id
      AND ps.auth_session_id = route_sessions.auth_session_id
    ORDER BY ps.issued_at DESC
    LIMIT 1
)
WHERE product_session_id IS NULL;
