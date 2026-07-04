# Backend: дрібніші проблеми якості (фільтр помилок, кеш, мертвий код)

- **Пріоритет:** P2/P3 — важливе/бажане
- **Репозиторій:** tesla-backend
- **Статус:** TODO

## Список

1. **PrismaExceptionFilter маскує інфраструктурні помилки під 400** — `prisma.filter.ts:28-33`: default-гілка повертає Bad Request для будь-якого невідомого P-коду (включно з проблемами з'єднання) — має бути 500, інакше моніторинг сліпне.
2. **Немає HTTP-кешування публічного каталогу** — `catalog.controller.ts`: жодного `Cache-Control`/ETag на `GET /catalog/*` — кожен хіт іде в БД.
3. **Пошукове сортування без відповідного індексу** — `catalog.service.ts:160-170`: `ORDER BY GREATEST(word_similarity(...))` не покривається GIN (потрібен GiST для similarity-ordering) — full scan на кожен саджест; на поточному обсязі прийнятно.
4. **`uniqueSlug` — цикл запитів із race** — `products.service.ts:167-180`: конкурентний запит дасть P2002/Conflict замість ретраю.
5. **topProducts у wishlist-адмінці ігнорує фільтр** — `wishlist.service.ts:104-109`: `groupBy` без `where`, хоча список поруч фільтрується за `productId`.
6. **Мертві залежності/конфіг** — `axios`, `resend` у deps; `ScheduleModule.forRoot()` без жодного `@Cron`; env `NOVA_POSHTA_API_KEY`, `RUN_CRON` не використані — шум, що маскує реальний стан.
7. **Схема попереду коду** — моделі `Address`, `BlogPost`, `Banner`, `Redirect` без жодного API; `endpoints.constant.ts:12-27` заявляє forgot/reset-password, USERS, ACCOUNT — ендпоінтів немає. Позначити як план або видалити.
