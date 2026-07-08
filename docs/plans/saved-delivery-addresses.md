# План/handoff: збережені адреси доставки (ADR-0017)

> Статус: **реалізовано** (2026-07-08). Backend + frontend зібрані, типи чисті, lint без нових
> помилок, міграцію застосовано до dev-БД. Лишилось **живе тестування** повного циклу (див. нижче).
> Рішення користувача: збережені адреси — **лише для авторизованих** (без localStorage для гостей);
> `Address` розширено НП-референсами; при виборі адреси підтягуються ще й **ПІБ + телефон**.

## Що зроблено

### tesla-backend
- **Схема** (`schema.prisma`, модель `Address`): додано `cityRef`, `warehouseRef`,
  `warehouseType` (enum `NpWarehouseType`) + `@@index([userId])`.
- **Міграція** `20260707141223_saved_addresses_np_refs` — застосована до dev-БД
  (`195.72.145.206`, база `tesla-dev`). Prisma Client перегенеровано.
- **Модуль `src/modules/addresses/`** (auth-scoped, `@Controller('account/addresses')`,
  `JwtAuthGuard`), зареєстрований у `app.module.ts`:
  - `GET /account/addresses` — список (основна першою, далі новіші).
  - `POST /account/addresses` — створення.
  - `PATCH /account/addresses/:id` — редагування.
  - `PATCH /account/addresses/:id/default` — зробити основною.
  - `DELETE /account/addresses/:id` — видалення.
  - Інваріант «одна `isDefault` на користувача» тримається у транзакціях; перша адреса —
    авто-основна; видалення основної підвищує найновішу з решти; перевірка власності (404 на чужу).

### tesla-frontend
- **`common/services/addresses.api.ts`** — сервіс + zod-схеми (list/create/update/setDefault/remove).
  `create` має тихий режим `{ silent: true }` (для фонового збереження з чекауту).
- **`app/checkout/page.tsx`**:
  - Окремий **блок «Збережені адреси» зверху** лівої колонки (над «Контактні дані»), лінк
    «Керувати» → `/account/addresses`. Картки-радіо + «Нова адреса».
  - Вибір збереженої адреси заповнює доставку **і контакт (ПІБ + телефон)** — з `recipient`/`phone`
    адреси; якщо там порожньо — лишаються дані профілю.
  - Коли адресу обрано, блок «Доставка» показує компактне резюме + «Змінити».
  - У режимі «Нова адреса» — старий флоу + чекбокс «Зберегти цю адресу в профіль»
    (увімкнений, коли збережених адрес ще нема); при оформленні адреса створюється (тихо).
- **`app/account/addresses/page.tsx`** — профіль: список карток + CRUD (додати/редагувати/видалити/
  зробити основною), react-query mutations.
- **`common/components/account/AddressForm.tsx`** — переюзабельна форма (НП combobox / Укрпошта,
  label/recipient/phone/isDefault), локальний стан.
- **`app/account/page.tsx`** — плитка «Адреси доставки»; **`constants/ui-routes.constants.ts`** —
  `ACCOUNT_ADDRESSES`.

### tesla-meta (докси)
- ADR **0017** (`docs/adr/0017-saved-delivery-addresses.md`, Accepted), реєстр `adr/README.md`,
  `CLAUDE.md` (рядок 0017), FRD **FR-6.4a** + уточнено **FR-7.2**, `db-schema.md` (модель `Address`).

## Ключові рішення

1. **Тільки авторизовані.** Гість — без збереження, лише нудж «Увійдіть». localStorage навмисно не
   робимо (можна додати згодом окремим рішенням).
2. **НП-референси в `Address`** — щоб збережена адреса відновлювала combobox і давала майбутній ТТН.
3. **Ключ контакту з адреси.** Вибір адреси підтягує ПІБ (`recipient`) + телефон (`phone`),
   fallback — профіль. Снапшот `Order.delivery`/`customer` лишається незалежним (ADR-0013):
   видалення/зміна адреси не впливає на замовлення.
4. **`warehouseType`** — enum `NpWarehouseType` (`branch|postomat|cargo`), як у `np_warehouses`/DTO.

## Гоча / важливе

- **Backend треба перезапускати вручну** при змінах: попередній інстанс був `nest start` **без
  `--watch`** → віддавав стару збірку, `/account/addresses` давав 404, збереження тихо падало.
  Зараз запущено `yarn start:dev` (watch) у фоні, лог `/tmp/tesla-backend-dev.log`, слухає :4040.
- Міграцію вже застосовано до **спільної dev-БД** — повторно застосовувати не треба.
- У робочих деревах є **сторонні незакомічені зміни не з цієї фічі** (backend `seed.ts`; frontend
  `product/[slug]/page.tsx`, `CatalogFilters.tsx`, `LivePhotos.tsx`, `Header.tsx`) — у коміти фічі
  НЕ включені, лишені як є.
- Коміти зроблено на `main` кожного репо, **не запушено** (чекає рішення користувача про push).

## Залишок для живого тесту

1. Checkout: заповнити ПІБ + телефон, обрати місто/відділення НП, лишити «Зберегти в профіль» →
   оформити замовлення. Переконатись, що адреса зʼявилась у БД (`select * from addresses`).
2. Повторний checkout: зверху блок «Збережені адреси»; клік по картці підставляє ПІБ, телефон,
   доставку; «Доставка» показує резюме.
3. Профіль `/account/addresses`: CRUD, «зробити основною», видалення основної (має підвищитись інша).
4. Перевірити редагування збереженої НП-адреси (у `AddressForm` для зміни НП треба обрати заново —
   поточне значення показується підказкою).

## Файли (для швидкої навігації)

- backend: `src/modules/addresses/*`, `src/app.module.ts`, `schema.prisma`,
  `migrations/20260707141223_saved_addresses_np_refs/`
- frontend: `src/app/checkout/page.tsx`, `src/app/account/addresses/page.tsx`,
  `src/app/account/page.tsx`, `src/common/components/account/AddressForm.tsx`,
  `src/common/services/addresses.api.ts`, `src/common/constants/ui-routes.constants.ts`
