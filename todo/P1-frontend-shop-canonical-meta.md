# /shop без canonical і динамічних meta — дублікатні сторінки

- **Пріоритет:** P1 — критичний (SEO)
- **Репозиторій:** tesla-frontend
- **Статус:** TODO

## Проблема

`/shop` має статичний title для всіх комбінацій `?category=&car=&page=` — сотні дублікатних сторінок без канонізації з'їдять crawl budget і розмиють релевантність. Те саме — `/price-sheet`.

## Де в коді

- `src/app/shop/page.tsx:8-12` — статичні metadata
- `src/app/price-sheet/page.tsx:7` — те саме

## Що зробити

1. `generateMetadata` на `/shop`: динамічний title/description за обраною категорією/моделлю авто; для пагінації — «Сторінка N».
2. Canonical: базовий `/shop` (або `/shop?category=x` для категорійних сторінок) без зайвих параметрів сортування/фільтрів.
3. Для `/price-sheet` — окреме рішення canonical (див. P3-docs-seo-strategy-gaps: ризик duplicate content з `/shop`).
