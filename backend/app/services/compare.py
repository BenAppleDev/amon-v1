from __future__ import annotations

from collections import OrderedDict
from typing import Any

from app.schemas import CompareCellPayload, CompareResponse, CompareRowPayload, ItemSourcePayload


class CompareService:
    def build_compare(self, title: str, items: list[ItemSourcePayload]) -> CompareResponse:
        rows: list[CompareRowPayload] = []
        rows.append(self._text_row('title', 'Title', items, lambda item: item.page_title or item.title))
        rows.append(self._text_row('domain', 'Domain', items, lambda item: item.domain))

        if any(item.snippet for item in items):
            rows.append(self._text_row('snippet', 'Snippet', items, lambda item: item.snippet))
        if any(item.cleaned_excerpt for item in items):
            rows.append(self._text_row('excerpt', 'Excerpt', items, lambda item: item.cleaned_excerpt))
        if any(item.bullet_points for item in items):
            rows.append(
                CompareRowPayload(
                    field_key='bullet_points',
                    field_label='Bullet Points',
                    row_type='bullet_list',
                    cells=[
                        CompareCellPayload(item_id=item.item_id, value_json=item.bullet_points or [])
                        for item in items
                    ],
                )
            )

        typed_keys = OrderedDict()
        for item in items:
            for key in (item.typed_metadata or {}).keys():
                typed_keys[key] = True

        for key in typed_keys.keys():
            values = [(item.typed_metadata or {}).get(key) for item in items]
            row_type = 'number' if all(isinstance(v, (int, float)) or v is None for v in values) else 'text'
            rows.append(
                CompareRowPayload(
                    field_key=key,
                    field_label=key.replace('_', ' ').title(),
                    row_type=row_type,
                    cells=[
                        self._typed_cell(item.item_id, (item.typed_metadata or {}).get(key))
                        for item in items
                    ],
                )
            )

        summary = f'Compared {len(items)} saved items across {len(rows)} structured fields.'
        return CompareResponse(title=title, summary=summary, rows=rows)

    @staticmethod
    def _text_row(field_key: str, field_label: str, items: list[ItemSourcePayload], getter: Any) -> CompareRowPayload:
        return CompareRowPayload(
            field_key=field_key,
            field_label=field_label,
            row_type='text',
            cells=[CompareCellPayload(item_id=item.item_id, value_text=getter(item)) for item in items],
        )

    @staticmethod
    def _typed_cell(item_id: str | None, value: Any) -> CompareCellPayload:
        if isinstance(value, list):
            return CompareCellPayload(item_id=item_id, value_json=value)
        if value is None:
            return CompareCellPayload(item_id=item_id, value_text=None)
        return CompareCellPayload(item_id=item_id, value_text=str(value))
