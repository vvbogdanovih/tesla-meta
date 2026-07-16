# План виконання P2/P3-задач (для моделі-виконавця)

> Контекст: 3 app-репо у `repos/` (поза git). Порти: backend 4040, frontend 3040, admin 3030.
> Стек: NestJS 11 · Prisma 7 · Next.js 16 · React 19 · Tailwind v4. Стиль коду: tabs, без `;`, одинарні лапки, коментарі UK.
> **Комітити/пушити — лише з явної згоди користувача.** Тексти UI — українською.
> Перевірено проти коду 2026-07-15. Схема Prisma: `src/database/prisma/schemas/schema.prisma`.

## Уточнені факти (розбіжності з todo-файлами, зʼясовані з коду)

1. **`axios` — НЕ мертва залежність**: використовується `payments/monopay.client.ts:2` і `delivery-np/nova-poshta.client.ts:2`. Видаляти лише `resend`.
2. **TS strict дешевий**: `npx tsc --noEmit --strict` → рівно **35 помилок, усі TS2564** (DTO-поля без ініціалізатора) — лікується `!` після імені поля.
3. **sharp у поточній збірці НЕ декодує HEIC** (libheif без HEVC-декодера, лише AVIF) → потрібен WASM-фолбек `heic-convert`.
4. **Refresh-токен**: httpOnly-cookie `ENV.REFRESH_TOKEN_NAME`, TTL 30 діб; access — 15 хв. Ротація на `/refresh` вже видає нові токени, але **старий лишається валідним** — це і є вада.
5. **`PrismaModule` — `@Global()`** → `RolesGuard` може інжектити `PrismaService` без правок модулів.
6. **Monopay-вебхук безпечний для `forbidNonWhitelisted`**: приймає rawBody без `@Body()` DTO.
7. **Аплоад — multipart (multer)** зі своїм лімітом 10MB → глобальний json-limit можна знижувати.
8. **Auth-cookie видимі admin-middleware локально**: host-only (без `Domain`), обидва на `localhost` → браузер шле їх і на :3030. У проді працює лише при спільному host (reverse proxy) — див. A1.
9. Дублікати `BigInt(id)` є ще й у `payment-requisites.controller.ts:29,34` (не лише products/orders/leads).

## Порядок виконання: три незалежні треки + точки синхронізації

| Трек | Послідовність | Примітка |
|---|---|---|
| **Backend** | B1 → B2 → B3 → B4 → B5+B6 → B7 | B5+B6 — один PR (обидва переписують `uploadImage`) |
| **Admin** | A0 → A1 → A2 → A3 → A4 → A5 | A3 (HEIC accept) — лише після деплою B5 |
| **Frontend** | F1 → F2 → F3 → F4 → F5 → F6 | F5 (thumbSrc) fallback-safe — можна до B6 |
| **Meta (доки)** | M1 → M2 → M3 → M4 | будь-коли; M3/M4 потребують фактів від користувача |

**Точки синхронізації:**
- 🔗 **HEIC**: B5 (backend) деплоїться **раніше** за A3 (admin accept) — інакше вибраний .heic гарантовано падає.
- 🔗 **Мініатюри**: контракт — `ProductImage.thumbUrl` (nullable), варіант **400px**, ключ `<uuid>_w400.avif`. F5 мержиться будь-коли (фолбек `thumbUrl ?? url`), B6 «вмикає» ефект.
- 🔗 **Пароль 8+**: B4 (MinLength у register/change-password DTO) — синхронно оновити zod-схеми реєстрації/зміни пароля у frontend (і admin, якщо є).
- 🔗 **`forbidNonWhitelisted`** (B3): перед вмиканням — grep POST/PATCH-payload'ів у frontend/admin на поля поза DTO (типовий кандидат — `id` у тілі PATCH).
- 🔗 **slugify-контракт**: однакова таблиця тест-векторів у admin-сьюті (A4) і backend-сьюті (B7) з перехресним коментарем.

---

# BACKEND (`repos/tesla-backend`)

## B1. `ParseBigIntPipe` (P2-backend-bigint-500) — ✅ виконано 15.07 (не закомічено)

Найменша й незалежна — робити першою.

1. Створити `src/common/pipes/parse-bigint.pipe.ts` (нова тека поруч із `guards/`):
   ```ts
   import { BadRequestException, Injectable, PipeTransform } from '@nestjs/common'

   // ':id' → bigint; невалідне значення → 400 (замість SyntaxError → 500)
   @Injectable()
   export class ParseBigIntPipe implements PipeTransform<string, bigint> {
   	transform(value: string): bigint {
   		if (!/^\d+$/.test(value ?? '')) {
   			throw new BadRequestException('Невалідний ідентифікатор')
   		}
   		return BigInt(value)
   	}
   }
   ```
   Regex обовʼязковий: `BigInt('0x10')`, `BigInt('  1 ')` теж парсяться — потрібні лише десяткові id.
2. Застосувати `@Param('id', ParseBigIntPipe) id: bigint` (сигнатури методів → `bigint`, прямі `BigInt(id)` прибрати):
   - `products.controller.ts:26,36,41` (findOne/update/remove)
   - `orders.controller.ts:59,66` (setStatus/setPaymentStatus); `byId` (:45) — уніфікувати теж: пайп + сигнатура `findById(id: bigint)`, внутрішній `parseId` прибрати (його спека переїде на рівень пайпа)
   - `leads.controller.ts:33,40`
   - `payment-requisites.controller.ts:29,34` (та сама вада, у todo не значилась)
3. Спека `parse-bigint.pipe.spec.ts`: `'12'→12n`; `'abc'`, `'0x10'`, `'-1'`, `''` → 400.

**Перевірка:** `yarn test`; `GET /api/products/abc` (admin) → 400, не 500.

## B2. Misc quality (P2-backend-misc-quality) — ✅ виконано 15.07 (не закомічено)

Точкові правки, один PR.

