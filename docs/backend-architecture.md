# Архітектура бекенду — tesla-backend (NestJS)

**Версія:** 1.0
**Дата:** 27.06.2026
**Статус:** Draft
**Стек:** NestJS · Prisma · PostgreSQL · S3
**Пов'язано:** [FRD](FRD.md) · [db-schema.md](db-schema.md) · [ADR-0003](adr/0003-database-postgresql.md) · [ADR-0004](adr/0004-admin-separate-app-and-roles.md) · [ADR-0005](adr/0005-implementation-order-admin-first.md)

> `tesla-backend` — **спільний backend** для двох фронтів (`tesla-frontend`, `tesla-admin`). API-first: один контракт, доступ за роллю в JWT. Реалізується **першим** після БД (ADR-0005).

---

## 1. Принципи

- **Модульність** (NestJS modules) за бізнес-доменами; чіткі межі.
- **Шаруватість:** `Controller` (HTTP/DTO) → `Service` (бізнес-логіка) → `Repository`/Prisma (дані). Жодної бізнес-логіки в контролерах.
- **API-first:** REST, версіонування `/api/v1`, OpenAPI (Swagger) автогенерація.
- **Валідація на межі:** DTO + `class-validator`/`class-transformer`, глобальний `ValidationPipe`.
- **RBAC:** один API, права за роллю (User/Admin/SuperAdmin) через guards.
- **Безпека за замовчуванням** (NFR-6): helmet, CORS-allowlist, rate-limit, хешування паролів, JWT+refresh.

---

## 2. Високорівнева схема

```mermaid
flowchart TB
  web["tesla-frontend (Next.js)"] -->|REST /api/v1| api
  admin["tesla-admin (Next.js)"] -->|REST + JWT (admin)| api

  subgraph api["tesla-backend · NestJS"]
    direction TB
    G["Guards: JwtAuth · Roles · Throttler"]
    M["Модулі: catalog · cars · categories · search · cart · orders · auth · users · account · leads · blog · banners · media · integrations · admin · seo"]
    P["PrismaService"]
    G --> M --> P
  end

  P --> DB[("PostgreSQL")]
  M --> S3[("S3 / CDN")]
  M --> NP["Нова Пошта API"]
  M --> PAY["Платіжний шлюз"]
  M --> MAIL["Email / SMS / Telegram"]
```

---

## 3. Модулі

| Модуль | Відповідальність | Доступ |
|--------|------------------|--------|
| **AuthModule** | Реєстрація/логін, JWT access+refresh, відновлення пароля | public |
| **UsersModule** | Користувачі, ролі | admin/superadmin |
| **AccountModule** | Профіль, адреси, історія замовлень поточного користувача | user |
| **CatalogModule** | Товари: список з фільтрами/сортуванням/пагінацією, деталі | public read / admin write |
| **CarsModule** | Довідник авто (моделі/покоління) | public read / admin write |
| **CategoriesModule** | Глобальне дерево категорій | public read / admin write |
| **FitmentModule** | M2M сумісність товар↔авто (керування, запити) | admin write |
| **SearchModule** | Пошук + автодоповнення (pg_trgm) | public |
| **CartModule** | Кошик (синхронізація для авторизованих) | user/guest |
| **OrdersModule** | Створення/перегляд/зміна статусу замовлень | user (свої) / admin (всі) |
| **LeadsModule** | Заявки (підбір/дешевше/підписка/контакт) + нотифікації | public create / admin read |
| **BlogModule** | Статті | public read / content write |
| **BannersModule** | Банери головної | admin write |
| **ContentBlocksModule** | Наскрізні тексти сайту (гарантія, доставка) — фікс. набір, rich text ([ADR-0009](adr/0009-content-blocks.md)) | public read / admin write |
| **PaymentRequisitesModule** | Реквізити продавця + канали IBAN/LiqPay, шифрування ключа ([ADR-0008](adr/0008-payment-requisites-channels.md)) | **superadmin** |
| **S3Module / Media** | Завантаження → конвертація в **AVIF** (sharp), R2; presign ([ADR-0007](adr/0007-image-pipeline-avif.md)) | admin |
| **IntegrationsModule** | Нова Пошта, еквайринг (LiqPay), email/SMS — проксі/адаптери | internal |
| **SeoModule** | `sitemap.xml`, `robots.txt`, редиректи | public |
| **AdminModule** | Агрегація адмін-операцій, дашборд-метрики, імпорт/експорт | admin/superadmin |

---

## 4. Аутентифікація та RBAC

- **JWT:** короткий `access` (~15 хв) + `refresh` (ротація, httpOnly cookie / захищене сховище).
- **Ролі** (ADR-0004): `user` · `admin` · `superadmin`. У токені — `sub`, `role`.
- **Guards:** `JwtAuthGuard` (автентифікація) + `RolesGuard` з декоратором `@Roles('admin','superadmin')`.
- **Паролі:** `argon2` (або bcrypt).
- Адмінські ендпоінти доступні лише `admin`/`superadmin` — незалежно від того, з якого фронту запит.

```ts
@Roles('admin', 'superadmin')
@UseGuards(JwtAuthGuard, RolesGuard)
@Post('products')
create(@Body() dto: CreateProductDto) { … }
```

---

## 5. Конвенції API

