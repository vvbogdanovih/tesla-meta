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
├── adr/                       # Architecture Decision Records (0000-template + 0001..0006)
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
- **0008** — реквізити продавця + канали **IBAN/LiqPay**; приватний ключ зашифровано, доступ superadmin.
- **0009** — наскрізні тексти (гарантія/доставка) — сутність **ContentBlock**, не поля товару.
- **0010** — єдина сутність **User + роль** (без розділення профілів).
- **0011** — **price-sheet**: табличний вигляд каталогу (`/price-sheet`), той самий ендпоінт `+ include=fitment`, нескінченний скрол.
- **0012** — **обране (wishlist)**: авторизований сигнал інтересу (модель `WishlistItem`), ♡ лише для залогінених; адмінам видно попит/контакти під розділом «Ліди».
- **0013** — **Order**: `paymentStatus`/`paymentMethod`/`deliveryMethod` винесено з JSON у колонки (+ trigram-пошук за телефоном/email); `payment` jsonb прибрано (була порожня); `customer`/`delivery` — лише снапшот; форма API незмінна (композиться з колонок).

## Conventions

- Уся продуктова документація та UI-тексти — **українською**.
- Діаграми — **Mermaid**.
- Архітектурні рішення оформлювати як ADR (копія `adr/0000-template.md`).
- **Коміт/пуш у будь-якому репо — лише з явної згоди користувача.**
