# Admin: дублювання UI-примітивів, мертвий код, дрібниці

- **Пріоритет:** P3 — бажане (гігієна)
- **Репозиторій:** tesla-admin
- **Статус:** TODO

## Список

1. **Дублювання `Field`** — ідентичний компонент скопійовано 4 рази: `ProductForm.tsx:563`, `cars/page.tsx:269`, `categories/page.tsx:219`, `requisites/page.tsx:328`; блок «Loader2 + Завантаження…» повторено в ~7 сторінках; каркас таблиці — у 4. Винести спільні `Field`, `LoadingState`, `EmptyState`, `DataTable`.
2. **Мертвий код/залежності**: `sharp` у deps не імпортується; `ANY_AUTHENTICATED`, `ROLES` (`role.constants.ts:13-14`), `API_URLS.UPLOAD.PRESIGN` не використовуються; `src/common/hooks/` згадано в CLAUDE.md адмінки, але директорії немає.
3. **Topbar-пошук — макет**: «🔍 Пошук по адмінці…» — статичний div без функціоналу і без TODO-позначки.
4. **`API_BASE_URL` з `!`** — `api-routes.constants.ts:1`: без env-змінної запити тихо підуть на `undefined/...`; зробити fail-fast.
5. **`content/page.tsx`** — немає empty-state; ключ рядків характеристик у `ProductForm.tsx:363` — індекс масиву.
