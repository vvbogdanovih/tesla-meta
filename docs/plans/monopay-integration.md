# План імплементації: онлайн-оплата через monopay (Monobank acquiring)

> Статус: **усі етапи 1–4 реалізовані** (2026-07-05). Лишилось живе тестування з тестовим токеном
> monopay (див. нижче). Токен зберігається в БД (`PaymentRequisite.monopayToken`), рішення користувача —
> **env-змінна `MONOBANK_API_KEY` не потрібна**.
>
> **Залишок для живого тесту:** (1) внести тестовий токен monopay у розділі «Реквізити» й активувати
> канал; (2) пройти чекаут із «Картка онлайн» → оплата → повернення на success; (3) звірити
> інтерпретацію `basketOrder[].sum` (чек); (4) для вебхука — виставити `API_PUBLIC_URL` на публічний
> URL (у dev працює поллінг без нього).

## Що вже зроблено (етап 0 — готово)

- **tesla-backend**: `PaymentRequisite.monopayToken` (AES-256-GCM, write-only) + `monopayActive`,
  міграція `20260629094714_requisite_monopay`, сервіс `payment-requisites.service.ts` з
  `getActiveMonopayWithSecret()` (ніде ще не викликається).
- **tesla-admin**: сторінка «Реквізити» вже має поля monopay (page/types/schema/api).
- **Не зроблено**: створення інвойсів, вебхук, оплата на фронті.

## Ключові рішення (зафіксувати в ADR-0015)

1. **Метод оплати** — повторно використовуємо наявне enum-значення `PaymentMethod.card`
   (лейбл «Картка онлайн» уже є у фронті/адмінці). monopay — *провайдер* методу `card`,
   не окремий метод. Якщо колись додасться LiqPay — бекенд обиратиме активний провайдер.
2. **Зберігання invoiceId** — нова колонка `orders.payment_invoice_id TEXT NULL` + індекс
   (ADR-0013 передбачав «канал-деталі додамо колонкою за потреби»).
3. **Вебхук** — публічний `POST /api/payments/monopay/webhook`, перевірка підпису `X-Sign`
   (ECDSA SHA-256, публічний ключ з `GET /api/merchant/pubkey`, кешується). Потрібен **raw body**.
4. **Fallback без вебхука** (dev/пропущений колбек) — звірка статусу через
   `GET /api/merchant/invoice/status?invoiceId=` при поллінгу зі сторінки успіху.
5. **Нова env-змінна** `API_PUBLIC_URL` (опційна) — публічний URL бекенда для `webHookUrl`.
   Без неї інвойс створюється без вебхука (лише поллінг) — робочий режим для dev.

## Довідка: Monobank acquiring API

- База: `https://api.monobank.ua`, авторизація заголовком `X-Token` (токен з БД, розшифрований).
- `POST /api/merchant/invoice/create` → `{ invoiceId, pageUrl }`. Тіло:
  `amount` (копійки, integer!), `ccy: 980`, `merchantPaymInfo { reference: orderNumber,
  destination, basketOrder[] }`, `redirectUrl`, `webHookUrl`, `validity` (сек).
- Вебхук: POST з тілом-статусом інвойсу, заголовок `X-Sign` — base64 ECDSA-підпис raw body.
- Статуси інвойсу → `PaymentStatus`: `success → paid`, `failure | expired → failed`,
  `reversed → refunded`, `created | processing | hold → pending` (лишаємо).
- Тестування: тестовий токен з особистого кабінету monobank merchant.

---

## Етап 1 — Backend: модуль `payments` + міграція ✅ ГОТОВО (2026-07-04)

> Реалізовано і перевірено (build + 76 unit-тестів + boot, роути змаплені).
> Створено: `payments.module/service/controller`, `monopay.client`, DTO, специфікації
> `payments.service.spec` + `monopay.client.spec`. Міграція `20260704203115_order_payment_invoice_id`.
> `card` під'єднано до `orders.service.create` (повертає `paymentUrl`). Env: `API_PUBLIC_URL`.
> **Перевірити при живому тесті з тестовим токеном:** інтерпретацію `basketOrder[].sum`
> (зараз — ціна за одиницю в копійках; monobank може очікувати суму рядка). Сума платежу
> (`amount`) рахується authoritative з `order.total`, тож на факт оплати це не впливає — лише на чек.

