# Немає тестів на критичні флоу (усі три репо)

- **Пріоритет:** P2 — важливо (гроші, склад, доступ)
- **Репозиторії:** tesla-backend, tesla-frontend, tesla-admin
- **Статус:** TODO (виявлено 17.07.2026)

## Проблема

Наявні тести покривають переважно чисту логіку; критичні e-commerce-флоу з реальними грошима — ні.

**tesla-backend** (184 unit-тести зелені, але):
- `delivery-np` — 0 spec: складна логіка чанків, мапінгу типів, атомарної заміни дзеркала, парсингу ваги.
- `leads` — 0 spec: публічна форма + admin CRUD.
- `cars`, `categories`, `content-blocks`, `stats` — 0 (нижчий ризик, P3).
- e2e (`test/*.e2e-spec.ts`) є для auth/catalog/products/payment-requisites — потребують Docker (Testcontainers).

**tesla-frontend** (36 тестів — лише pure logic: phone, cart store, схеми):
- 0 component/integration тестів (`@testing-library/react` встановлено, не використовується для рендер-тестів);
- 0 e2e/Playwright (немає залежності й конфіга);
- не протестовано: сабміт checkout (mapping payload, save-to-profile), infinite scroll, каталог-фільтри, wishlist optimistic, auth з refresh-retry, застосування збережених адрес.

**tesla-admin** (22 тести — build-product-payload, http, slugify; MSW встановлено, не задіяно):
- не протестовано: замовлення (зміна статусу/оплати, cancel/restore), ліди, контент-блоки (TipTap save), НП-синхронізація, платіжні реквізити (superadmin-гейтинг + маскування секретів).

## Що зробити

1. Backend: unit-spec для `delivery-np` та `leads`.
2. Frontend: хоча б smoke-e2e на checkout (mapping payload, monopay) + component-тести каталог-фільтрів/wishlist.
3. Admin: інтеграційні тести (через MSW) на orders-статуси/оплату та реквізити.
