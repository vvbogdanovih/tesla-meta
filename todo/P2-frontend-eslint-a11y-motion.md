# ESLint-помилки, a11y модалки LeadButton, prefers-reduced-motion

- **Пріоритет:** P2 — важливий (якість/доступність)
- **Репозиторій:** tesla-frontend
- **Статус:** TODO

## Проблема

1. **Lint не проходить**: 2 errors у `SearchBox.tsx` (`react-hooks/set-state-in-effect`).
2. **Модалка LeadButton без a11y**: немає `role='dialog'`, `aria-modal`, Escape, блокування скролу — на відміну від LoginGateModal/CartDrawer/LivePhotos, де все це є; дублювання модального паттерну замість спільного компонента.
3. **`prefers-reduced-motion` не поважається ніде** (вимога CLAUDE.md фронта) — hero-відео автопрограється завжди.

## Де в коді

- `src/common/components/layout/SearchBox.tsx:32-33`
- `src/common/components/catalog/LeadButton.tsx:84-96`
- `src/app/page.tsx` — hero-відео

## Що зробити

1. Виправити setState-in-effect у SearchBox.
2. Винести спільний Modal-компонент (dialog role, Escape, scroll lock, focus trap) і використати в LeadButton.
3. Не автопрогравати hero-відео при `prefers-reduced-motion: reduce`.
