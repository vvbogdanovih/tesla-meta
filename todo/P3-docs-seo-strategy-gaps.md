# seo-strategy.md відстала від ADR-0011/0012 (price-sheet, wishlist)

- **Пріоритет:** P3 — документація (SEO-критичний проєкт)
- **Репозиторій:** tesla-meta
- **Статус:** TODO

## Проблема

`docs/seo-strategy.md` (v1.0, 27.06) не згадує:

1. **`/price-sheet`** (ADR-0011 декларує «власне SEO») — потенційний duplicate content з `/shop`; потрібне явне рішення: індексувати як окрему сторінку чи canonical на `/shop`, і як поводитись із фільтр-параметрами.
2. **`/wishlist` → noindex** — зараз це записано лише у FRD FR-W6 і ADR-0012, у SEO-стратегії відсутнє.

## Що зробити

Додати в seo-strategy.md розділ про нові сторінки: рішення canonical/індексації для `/price-sheet`, noindex для `/wishlist`, підняти версію документа. Рішення потім відобразити в коді фронта (пов'язано з P1-frontend-shop-canonical-meta).
