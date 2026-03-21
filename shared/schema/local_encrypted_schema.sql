PRAGMA foreign_keys = ON;

CREATE TABLE workspaces (
    id TEXT PRIMARY KEY,
    title TEXT NOT NULL,
    description TEXT,
    color_tag TEXT,
    icon_name TEXT,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    last_opened_at TEXT,
    is_archived INTEGER NOT NULL DEFAULT 0 CHECK (is_archived IN (0, 1)),
    export_version INTEGER NOT NULL DEFAULT 1,
    local_schema_version INTEGER NOT NULL DEFAULT 1
);

CREATE TABLE items (
    id TEXT PRIMARY KEY,
    workspace_id TEXT NOT NULL,
    source_kind TEXT NOT NULL CHECK (source_kind IN ('search_result', 'opened_page', 'retrieved_page')),
    result_type TEXT NOT NULL CHECK (result_type IN ('web_page', 'article', 'place', 'product')),
    title TEXT NOT NULL,
    canonical_url TEXT NOT NULL,
    domain TEXT NOT NULL,
    snippet TEXT,
    page_title TEXT,
    cleaned_excerpt TEXT,
    bullet_points_json TEXT,
    provider_name TEXT,
    provider_result_id TEXT,
    fetched_at TEXT,
    saved_at TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    typed_metadata_json TEXT,
    source_metadata_json TEXT,
    content_hash TEXT,
    is_deleted INTEGER NOT NULL DEFAULT 0 CHECK (is_deleted IN (0, 1)),
    FOREIGN KEY (workspace_id) REFERENCES workspaces(id) ON DELETE CASCADE
);

CREATE TABLE compare_artifacts (
    id TEXT PRIMARY KEY,
    workspace_id TEXT NOT NULL,
    title TEXT NOT NULL,
    summary TEXT,
    compare_schema_version INTEGER NOT NULL DEFAULT 1,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    FOREIGN KEY (workspace_id) REFERENCES workspaces(id) ON DELETE CASCADE
);

CREATE TABLE notes (
    id TEXT PRIMARY KEY,
    workspace_id TEXT,
    item_id TEXT,
    compare_artifact_id TEXT,
    scope_type TEXT NOT NULL CHECK (scope_type IN ('workspace', 'item', 'compare')),
    body TEXT NOT NULL,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    is_deleted INTEGER NOT NULL DEFAULT 0 CHECK (is_deleted IN (0, 1)),
    FOREIGN KEY (workspace_id) REFERENCES workspaces(id) ON DELETE CASCADE,
    FOREIGN KEY (item_id) REFERENCES items(id) ON DELETE CASCADE,
    FOREIGN KEY (compare_artifact_id) REFERENCES compare_artifacts(id) ON DELETE CASCADE,
    CHECK (
        (workspace_id IS NOT NULL AND item_id IS NULL AND compare_artifact_id IS NULL AND scope_type = 'workspace') OR
        (workspace_id IS NULL AND item_id IS NOT NULL AND compare_artifact_id IS NULL AND scope_type = 'item') OR
        (workspace_id IS NULL AND item_id IS NULL AND compare_artifact_id IS NOT NULL AND scope_type = 'compare')
    )
);

CREATE TABLE compare_artifact_items (
    id TEXT PRIMARY KEY,
    compare_artifact_id TEXT NOT NULL,
    item_id TEXT NOT NULL,
    sort_order INTEGER NOT NULL,
    FOREIGN KEY (compare_artifact_id) REFERENCES compare_artifacts(id) ON DELETE CASCADE,
    FOREIGN KEY (item_id) REFERENCES items(id) ON DELETE CASCADE,
    UNIQUE (compare_artifact_id, item_id)
);

