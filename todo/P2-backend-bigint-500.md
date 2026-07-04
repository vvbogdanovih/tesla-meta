# BigInt(id) у контролерах без обробки → 500 на невалідний id

- **Пріоритет:** P2 — важливий (стабільність API)
- **Репозиторій:** tesla-backend
- **Статус:** TODO

## Проблема

`GET /api/products/abc` кидає неспійманий `SyntaxError` від `BigInt('abc')` → 500 замість 400. Сервіси мають `parseId`, а контролери викликають `BigInt()` напряму.

## Де в коді

- `src/modules/products/products.controller.ts:25,35,40`
- `src/modules/orders/orders.controller.ts:45`
- `src/modules/leads/leads.controller.ts:33,40`

## Що зробити

Ввести спільний `ParseBigIntPipe` (кидає `BadRequestException` на невалідне значення) і застосувати до всіх `:id`-параметрів замість прямих викликів `BigInt()`.
