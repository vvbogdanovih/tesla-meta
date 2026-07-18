# Закомічені JWT-токени суперадміна у tesla-frontend

- **Пріоритет:** P1 — безпека, терміново
- **Репозиторій:** tesla-frontend
- **Статус:** TODO (виявлено 17.07.2026)

## Проблема

Файл `c.txt` у корені `tesla-frontend` **відстежується git** (`git ls-files` підтверджує) і містить дамп cookie у форматі Netscape із живими `access_token` та `refresh_token` **суперадміна** (`role":"superadmin"`, `email: vvbogdanovih@gmail.com`). `refresh_token` дійсний до `exp: 1785315620` (~грудень 2026). У `.gitignore` немає патерну для `.txt`/cookie-дампів.

Навіть якщо токени підписані для `localhost` (dev), вони вже в git-історії. Якщо `JWT_SECRET`/`REFRESH_JWT_SECRET` спільний між dev і prod — це прямий компроміс.

## Що зробити

1. `git rm c.txt`, закомітити видалення.
2. Додати в `.gitignore`: `c.txt`, `*.cookies`, cookie-дампи.
3. **Ротувати `JWT_SECRET` та `REFRESH_JWT_SECRET` на бекенді** — токен залишається в git-історії; ротація інвалідує його (таблиця `refresh_sessions` уже дозволяє інвалідацію refresh-сесій).
4. Переконатися, що dev і prod використовують **різні** секрети.
5. Опційно: почистити git-історію (`git filter-repo`) якщо репо приватне і історія критична — але ротація секрету важливіша.