CREATE TABLE compare_rows (
    id TEXT PRIMARY KEY,
    compare_artifact_id TEXT NOT NULL,
    field_key TEXT NOT NULL,
    field_label TEXT NOT NULL,
    row_type TEXT NOT NULL CHECK (row_type IN ('text', 'number', 'bullet_list', 'url')),
    sort_order INTEGER NOT NULL,
    FOREIGN KEY (compare_artifact_id) REFERENCES compare_artifacts(id) ON DELETE CASCADE
);

CREATE TABLE compare_cells (
    id TEXT PRIMARY KEY,
    compare_row_id TEXT NOT NULL,
    item_id TEXT NOT NULL,
    value_text TEXT,
    value_json TEXT,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    FOREIGN KEY (compare_row_id) REFERENCES compare_rows(id) ON DELETE CASCADE,
    FOREIGN KEY (item_id) REFERENCES items(id) ON DELETE CASCADE,
    UNIQUE (compare_row_id, item_id)
);

CREATE TABLE research_artifacts (
    id TEXT PRIMARY KEY,
    workspace_id TEXT NOT NULL,
    title TEXT NOT NULL,
    prompt_context TEXT,
    summary_text TEXT NOT NULL,
    bullet_summary_json TEXT,
    model_name TEXT,
    model_version TEXT,
    generation_mode TEXT NOT NULL CHECK (generation_mode IN ('source_grounded_summary')),
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    FOREIGN KEY (workspace_id) REFERENCES workspaces(id) ON DELETE CASCADE
);

CREATE TABLE research_artifact_items (
    id TEXT PRIMARY KEY,
    research_artifact_id TEXT NOT NULL,
    item_id TEXT NOT NULL,
    sort_order INTEGER NOT NULL,
    FOREIGN KEY (research_artifact_id) REFERENCES research_artifacts(id) ON DELETE CASCADE,
    FOREIGN KEY (item_id) REFERENCES items(id) ON DELETE CASCADE,
    UNIQUE (research_artifact_id, item_id)
);

CREATE TABLE export_records (
    id TEXT PRIMARY KEY,
    workspace_id TEXT NOT NULL,
    export_type TEXT NOT NULL CHECK (export_type IN ('workspace_export', 'workspace_import')),
    file_name TEXT,
    file_checksum TEXT,
    created_at TEXT NOT NULL,
    completed_at TEXT,
    format_version INTEGER NOT NULL DEFAULT 1,
    status TEXT NOT NULL CHECK (status IN ('started', 'completed', 'failed')),
    FOREIGN KEY (workspace_id) REFERENCES workspaces(id) ON DELETE CASCADE
);

CREATE TABLE app_preferences (
    key TEXT PRIMARY KEY,
    value_json TEXT NOT NULL,
    updated_at TEXT NOT NULL
);

CREATE TABLE local_key_metadata (
    id TEXT PRIMARY KEY,
    key_version INTEGER NOT NULL,
    key_wrapping_scheme TEXT NOT NULL,
    created_at TEXT NOT NULL,
    rotated_at TEXT
);

CREATE INDEX idx_workspaces_updated_at ON workspaces(updated_at);
CREATE INDEX idx_workspaces_last_opened_at ON workspaces(last_opened_at);
CREATE INDEX idx_items_workspace_id ON items(workspace_id);
CREATE INDEX idx_items_saved_at ON items(saved_at);
CREATE INDEX idx_items_canonical_url ON items(canonical_url);
CREATE INDEX idx_items_result_type ON items(result_type);
CREATE INDEX idx_notes_workspace_id ON notes(workspace_id);
CREATE INDEX idx_notes_item_id ON notes(item_id);
CREATE INDEX idx_notes_compare_artifact_id ON notes(compare_artifact_id);
CREATE INDEX idx_compare_artifact_items_compare_id ON compare_artifact_items(compare_artifact_id);
CREATE INDEX idx_compare_artifact_items_item_id ON compare_artifact_items(item_id);
CREATE INDEX idx_research_artifact_items_research_id ON research_artifact_items(research_artifact_id);
CREATE INDEX idx_research_artifact_items_item_id ON research_artifact_items(item_id);