1. **`prisma.filter.ts:24-30`** — default-гілка → **500** + `Logger.error` (зараз будь-який невідомий P-код → 400, моніторинг сліпне):
   ```ts
   default:
   	this.logger.error(`Prisma ${exception.code}: ${exception.message}`)
   	return res.status(HttpStatus.INTERNAL_SERVER_ERROR).json({
   		statusCode: 500, error: 'Internal Server Error', message: 'Внутрішня помилка сервера'
   	})
   ```
2. **Cache-Control на каталог** — патерн з `delivery-np.controller.ts:21`: на всі GET `catalog.controller.ts` (list/search/bySlug) `@Header('Cache-Control', 'public, max-age=60, stale-while-revalidate=300')`. Адмін редагує ціни/залишки — 60 с застарівання прийнятно. Опційно те саме на `payment-requisites-public.controller.ts` (`/active`).
3. **`uniqueSlug` race** — ретрай у `products.service.ts` `create` (:76-99): до 3 спроб, на `P2002` по `slug` перегенерувати кандидата:
   ```ts
   for (let attempt = 0; ; attempt++) {
   	const slug = await this.uniqueSlug(dto.slug?.trim() || dto.name)
   	try { return await this.prisma.product.create({ data: { ..., slug }, ... }) }
   	catch (e) {
   		if (attempt < 2 && this.isSlugConflict(e)) continue
   		throw this.mapError(e)
   	}
   }
   ```
   (`isSlugConflict`: `P2002` && `meta.target` містить `slug`.) В `update` slug задає адмін явно — там поточний Conflict коректний.
4. **`wishlist.service.ts` topProducts** (~:106) — додати `where` (той самий обʼєкт, що для списку вище) у `groupBy`.
5. **Видалити `resend`** (`yarn remove resend`) + викинути `RESEND_API_KEY`/`SERVICE_EMAIL`/`ALLOW_EMAIL_SENDING` з `env.constant.ts` (~:44-47). `axios` **не чіпати** (факт 1). Контрольний grep по `scripts/` перед видаленням.
6. **Схема попереду коду** — таблиці не дропати (порожні, не заважають): у `schema.prisma` над `BlogPost`/`Banner`/`Redirect` коментар `// ЗАПЛАНОВАНО: API ще немає (P3)`; з `endpoints.constant.ts` видалити мертві блоки (FORGOT/RESET_PASSWORD, USERS, CART, BLOG, BANNERS) — константа реально використовується лише `health.controller.ts:6`.

**Перевірка:** `curl -I /api/catalog/products` → Cache-Control; юніт на невідомий P-код → 500; `yarn build` після видалення resend.

## B3. Swagger / ValidationPipe / body limit / strict (P2-backend-swagger-strict-validation)

Робити **до** B4–B6, щоб нові файли писались одразу під strict.

1. **Swagger лише поза prod** — `main.ts:38-45` обгорнути в `if (ENV.NODE_ENV !== 'production') { ... }`.
2. **`forbidNonWhitelisted: true`** — `main.ts:33`. Ризики перевірені: monopay-вебхук без DTO — не зачеплений; `@Body('prefix')` у s3 — не зачеплений. Обовʼязково: grep клієнтських payload'ів (🔗 див. синхронізацію) і дзеркально оновити ValidationPipe у e2e-сетапах (`test/auth.e2e-spec.ts:17`, catalog, products — там пайп створюється вручну).
3. **Body limit** — `main.ts:34`: `'10mb'` → `'1mb'`. Аплоад — multipart (факт 7), TipTap-JSON — текст без base64, вебхук — сотні байтів → безпечно.
4. **`strict: true`** у `tsconfig.json` (замість `noImplicitAny:false`, `strictBindCallApply:false`) → виправити 35 TS2564: definite-assignment `!` у DTO-полях (`email!: string`) — список дасть компілятор.

**Перевірка:** `yarn build`, `yarn test && yarn test:e2e`; `NODE_ENV=production` → `GET /swagger` 404; зайве поле у body → 400; JSON >1MB → 413.

## B4. Auth hardening (P2-backend-auth-hardening)

Найбільша. Одна міграція — атомарний PR разом із тестами.

### B4.1. Модель refresh-сесій
Дизайн під малий магазин: зберігаємо лише `jti` (UUID), без хешу токена. Ротація: кожен `/refresh` видає новий jti і видаляє старий. Reuse-детекція: валідний за підписом токен із jti, якого немає в БД → відкликати **всі** сесії користувача.

`schema.prisma` (після `User`; + `refreshSessions RefreshSession[]` у `User`):
```prisma
// Активні refresh-сесії (ротація jti). Рядок = один чинний refresh-токен.
model RefreshSession {
  jti       String   @id
  userId    BigInt   @map("user_id")
  user      User     @relation(fields: [userId], references: [id], onDelete: Cascade)
  expiresAt DateTime @map("expires_at")
  createdAt DateTime @default(now()) @map("created_at")

  @@index([userId])
  @@map("refresh_sessions")
}
```
Міграція: `npx prisma migrate dev --name refresh_sessions`.

### B4.2. `AuthService`
- `jwt-payload.ts`: додати `jti?: string` (лише в refresh-токені).
- `buildAuthResult` (:66-83): генерувати `randomUUID()`, писати `refreshSession.create`, підписувати refresh із `{ ...payload, jti }`.
- `refresh` (:47-63):
  ```ts
  const session = payload.jti
  	? await this.prisma.refreshSession.findUnique({ where: { jti: payload.jti } })
  	: null
  if (!session || session.expiresAt < new Date()) {
  	// Повторне використання ротованого токена → відкликаємо всі сесії користувача
  	await this.prisma.refreshSession.deleteMany({ where: { userId: BigInt(payload.sub) } })
  	throw new UnauthorizedException('Недійсний токен оновлення')
  }
  await this.prisma.refreshSession.delete({ where: { jti: payload.jti! } }).catch(() => undefined)
  await this.prisma.refreshSession.deleteMany({ where: { expiresAt: { lt: new Date() } } }) // лінивий cleanup, без крону
  ```
