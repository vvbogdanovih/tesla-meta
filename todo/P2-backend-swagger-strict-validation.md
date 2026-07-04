# Swagger відкритий у prod, TS strict вимкнено, ValidationPipe/body limit

- **Пріоритет:** P2 — важливий (безпека/якість)
- **Репозиторій:** tesla-backend
- **Статус:** TODO

## Проблема

1. **Swagger `/swagger` без захисту й без умови на `NODE_ENV`** — публічна мапа всієї API-поверхні у продакшені.
2. **TS strict вимкнено**: `noImplicitAny: false`, `strictBindCallApply: false`, немає `strict: true` — при тому, що обидва фронти strict-чисті.
3. **`ValidationPipe` без `forbidNonWhitelisted`** — зайві поля мовчки відкидаються; **глобальний body limit 10mb** приймається на всі ендпоінти, включно з публічними.

## Де в коді

- `src/main.ts:38` — Swagger
- `src/main.ts:24-25` — ValidationPipe, body limit
- `tsconfig.json`

## Що зробити

1. Swagger — лише при `NODE_ENV !== 'production'` (або за basic auth).
2. Увімкнути `strict: true`, виправити помилки поетапно.
3. `forbidNonWhitelisted: true`; body limit 10mb — тільки на маршрут аплоаду, глобально ~1mb.
