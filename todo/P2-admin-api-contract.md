# Адмінка: валідація відповідей API + звірка типу Order.payment + enforcement реквізитів

- **Пріоритет:** P2
- **Репозиторій:** tesla-admin (+ перевірка tesla-backend)
- **Статус:** TODO (виявлено 17.07.2026)

## 1. Zod-валідація відповідей лише у 3/11 сервісів
`http.service` підтримує рантайм-`schema`, але задіяно тільки в `products.api.ts`, `payment-requisites.api.ts`, `cars.api.ts`/`auth.api.ts`. Без схем (приймають `as T` «на віру»): `orders.api.ts`, `leads.api.ts`, `content-blocks.api.ts`, `delivery-np.api.ts`, `wishlist.api.ts`, `categories.api.ts`, `stats.api.ts`.

## 2. Ризик розбіжності Order.payment після ADR-0013
ADR-0013 виніс `payment` з jsonb у колонки, але admin-тип `src/common/types/order.type.ts` усе ще очікує вкладений `payment: {method, status}`, а `orders/[id]/page.tsx:199-205` покладається на `order.payment.method/status`. Якщо бекенд віддає плоскі колонки — рантайм-undefined, а не зрозуміла помилка.
**Дія:** звірити реальну форму відповіді `/orders/:id` з admin-типом; додати zod-схему для orders першою.

## 3. Підтвердити backend-enforcement для superadmin-розділів
`requisites/page.tsx` та `settings/page.tsx` ховають вміст client-side (`enabled: isSuperadmin`). Це лише UX. Треба **явно верифікувати**, що бекенд повертає 403 для роль=admin на list/create/update платіжних реквізитів і НП-налаштувань (клієнт коректно на це покладається; сам enforcement — на бекенді).
