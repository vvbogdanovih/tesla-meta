# Тестів немає взагалі у frontend і admin

- **Пріоритет:** P2 — важливий (якість)
- **Репозиторії:** tesla-frontend, tesla-admin
- **Статус:** TODO

## Проблема

В обох репо — жодного тест-файлу і жодного test-раннера в `package.json`. Критичні місця без покриття:

- **admin**: single-flight refresh у `http.service.ts:22-31`; `slugify.ts` — ручне «дзеркало бекенду» (ризик розсинхрону слагів без тесту-контракту); збирання payload у `ProductForm` (580 рядків).
- **frontend**: кошик (Zustand persist, обробка stockQty), collision логіки фільтрів `/shop`.

## Що зробити

1. Додати vitest + testing-library в обидва репо.
2. Перші сьюти: slugify (контракт із бекендом — однакові вхід/вихід), http.service refresh-логіка, cart store.