- `logout(refreshToken?)`: verify → `delete({ where: { jti } })`, помилки ковтати (cookie все одно чистимо). `auth.controller.ts:46-50` — logout стає `async`, читає cookie `ENV.REFRESH_TOKEN_NAME`.
- Бонус: у `profile.service.ts` `changePassword` після успіху — `refreshSession.deleteMany({ where: { userId } })`.

### B4.3. Звірка ролі з БД — у `RolesGuard`, не в `validate()`
Платимо 1 запит лише на admin/superadmin-роутах; звичайні запити лишаються stateless. `roles.guard.ts`: інжект `PrismaService` (модуль глобальний, факт 5), після перевірки ролі з payload — `user.findUnique({ select: { role: true } })` і фінальна звірка. `jwt.strategy.ts` не чіпати.

### B4.4. Пароль 8+
`register.dto.ts:8` і `profile/dto/change-password.dto.ts` (`newPassword`) → `@MinLength(8, { message: 'Пароль має містити щонайменше 8 символів' })`. `LoginDto` **не чіпати** (старі короткі паролі мають логінитись). 🔗 Синхронізувати zod-схеми клієнтів.

### B4.5. Тести (той самий PR)
- `auth.service.spec.ts`: ротація видаляє старий jti; невідомий jti → 401 + `deleteMany` по userId; logout видаляє сесію.
- `test/auth.e2e-spec.ts`: refresh → повторний refresh старою cookie → 401; logout → refresh → 401.
- Спека `RolesGuard`: розжалуваний у БД admin → false.

**Перевірка:** міграція без дрейфу; вручну: login → refresh → повторити refresh старою cookie (curl) → 401; понизити роль у БД → адмін-роут → 403 одразу.

## B5. HEIC-аплоад (backend-частина P2-admin-heic-upload)

1. `yarn add heic-convert` (+ `-D @types/heic-convert`) — WASM-декодер, однаково працює на dev-macOS і prod-Linux (факт 3).
2. `s3.controller.ts:48` — `FileTypeValidator({ fileType: /^image\/(jpeg|png|webp|avif|gif|heic|heif)$/ })`. `PresignDto` (:24) **не розширювати** — presign кладе файл без конвертації, сирий HEIC публікувати не можна.
3. `s3.service.ts` `uploadImage` — feature-detect + фолбек:
   ```ts
   private isHeic(buf: Buffer): boolean {
   	const brand = buf.subarray(8, 12).toString('ascii') // ftyp-брендинг
   	return ['heic', 'heix', 'hevc', 'heim', 'heis', 'hevm', 'mif1', 'msf1'].includes(brand)
   }
   // на початку uploadImage:
   if (this.isHeic(buffer)) {
   	try { input = Buffer.from(await convert({ buffer, format: 'JPEG', quality: 0.9 })) }
   	catch { throw new UnsupportedMediaTypeException('Не вдалося прочитати HEIC-файл') }
   }
   ```
   `rotate()` після конвертації лишається коректним (EXIF переноситься). Ліміт 10MB достатній для фото з iPhone.
4. Спека: `isHeic` на синтетичному буфері.

**Перевірка:** `POST /api/s3/upload` з реальним .heic → 201, `.avif`-URL відкривається.

## B6. Мініатюри (backend-частина P2-frontend-image-optimization) — один PR з B5

Рішення: Next optimizer лишається вимкненим (свідомий VPS trade-off, `next.config.ts:6-8`); варіанти генерує бекенд при аплоаді (ADR-0007, upload-time, нуль runtime-CPU). **Один розмір 400px** (не 100/400/800): 400px AVIF ≈ 10–25KB, покриває і 44px-мініатюру прайс-листа, і картку @2x; три розміри — утричі більше обʼєктів заради маргінального виграшу.

1. `ProductImage` + міграція `npx prisma migrate dev --name product_image_thumb_url`:
   ```prisma
   thumbUrl String? @map("thumb_url") // 400px AVIF; null → фронт бере url (старі записи)
   ```
2. `s3.service.ts` — два розміри з одного інстансу (`base = sharp(input,{failOn:'none'}).rotate()`; `base.clone().resize(1600...)` і `base.clone().resize(400...)`, обидва `.avif()`); ключі `<uuid>.avif` + `<uuid>_w400.avif` (детерміновано — знадобиться для backfill), повертати `{ key, url, thumbUrl }`.
3. Пронести `thumbUrl`: `create-product.dto.ts` (`ProductImageDto` + `@IsOptional() thumbUrl?`), `products.service.ts:207` (`imageRows`), селекти карток — `catalog.service.ts:26` і `:149-150`, `wishlist.service.ts` CARD_SELECT.
4. Backfill: одноразовий `scripts/backfill-thumbs.ts` (патерн запуску — `scripts/np-sync-once.ts`): `findMany({ where: { thumbUrl: null } })` → fetch(url) → sharp 400 → PutObject `<basename>_w400.avif` → update. Фолбек на фронті робить скрипт безпечним для відкладеного запуску.

**Перевірка:** аплоад → два обʼєкти в R2; `GET /api/catalog/products` містить `thumbUrl`; старі записи з `null` не ламають фронт.

## B7. Тестове покриття (P2-backend-test-coverage)

Патерни: юніт — моки Prisma як в `orders.service.spec.ts:73-97`; e2e — `test/auth.e2e-spec.ts` + Testcontainers. **У `test/jest.setup.ts` додати `process.env.PAYMENT_ENC_KEY ||= 'test-enc-key-min-16-chars'`** — інакше `crypto.util` падає на імпорті.

