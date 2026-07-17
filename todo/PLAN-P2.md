# PLAN-P2 — залишки після реалізації (15–16.07.2026)

> Реалізацію P2+P3 завершено; зміни в трьох app-репо закомічені й запушені (16.07.2026). Зведення змін по репо та покрокові інструкції — у git-історії цього файлу. Лишились: відкриті хвости, нотатки до деплою та невиконаний M3.

## Відкриті хвости

1. **Запустити `scripts/backfill-thumbs.ts`** (backend, разово, проти БД+R2) — мініатюри для наявних фото; фронт до того працює через фолбек `thumbUrl ?? url`. Чекає згоди користувача (пише у спільні dev-БД і R2).
2. Опційно: `DataTable` в адмінці (A5.7); стиснення `hero.mp4` до ~1MB — ffmpeg локально відсутній (`brew install ffmpeg`; після F4 відео і так лише desktop без reduce).

## Деплой (коли дійде; зараз не потрібен)

- Порядок: **backend → admin/frontend** (HEIC-accept в адмінці вимагає нового бекенда; фронтові thumb'и — fallback-safe).
- Після деплою B4 старі refresh-токени (без jti) невалідні → користувачі разово перелогіняться.
- Прод-обмеження proxy: auth-cookie host-only — потрібен спільний host (reverse proxy) або `Domain=.site.com` / маркер-cookie (варіанти — в коментарі `src/proxy.ts`).
- Прод-міграції: `prisma migrate deploy` (дві нові: `refresh_sessions`, `product_image_thumb_url`).

## M3 — `docs/deployment.md` (НЕ виконано; відкладено 16.07 — деплоймент зараз не потрібен)

Потребує фактів від користувача: хостинг/VPS, домени проду, чи є staging, де зберігаються ключі зараз, куди шипити логи.

Структура документа:
1. Середовища й домени (dev-порти з CLAUDE.md; prod: frontend 3000, admin 3001, backend 4040 — reverse proxy?).
2. Env-змінні per-repo (backend — `env.constant.ts`; frontend/admin — `.env.example`); окремо секрети: `PAYMENT_ENC_KEY`, `JWT_SECRET`/`REFRESH_JWT_SECRET`, pepper, `API_PUBLIC_URL`, `AUTH_COOKIE_NAMES`.
3. CI/CD: зараз немає ані workflows, ані Dockerfile — мінімальний пайплайн lint → tsc → tests → build; `prisma migrate deploy` у деплої.
4. Бекапи: PostgreSQL (pg_dump розклад/ретенція/тест відновлення), R2 (versioning або rclone-дзеркало).
5. Ротація ключів: `PAYMENT_ENC_KEY` (втрата = нечитабельні платіжні секрети → розшифрувати всі → перешифрувати → атомарна заміна), JWT-секрети (інвалідація — таблиця `refresh_sessions`).
6. Моніторинг/логи (pino вже в коді; куди шипити — питання).
