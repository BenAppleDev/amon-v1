from __future__ import annotations

from collections import Counter
import re

from app.schemas import ItemSourcePayload, ModelInfo, ResearchResponse, ResearchSourceRef


_WORD_RE = re.compile(r"[A-Za-z][A-Za-z'-]{2,}")
_STOPWORDS = {
    'the', 'and', 'for', 'with', 'that', 'this', 'from', 'into', 'their', 'about', 'have', 'has', 'are', 'was',
    'were', 'they', 'them', 'your', 'over', 'will', 'would', 'than', 'more', 'less', 'into', 'also', 'across',
    'best', 'guide', 'page', 'result'
}


class ResearchService:
    def build_summary(self, title: str, prompt_context: str | None, items: list[ItemSourcePayload]) -> ResearchResponse:
        text_pool = []
        source_refs = [ResearchSourceRef(item_id=item.item_id) for item in items]
        for item in items:
            text_pool.extend(item.bullet_points)
            if item.cleaned_excerpt:
                text_pool.append(item.cleaned_excerpt)
            elif item.snippet:
                text_pool.append(item.snippet)

        themes = self._top_terms(' '.join(text_pool))
        titles = ', '.join((item.page_title or item.title) for item in items[:3])
        theme_sentence = f'Common themes include {", ".join(themes[:3])}.' if themes else 'The sources overlap on several recurring points.'
        context_sentence = f' Framing: {prompt_context.strip()}.' if prompt_context else ''
        summary_text = (
            f'Across {len(items)} selected sources, the strongest signal comes from {titles}. '
            f'{theme_sentence}{context_sentence}'
        )

        bullet_summary = self._build_bullets(items, themes)
        return ResearchResponse(
            title=title,
            summary_text=summary_text,
            bullet_summary=bullet_summary,
            sources=source_refs,
            model=ModelInfo(name='amon-grounded-heuristic', version='0.1'),
        )

    @staticmethod
    def _top_terms(text: str) -> list[str]:
        counter: Counter[str] = Counter()
        for word in _WORD_RE.findall(text.lower()):
            if word in _STOPWORDS:
                continue
            counter[word] += 1
        return [word for word, _count in counter.most_common(5)]

    @staticmethod
    def _build_bullets(items: list[ItemSourcePayload], themes: list[str]) -> list[str]:
        bullets: list[str] = []
        for item in items[:3]:
            descriptor = item.cleaned_excerpt or item.snippet or ''
            if descriptor:
                bullets.append(f'{item.page_title or item.title}: {descriptor[:140].strip()}')
        if themes:
            bullets.append(f'Repeated terms across sources: {", ".join(themes[:4])}.')
        return bullets[:4]
