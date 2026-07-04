# TODO — знахідки аудиту від 01.07.2026

Один файл = одна проблема. Пріоритети: **P1** — критичне (виправити перед запуском), **P2** — важливе, **P3** — бажане/документація. Після виконання — видаляти файл або переносити позначку «Статус: DONE».

## P1 — критичне

| Файл | Репо | Суть |
|---|---|---|
| [P1-backend-rate-limiting-helmet](P1-backend-rate-limiting-helmet.md) | backend | Немає throttler (брутфорс/спам) і helmet |
| [P1-frontend-sitemap-broken-links](P1-frontend-sitemap-broken-links.md) | frontend | Sitemap без товарів + биті лінки в Header/Footer |
| [P1-frontend-error-loading-boundaries](P1-frontend-error-loading-boundaries.md) | frontend | Немає error.tsx/loading.tsx — падіння API кладе каталог |
| [P1-frontend-shop-canonical-meta](P1-frontend-shop-canonical-meta.md) | frontend | /shop без canonical і динамічних meta — дублікати |
| [P1-admin-products-pagination-search](P1-admin-products-pagination-search.md) | admin | Товари/ліди/wishlist без пагінації й пошуку (orders — вже готово) |

## P2 — важливе

| Файл | Репо | Суть |
|---|---|---|
| [P2-frontend-image-optimization](P2-frontend-image-optimization.md) | frontend | unoptimized:true — повнорозмірні фото, LCP |
| [P2-frontend-seo-jsonld-misc](P2-frontend-seo-jsonld-misc.md) | frontend | Organization JSON-LD, неповний Product JSON-LD, manifest |
| [P2-frontend-eslint-a11y-motion](P2-frontend-eslint-a11y-motion.md) | frontend | 2 lint-errors, a11y LeadButton, reduced-motion |
| [P2-backend-auth-hardening](P2-backend-auth-hardening.md) | backend | Refresh без інвалідації, роль JWT без звірки з БД |
| [P2-backend-bigint-500](P2-backend-bigint-500.md) | backend | BigInt(id) → 500 на невалідний id |
| [P2-backend-admin-lists-pagination](P2-backend-admin-lists-pagination.md) | backend | Адмін-списки без take, немає індексів createdAt |
| [P2-backend-swagger-strict-validation](P2-backend-swagger-strict-validation.md) | backend | Swagger у prod, strict вимкнено, body limit 10mb |
| [P2-backend-test-coverage](P2-backend-test-coverage.md) | backend | Покрито 3/13 модулів; orders без тестів |
| [P2-backend-misc-quality](P2-backend-misc-quality.md) | backend | Фільтр помилок, кеш каталогу, мертвий код тощо |
| [P2-admin-middleware-guard](P2-admin-middleware-guard.md) | admin | Захист роутів лише клієнтський |
| [P2-admin-error-states-zod](P2-admin-error-states-zod.md) | admin | Вічний спінер, невикористана zod-валідація, confirm() |
| [P2-admin-heic-upload](P2-admin-heic-upload.md) | admin | Аплоад не приймає HEIC (фото з iPhone) |
| [P2-tests-frontend-admin](P2-tests-frontend-admin.md) | frontend, admin | Нуль тестів в обох репо |

## P3 — бажане / документація

| Файл | Репо | Суть |
|---|---|---|
| [P3-frontend-dead-code-hardcode](P3-frontend-dead-code-hardcode.md) | frontend | Мертві константи, зайві deps, хардкоди |
| [P3-admin-ui-dedup-dead-code](P3-admin-ui-dedup-dead-code.md) | admin | Дублювання Field/таблиць, мертвий код |
| [P3-docs-commit-tails](P3-docs-commit-tails.md) | meta | 5 хвостів у незакомічених доках перед комітом |
| [P3-docs-sync-with-code](P3-docs-sync-with-code.md) | meta | FRD orders «(план)», /api/v1, trgm-абзац — застаріле |
| [P3-docs-seo-strategy-gaps](P3-docs-seo-strategy-gaps.md) | meta | seo-strategy без /price-sheet і noindex /wishlist |
| [P3-docs-deployment](P3-docs-deployment.md) | meta | Немає deployment.md: CI/CD, бекапи, ротація ключів |
| [P3-docs-migration-runbook](P3-docs-migration-runbook.md) | meta | Немає runbook міграції з WooCommerce |

## Рекомендований порядок

1. P1 backend (безпека) → 2. P1 frontend (SEO) → 3. P1 admin + P2 checkout (замкнути e-commerce-цикл) → 4. решта P2 → 5. P3.
