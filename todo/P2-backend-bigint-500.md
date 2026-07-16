# BigInt(id) у контролерах без обробки → 500 на невалідний id

- **Пріоритет:** P2 — важливий (стабільність API)
- **Репозиторій:** tesla-backend
- **Статус:** TODO

## Проблема

`GET /api/products/abc` кидає неспійманий `SyntaxError` від `BigInt('abc')` → 500 замість 400. Сервіси мають `parseId`, а контролери викликають `BigInt()` напряму.

## Де в коді

- `src/modules/products/products.controller.ts:26,36,41`
- `src/modules/orders/orders.controller.ts:59,66` (+ `byId` :45 — уніфікувати)
- `src/modules/leads/leads.controller.ts:33,40`
- `src/modules/payment-requisites/payment-requisites.controller.ts:29,34` (знайдено 15.07)

## Що зробити

Ввести спільний `ParseBigIntPipe` (кидає `BadRequestException` на невалідне значення) і застосувати до всіх `:id`-параметрів замість прямих викликів `BigInt()`.
