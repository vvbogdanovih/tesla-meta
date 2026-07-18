# TODO — аудит проєкту

Один файл = одна проблема. Пріоритети: **P1** — критичне (виправити перед запуском), **P2** — важливе, **P3** — бажане/документація/борг. Після виконання — видаляти файл.

## Історія

- **Аудит 01.07.2026** — P1 закрито 06.07; P2+P3 реалізовано 15–16.07 (див. [PLAN-P2.md](PLAN-P2.md), деталі в git-історії). Закриті файли видалено.
- **Аудит 17.07.2026** — свіжий наскрізний аудит трьох app-репо + звірка вимог (FRD/PRD/ADR/runbook) з кодом. Знахідки нижче.

## P1 — критичне (перед запуском)

| Файл | Репо | Суть |
|---|---|---|
| [P1-frontend-committed-tokens](P1-frontend-committed-tokens.md) | frontend | `c.txt` із живим JWT суперадміна відстежується git → видалити + **ротувати JWT-секрет** |
| [P1-frontend-build-breaks-without-backend](P1-frontend-build-breaks-without-backend.md) | frontend | `/kontakty`, `/pro-nas` валять `yarn build` без бекенда (немає try/catch) |
| ~~P1-backend-order-enumeration~~ | backend | ✅ Виконано 17.07.2026 — додано `Order.publicId` (UUID v7); публічні order/payment-ендпоінти переведено на нього (backend+frontend, білд/тести зелені). Лишилось на деплої: `prisma migrate deploy` |
| [P1-migration-etl-script](P1-migration-etl-script.md) | backend | Немає повноцінного ETL-скрипта міграції 1000+ SKU (лише scrape+seed) — блокер запуску |
| [P1-seo-301-redirects](P1-seo-301-redirects.md) | frontend/backend | Немає механізму 301-редиректів. **Умовний** — блокер, якщо GSC підтвердить індексацію (ADR-0001 Proposed) |

## P2 — важливе

| Файл | Репо | Суть |
|---|---|---|
| [P2-tests-critical-flows](P2-tests-critical-flows.md) | усі | Немає тестів на checkout/оплату/статуси, delivery-np, leads, реквізити |
| [P2-seo-gaps](P2-seo-gaps.md) | frontend | ЧПУ `/category/*`, metadata головної, `/wishlist` noindex, LCP `priority`, GA4-аналітика |
| [P2-missing-features](P2-missing-features.md) | admin/frontend | Розділи «Користувачі»/«Банери»/«Блог» (ComingSoon), юр-сторінки, відновлення пароля, price-slider, нотифікації лідів |
| [P2-backend-1c-integration](P2-backend-1c-integration.md) | backend | ADR-0016 не реалізовано (немає `externalId`, pull/push) |
| [P2-admin-api-contract](P2-admin-api-contract.md) | admin | Zod-валідація у 3/11 сервісів; звірити `Order.payment` після ADR-0013; enforcement реквізитів на бекенді |
| [P2-backend-lint-hardening](P2-backend-lint-hardening.md) | backend | `yarn lint` червоний (79 errors); floating `bootstrap()` |

## P3 — бажане / борг / документація

| Файл | Репо | Суть |
|---|---|---|
| [P3-frontend-a11y](P3-frontend-a11y.md) | frontend | `<label>` без `htmlFor` у формах |
| [P3-tech-debt](P3-tech-debt.md) | усі | DataTable, TipTap контракт-тест, ES2022, HEIC-декодер, `migrate status` |
| [P3-docs-consistency](P3-docs-consistency.md) | meta+код | НП trigram-індекси, шлях schema.prisma, FR↔код розбіжності, відкриті питання FRD §8 |
| [P3-docs-deployment](P3-docs-deployment.md) | meta | `docs/deployment.md`: CI/CD, бекапи, ротація ключів. **Відкладено** — потребує фактів від користувача |

## Хвости з попереднього аудиту (PLAN-P2)

- Запустити `scripts/backfill-thumbs.ts` (мініатюри для старих фото) — разово, проти БД+R2; чекає згоди користувача.
- Опційно: стиснення `hero.mp4` (потрібен ffmpeg).
- Порядок деплою: backend → admin/frontend; після auth-hardening користувачі разово перелогіняться.

## Загальна оцінка (17.07.2026)

Технічна якість реалізованого — **висока**: чиста архітектура, повний RBAC, шифрування секретів, робочі monopay/НП-синхронізація, схема БД майже 1:1 з docs. Застосунок функціонально близький до MVP по користувацьких сценаріях. **Не готовий до продакшн-запуску** через: (1) відсутність міграційного пайплайну, (2) безпековий P1 (токени в git; енумерацію замовлень закрито 17.07 через `publicId`), (3) залежність по редіректах від GSC. Основний борг — міграція, SEO-роутинг категорій, аналітика й тести критичних флоу.