Топ-6 сьютів за пріоритетом:
1. **`crypto.util.spec.ts`**: roundtrip; формат `iv:tag:data`; два шифрування → різні результати (random IV); підміна tag → throw.
2. **`payment-requisites.service.spec.ts`**: create шифрує секрети; `toSafe` не містить `liqpayPrivateKey`/`monopayToken`, містить `*Set`-прапорці (:236-243); write-only update не перетирає секрет порожнім; один активний на канал; авто-активація; `getActive*` повертають розшифроване. + e2e: admin (не superadmin) → `GET /api/payment-requisites` → 403.
3. **`wishlist.service.spec.ts`**: add — upsert-ідемпотентність, 404/400; remove — deleteMany без throw; adminList — topProducts поважає фільтр (регресія до B2.4), limit ≤200.
4. **`addresses.service.spec.ts`**: ensureOwner (чужий id → 404); перша адреса → `isDefault:true` попри dto; setDefault знімає прапорець з інших у транзакції; remove основної підвищує найновішу.
5. **`profile.service.spec.ts`**: changePassword — невірний поточний → 400, успіх → argon2+pepper; після B4 — інвалідація сесій. + DTO-тест MinLength(8) через `plainToInstance`+`validate` (зразок `orders.service.spec.ts:206-223`).
6. **Доповнити `orders.service.spec.ts`**: create з `userId` (привʼязка) і гість (`null`); формат/послідовність `orderNumber`; `findAll` за `status` і пошук+статус; мультипозиційний відкат при нестачі другої позиції; `findByNumber` не віддає `paymentInvoiceId`.

**Перевірка:** `yarn test --coverage` — payment-requisites/wishlist/addresses/profile ≥80% рядків; e2e зелені.

---

# ADMIN (`repos/tesla-admin`)

## A0. Спільні UI-примітиви (створення) — фундамент для A2/A5 — ✅ виконано 15.07 (не закомічено)

1. **`src/common/components/ui/field.tsx`** — точна копія 4 ідентичних дублікатів (`ProductForm.tsx:566-583`, `cars/page.tsx:272-289`, `categories/page.tsx:222-239`, `requisites/page.tsx:331-348`): `{ label, hint?, error?, children }`.
2. **`ui/states.tsx`** — `LoadingState` (Loader2 + «Завантаження…», донор `products/page.tsx:88-91`), `EmptyState` (dashed-рамка, донор `:92-95`), `ErrorState` (`{ message?, onRetry? }` + кнопка «Спробувати ще раз»; донор error-гілки — `(dashboard)/page.tsx:36-38`).
3. **`ui/confirm-dialog.tsx`** — поверх наявного `ui/modal.tsx`: `{ open, title, description?, confirmLabel?='Видалити', pending?, onConfirm, onClose }`; кнопки «Скасувати» + destructive-підтвердження (перевірити, чи `button.tsx` має `variant='destructive'`).
4. **`src/common/hooks/useDebounce.ts`** (тека зараз порожня, хоч і згадана в CLAUDE.md адмінки) — донор `products/page.tsx:34-40`, `useDebounce<T>(value, delay=400)`.
5. Barrel `components/index.ts`: `export * from './ui/field' | './ui/states' | './ui/confirm-dialog'`.

**Перевірка:** `yarn lint && yarn build`; примітиви ще не використовуються — регресій нуль.

## A1. Server-side guard: `src/proxy.ts` (P2-admin-middleware-guard) — ✅ виконано 15.07 (не закомічено)

Next 16: конвенція `middleware.ts` → **`proxy.ts`** (у `src/`).

```ts
import { NextResponse, type NextRequest } from 'next/server'

// Імена auth-cookie бекенда. Перевіряємо ЛИШЕ наявність — валідність/ролі перевіряє бекенд.
const AUTH_COOKIES = (process.env.AUTH_COOKIE_NAMES ?? 'refresh_token,tesla_refresh')
	.split(',').map(s => s.trim()).filter(Boolean)

export default function proxy(req: NextRequest) {
	if (AUTH_COOKIES.some(name => req.cookies.has(name))) return NextResponse.next()
	return NextResponse.redirect(new URL('/login', req.url))
}

export const config = {
	matcher: ['/((?!login|_next/static|_next/image|favicon.ico|.*\\..*).*)']
}
```
- Перевіряємо **refresh**-cookie (не access: він живе 15 хв і протухає при живій сесії → хибні виходи).
- `AUTH_COOKIE_NAMES` — server-side env, додати в `.env`/`.env.example` (локально `refresh_token`).
- Роль на edge не перевіряємо; `AdminGuard.tsx` лишається (роль + протухлий refresh).
- **Прод-застереження** (у коментар + PR-опис): cookie host-only (факт 8) — proxy працює лише при спільному host (reverse proxy `admin.site.com/api → backend`). Якщо домени розведуть: (а) бекенд ставить `Domain=.site.com`, або (б) адмінка ставить легкий не-httpOnly маркер `admin_session=1` у `useAuthStore.login`/чистить у `logOut`, і proxy перевіряє його (маркер підробний — прийнятно, гейтимо лише віддачу бандла).

**Перевірка:** без cookie `curl -I :3030/products` → 307 на `/login`; `/login` без циклу; статика не редіректиться; `yarn build` (edge runtime — без node-API).

## A2. Error-стани + zod-відповіді + ConfirmDialog + login catch (P2-admin-error-states-zod)

Глобальний тост на помилки вже є в інтерсепторі (`http.service.ts:33`) → мутаціям досить `onSettled` для закриття діалогу, логіну — придушити unhandled rejection + польова помилка.

