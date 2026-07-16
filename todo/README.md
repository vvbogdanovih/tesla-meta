# TODO — знахідки аудиту від 01.07.2026

Один файл = одна проблема. Пріоритети: **P1** — критичне (виправити перед запуском), **P2** — важливе, **P3** — бажане/документація. Після виконання — видаляти файл або переносити позначку «Статус: DONE».

> **Ревізія 15.07.2026:** усі пункти перевірено проти актуального коду; виконане прибрано (закриті підпункти позначено в самих файлах).

## P1 — критичне ✅ виконано (06.07.2026)

Усі P1 реалізовано в коді (план — [PLAN-P1.md](PLAN-P1.md)). Разом закрито й **P2-backend-admin-lists-pagination** (пагінація products/leads + createdAt-індекси) і **P3-docs-seo-strategy-gaps** (seo-strategy §4.1b).

> **Лишилось перед запуском P1 у проді:** застосувати міграцію `20260706120000_lead_order_created_at_index` (`yarn prisma:deploy`) і запустити seed ContentBlock'ів (`yarn prisma db seed`) — інакше `/pro-nas` та `/kontakty` віддають 404.

## P2 — важливе

| Файл | Репо | Суть |
|---|---|---|
| [P2-frontend-image-optimization](P2-frontend-image-optimization.md) | frontend | unoptimized:true — повнорозмірні фото, LCP |
| [P2-frontend-seo-jsonld-misc](P2-frontend-seo-jsonld-misc.md) | frontend | Organization JSON-LD, неповний Product JSON-LD, manifest |
| [P2-frontend-a11y-motion](P2-frontend-a11y-motion.md) | frontend | a11y LeadButton, reduced-motion |
| [P2-backend-auth-hardening](P2-backend-auth-hardening.md) | backend | Refresh без інвалідації, роль JWT без звірки з БД |
| [P2-backend-bigint-500](P2-backend-bigint-500.md) | backend | BigInt(id) → 500 на невалідний id |
| [P2-backend-swagger-strict-validation](P2-backend-swagger-strict-validation.md) | backend | Swagger у prod, strict вимкнено, body limit 10mb |
| [P2-backend-test-coverage](P2-backend-test-coverage.md) | backend | Покрито 5/18 модулів; payment-requisites без тестів |
| [P2-backend-misc-quality](P2-backend-misc-quality.md) | backend | Фільтр помилок, кеш каталогу, мертвий код тощо |
| [P2-admin-middleware-guard](P2-admin-middleware-guard.md) | admin | Захист роутів лише клієнтський |
| [P2-admin-error-states-zod](P2-admin-error-states-zod.md) | admin | Вічний спінер, невикористана zod-валідація, confirm() |
| [P2-admin-heic-upload](P2-admin-heic-upload.md) | admin | Аплоад не приймає HEIC (фото з iPhone) |
| [P2-tests-frontend-admin](P2-tests-frontend-admin.md) | frontend, admin | Нуль тестів в обох репо |

## P3 — бажане / документація

| Файл | Репо | Суть |
|---|---|---|
| [P3-frontend-dead-code-hardcode](P3-frontend-dead-code-hardcode.md) | frontend | Зайві deps, хардкоди Footer/головної |
| [P3-admin-ui-dedup-dead-code](P3-admin-ui-dedup-dead-code.md) | admin | Дублювання Field/таблиць, мертвий код |
| [P3-docs-crossref-tails](P3-docs-crossref-tails.md) | meta | ADR-0008 без monopay, биті перехресні посилання |
| [P3-docs-sync-with-code](P3-docs-sync-with-code.md) | meta | /api/v1, swagger-шлях, trgm-абзац, stats/health |
| [P3-docs-deployment](P3-docs-deployment.md) | meta | Немає deployment.md: CI/CD, бекапи, ротація ключів |
| [P3-docs-migration-runbook](P3-docs-migration-runbook.md) | meta | Немає runbook міграції з WooCommerce |

## Рекомендований порядок

P1 закрито. Детальний план виконання решти — **[PLAN-P2.md](PLAN-P2.md)** (звірений з кодом 15.07.2026): три незалежні треки (backend B1–B7, admin A0–A5, frontend F1–F6, доки M1–M4) з точками синхронізації (HEIC, thumbUrl-контракт, пароль 8+, forbidNonWhitelisted, slugify-вектори).
