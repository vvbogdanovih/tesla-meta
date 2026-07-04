# Немає rate limiting і security-заголовків

- **Пріоритет:** P1 — критичний (безпека)
- **Репозиторій:** tesla-backend
- **Статус:** TODO

## Проблема

`@nestjs/throttler` відсутній у `package.json` — публічні `POST /auth/login`, `POST /leads`, `POST /orders` відкриті для брутфорсу паролів та спаму лідами/замовленнями в БД. Також немає `helmet` — жодних security-заголовків (CSP, X-Frame-Options тощо) для API, що обслуговує кукі-авторизацію.

## Де в коді

- `src/modules/auth/auth.controller.ts:24` — `POST /auth/login` без ліміту
- `src/modules/leads/leads.controller.ts:17` — `POST /leads` без ліміту
- `src/modules/orders/orders.controller.ts:21` — `POST /orders` без ліміту
- `src/main.ts` — немає helmet

## Що зробити

1. Додати `@nestjs/throttler`: глобальний помірний ліміт + жорсткі ліміти на auth/leads/orders (напр. 5 req/min на login).
2. Додати `helmet` у `main.ts`.

Дві залежності та ~15 рядків коду — найбільший security-ефект за найменшу ціну.