1. **`products/[id]/page.tsx`** (:11-22): додати `isError, error, refetch`; `if (isLoading) return <LoadingState />`; на помилку — `ErrorState` («Товар не знайдено.» при `err.status === 404` без retry — статус навішує інтерсептор `http.service.ts:34-35`; інакше — з `onRetry={() => refetch()}`).
2. **Retry на списках** — гілка `isError` перед `isLoading`-тернарником: products (:42→:88), cars (:35→:122), leads (:38→:108), requisites (:42→:134), content (:14→:45), categories, orders, orders/[id], wishlist, users — той самий патерн.
3. **Zod-схеми відповідей** — нова тека `src/common/schemas/api/`: `product.api.schema.ts` (`productListResponseSchema`, `productDetailSchema`) і `payment-requisite.api.schema.ts` (`paymentRequisiteListSchema`). Кожна схема — `satisfies z.ZodType<Interface>` (компілятор впаде при дрейфі; інтерфейси в `types/` — джерело правди). **Памʼятати: zod стріпає невідомі ключі** — перелічити всі поля, які споживає UI. Передати: `products.api.ts:43-47` (`list`/`get` → `{ schema }`), `payment-requisites.api.ts:19`. Механізм `config.schema` вже готовий (`http.service.ts:40-52`).
4. **ConfirmDialog замість `confirm()`** — 7 місць: `products/page.tsx:59` (базовий патерн: стан `toDelete`, мутація з `onSettled: () => setToDelete(null)`), `cars/page.tsx:105` (лишити guard `linked > 0 → toast.error`), `categories/page.tsx:95` (guard по `_count.products`), `requisites/page.tsx:198`, `leads/page.tsx:125`, `orders/[id]/page.tsx:83,86` (не delete, а cancel/restore: `confirmLabel='Так, скасувати'/'Відновити'`).
5. **Login catch** (`login/page.tsx:29-39`): try/catch → `setError('root', { message })` + `{errors.root && <p …>}` під кнопкою; в `auth.api.ts:7-8` до `login` додати `{ skipErrorToast: true }` (без дубля тост+поле).

**Перевірка:** неіснуючий id → «Товар не знайдено» без вічного спінера; вимкнений бекенд → ErrorState + робочий retry; діалог видалення блокує подвійний клік (`pending`); логін з невірним паролем → польова помилка без unhandled rejection; тимчасово зіпсувати поле схеми → тост валідації.

## A3. HEIC accept (admin-частина P2-admin-heic-upload) — 🔗 після деплою B5

1. `ProductForm.tsx:478` і `cars/page.tsx:224`: `accept='image/jpeg,image/png,image/webp,image/heic,image/heif'`.
2. `upload.service.ts:28-31` — зрозуміла помилка на 400/422: «Формат файлу не підтримується. Дозволено: JPEG, PNG, WebP, HEIC.» (шлях тосту вже є: `makeUpload` `ProductForm.tsx:163-164`, `onUpload` `cars/page.tsx:91-92`).

**Перевірка:** реальний .heic → 201, `.avif` рендериться; зі старим бекендом → читабельний тост, спінер скидається (`finally`).

## A4. Тести: vitest (admin-частина P2-tests-frontend-admin)

1. `yarn add -D vitest @vitejs/plugin-react vite-tsconfig-paths happy-dom @testing-library/react @testing-library/jest-dom msw`; scripts `test`/`test:watch`.
2. `vitest.config.ts`: plugins react+tsconfigPaths, environment happy-dom, `env: { NEXT_PUBLIC_API_BASE_URL: 'http://api.test/api' }` (**обовʼязково** — після fail-fast з A5.6 http.service читає env на імпорті).
3. **`slugify.test.ts`** — контракт із бекендом (файли — посимвольні дзеркала). Таблиця векторів `[input, expected][]` (кирилиця/апострофи/трим/'Ёлка объём'…) з коментарем «Змінюєш тут → зміни в tesla-backend/src/common/utils/slugify.spec.ts (слаги вже в БД)». Очікування зафіксувати **виконанням** реальної функції, не на око.
4. **`http.service.test.ts`** — single-flight refresh через msw/node (перехоплює і axios, і нативний fetch у `refreshToken` :86-99): 3 одночасні 401 → рівно один `/auth/refresh`, усі запити повторені; невдалий refresh → logOut (застабити `/auth/logout`) і reject без ретраю.
5. **`build-product-payload.test.ts`** — попередньо винести з `ProductForm.tsx:115-142` чисту функцію `buildProductPayload(v, { attrs, descJson, images, livePhotos, carIds })` у `products/build-product-payload.ts` (єдиний рефакторинг задачі). Тести: порожні attr-ключі відкидаються; `oldPrice: 0` → `undefined`; порожні seo/alt → `undefined`; carIds/descJson as-is.

**Перевірка:** `yarn test` зелений; `yarn build` після рефакторингу; смок створення товару з характеристиками.

## A5. Дедуплікація + мертвий код (P3-admin-ui-dedup-dead-code)

Наймасовіші правки — в кінці, коли тести вже є як safety net.

1. Замінити 4 локальні `Field` на спільний (A0.1); видалити дублікати.
2. Loader2-блоки (11 файлів) → `LoadingState`; dashed-empty-діви → `EmptyState`. Інлайн-спінери в кнопках аплоаду (`ProductForm.tsx:469-475`, `cars/page.tsx:215-221`) — **не чіпати** (інший патерн).
3. `content/page.tsx` — явний empty-state: `!blocks?.length → <EmptyState>Блоків ще немає — вони створюються на бекенді (seed).</EmptyState>`.
4. `ProductForm.tsx:365` — стабільний ключ характеристик: `AttrRow` отримує `uid` (фабрика `newUid()` вже є, :51-54); `key={row.uid}`; onChange/remove — по `uid`, не по індексу. `buildProductPayload` ігнорує `uid` — тест A4.5 не змінюється.
5. `useDebounce` у products/leads/orders (замість 3 інлайн-дублікатів): `const q = useDebounce(search.trim())` + `useEffect(() => setPage(1), [q])`.
6. Мертвий код: `yarn remove sharp`; видалити `ROLES`/`ANY_AUTHENTICATED` (`role.constants.ts:7-15`; енум `Role` лишити); видалити `API_URLS.UPLOAD.PRESIGN`; **видалити `Topbar` повністю** (статичний мокап без функціональності: сам файл, рядок у `index.ts:11`, імпорт у `(dashboard)/layout.tsx:1,15`); `api-routes.constants.ts:1` — fail-fast:
   ```ts
   const baseUrl = process.env.NEXT_PUBLIC_API_BASE_URL
   if (!baseUrl) throw new Error('NEXT_PUBLIC_API_BASE_URL не задано — перевір .env (див. .env.example)')
   export const API_BASE_URL = baseUrl
   ```
   В CLAUDE.md адмінки — прибрати згадку Topbar (тека hooks/ тепер не бреше — заповнена в A0.4).
