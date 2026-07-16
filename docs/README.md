# Документація — Tesla Lviv

Індекс продуктової та технічної документації проєкту. Точка входу в проєкт — [кореневий README](../README.md).

## Документи

| Документ | Опис | Статус |
|----------|------|--------|
| [PRD.md](PRD.md) | **Product Requirements** — контекст, цілі, аудиторія, scope, епіки, user stories, ризики, фази | Draft v1.2 |
| [FRD.md](FRD.md) | **Functional Requirements** — архітектура, sitemap, FR по компонентах, API, моделі даних, NFR | Draft v1.3 |
| [db-schema.md](db-schema.md) | **Модель БД (PostgreSQL + Prisma)** — ER-діаграма, Prisma-схема, enum'и, індекси, запити | Draft v1.3 |
| [backend-architecture.md](backend-architecture.md) | **Архітектура бекенду (NestJS)** — модулі, шари, auth/RBAC, інтеграції, ETL, структура | Draft v1.1 |
| [current-site-audit.md](current-site-audit.md) | **Аудит чинного сайту** — фактичний стан teslalviv.com, що зберегти, реальні слабкі місця | v1.0 |
| [seo-strategy.md](seo-strategy.md) | **SEO-стратегія** — міграція без втрат, технічний фундамент, фасети, приріст | Draft v1.1 |
| [design-principles.md](design-principles.md) | **Дизайн-принципи** — візуальна мова, теми, типографіка, рух, компоненти | Draft v1.0 |
| [integration-1c.md](integration-1c.md) | **ТЗ інтеграції з 1С** — сайт-ініціатор: pull наявності/цін, push замовлень ([ADR-0016](adr/0016-erp-1c-integration.md)) | ТЗ |
| [migration-runbook.md](migration-runbook.md) | **Runbook міграції WooCommerce → новий стек** — ETL: експорт, дедуплікація за sku, мапінг, AVIF, редіректи, верифікація, rollback | Draft v1.0 |

## Розділи

- [`adr/`](adr/) — **Architecture Decision Records**: зафіксовані архітектурні рішення (вибір стеку, інтеграцій тощо).
- [`assets/`](assets/) — растрові зображення та скриншоти. Діаграми за замовчуванням робимо в [Mermaid](https://mermaid.js.org/) прямо в Markdown (див. [CONTRIBUTING.md](../CONTRIBUTING.md#конвенції-документів)).

## Порядок читання

1. **PRD** — навіщо й що будуємо (продуктовий рівень).
2. **FRD** — як саме (функціональні та технічні вимоги).
3. **ADR** — чому ухвалили ключові технічні рішення.

## Конвенції

Формат документів, версіонування та правила внесення змін — у [CONTRIBUTING.md](../CONTRIBUTING.md).
