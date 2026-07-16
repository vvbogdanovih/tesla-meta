# CLAUDE.md

Guidance for Claude Code when working in **tesla-meta** — координаційний/документаційний репозиторій проєкту «Tesla Spare Parts Lviv» (оригінальні/аналогові запчастини Tesla, ринок України; реплатформінг із WordPress+WooCommerce на власний стек).

Цей репозиторій — **джерело правди** для вимог, архітектури та дизайну. Код живе у трьох app-репо.

## Структура

```
docs/
├── PRD.md · FRD.md            # продуктові та функціональні вимоги (звірені з реальним сайтом)
├── current-site-audit.md      # аудит teslalviv.com
├── seo-strategy.md            # SEO (критичний пріоритет)
├── design-principles.md       # дизайн-система: токени, типографіка, контейнер
├── db-schema.md               # Prisma-схема + ER-діаграма
├── backend-architecture.md
├── adr/                       # Architecture Decision Records (0000-template + 0001..0017)
└── assets/                    # живі HTML-референси сторінок + logo.png + hero
scripts/clone-repos.sh         # клонує 3 app-репо у repos/ (gitignored)
repos/                         # робочі копії app-репо (поза git)
```

## App-репозиторії

| Репо | Стек | Порти (dev / prod) |
|---|---|---|
| **tesla-backend** | NestJS 11 · Prisma 7 · PostgreSQL · S3/R2 | 4040 |
| **tesla-frontend** | Next.js 16 · React 19 · Tailwind v4 | 3040 / 3000 |
| **tesla-admin** | Next.js 16 · React 19 · Tailwind v4 · TipTap | 3030 / 3001 |

Кожне app-репо має власний `CLAUDE.md`. Клонувати: `bash scripts/clone-repos.sh`.

## Ключові рішення (див. ADR)

- **0001** — структура URL та редіректи (реклама/індексація ще не запускались).
- **0002** — каталог і сумісність: товар — єдиний канонічний запис; авто (`ProductFitment`, M2M) — фільтр, не власник; `Category` — глобальна таксономія.
- **0003** — PostgreSQL.
- **0004** — окрема admin-аплікація + ролі user/admin/superadmin.
- **0005** — порядок реалізації: адмінка спершу.
- **0006** — rich text: TipTap, зберігати **JSON** (джерело правди) + **HTML** (санітизований, для SSR).
- **0007** — зображення: конвертація у **AVIF** на бекенді (sharp), проксі-аплоад.
- **0008** — реквізити продавця + канали **IBAN/LiqPay/monopay**; секрети зашифровано, доступ superadmin.
- **0009** — наскрізні тексти (гарантія/доставка) — сутність **ContentBlock**, не поля товару.
- **0010** — єдина сутність **User + роль** (без розділення профілів).
- **0011** — **price-sheet**: табличний вигляд каталогу (`/price-sheet`), той самий ендпоінт `+ include=fitment`, нескінченний скрол.
- **0012** — **обране (wishlist)**: авторизований сигнал інтересу (модель `WishlistItem`), ♡ лише для залогінених; адмінам видно попит/контакти під розділом «Ліди».
- **0013** — **Order**: `paymentStatus`/`paymentMethod`/`deliveryMethod` винесено з JSON у колонки (+ trigram-пошук за телефоном/email); `payment` jsonb прибрано (була порожня); `customer`/`delivery` — лише снапшот; форма API незмінна (композиться з колонок).
- **0014** — **Nova Poshta**: дзеркало довідника (`np_cities`/`np_warehouses`) у БД; автопідказки в чекауті — зі своєї бази; синхронізація cron (`RUN_CRON`) + кнопка superadmin у розділі «Налаштування»; тип відділення `branch/postomat/cargo`.
- **0015** — **monopay** (Monobank acquiring): онлайн-оплата карткою (метод `card`); токен `X-Token` у `PaymentRequisite.monopayToken` (зашифровано), не env; інвойс → `pageUrl` → вебхук (`X-Sign`) / поллінг оновлюють `Order.paymentStatus`; `Order.paymentInvoiceId` привʼязує колбек; `API_PUBLIC_URL` — для `webHookUrl`.
- **0016** — **інтеграція з 1С**: сайт-ініціатор (1С — HTTP-сервер, сайт — клієнт «дьоргає»); контракт site-agnostic (1С налаштовується раз → N сайтів). Наявність + базова ціна — pull cron у `Product.stockQty`/кеш (знижку рахує сайт); замовлення — push у 1С одразу після створення, **ідемпотентно** за `externalId`; статус/оплата — сайт джерело, push у 1С. Ключ матчингу — `sku`. Повне ТЗ: `docs/integration-1c.md`.
- **0017** — **збережені адреси доставки**: лише для авторизованих (модель `Address`); у checkout — картки-радіо збережених адрес + «Нова адреса» з чекбоксом «Зберегти в профіль» (перша → `isDefault`); профіль — CRUD адрес; `Address` розширено НП-референсами `cityRef`/`warehouseRef`/`warehouseType` (відновлення combobox + ТТН); снапшот `Order.delivery` незалежний (ADR-0013); гість — без збереження, лише нудж на вхід.

## Conventions

- Уся продуктова документація та UI-тексти — **українською**.
- Діаграми — **Mermaid**.
- Архітектурні рішення оформлювати як ADR (копія `adr/0000-template.md`).
- **Коміт/пуш у будь-якому репо — лише з явної згоди користувача.**
