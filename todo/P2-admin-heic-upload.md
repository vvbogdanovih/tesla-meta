# Аплоад зображень не приймає HEIC (фото з iPhone)

- **Пріоритет:** P2 — важливий (щоденний сценарій продавця)
- **Репозиторій:** tesla-admin (+ tesla-backend)
- **Статус:** TODO

## Проблема

Інпути аплоаду мають `accept='image/jpeg,image/png,image/webp'` — фото з iPhone (HEIC, типовий сценарій продавця, який фотографує запчастини телефоном) відхиляються ще до бекенда.

## Де в коді

- `src/common/components/products/ProductForm.tsx:475`
- `src/app/(dashboard)/cars/page.tsx:221`
- Бекенд: sharp у пайплайні ADR-0007 (перевірити підтримку HEIF — може знадобитись libheif у збірці)

## Що зробити

1. Додати `image/heic,image/heif` у `accept`.
2. Переконатися, що бекенд-конвертація в AVIF приймає HEIC (sharp з libheif) — інакше конвертувати на клієнті або повертати зрозумілу помилку.
