import Foundation

enum LocalSchema {
    static let createStatements = [
        """
        PRAGMA foreign_keys = ON;
        """,
        """
        CREATE TABLE IF NOT EXISTS workspaces (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            description TEXT,
            color_tag TEXT,
            icon_name TEXT,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            last_opened_at TEXT,
            is_archived INTEGER NOT NULL DEFAULT 0,
            export_version INTEGER NOT NULL DEFAULT 1,
            local_schema_version INTEGER NOT NULL DEFAULT 1
        );
        """,
        """
        CREATE TABLE IF NOT EXISTS items (
            id TEXT PRIMARY KEY,
            workspace_id TEXT NOT NULL,
            source_kind TEXT NOT NULL,
            result_type TEXT NOT NULL,
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
            is_deleted INTEGER NOT NULL DEFAULT 0,
            FOREIGN KEY (workspace_id) REFERENCES workspaces(id) ON DELETE CASCADE
        );
        """,
        """
        CREATE TABLE IF NOT EXISTS compare_artifacts (
            id TEXT PRIMARY KEY,
            workspace_id TEXT NOT NULL,
            title TEXT NOT NULL,
            summary TEXT,
            compare_schema_version INTEGER NOT NULL DEFAULT 1,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            FOREIGN KEY (workspace_id) REFERENCES workspaces(id) ON DELETE CASCADE
        );
        """,
        """
        CREATE TABLE IF NOT EXISTS notes (
            id TEXT PRIMARY KEY,
            workspace_id TEXT,
            item_id TEXT,
            compare_artifact_id TEXT,
            scope_type TEXT NOT NULL,
            body TEXT NOT NULL,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            is_deleted INTEGER NOT NULL DEFAULT 0,
            FOREIGN KEY (workspace_id) REFERENCES workspaces(id) ON DELETE CASCADE,
            FOREIGN KEY (item_id) REFERENCES items(id) ON DELETE CASCADE,
            FOREIGN KEY (compare_artifact_id) REFERENCES compare_artifacts(id) ON DELETE CASCADE
        );
        """,
        """
        CREATE TABLE IF NOT EXISTS compare_artifact_items (
            id TEXT PRIMARY KEY,
            compare_artifact_id TEXT NOT NULL,
            item_id TEXT NOT NULL,
            sort_order INTEGER NOT NULL,
            FOREIGN KEY (compare_artifact_id) REFERENCES compare_artifacts(id) ON DELETE CASCADE,
            FOREIGN KEY (item_id) REFERENCES items(id) ON DELETE CASCADE
        );
        """,
        """
        CREATE TABLE IF NOT EXISTS compare_rows (
            id TEXT PRIMARY KEY,
            compare_artifact_id TEXT NOT NULL,
            field_key TEXT NOT NULL,
            field_label TEXT NOT NULL,
            row_type TEXT NOT NULL,
            sort_order INTEGER NOT NULL,
            FOREIGN KEY (compare_artifact_id) REFERENCES compare_artifacts(id) ON DELETE CASCADE
        );
        """,
        """
        CREATE TABLE IF NOT EXISTS compare_cells (
            id TEXT PRIMARY KEY,
            compare_row_id TEXT NOT NULL,
            item_id TEXT NOT NULL,
            value_text TEXT,
            value_json TEXT,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            FOREIGN KEY (compare_row_id) REFERENCES compare_rows(id) ON DELETE CASCADE,
            FOREIGN KEY (item_id) REFERENCES items(id) ON DELETE CASCADE
        );
        """,
        """
        CREATE TABLE IF NOT EXISTS research_artifacts (
            id TEXT PRIMARY KEY,
            workspace_id TEXT NOT NULL,
            title TEXT NOT NULL,
            prompt_context TEXT,
            summary_text TEXT NOT NULL,
            bullet_summary_json TEXT,
            model_name TEXT,
            model_version TEXT,
            generation_mode TEXT NOT NULL,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            FOREIGN KEY (workspace_id) REFERENCES workspaces(id) ON DELETE CASCADE
        );
        """,
        """
        CREATE TABLE IF NOT EXISTS research_artifact_items (
            id TEXT PRIMARY KEY,
            research_artifact_id TEXT NOT NULL,
            item_id TEXT NOT NULL,
            sort_order INTEGER NOT NULL,
            FOREIGN KEY (research_artifact_id) REFERENCES research_artifacts(id) ON DELETE CASCADE,
            FOREIGN KEY (item_id) REFERENCES items(id) ON DELETE CASCADE
        );
        """,
        """
        CREATE TABLE IF NOT EXISTS export_records (
            id TEXT PRIMARY KEY,
            workspace_id TEXT NOT NULL,
            export_type TEXT NOT NULL,
            file_name TEXT,
            file_checksum TEXT,
            created_at TEXT NOT NULL,
            completed_at TEXT,
            format_version INTEGER NOT NULL DEFAULT 1,
            status TEXT NOT NULL,
            FOREIGN KEY (workspace_id) REFERENCES workspaces(id) ON DELETE CASCADE
        );
        """,
        """
        CREATE TABLE IF NOT EXISTS app_preferences (
            key TEXT PRIMARY KEY,
            value_json TEXT NOT NULL,
            updated_at TEXT NOT NULL
        );
        """
    ]
}
