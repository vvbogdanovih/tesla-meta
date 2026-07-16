# Backend: дрібніші проблеми якості (фільтр помилок, кеш, мертвий код)

- **Пріоритет:** P2/P3 — важливе/бажане
- **Репозиторій:** tesla-backend
- **Статус:** TODO

## Список

1. **PrismaExceptionFilter маскує інфраструктурні помилки під 400** — `prisma.filter.ts:24-30`: default-гілка повертає Bad Request для будь-якого невідомого P-коду (включно з проблемами з'єднання) — має бути 500, інакше моніторинг сліпне.
2. **Немає HTTP-кешування публічного каталогу** — `catalog.controller.ts`: жодного `Cache-Control`/ETag на `GET /catalog/*` — кожен хіт іде в БД (довідники НП уже кешуються — `delivery-np.controller.ts`; каталог — ні).
3. **Пошукове сортування без відповідного індексу** — `catalog.service.ts:160-170`: `ORDER BY GREATEST(word_similarity(...))` не покривається GIN (потрібен GiST для similarity-ordering) — full scan на кожен саджест; на поточному обсязі прийнятно.
4. **`uniqueSlug` — цикл запитів із race** — `products.service.ts:143-151`: конкурентний запит дасть P2002/Conflict замість ретраю.
5. **topProducts у wishlist-адмінці ігнорує фільтр** — `wishlist.service.ts:85`: `groupBy` без `where`, хоча список поруч фільтрується за `productId`.
6. **Мертва залежність** — `resend` у deps не імпортується (+ мертві env `RESEND_API_KEY`/`SERVICE_EMAIL`/`ALLOW_EMAIL_SENDING`). `axios` — НЕ мертвий: використовується `monopay.client.ts` і `nova-poshta.client.ts` (уточнено 15.07).
7. **Схема попереду коду** — моделі `BlogPost`, `Banner`, `Redirect` без жодного API; `endpoints.constant.ts` заявляє forgot/reset-password, USERS — ендпоінтів немає. Позначити як план або видалити.

> Виконано раніше (перевірено 15.07): `@Cron` тепер є (`np-sync.service.ts`, `RUN_CRON` використовується); `Address` отримав CRUD (`addresses`-модуль, ADR-0017) + додано `profile`-модуль.