- База: `/api/v1`. Ресурсні маршрути (REST), узгоджені з [FRD §5](FRD.md).
- **Фільтрація каталогу:** `GET /products?car=&category=&type=&condition=&inStock=&minPrice=&maxPrice=&sort=&page=&limit=`.
- **Пагінація:** `page`/`limit` + відповідь `{ items, total, page, limit }`.
- **Помилки:** єдиний формат (`{ statusCode, message, error }`) через глобальний `ExceptionFilter`.
- **DTO + валідація:** усі вхідні дані; whitelist + forbidNonWhitelisted.
- **OpenAPI:** Swagger на `/api/docs` (захищено в проді).

---

## 6. Інтеграції

| Інтеграція | Призначення | Нотатки |
|------------|-------------|---------|
| **Нова Пошта API** | Міста, відділення/поштомати, ТТН/статуси | Проксі через бекенд (ключ не на клієнті); кеш міст/відділень |
| **LiqPay (еквайринг)** | Онлайн-оплата карткою | Провайдер — **LiqPay** ([ADR-0008](adr/0008-payment-requisites-channels.md)); ключі — у `PaymentRequisite` (зашифровано); вебхуки статусів. Адаптер дозволяє заміну |
| **Email / SMS / Telegram** | Підтвердження замовлень, нотифікації лідів менеджеру | Черга/ретраї; шаблони |
| **S3 / CDN** | Зберігання зображень, OG | Підписані URL для завантаження з адмінки |

Інтеграції — за **адаптер-патерном** (інтерфейс + провайдер), щоб міняти провайдера (напр. еквайринг) без зміни бізнес-логіки.

---

## 7. Міграція з WooCommerce (ETL)

Окремий скрипт/команда (`AdminModule`/CLI), узгоджено з [ADR-0002](adr/0002-catalog-compatibility-architecture.md):

1. **Extract:** експорт товарів/категорій/SKU з WooCommerce (MySQL/REST/CSV).
2. **Transform:**
   - наповнити `Car` (покоління/дати);
   - **дедуплікація товарів за `sku`** → один `Product`;
   - побудувати `ProductFitment` зі старих модельних категорій;
   - звести категорії до глобального довідника `Category`;
   - сформувати `Redirect` (старий URL → новий, 301).
3. **Load:** запис у PostgreSQL через Prisma; валідація; звіт розбіжностей.

---

## 8. Наскрізні аспекти

- **Конфіг:** `@nestjs/config` + zod-валідація `.env` (`env.constant.ts`) за середовищами; секрети поза репо. Окремий `PAYMENT_ENC_KEY` — для шифрування платіжних секретів.
- **Шифрування секретів:** `common/utils/crypto.util.ts` (AES-256-GCM) — для приватного ключа LiqPay у `PaymentRequisite` ([ADR-0008](adr/0008-payment-requisites-channels.md)).
- **Slug:** спільний `common/utils/slugify.ts` — транслітерація **укр/рос → латиниця** (товари/категорії/авто); slug стабільний, не змінюється при перейменуванні (SEO).
- **Кеш:** кеш гарячих читань (каталог/категорії) + ISR на фронті; інвалідація при змінах у адмінці.
- **Rate limiting:** `@nestjs/throttler` на публічних і auth-ендпоінтах (NFR-6, anti-spam форм).
- **Логування/моніторинг:** структуровані логи, request-id; помилки — у трекер.
- **Тести:** unit (services) + e2e (контролери) ключових потоків (checkout, auth, фільтри).
- **Документація API:** Swagger як частина CI.

---

## 9. Структура папок (орієнтовно)

> **Prisma 7** з `prisma.config.ts` (корінь) і драйвер-адаптером `@prisma/adapter-pg`; схема та міграції — під `src/database/prisma/`.

```
tesla-backend/
├── prisma.config.ts             # Prisma 7 config (schema/migrations/seed paths)
├── src/
│   ├── main.ts
│   ├── app.module.ts
│   ├── common/                  # constants(env,endpoints), guards, decorators, strategies, types
│   ├── database/prisma/         # PrismaService(+adapter), PrismaModule, filter, seed
│   │   ├── schemas/schema.prisma # див. db-schema.md
│   │   └── migrations/
│   ├── config/
│   ├── modules/
│   │   ├── auth/                # controller, service, dto, strategies, guards
│   │   ├── users/
│   │   ├── account/
│   │   ├── catalog/            # products
│   │   ├── cars/
│   │   ├── categories/
│   │   ├── fitment/
│   │   ├── search/
│   │   ├── cart/
│   │   ├── orders/
│   │   ├── leads/
│   │   ├── blog/
│   │   ├── banners/
│   │   ├── media/
│   │   ├── seo/
│   │   ├── integrations/        # nova-poshta/, payments/, notifications/
│   │   └── admin/               # dashboard, import-export
│   └── jobs/                    # черги/крони (нотифікації, ETL)
└── test/
```

Кожен модуль: `*.module.ts`, `*.controller.ts`, `*.service.ts`, `dto/`, (за потреби) `*.repository.ts`.

---

## 10. Відкриті питання (бекенд)

1. **Еквайринг:** який провайдер (LiqPay/Fondy/WayForPay/monobank) — впливає на IntegrationsModule й вебхуки.
2. **GraphQL чи REST-only:** наразі REST; GraphQL — за потреби фронтів.
3. **Черги:** чи вводимо черги (BullMQ/Redis) для нотифікацій/ETL одразу, чи синхронно в MVP.
4. **Кеш-шар:** Redis для кешу/сесій/rate-limit — у MVP чи пізніше.
5. **Хостинг/деплой:** середовища, CI/CD, міграції Prisma у пайплайні.