<details><summary>Вихідний план етапу (для довідки)</summary>

### Етап 1 — Backend: модуль `payments` + міграція

**Файли (tesla-backend):**

- `src/database/prisma/schemas/schema.prisma` — `Order.paymentInvoiceId String? @map("payment_invoice_id")` + `@@index([paymentInvoiceId])`; міграція `yarn prisma migrate dev --name order_payment_invoice_id`.
- `src/common/constants/env.constant.ts` + `.env.example` — додати `API_PUBLIC_URL` (optional, url).
  Прибрати мертві `PAYMENT_PROVIDER/PAYMENT_PUBLIC_KEY/PAYMENT_PRIVATE_KEY` (ніде не використовуються).
- `src/common/constants/endpoints.constant.ts` — блок `PAYMENTS`.
- `src/modules/payments/monopay.client.ts` — HTTP-клієнт: `createInvoice()`, `getInvoiceStatus()`,
  `getPubkey()` (кеш у памʼяті). Токен передається аргументом, **ніколи не логувати**.
- `src/modules/payments/payments.service.ts`:
  - `createInvoiceForOrder(orderNumber)` — бере активний monopay-реквізит
    (`getActiveMonopayWithSecret()`), суму з `order.total` (→ копійки), `basketOrder` з items,
    `redirectUrl = FRONTEND_URL/order/{number}/success`,
    `webHookUrl = API_PUBLIC_URL/api/payments/monopay/webhook` (якщо є env); зберігає
    `paymentInvoiceId`. Помилка, якщо канал monopay неактивний або order не `card`/вже `paid`.
  - `handleWebhook(rawBody, xSign)` — верифікація підпису, мапінг статусу, ідемпотентне
    оновлення `paymentStatus` за `invoiceId`; відповідь 200 завжди швидко.
  - `syncStatus(orderNumber)` — fallback-звірка через status API (для поллінгу).
- `src/modules/payments/payments.controller.ts`:
  - `POST /payments/monopay/invoice` — тіло `{ orderNumber }`, повертає `{ pageUrl }` (повторна
    оплата зі сторінки успіху). Без auth-guard: orderNumber — непередбачуваний ідентифікатор;
    ендпоінт не розкриває даних замовлення, лише pageUrl.
  - `POST /payments/monopay/webhook` — публічний, raw body (`rawBody: true` у
    `NestFactory.create(..., { rawBody: true })` в `main.ts` + `@Req() req.rawBody`).
  - `GET /payments/monopay/status/:orderNumber` — поллінг зі сторінки успіху; викликає
    `syncStatus`, повертає `{ paymentStatus }`.
- `src/modules/orders/orders.service.ts` — у `create()`: якщо `paymentMethod === 'card'`,
  після створення замовлення викликати `createInvoiceForOrder` і додати `paymentUrl`
  у відповідь (без падіння всього create, якщо інвойс не створився — замовлення лишається,
  оплату можна повторити).
- `src/modules/orders/dto/create-order.dto.ts` — дозволити `card` у валідації paymentMethod.
- Тести: unit на мапінг статусів + верифікацію підпису (згенерувати тестову ECDSA-пару);
  оновити `orders.service.spec.ts`.

**Перевірка етапу:** `yarn lint && yarn test && yarn build`; Swagger показує нові ендпоінти.

</details>

## Етап 2 — Frontend: чекаут + сторінка успіху ✅ ГОТОВО (2026-07-04)

> Реалізовано і перевірено (`yarn build` — TypeScript чистий, lint на змінених файлах — 0 помилок).
> Створено `payments.api.ts` (invoice/status). `orders.api`: `card` у типі + `paymentUrl` у схемі.
> Чекаут: радіо «Картка онлайн» + редірект на `pageUrl` (`window.location.assign`). Сторінка успіху:
> поллінг статусу (4с, поки `pending`), бейдж статусу, кнопка «Перейти до оплати / Спробувати ще раз».
> Лейбли `paymentStatusLabel/Badge`. **Пропущено (опційно):** кнопка «Сплатити» у кабінеті
> `account/orders` — можна додати пізніше.

