# Адмін-списки бекенда без пагінації + відсутні індекси на createdAt

- **Пріоритет:** P2 — важливий (продуктивність)
- **Репозиторій:** tesla-backend
- **Статус:** TODO

## Проблема

Admin `GET /products`, `GET /orders`, `GET /leads` — `findMany` без `take`: при тисячах записів відповіді на мегабайти. Додатково: `orders` і `leads` сортуються за `createdAt desc`, але індексів на `createdAt` немає (лише `userId`/`status`).

## Де в коді

- `src/modules/products/products.service.ts:19-28`
- `src/modules/orders/orders.service.ts:110-116`
- `src/modules/leads/leads.service.ts:39-45`
- `schema.prisma:258-259` (orders), `schema.prisma:310` (leads) — індекси

## Що зробити

1. Пагінація за патерном з `catalog.service.ts:84-93` (`$transaction([findMany, count])` — він уже правильний).
2. Додати `@@index([createdAt])` для orders і leads (міграція).
3. Синхронно підключити пагінацію в UI адмінки (див. P1-admin-products-pagination-search).
