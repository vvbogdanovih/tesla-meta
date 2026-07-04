# SEO-дрібниці: Organization JSON-LD, неповний Product JSON-LD, manifest/og:image

- **Пріоритет:** P2 — важливий (SEO)
- **Репозиторій:** tesla-frontend
- **Статус:** TODO

## Проблема

1. Немає **Organization JSON-LD** (вимога CLAUDE.md фронта: Product/BreadcrumbList/Organization) — є лише Product+Breadcrumb на сторінці товару.
2. **Product JSON-LD неповний**: немає `description`, `brand`, `itemCondition` (стан new/used — ключова властивість товару), `offers.priceValidUntil` — Google Merchant/rich results дадуть warnings.
3. Немає `manifest.webmanifest`, apple-touch-icon, дефолтного `og:image` — лише favicon.ico.

## Де в коді

- `src/app/product/[slug]/page.tsx:83-113` — JSON-LD Product+Breadcrumb
- `src/app/layout.tsx` — місце для Organization JSON-LD і metadata

## Що зробити

1. Organization JSON-LD у кореневий layout (назва, лого, контакти, соцмережі).
2. Доповнити Product JSON-LD: `description`, `brand`, `itemCondition` (`NewCondition`/`UsedCondition`), `priceValidUntil`.
3. Додати webmanifest, apple-touch-icon, дефолтний og:image.
