# A11y модалки LeadButton, prefers-reduced-motion

- **Пріоритет:** P2 — важливий (якість/доступність)
- **Репозиторій:** tesla-frontend
- **Статус:** TODO

## Проблема

1. **Модалка LeadButton без a11y**: немає `role='dialog'`, `aria-modal`, Escape, блокування скролу — на відміну від LoginGateModal/CartDrawer/LivePhotos, де все це є; дублювання модального паттерну замість спільного компонента.
2. **`prefers-reduced-motion` не поважається ніде** (вимога CLAUDE.md фронта) — hero-відео автопрограється завжди.

## Де в коді

- `src/common/components/catalog/LeadButton.tsx:110`
- `src/app/page.tsx:221` — hero-відео

## Що зробити

1. Винести спільний Modal-компонент (dialog role, Escape, scroll lock, focus trap) і використати в LeadButton.
2. Не автопрогравати hero-відео при `prefers-reduced-motion: reduce`.

> Виконано раніше: lint-помилки `react-hooks/set-state-in-effect` у SearchBox виправлені (перевірено 15.07).
