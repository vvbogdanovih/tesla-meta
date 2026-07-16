# Architecture Decision Records (ADR)

Тут фіксуються значущі архітектурні та технічні рішення проєкту: контекст, ухвалене рішення та його наслідки. ADR незмінні — якщо рішення переглядається, створюється новий запис зі статусом `Superseded` для старого.

## Як додати ADR

1. Скопіюйте [`0000-template.md`](0000-template.md).
2. Назвіть файл `NNNN-короткий-заголовок.md` (наступний порядковий номер).
3. Заповніть розділи й виставте статус.
4. Додайте рядок у таблицю нижче.

## Реєстр

| # | Рішення | Статус | Дата |
|---|---------|--------|------|
| [0001](0001-url-structure-and-redirects.md) | Структура URL та стратегія редиректів | Proposed | 27.06.2026 |
| [0002](0002-catalog-compatibility-architecture.md) | Каталог: довідник авто, M2M-сумісність, глобальні системи | Accepted | 27.06.2026 |
| [0003](0003-database-postgresql.md) | PostgreSQL замість MongoDB | Accepted | 27.06.2026 |
| [0004](0004-admin-separate-app-and-roles.md) | Адмінка — окремий Next.js застосунок; ролі User/Admin/SuperAdmin | Accepted | 27.06.2026 |
| [0005](0005-implementation-order-admin-first.md) | Порядок реалізації: БД/API → адмінка → клієнтський застосунок | Accepted | 27.06.2026 |
| [0006](0006-rich-text-tiptap-json-html.md) | Rich text — TipTap; зберігання JSON (редагування) + HTML (показ) | Accepted | 28.06.2026 |
| [0007](0007-image-pipeline-avif.md) | Завантаження зображень — конвертація в AVIF на бекенді (sharp) | Accepted | 29.06.2026 |
| [0008](0008-payment-requisites-channels.md) | Реквізити продавця та канали оплати (IBAN / LiqPay / monopay), шифрування секретів | Accepted | 29.06.2026 |
| [0009](0009-content-blocks.md) | Наскрізні тексти сайту — сутність ContentBlock | Accepted | 29.06.2026 |
| [0010](0010-single-user-entity.md) | Єдина сутність User + роль (без розділення профілів) | Accepted | 29.06.2026 |
| [0011](0011-price-sheet-table-view.md) | Price-sheet — табличний вигляд каталогу | Accepted | 01.07.2026 |
| [0012](0012-wishlist-auth-crm.md) | Обране (wishlist) — авторизований сигнал інтересу для CRM | Accepted | 01.07.2026 |
| [0013](0013-order-status-method-columns.md) | Order: статус/методи оплати й доставки та пошук контактів — окремі колонки | Accepted | 02.07.2026 |
| [0014](0014-nova-poshta-directory-mirror.md) | Nova Poshta: дзеркало довідника в БД + синхронізація (cron + кнопка) | Accepted | 02.07.2026 |
| [0015](0015-monopay-online-payment.md) | Онлайн-оплата карткою через monopay: токен у БД, метод `card`, вебхук + поллінг | Accepted | 05.07.2026 |
| [0016](0016-erp-1c-integration.md) | Інтеграція з 1С — сайт-ініціатор: pull наявності/цін, push замовлень (ідемпотентно) | Accepted | 06.07.2026 |
| [0017](0017-saved-delivery-addresses.md) | Збережені адреси доставки — лише для авторизованих (`Address` + НП-референси) | Accepted | 07.07.2026 |
