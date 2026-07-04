# Frontend: мертвий код, зайві залежності, хардкоди

- **Пріоритет:** P3 — бажане (гігієна)
- **Репозиторій:** tesla-frontend
- **Статус:** TODO

## Список

1. **Мертві константи** — `api-routes.constants.ts`: `CART`, `ORDERS`, `NOVA_POSHTA`, `BLOG`, `ACCOUNT.PROFILE/ADDRESSES`, `LEADS.PRICE_MATCH/PRICE_SUBSCRIBE`; `ui-routes.constants.ts`: `CATEGORY`/`SUBCATEGORY` (маршрут не існує), `PRIVACY`, `OFFER`.
2. **Зайві залежності** — `sharp` марний при `unoptimized: true`; `@tanstack/react-query-devtools` не підключено; `radix-ui`, `react-icons`, `class-variance-authority` — використання мінімальне/нульове.
3. **`Pagination.tsx:20` хардкодить `/shop`** — компонент непереносний.
4. **Хардкоди в UI** — «Понад 1000», «1000+ позицій», «Visa · Mastercard · накладений», email/©2026 у Footer — кандидати на ContentBlock (ADR-0009).
5. **LeadButton валідується інакше ніж auth-сторінки** — ручний `useState`-form без zod проти RHF+zod; уніфікувати.
6. **Гість ловить 401→refresh на кожен візит** — `http.service.ts:22-31`: `checkAuth` для анонімного користувача завжди тригерить зайвий refresh-запит.
