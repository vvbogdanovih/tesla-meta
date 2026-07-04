# Адмінка: error-стани запитів + невикористана zod-валідація відповідей

- **Пріоритет:** P2 — важливий (надійність UI)
- **Репозиторій:** tesla-admin
- **Статус:** TODO

## Проблема

1. **Вічний спінер при помилці**: `products/[id]/page.tsx:16` — `if (isLoading || !data) return <спінер>`: 404/помилка мережі → нескінченне «Завантаження…» без повідомлення.
2. **Механізм `config.schema` (zod) у `http.service.ts:40-52` готовий, але жоден із 9 сервісів його не передає** — усі типи (`ProductDetail`, `PaymentRequisite`…) — небезпечні касти; розбіжність із бекендом виявиться рантайм-падінням UI.
3. **Мутації без `onError` + сирі `confirm()`** у всіх delete-потоках (products, cars, requisites, leads); помилка логіну кидається крізь `handleSubmit` → unhandled rejection.

## Де в коді

- `src/app/(dashboard)/products/[id]/page.tsx:16`
- `src/common/services/http.service.ts:40-52`
- `products/page.tsx:31`, `cars/page.tsx:102`, `requisites/page.tsx:195`, `leads/page.tsx:92`, `login/page.tsx:27`

## Що зробити

1. Error-стан у `products/[id]` та retry-повідомлення на списках.
2. Передавати `schema` хоча б для критичних сутностей (products, payment-requisites).
3. Спільний `ConfirmDialog` замість `confirm()`, `onError` на мутаціях, catch на логіні.
