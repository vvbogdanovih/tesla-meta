# Немає повноцінного ETL-скрипта міграції даних з WooCommerce

- **Пріоритет:** P1 — блокер запуску
- **Репозиторій:** tesla-backend (+ дані teslalviv.com)
- **Статус:** TODO (виявлено 17.07.2026)

## Проблема

`migration-runbook.md` описує детальний ETL: експорт REST → дедуплікація за `sku` → мапінг `Car`/`ProductFitment`/`Category` → AVIF → `Redirect` → верифікація. Реально є лише:
- `scripts/scrape/scrape-products.ts` + `scrape-categories.ts` (тягнуть зі Store API у JSON);
- `seed.ts` (upsert).

**Немає:**
- дедуплікації за `sku` зі звітом конфліктів;
- мапінг-таблиці старих категорій → (`car`, `category`);
- побудови `ProductFitment` зі старих модельних категорій;
- звіту розбіжностей та верифікаційних звірянь після імпорту.

Runbook сам це визнає («Міграційний скрипт — окрема CLI-команда … ще належить зробити»). Каталог — 1000+ SKU; runbook §0: «без міграції запуск неможливий».

## Що зробити

1. Написати CLI-команду міграції за сценарієм runbook (дедуплікація, мапінг fitment/категорій, AVIF, звіти).
2. Прогнати dry-run проти реального експорту, звірити кількості/конфлікти.
3. Пов'язано з [P1-seo-301-redirects](P1-seo-301-redirects.md) (наповнення `Redirect`) та FR-A8 (масовий import/export — [P2-missing-features](P2-missing-features.md)).
