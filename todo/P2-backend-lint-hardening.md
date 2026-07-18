# Backend: червоний lint + floating promise у bootstrap

- **Пріоритет:** P2
- **Репозиторій:** tesla-backend
- **Статус:** TODO (виявлено 17.07.2026)

## 1. `yarn lint` червоний — 79 errors, 26 warnings
`eslint.config.mjs` вмикає `recommendedTypeChecked` → `no-unsafe-*` як **error**. Порушення в test/spec-файлах (auth/catalog/products/e2e), `seed.ts`, `main.ts`, framework-glue (`jwt.strategy.ts`, `roles.guard.ts`, `current-user.decorator.ts`, `auth.controller.ts`). Здебільшого `any` на межах passport/JWT та в тестах.
CI-крок «lint» падатиме. **Дія:** типізувати або локально придушити (`overrides` для тестів/glue).

## 2. `bootstrap()` — floating promise
`src/main.ts:55` — `bootstrap()` без `.catch`. Правило `no-floating-promises` знижене до `warn`, тож не ловиться. Падіння старту не залогується як слід. **Дія:** обгорнути `bootstrap().catch(...)` з логуванням і `process.exit(1)`.

## 3. (P3) `.env.prod` порожній (0 байт)
Переконатися, що прод-конфіг береться з secrets manager, а не з цього файлу — інакше видалити, щоб не вводив в оману.