7. **Опційно, окремим PR**: `DataTable<T>` (`{ columns: {header, cell, className?}[], rows, rowKey }`) за каркасом `products/page.tsx:98-187` — мігрувати по сторінці на PR; якщо часу мало — follow-up, Field/states дають 80% виграшу.

**Перевірка:** `grep -rn "const Field = (" src` → лише `ui/field.tsx`; `grep -rn "confirm(" src` → 0; `yarn build` без env → читабельне падіння; смок: пошук з дебаунсом скидає на стор. 1; додати/видалити рядок характеристик посередині — значення не «стрибають».

---

# FRONTEND (`repos/tesla-frontend`)

## F1. Мертвий код + контактні константи (P3-frontend-dead-code-hardcode)

1. Видалити deps (grep по src — нуль збігів): `sharp`, `@tanstack/react-query-devtools`, `radix-ui`, `react-icons`; `class-variance-authority` **лишити** (`ui/button.tsx`). `yarn install`.
2. Видалити блок `BLOG` з `api-routes.constants.ts:60-63`.
3. **`src/common/constants/contacts.constants.ts`** (канон — seed бекенда `seed.ts:52-55`):
   ```ts
   // Канонічні контакти магазину (синхронізовано з ContentBlock 'contacts' у seed бекенда).
   // Для Footer та Organization JSON-LD — щоб не тягнути ContentBlock у статичний layout.
   export const CONTACT_PHONE_DISPLAY = '073 725 18 81'
   export const CONTACT_PHONE_E164 = '+380737251881'
   export const CONTACT_EMAIL = 'teslashoplviv@gmail.com'
   export const CONTACT_CITY = 'м. Львів, Україна'
   ```
   + export у `constants/index.ts`. **Рішення**: НЕ робити ContentBlock-round-trip для футера (футер має рендеритись і без API; `/kontakty` вже використовує ContentBlock для людей, константи — для машиночитаних місць; дублювання свідоме, задокументоване коментарем).
4. `Footer.tsx:34-35,39`: константи + `tel:`-посилання + `© {new Date().getFullYear()}`.
5. `page.tsx` (головна): «Понад 1000» → з реальних даних (`featured.total` вже фетчиться, :18-21): `const positionsLabel = featured.total >= 100 ? \`${Math.floor(featured.total / 100) * 100}+\` : '1000+'` — рядки 69, 93, 140.

**Перевірка:** `grep -rn "BLOG\|radix-ui\|react-icons" src` → порожньо; `yarn lint && yarn build`.

## F2. SEO: Organization JSON-LD, Product JSON-LD, manifest, іконки (P2-frontend-seo-jsonld-misc)

1. **Organization JSON-LD** у `layout.tsx` (донор вставки — `product/[slug]/page.tsx:124-127`): `{ '@type': 'Organization', name: SITE_NAME, url: SITE_URL, logo: \`${SITE_URL}/icon.png\`, email: CONTACT_EMAIL, contactPoint: { telephone: CONTACT_PHONE_E164, contactType: 'customer service', areaServed: 'UA', availableLanguage: 'uk' }, address: { addressLocality: 'Львів', addressCountry: 'UA' } }`.
2. **Product JSON-LD** (`product/[slug]/page.tsx:83-97`) — тип `ProductDetail` має `condition: 'new'|'used'|'clearance'`, `type: 'original'|'analog'`, `seo?.description`, `descriptionHtml`:
   - мапінг: `new → NewCondition`, `used → UsedCondition`, `clearance → DamagedCondition` (уцінка = новий з дефектом);
   - `description`: `p.seo?.description || stripHtml(p.descriptionHtml).slice(0, 300) || фолбек` (хелпер `stripHtml` → `utils/format.ts`);
   - `brand: { '@type': 'Brand', name: 'Tesla' }` **лише для `type === 'original'`** (для аналогів виробник невідомий);
   - `offers.priceValidUntil`: ковзна дата `+30 діб` (ISR revalidate=60 тримає свіжою);
   - `itemCondition` — і на Product, і в offers.
3. **Іконки/og:image** — file-conventions Next (нуль коду в metadata): `src/app/icon.png` (512×512), `apple-icon.png` (180×180), `opengraph-image.png` (1200×630). Джерело — `tesla-meta/docs/assets/logo.png` (1769×678, несквадратне) — вписати з паддінгом на фоні `#0b0d10`. Сторінка товару перекриває og:image власним — це ок.
4. **`src/app/manifest.ts`** (донор стилю — `robots.ts`): name/short_name/description, `display: 'standalone'`, `background_color: '#0b0d10'`, `theme_color: '#F59E0B'`, icons → `/icon.png`.

**Перевірка:** `curl :3040/manifest.webmanifest` — валідний JSON; view-source головної — Organization ld+json, og:image, apple-touch-icon; Rich Results Test сторінки товару — без warnings про description/brand/condition/priceValidUntil (для `analog` warning про brand допустимий — свідомо).

## F3. Спільний Modal + LeadButton на RHF+zod (P2-frontend-a11y-motion п.1 + P3 п.3) — один PR (LeadButton переписується раз)

