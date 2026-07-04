# Немає error.tsx / loading.tsx у всьому app/

- **Пріоритет:** P1 — критичний (стабільність публічного сайту)
- **Репозиторій:** tesla-frontend
- **Статус:** TODO

## Проблема

У `src/app` немає жодного `error.tsx`, `global-error.tsx` чи `loading.tsx`. `catalog.api.ts` кидає виняток на будь-яку не-ok відповідь — падіння бекенда на `/shop` чи `/product/*` показує користувачу сирий дефолтний екран помилки Next. Головна має graceful fallback, каталог — ні.

## Де в коді

- `src/common/services/catalog.api.ts:14` — throw на не-ok
- `src/app/page.tsx:15-21` — приклад правильного fallback (головна)
- `src/app/shop/`, `src/app/product/[slug]/` — без boundaries

## Що зробити

1. Додати `error.tsx` + `loading.tsx` щонайменше для `/shop` і `/product/[slug]` (а краще кореневий `global-error.tsx`).
2. У error-стані — дружнє повідомлення українською + кнопка «Спробувати ще раз» (reset).
