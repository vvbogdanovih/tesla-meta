# yarn build падає без доступного бекенда (content-block сторінки)

- **Пріоритет:** P1 — блокує деплой
- **Репозиторій:** tesla-frontend
- **Статус:** TODO (виявлено 17.07.2026)

## Проблема

`src/app/kontakty/page.tsx:13` та `src/app/pro-nas/page.tsx:14` викликають `catalogApi.contentBlock(...)` при статичному prerender **без try/catch**. Якщо бекенд недоступний під час збірки — `yarn build` падає з `Error occurred prerendering page "/kontakty"` (`ECONNREFUSED`), `exit code 1`.

Порівняти з `sitemap.ts` та `product/[slug]/page.tsx`, які обгорнуті в try/catch і білд не валять. Наслідок: будь-яка недоступність API під час CI/деплою повністю ламає збірку фронтенду.

## Що зробити

1. Обгорнути fetch content-block у `try/catch` з fallback-контентом (як у `product/[slug]`).
2. Або перевести ці сторінки на `dynamic`/`revalidate` замість статичного prerender.
3. Розглянути додавання власних `error.tsx` для content-сторінок (зараз падають у повноекранний `global-error.tsx`).
