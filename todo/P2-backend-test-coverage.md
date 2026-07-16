# Тестами покрито 5 модулів з ~18 — payment-requisites (шифрування) без тестів

- **Пріоритет:** P2 — важливий (якість)
- **Репозиторій:** tesla-backend
- **Статус:** TODO

## Проблема

Unit-spec є для auth/catalog/products/orders/payments; e2e (Testcontainers) — auth/catalog/products. Нуль тестів: **payment-requisites** (шифрування!), wishlist, leads, addresses, profile, s3, content-blocks, cars, categories, stats, delivery-np.

## Де в коді

- `test/`, `src/**/*.spec.ts` — 5 модулів з ~18

## Що зробити

Пріоритет покриття:
1. **payment-requisites** — шифрування/маскування секретів (`toSafe`, write-only), доступ superadmin-only.
2. **wishlist** — ідемпотентність, guards.
3. **addresses/profile** — нові CRUD (ADR-0017): ownership, `isDefault`, зміна пароля.

Також переглянути повноту наявного `orders.spec` (знімок цін, транзакція залишків, скасування). Інфраструктура (jest + Testcontainers) вже налаштована — треба лише дописати сьюти.
