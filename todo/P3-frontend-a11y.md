# Frontend: a11y — label↔input не пов'язані

- **Пріоритет:** P3 (доступність; впливає на форми login/register/checkout/profile)
- **Репозиторій:** tesla-frontend
- **Статус:** TODO (виявлено 17.07.2026)

## Проблема

`src/common/components/auth/parts.tsx:13-19` (`AuthField`) — `<label>` без `htmlFor`, а input без `id`; input не вкладений усередину `<label>`. `grep htmlFor` по `src/` — 0 збігів. Використовується в login, register, checkout, ProfileForm. Скрін-рідери не озвучують підпис, клік по підпису не фокусує поле.

## Що зробити

Генерувати `id` (напр. `useId`) і додати `htmlFor`/`id`, або обгорнути input у `<label>`.

Позитив (не чіпати): `lang='uk'`, `aria-label`/`sr-only` у Modal/CartDrawer/QtyStepper/ThemeToggle, sr-only radio у checkout, `alt` на зображеннях, `prefers-reduced-motion`.