<details><summary>Вихідний план етапу (для довідки)</summary>

### Етап 2 — Frontend: чекаут + сторінка успіху

**Файли (tesla-frontend):**

- `src/app/checkout/page.tsx` — додати `card` у zod-enum і радіо «Картка онлайн
  (Apple Pay / Google Pay / mono)»; при сабміті з `card`: якщо відповідь містить `paymentUrl` —
  `window.location.href = paymentUrl` (замість редіректу на success).
- `src/common/services/orders.api.ts` — тип відповіді create з опційним `paymentUrl`;
  новий api-виклик `payments` (invoice/status).
- `src/app/order/[number]/success/page.tsx` — для замовлень `card`: показ статусу оплати,
  поллінг `GET /payments/monopay/status/:orderNumber` поки `pending` (з інтервалом і лімітом),
  кнопка «Сплатити» (повторний інвойс → редірект) для `pending/failed`.
- `src/common/constants/order-labels.constants.ts` — лейбл `card` уже є, перевірити.
- Кабінет (`account/orders`) — опційно: кнопка «Сплатити» для несплачених card-замовлень.

**Перевірка етапу:** чекаут з опцією «Картка онлайн», редірект на pageUrl (тестовий токен),
повернення на success, статус оновлюється.

</details>

## Етап 3 — Admin: дрібниці ✅ ГОТОВО (2026-07-05) — без змін коду

> Перевірено: сторінка «Реквізити» вже має поля monopay (`monopayToken`/`monopayTokenSet`/
> `monopayActive`), узгоджені з бекендом. Деталь замовлення вже показує `paymentStatus` (бейдж +
> дропдаун ручної зміни) — вебхук оновлює той самий статус. **Пропущено (опційно):** показ
> `paymentInvoiceId` в адмінці (потребує розширення `toFull` на бекенді — не робили).

## Етап 4 — Документація ✅ ГОТОВО (2026-07-05)

> ADR-0015 створено; `adr/README.md`, `db-schema.md` (колонка + ER), `backend-architecture.md`
> (модуль payments + інтеграція monopay + sequence-діаграма), `FRD.md` (FR-6.3/6.3a, ендпоінти,
> схема orders, відкрите питання), `CLAUDE.md` (рядок 0015) — оновлено.

<details><summary>Вихідний план етапів 3–4 (для довідки)</summary>

### Етап 3 — Admin: дрібниці

- Сторінка «Реквізити» — вже готова; перевірити збереження/активацію monopay вручну.
- Сторінка замовлення — переконатися, що `paymentStatus` відображається; опційно показати
  `paymentInvoiceId`. Врахувати, що статус тепер може змінюватися вебхуком.

## Етап 4 — Документація (tesla-meta)

- **ADR-0015** — «Онлайн-оплата monopay» (рішення з розділу вище, копія `adr/0000-template.md`).
- `docs/db-schema.md` — колонка `payment_invoice_id`.
- `docs/backend-architecture.md` — модуль payments, потік оплати (Mermaid sequence:
  checkout → create order → create invoice → pageUrl → webhook/поллінг → paid).
- `docs/FRD.md` — розділ оплати.
- `CLAUDE.md` (tesla-meta) — рядок 0015 у «Ключові рішення».

## Ризики / нюанси

- **Raw body для вебхука** — обовʼязково, інакше підпис не зійдеться (`rawBody: true` в Nest).
- **Сума в копійках** — `Decimal(12,2) * 100`, округлення `Math.round`.
- **Ідемпотентність вебхука** — monobank шле повтори; оновлення статусу має бути безпечним
  до повторів; не понижати `paid → pending` від запізнілого `processing`.
- **Секрет** — розшифрований токен живе лише в межах виклику сервісу, не логувати, не повертати.
- **Dev без публічного URL** — вебхук не прийде; поллінг-fallback покриває цей режим.
- **Коміти** — лише з явної згоди користувача (конвенція репо).

## Порядок роботи

Етапи виконуються по черзі: 1 (backend) → 2 (frontend) → 3 (admin) → 4 (docs).
Кожен етап завершується перевіркою і підтвердженням користувача перед наступним.
