# Frontend: зайві залежності, хардкоди

- **Пріоритет:** P3 — бажане (гігієна)
- **Репозиторій:** tesla-frontend
- **Статус:** TODO

## Список

1. **Зайві залежності** — `sharp` (марний при `unoptimized: true`), `@tanstack/react-query-devtools`, `radix-ui`, `react-icons` — не використовуються в `src/` (`class-variance-authority` використовується — `ui/button.tsx`). Мертва константа `BLOG` в `api-routes.constants.ts`.
2. **Хардкоди в UI** — «Понад 1000» (`src/app/page.tsx:148`), email/місто/©2026 у Footer (`Footer.tsx:14`) — кандидати на ContentBlock (ADR-0009).
3. **LeadButton валідується інакше ніж auth-сторінки** — ручний `useState`-form без zod (`LeadButton.tsx:27-35`) проти RHF+zod у checkout; уніфікувати.

> Виконано раніше (перевірено 15.07): константи `CART`/`ORDERS`/`NOVA_POSHTA`/`ACCOUNT.*`/`LEADS.PRICE_*` тепер використовуються (checkout, NP-picker, профіль/адреси); `ui-routes` почищено; хардкод `/shop` у Pagination — коректний для поточного використання; зайвий guest-refresh у `http.service.ts` виправлено (дедуплікація `refreshPromise`).
