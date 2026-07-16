# PLAN-P2 — підсумок реалізації (15–16.07.2026)

> Детальні покрокові інструкції виконаних задач прибрано (є в git-історії файлу). Лишилось: зведення змін по репо (основа для commit-повідомлень), відкриті хвости та невиконаний M3.
> **Зміни в усіх трьох app-репо НЕ закомічені. Коміт/пуш — лише з явної згоди користувача.**

## Зведення змін (для комітів)

### tesla-backend (~37 файлів; 2 Prisma-міграції застосовані до dev-БД)

- **B1** — `ParseBigIntPipe` (+спека): 400 замість 500 на невалідний `:id` у products/orders/leads/payment-requisites; `orders.findById` уніфіковано на `bigint`.
- **B2** — Prisma-фільтр: невідомі P-коди → 500 + `Logger.error`; `Cache-Control: public, max-age=60, swr=300` на GET каталогу і публічних реквізитах; retry slug-P2002 у `create()`; `where` у wishlist topProducts; видалено `resend` (+env-константи; `axios` живий — monopay/НП); мертві блоки з `endpoints.constant.ts`; коментарі «ЗАПЛАНОВАНО» над BlogPost/Banner/Redirect.
- **B3** — Swagger лише поза prod; `forbidNonWhitelisted: true` (аудит клієнтських payload'ів: 0 розбіжностей); json limit 10mb → 1mb (аплоад — multipart зі своїм 10MB); `strict: true` (35× TS2564 → `!` у DTO).
- **B4** — модель `RefreshSession` (міграція `20260716064812_refresh_sessions`): ротація jti, reuse-детекція (повтор старого токена → відкликання всіх сесій), logout інвалідовує, changePassword скидає сесії; `RolesGuard` звіряє роль із БД (validate() не чіпали); пароль 8+ (register/change-password DTO + фронтові схеми).
- **B5** — HEIC: `heic-convert` (WASM; sharp без HEVC), `isHeic` з перевіркою ftyp, whitelist розширено; PresignDto свідомо ні.
- **B6** — мініатюри: `ProductImage.thumbUrl` (міграція `20260716070155`), 400px `_w400.avif` при аплоаді, прокинуто в catalog/wishlist-селекти; `scripts/backfill-thumbs.ts` створено, **не запущено**. `orders.listForUser` і `search` лишили одинарний `image` — свідомо (інший контракт).
- **B7** — тести: 15 сьютів / **184 зелених** (crypto.util, payment-requisites, wishlist, addresses, profile, orders-доповнення); покриття цільових сервісів 97–100%; виправлено давній failing `listForUser`; slugify-контракт (15 векторів, дзеркало admin); у `jest.setup.ts` — `PAYMENT_ENC_KEY`.

### tesla-admin (~25 файлів + 7 нових)

- **A0** — спільні `Field`/`LoadingState`/`EmptyState`/`ErrorState`/`ConfirmDialog`/`useDebounce`.
- **A1** — `src/proxy.ts` (Next 16-конвенція, перевірено емпірично): наявність refresh-cookie → далі, інакше redirect `/login`; env `AUTH_COOKIE_NAMES`; прод-застереження про host-only cookie — в коментарі файлу.
- **A2** — error-стани з retry на всіх сторінках; `products/[id]` без вічного спінера (404 → «Товар не знайдено»); zod-схеми відповідей (`schemas/api/`, `satisfies z.ZodType`) для products/payment-requisites; 7× `confirm()` → `ConfirmDialog`; login: try/catch + `setError('root')` + `skipErrorToast`.
- **A3** — HEIC у `accept` (ProductForm, cars) + читабельна помилка 400/422 в upload.service.
- **A4** — vitest (happy-dom + msw): **22 тести** — slugify-контракт, single-flight refresh (3×401 → один /auth/refresh), `buildProductPayload` (винесено з ProductForm у чисту функцію).
- **A5** — дедуплікація: 4 локальні `Field` → спільний; Loader2-розсип → states; empty-state у content; стабільні `uid`-ключі характеристик; `useDebounce` на 3 сторінках (скидання page — adjust-during-render, не useEffect: lint); видалено `sharp`, `ROLES`/`ANY_AUTHENTICATED`, `UPLOAD.PRESIGN`, **Topbar повністю**; fail-fast `API_BASE_URL`; CLAUDE.md адмінки оновлено. `DataTable` — свідомо відкладено.

### tesla-frontend (~24 файли + 17 нових)

- **F1** — видалено deps `sharp`/`react-query-devtools`/`radix-ui`/`react-icons` і константу `BLOG`; `contacts.constants.ts` (канон із seed); Footer на константах + `tel:` + динамічний рік; «Понад 1000» — з `featured.total`.
- **F2** — Organization JSON-LD у layout; Product JSON-LD доповнено (`description` через `stripHtml`, `brand: Tesla` лише для оригіналів, `itemCondition` new/used/clearance, `priceValidUntil` +30 діб); `manifest.ts`; `icon.png`/`apple-icon.png`/`opengraph-image.png` (згенеровані з logo.png, перефарбування у білий на #0b0d10 — **переглянути візуально**).
- **F3** — спільний `ui/Modal` (dialog-role, Escape, scroll-lock, focus-повернення); `lead.schema.ts`; LeadButton на RHF+zod з `'use no memo'`; LoginGateModal мігровано. + виправлено **3 справжні lint-помилки** `set-state-in-effect` (SearchBox, QtyStepper, NpDeliveryPicker) — ідіоматично, без eslint-disable; `yarn lint` = 0.
- **F4** — `useReducedMotion`; `HeroVideo` (постер завжди; 2.6MB mp4 — лише desktop і без reduce); глобальне css-правило reduced-motion.
- **F5** — `thumbUrl?` у типі + `thumbSrc()` з фолбеком; застосовано в PriceSheet/ProductCard/ProductGallery-стрічці/LivePhotos-стрічці/AddToCart; головні фото, лайтбокс і JSON-LD — повний `url`.
- **F6** — vitest (jsdom): **36 тестів** — cart store (clamp/persist), lead.schema, phone-утиліти, checkout.schema (винесено з page у `checkout.schema.ts`, superRefine-гілки np/ukrposhta).

### tesla-meta (доки)

- **M1** — ADR-0008 заголовок/README/CLAUDE + monopay; CLAUDE.md `0001..0017`; ADR-0011 → §3.3a; FRD §6: `is_live`+`thumb_url`, блок `wishlist_items`, прибрано привид `system_id`; версії в docs/README (PRD v1.2, seo-strategy v1.1, додано integration-1c і migration-runbook в індекс).
- **M2** — FRD §5: +stats/health, НП-рядок → реальні ендпоінти з дзеркала БД; backend-architecture: `/api` (без v1), `/swagger` + «вимкнено в prod», §3 → фактичні 17 модулів (неіснуючі — *(план)*), §10 п.1 → вирішено ADR-0015; db-schema §3: trigram нативно (extensions+ops:raw), GIN-індекси в Prisma-блоці, чесне розмежування native vs raw (orders/np — raw). Версії: FRD 1.3, db-schema 1.2, backend-architecture 1.1.
- **M4** — `docs/migration-runbook.md` (Draft v1.0): 7-кроковий ETL WooCommerce → новий стек.

## Відкриті хвости

1. **Запустити `scripts/backfill-thumbs.ts`** (backend, разово, проти БД+R2) — мініатюри для наявних фото; фронт до того працює через фолбек `thumbUrl ?? url`. Чекає згоди користувача (пише у спільні dev-БД і R2).
2. Опційно: `DataTable` в адмінці (A5.7); стиснення `hero.mp4` до ~1MB — ffmpeg локально відсутній (`brew install ffmpeg`; після F4 відео і так лише desktop без reduce).

**Закрито 16.07 (друга сесія):**
- ✅ Іконки переглянуто візуально — логотип читабельний, емблема збережена.
- ✅ Смок proxy: без cookie `/products` → 307 `/login`; `/login` 200; з cookie — 200.
- ✅ Смок HEIC: справжній HEVC-heic (sips) → `heic-convert` → sharp → 400px AVIF — наскрізно працює.
- ✅ e2e 403 payment-requisites: 3 нові кейси (401/403/200), повний e2e — 25/25 у Docker.
- ✅ Док-sync: `RefreshSession` у db-schema (v1.3; +2 дрейф-фікси: `warehouseType` enum, індекс Address) та НП-референси у FRD §6 `addresses`.

## Деплой (коли дійде; зараз не потрібен)

- Порядок: **backend → admin/frontend** (HEIC-accept в адмінці вимагає нового бекенда; фронтові thumb'и — fallback-safe).
- Після деплою B4 старі refresh-токени (без jti) невалідні → користувачі разово перелогіняться.
- Прод-обмеження proxy: auth-cookie host-only — потрібен спільний host (reverse proxy) або `Domain=.site.com` / маркер-cookie (варіанти — в коментарі `src/proxy.ts`).
- Прод-міграції: `prisma migrate deploy` (дві нові: `refresh_sessions`, `product_image_thumb_url`).

## M3 — `docs/deployment.md` (НЕ виконано; відкладено 16.07 — деплоймент зараз не потрібен)

Потребує фактів від користувача: хостинг/VPS, домени проду, чи є staging, де зберігаються ключі зараз, куди шипити логи.

Структура документа:
1. Середовища й домени (dev-порти з CLAUDE.md; prod: frontend 3000, admin 3001, backend 4040 — reverse proxy?).
2. Env-змінні per-repo (backend — `env.constant.ts`; frontend/admin — `.env.example`); окремо секрети: `PAYMENT_ENC_KEY`, `JWT_SECRET`/`REFRESH_JWT_SECRET`, pepper, `API_PUBLIC_URL`, `AUTH_COOKIE_NAMES`.
3. CI/CD: зараз немає ані workflows, ані Dockerfile — мінімальний пайплайн lint → tsc → tests → build; `prisma migrate deploy` у деплої.
4. Бекапи: PostgreSQL (pg_dump розклад/ретенція/тест відновлення), R2 (versioning або rclone-дзеркало).
5. Ротація ключів: `PAYMENT_ENC_KEY` (втрата = нечитабельні платіжні секрети → розшифрувати всі → перешифрувати → атомарна заміна), JWT-секрети (інвалідація — таблиця `refresh_sessions`).
6. Моніторинг/логи (pino вже в коді; куди шипити — питання).
