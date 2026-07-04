# Тестами покрито 3 модулі з 13 — orders (найризиковіший) без тестів

- **Пріоритет:** P2 — важливий (якість)
- **Репозиторій:** tesla-backend
- **Статус:** TODO

## Проблема

Unit і e2e (Testcontainers) є лише для auth/catalog/products (~530 рядків). Нуль тестів: **orders** (гроші, залишки, статуси), leads, wishlist, payment-requisites (шифрування!), s3, content-blocks, cars, categories, stats.

## Де в коді

- `test/`, `src/**/*.spec.ts` — покриті лише 3 модулі

## Що зробити

Пріоритет покриття:
1. **orders** — створення (знімок цін, транзакція залишків після фіксу P1-backend-orders-oversell), зміна статусу, публічний доступ за номером.
2. **payment-requisites** — шифрування/маскування секретів (`toSafe`, write-only), доступ superadmin-only.
3. **wishlist** — ідемпотентність, guards.
Інфраструктура (jest + Testcontainers) вже налаштована — треба лише дописати сьюти.
