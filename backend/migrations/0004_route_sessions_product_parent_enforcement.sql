UPDATE route_sessions
SET product_session_id = (
    SELECT ps.id
    FROM product_sessions ps
    WHERE ps.account_id = route_sessions.user_id
      AND ps.auth_session_id = route_sessions.auth_session_id
      AND ps.revoked_at IS NULL
    ORDER BY ps.last_seen_at DESC, ps.issued_at DESC
    LIMIT 1
)
WHERE product_session_id IS NULL;

UPDATE route_sessions
SET revoked_at = COALESCE(revoked_at, CURRENT_TIMESTAMP),
    revoke_reason = COALESCE(revoke_reason, 'product_session_missing')
WHERE product_session_id IS NULL;

CREATE TRIGGER IF NOT EXISTS trg_route_sessions_require_product_session_insert
BEFORE INSERT ON route_sessions
FOR EACH ROW
WHEN NEW.product_session_id IS NULL
BEGIN
    SELECT RAISE(ABORT, 'route_sessions.product_session_id is required');
END;

CREATE TRIGGER IF NOT EXISTS trg_route_sessions_require_product_session_update
BEFORE UPDATE OF product_session_id ON route_sessions
FOR EACH ROW
WHEN NEW.product_session_id IS NULL
BEGIN
    SELECT RAISE(ABORT, 'route_sessions.product_session_id is required');
END;