1. **`ui/Modal.tsx`** — донор `LoginGateModal.tsx` (:27-36 scroll-lock+Escape, :40-56 розмітка): API `{ open, onClose, title?, ariaLabel?, maxWidthClassName?, children }`; `role='dialog'`, `aria-modal`, Escape, `document.body.style.overflow`, фокус на панель при відкритті + повернення на тригер при закритті (`restoreRef`). Повний focus-trap — свідомо поза скоупом. **Не мігрувати** `CartDrawer` (drawer із transition — інший патерн) і `LivePhotos` (кастомний лайтбокс, aria вже є); опційно — `LoginGateModal`.
2. **`catalog/lead.schema.ts`** (окремим файлом — щоб F6 тестував без jsdom): zod-схема name/phone (`isValidUaPhone` з `utils/phone.ts`)/email?/vin?/link?/targetPrice (`z.union([z.literal(''), z.coerce.number().positive()])`)/message — донор checkout-схеми (`checkout/page.tsx:24-78`).
3. **`LeadButton.tsx`** — переписати: перший рядок тіла — **`'use no memo'`** (RHF `reset()` × React Compiler; прецедент+коментар: `checkout/page.tsx:80-84`); `useForm` + `zodResolver(leadSchema)`, помилки під полями; сабміт — та сама побудова body з умовними полями `showVin/showLink/showTarget/showMessage` (:47-57), той самий POST на `API_URLS.LEADS.BASE`; обгортка `<Modal open onClose title>`; `isSubmitting` з formState.

**Перевірка:** Escape закриває, фон не скролиться, фокус повертається; кривий телефон → помилка під полем (не тост); заявки з `/product/*` і головної доходять (адмінка/Network); `yarn lint && yarn build`.

## F4. prefers-reduced-motion + hero (P2-frontend-a11y-motion п.2)

1. **`hooks/useReducedMotion.ts`** — `useSyncExternalStore` на `matchMedia('(prefers-reduced-motion: reduce)')`, SSR-фолбек `false`.
2. **`layout/HeroVideo.tsx`** (`'use client'`) — замінити `<video>` у `page.tsx:37-51`: завжди рендерити `<img src='/hero.jpg'>` (постер), `<video>` поверх — лише після mount, лише `min-width: 768px`, лише без reduce (`preload='metadata'`, `poster='/hero.jpg'`). Зараз 2.6MB `hero.mp4` вантажиться навіть на мобайлі, де відео сховане CSS.
3. **`globals.css`** — глобальне правило:
   ```css
   /* Поважаємо prefers-reduced-motion: глушимо transition/animation.
      Спінери стануть статичними — поруч завжди є текстовий стан. */
   @media (prefers-reduced-motion: reduce) {
   	*, *::before, *::after {
   		animation-duration: 0.01ms !important;
   		animation-iteration-count: 1 !important;
   		transition-duration: 0.01ms !important;
   		scroll-behavior: auto !important;
   	}
   }
   ```
   (CartDrawer при reduce зʼявлятиметься миттєво — бажана поведінка.)
4. Опційно: перетиснути `public/hero.mp4` до ~1MB (ffmpeg crf 30-32, без аудіо).

**Перевірка:** macOS Reduce Motion → лише `hero.jpg`, відео не в Network; viewport <768px → mp4 не вантажиться; десктоп без reduce → грає; LCP не деградував.

## F5. Мініатюри: `thumbSrc` (frontend-частина P2-frontend-image-optimization) — fallback-safe, можна до B6

Контракт: `thumbUrl?: string | null` у зображеннях каталогу (🔗 400px, `_w400.avif`). `next.config.ts` **не чіпати** (`unoptimized: true` лишається; доповнити коментар посиланням на thumb-контракт).

1. Тип `CatalogImage` (`catalog.type.ts:4-7`): + `thumbUrl?: string | null`.
2. **`utils/image.ts`**: `export const thumbSrc = (img: CatalogImage) => img.thumbUrl ?? img.url`.
3. Точки заміни `.url` → `thumbSrc(img)`:

   | Файл:рядок | Контекст |
   |---|---|
   | `PriceSheet.tsx:159-166` (Thumb) | 44/64px мініатюра |
   | `PriceSheet.tsx:195-204` | hover-превʼю 288px (400px достатньо) |
   | `PriceSheet.tsx:27` (toCartProduct) | image у кошик (80px) |
   | `ProductCard.tsx:26-32` і `:82` | картка ~300px + кошик |
   | `ProductGallery.tsx` (другий `<Image>`) | мініатюри 64px; **головне фото лишити `url`** |
   | `product/[slug]/page.tsx:311` (AddToCart) | у кошик |
   | `LivePhotos.tsx:44` | стрічка 160px; лайтбокс (:104) — `url` |

   JSON-LD `image` — лишити повні `url`. `CartDrawer.tsx:96` — не міняти (`i.image` вже приходить thumb-ом зі store).

**Перевірка:** до B6 — поведінка без змін (фолбек); після — Network на `/price-sheet`: мініатюри `*_w400.avif`, 50 позицій ≤ ~1.5MB зображень (було 5–15MB).

## F6. Тести: vitest (frontend-частина P2-tests-frontend-admin)

1. `yarn add -D vitest @vitejs/plugin-react jsdom @testing-library/react @testing-library/jest-dom @testing-library/user-event`; `vitest.config.mts` (react-плагін, jsdom, alias `@ → src`, include `src/**/*.test.{ts,tsx}`); `vitest.setup.ts` → `import '@testing-library/jest-dom/vitest'`; scripts `test`/`test:watch`. React Compiler у vitest не застосовується — для логіки/store неважливо.
2. Сьюти:
   - **`store/useCartStore.test.ts`** — чиста логіка через `getState()` без рендера: `add` при `stockQty<=0` → `{ok:false,max:0}`; clamp понад наявність; `increment` на межі → false; `setQty(id,0)` → видалено; persist partialize — у `localStorage['tesla-cart']` є `items`, немає `isOpen`; `beforeEach` — `setState({items:[],isOpen:false})` + `localStorage.clear()`.
   - **`catalog/lead.schema.test.ts`** — контракт схеми з F3: валідний мінімум (`0737251881`, `+380…`, з пробілами); кривий телефон → issue на `phone`; `targetPrice: ''` ок / `'3000'` → 3000 / `-5` → помилка; кривий `link` → помилка.
   - **`utils/phone.test.ts`** — `normalizePhone` (`0XX…`→`+380…`), `isValidUaPhone` крайні кейси.
   - Опційно: винести checkout-схему в `checkout/checkout.schema.ts` (чистий move) і тестувати superRefine-гілки `np`/`ukrposhta`.
   - Фільтри `/shop` — тривіальний цикл по `FILTER_KEYS` усередині серверних компонентів; виносити заради тесту не варто.

