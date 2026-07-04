# Захист роутів адмінки лише клієнтський (немає middleware.ts)

- **Пріоритет:** P2 — важливий (безпека, defense in depth)
- **Репозиторій:** tesla-admin
- **Статус:** TODO

## Проблема

`AdminGuard` — client-side компонент; `middleware.ts` немає. Дані захищені бекендом (guards перевірені на всіх 13 контролерах), але весь JS-бандл адмінки віддається будь-кому. Server-side перевірка cookie в middleware — додатковий бар'єр.

## Де в коді

- `src/common/components/guards/AdminGuard.tsx:15-21`
- `middleware.ts` — відсутній

## Що зробити

Додати `middleware.ts`: перевірка наявності auth-cookie для всіх роутів `(dashboard)`, редірект на `/login` за відсутності. Ролі й валідність токена й далі перевіряє бекенд.
