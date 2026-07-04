# Sitemap без товарів + биті лінки в sitemap/Header/Footer

- **Пріоритет:** P1 — критичний (SEO — пріоритет №1 проєкту)
- **Репозиторій:** tesla-frontend
- **Статус:** TODO

## Проблема

`sitemap.ts` містить шість неіснуючих сторінок (`/about`, `/contacts`, `/delivery`, `/returns`, `/blog` → 404) і **не містить жодного товару чи категорії** — основний SEO-актив (тисячі продуктових URL) невидимий для пошуковика, а карта сайту бита. Ті самі биті посилання — наскрізно в Header («Про нас», «Контакти») та Footer (Блог, Доставка, Повернення, Оферта) на кожній сторінці.

## Де в коді

- `src/app/sitemap.ts:7` — статичний список з 404-сторінками, без products/categories
- `src/common/components/layout/Header.tsx:52-53`
- `src/common/components/layout/Footer.tsx`

## Що зробити

1. Зробити sitemap динамічним: підтягувати всі товари й категорії з API бекенда (`/catalog`), з `lastModified`.
2. Прибрати з sitemap і з Header/Footer лінки на неіснуючі сторінки — або створити ці сторінки через ContentBlock (ADR-0009).
