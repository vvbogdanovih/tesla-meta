# Синхронізувати доки з реальним кодом (FRD orders, backend-architecture, db-schema)

- **Пріоритет:** P3 — документація
- **Репозиторій:** tesla-meta
- **Статус:** TODO

## Розбіжності доки ↔ код

1. **FRD §5**: замовлення позначені «*(план)*», але **реалізовані** — `POST /orders` (гостьовий), `GET /orders?status=` (admin), `PATCH /orders/:id/status` (admin), `GET /orders/:number` (публічний; у FRD написано `:id`). Не задокументовані: `GET /api/admin/stats`, `GET /api/health`.
2. **backend-architecture.md §5**: «База: `/api/v1`» — реально `/api` без версії; «Swagger на `/api/docs`» — реально `/swagger`.
3. **backend-architecture.md §3/§6/§10**: PaymentRequisites описані як «IBAN/LiqPay» без Monopay; §10 п.1 «який еквайринг?» — уже вирішено ADR-0008; модулі stats/health відсутні в таблиці, а неіснуючі (search, cart, users, blog…) перелічені без позначки план/факт.
4. **db-schema.md §3**: «Prisma не виражає gin_trgm_ops, додаємо raw-міграцією» — застаріло: реальна схема має `extensions = [pg_trgm]` + `@@index([name(ops: raw("gin_trgm_ops"))], type: Gin)` нативно; цих індексів немає у Prisma-блоці документа.

## Що зробити

Оновити FRD §5 (статуси + реальні шляхи), виправити фактичні помилки backend-architecture.md, актуалізувати db-schema.md §3 і додати GIN-індекси в Prisma-блок.