**Перевірка:** `yarn test` зелений; `yarn build`/`yarn lint` не зачеплені (за потреби — override для тест-файлів у `eslint.config.mjs`).

---

# META / ДОКИ (`tesla-meta`)

## M1. Хвости перехресних посилань (P3-docs-crossref-tails)

1. `docs/adr/0008-payment-requisites-channels.md:1` — заголовок `(IBAN / LiqPay)` → `(IBAN / LiqPay / monopay)`; звірити тіло на згадку monopay-каналу (ADR-0015).
2. `docs/adr/README.md:23` — рядок 0008 так само.
3. `CLAUDE.md:17` — `(0000-template + 0001..0006)` → `(0000-template + 0001..0017)`; рядок «0008 — … канали IBAN/LiqPay» → `+ monopay`.
4. `docs/adr/0011-price-sheet-view.md:6` — `FRD §3.12` → `FRD §3.3a (FR-2.8–2.13)`.
5. `docs/FRD.md` §6: у `product_images` додати `is_live boolean`; додати блок `wishlist_items` (модель з ADR-0012); прибрати `AND system_id = :sys` з примітки (~:376).
6. `docs/README.md:9-12` — версії: PRD/FRD → фактичні (FRD v1.2), db-schema звірити.

## M2. Синхронізація доків із кодом (P3-docs-sync-with-code)

1. `docs/FRD.md` §5: додати рядки `GET /api/admin/stats` і `GET /api/health` (✅); рядок ~251 — НП вже не «проксі *(план)*», а віддача зі своєї бази-дзеркала (ADR-0014) ✅.
2. `docs/backend-architecture.md` §5 (:95,100): `/api/v1` → `/api` (без версії; й у діаграмі :28 та принципах :17); `/api/docs` → `/swagger` (+ примітка «вимкнено в prod» після B3).
3. `docs/backend-architecture.md` §3 (:53-70): додати реальні модулі stats/health/delivery-np/addresses/profile/payments; неіснуючі (Users/Search/Cart/Blog/Integrations…) позначити *(план)*; §10 п.1 (:217) — закреслити: вирішено ADR-0015 (monopay).
4. `docs/db-schema.md` §3 (:448): абзац «Prisma не виражає gin_trgm_ops → raw-міграція» переписати: реальна схема має `extensions = [pg_trgm]` + `@@index([name(ops: raw("gin_trgm_ops"))], type: Gin)` нативно (`schema.prisma:9,140-141`); додати ці індекси в Prisma-блок документа; згадки «raw-міграція» (:318,:407) звірити з фактом.
5. Підняти версії/дати змінених доків.

## M3. `docs/deployment.md` (P3-docs-deployment) — потребує фактів від користувача

Структура документа (розділи 1–2 і 5 частково — **питання до користувача**: хостинг/VPS, домени, чи є staging, де зберігаються ключі зараз):
1. Середовища й домени (dev-порти з CLAUDE.md; prod: frontend 3000, admin 3001, backend 4040 — reverse proxy?).
2. Env-змінні per-repo (повний перелік: backend `env.constant.ts`; frontend/admin `.env.example`) з призначенням; окремо секрети: `PAYMENT_ENC_KEY`, `JWT_SECRET`/`REFRESH_JWT_SECRET`, pepper, `API_PUBLIC_URL`, `AUTH_COOKIE_NAMES` (з A1).
3. CI/CD: зараз **немає** ані workflows, ані Dockerfile у жодному репо — мінімальний пайплайн lint → tsc → tests → build; Prisma-міграції (`prisma migrate deploy`) у деплої.
4. Бекапи: PostgreSQL (pg_dump розклад/ретенція/тест відновлення), R2 (versioning або rclone-дзеркало).
5. Ротація ключів: `PAYMENT_ENC_KEY` (ADR-0008 попереджає: втрата = нечитабельні платіжні секрети → процедура: розшифрувати всі → перешифрувати новим → атомарна заміна), JWT-секрети (інвалідація сесій після B4 — таблиця `refresh_sessions`).
6. Моніторинг/логи (pino вже в коді; куди шипити — питання).

## M4. `docs/migration-runbook.md` (P3-docs-migration-runbook)

Покроковий ETL із WooCommerce (згадки розкидані по PRD, ADR-0002, db-schema §5, FR-A8):
1. Експорт з WooCommerce (товари/категорії/зображення/метадані) — WP REST API або wp-cli csv.
2. Дедуплікація за `sku` (ADR-0002: товар — єдиний канонічний запис).
3. Мапінг на Car/ProductFitment (M2M) і глобальні категорії.
4. Зображення → R2 з конвертацією AVIF (той самий пайплайн ADR-0007; після B6 — з мініатюрами).
5. Таблиця `Redirect` (стара URL-структура → нова, ADR-0001) — модель уже в схемі (B2.6 позначила її «заплановано»; для міграції знадобиться мінімальний API/middleware — зафіксувати як залежність).
6. Верифікація: кількість, вибіркове звіряння цін/залишків, редіректи.
7. Rollback-план (старий сайт лишається на окремому хості до перемикання DNS).

---

# Наскрізна верифікація

- Backend: `yarn build && npx tsc --noEmit && yarn test && yarn test:e2e`; ручний прогін чекауту + адмін-CRUD через Swagger (dev).
- Admin/Frontend: `yarn lint && yarn build && yarn test`; смоки з розділів вище.
- Після B4: перевірити, що фронтові register/change-password форми не пускають пароль <8 (🔗).
- Після B5+A3: аплоад .heic з реального iPhone-фото наскрізно.
- Після B6+F5: Lighthouse `/price-sheet` — вага зображень і LCP до/після.
