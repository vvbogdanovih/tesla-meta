# SEO-прогалини (метадані, ЧПУ-роути категорій, noindex, LCP, аналітика)

- **Пріоритет:** P2 — SEO критичний пріоритет проєкту
- **Репозиторій:** tesla-frontend
- **Статус:** TODO (виявлено 17.07.2026)

SEO-фундамент загалом сильний (`sitemap.ts`, `robots.ts`, JSON-LD Product/BreadcrumbList/Organization, canonical/OG). Прогалини:

## 1. ЧПУ-роути категорій `/category/[model]` відсутні (FR-2.3, ADR-0001)
Замість документованих `/category/[model]` та `/category/[model]/[category]` каталог живе на `/shop?car=&category=`. Це суперечить FRD §2 sitemap, ADR-0001 (редіректи ведуть на `/category/...`) і runbook §5. SEO-наслідок: категорії на query-параметрах замість чистих URL. Пов'язано з [P1-seo-301-redirects](P1-seo-301-redirects.md).

## 2. Головна сторінка без metadata/canonical
`src/app/page.tsx` не експортує `metadata`/`generateMetadata` — успадковує лише дефолти root-layout: немає self-canonical `https://teslalviv.com/`, немає сторінко-специфічного OG. Головна має priority 1.0 у sitemap.

## 3. `/wishlist` без `noindex` (FR-W6)
Сторінка — клієнтський компонент без `robots: noindex`; у `robots.ts` disallow є `/cart,/checkout,/account,/search,/auth`, але **`/wishlist` не додано**. Приватні дані користувача можуть індексуватись.

## 4. Немає `priority` на LCP-зображеннях
Пошук `priority|fetchPriority` по `src/` — 0 збігів. Ні hero/головна, ні головне фото товару (`ProductGallery`) не позначені `priority` → страждають LCP/Core Web Vitals.

## 5. GA4 / аналітика відсутня повністю (NFR-7)
Немає `gtag`/`dataLayer`/GA-скрипта; не шлються події `add_to_cart`, `add_to_wishlist`, `begin_checkout`, `purchase`, `lead`.

## 6. sitemap: N+1 послідовних запитів (P3)
`sitemap.ts:15-22` тягне всі товари сторінками по 60 послідовно на кожен запит `/sitemap.xml`; розглянути ISR/кеш. `categories()` тут без `.catch()` (на відміну від products) — падіння категорій зламає sitemap.
