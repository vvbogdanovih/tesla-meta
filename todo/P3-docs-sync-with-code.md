# Синхронізувати доки з реальним кодом (FRD, backend-architecture, db-schema)

- **Пріоритет:** P3 — документація
- **Репозиторій:** tesla-meta
- **Статус:** TODO

## Розбіжності доки ↔ код

1. **FRD §5**: не задокументовані `GET /api/admin/stats`, `GET /api/health`; НП-ендпоінти (рядок ~251) позначені «проксі *(план)*», хоча реалізовані інакше — віддача зі своєї бази-дзеркала (ADR-0014).
2. **backend-architecture.md §5**: «База: `/api/v1`» — реально `/api` без версії; «Swagger на `/api/docs`» — реально `/swagger`.
3. **backend-architecture.md §2/§3/§10**: §10 п.1 «який еквайринг?» — уже вирішено (ADR-0015: monopay); модулі stats/health/delivery-np/addresses/profile відсутні в таблиці §3, а неіснуючі (search, cart, users, blog…) перелічені без позначки план/факт; IntegrationsModule описує «еквайринг (LiqPay)».
4. **db-schema.md §3**: «Prisma не виражає gin_trgm_ops, додаємо raw-міграцією» — застаріло: реальна схема має `extensions = [pg_trgm]` + `@@index([name(ops: raw("gin_trgm_ops"))], type: Gin)` нативно; цих індексів немає у Prisma-блоці документа.

## Що зробити

Доповнити FRD §5 (stats/health, формулювання НП), виправити фактичні помилки backend-architecture.md (§3/§5/§10), актуалізувати db-schema.md §3 і додати GIN-індекси в Prisma-блок.

> Виконано раніше (перевірено 15.07): FRD §5 orders уже актуалізовано (реалізовано ✅, публічний шлях `GET /orders/:number` виправлено); backend-architecture §3/§6 уже згадують monopay для PaymentRequisites/Payments.
