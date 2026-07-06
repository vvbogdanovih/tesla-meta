# План виконання P1-задач (для моделі-виконавця)

> Контекст: 3 app-репо у `repos/` (поза git). Порти: backend 4040, frontend 3040, admin 3030.
> Стек: NestJS 11 · Prisma 7 · Next.js 16 · React 19 · Tailwind v4.
> **Комітити/пушити — лише з явної згоди користувача.** Тексти UK. Патерни — брати з наявного коду (посилання нижче).
> Перевірено проти коду 2026-07-05: усі 5 задач у стані TODO (жодна не почата).

Рекомендований порядок: **1 → 2 → 3 → 4 → 5** (спершу ізольований backend, далі admin+backend пара, потім три frontend-SEO).

---

## 1. Backend: rate limiting + helmet
**Репо:** `repos/tesla-backend` · **Ефект/ціна:** максимальний за ~15 рядків.

### Кроки
1. Встановити залежності:
   ```bash
   cd repos/tesla-backend && npm i @nestjs/throttler helmet
   ```
2. **`src/app.module.ts`** — додати глобальний throttler. У масив `imports` (після `LoggerModule`, поряд зі `ScheduleModule`) додати:
   ```ts
   import { ThrottlerModule, ThrottlerGuard } from '@nestjs/throttler'
   import { APP_GUARD } from '@nestjs/core'
   // ...
   ThrottlerModule.forRoot([{ ttl: 60_000, limit: 120 }]), // глобально: 120 req/min/IP
   ```
   і в `@Module({ providers: [...] })` (створити секцію `providers`, зараз її немає) додати:
   ```ts
   providers: [{ provide: APP_GUARD, useClass: ThrottlerGuard }]
   ```
   > `app.set('trust proxy', 1)` вже є в `main.ts:22` — throttler коректно візьме реальний IP за проксі.
3. **Жорсткі ліміти на публічні мутації** через `@Throttle(...)`:
   - `src/modules/auth/auth.controller.ts` — над методом `login` (`@Post('login')`, ~рядок 24):
     ```ts
     import { Throttle } from '@nestjs/throttler'
     @Throttle({ default: { ttl: 60_000, limit: 5 } }) // 5 спроб/хв — антибрутфорс
     ```
     Те саме доцільно над `register` і `refresh`.
   - `src/modules/leads/leads.controller.ts` — над публічним `create` (`@Post()`, ~рядок 17): `@Throttle({ default: { ttl: 60_000, limit: 10 } })`.
   - `src/modules/orders/orders.controller.ts` — над публічним `POST /orders` (~рядок 21): `@Throttle({ default: { ttl: 60_000, limit: 10 } })`.
   > Вебхук monopay (`payments`) — **не** обмежувати або дати високий ліміт: його дьоргає банк.
4. **`src/main.ts`** — helmet. Після `app.set('trust proxy', 1)` (рядок 22), до `enableCors`:
   ```ts
   import helmet from 'helmet'
   app.use(helmet())
   ```
   > API віддає JSON, не HTML → дефолтний helmet безпечний. Якщо Swagger UI (`/swagger`) зламається від CSP — або лишити Swagger як є (окрема задача P2 його все одно закриє в prod), або `helmet({ contentSecurityPolicy: false })`. CORS уже налаштований окремо (`main.ts:29`) — helmet його не чіпає.

### Перевірка
- `npm run build` (tsc) без помилок.
- Локально: 6 швидких `POST /api/auth/login` з невірним паролем → 6-й дає **429 Too Many Requests**.
- У відповіді будь-якого запиту зʼявились заголовки `X-Frame-Options`, `X-Content-Type-Options` тощо.

---

## 2. Admin + Backend: пагінація і пошук у товарах/лідах/wishlist
**Репо:** `repos/tesla-backend` + `repos/tesla-admin`.
**Готовий еталон:** admin-сторінка `orders` вже має все (search-debounce + `keepPreviousData` + пагінація) — копіювати з `repos/tesla-admin/src/app/(dashboard)/orders/page.tsx`. Backend-еталон пагінації — `catalog.service.ts:83–93` та `orders.service.ts:188–200` (`$transaction([findMany({skip,take}), count])`).

### 2A. Backend — admin `GET /products` (пагінація + пошук)
1. **DTO** `src/modules/products/dto/` — створити `product-list-query.dto.ts` (за зразком `catalog-query.dto.ts:55–65`):
   ```ts
   import { Type } from 'class-transformer'
   import { IsInt, IsOptional, IsString, Min } from 'class-validator'
   export class ProductListQueryDto {
     @IsOptional() @IsString() q?: string // пошук за name/sku
     @IsOptional() @Type(() => Number) @IsInt() @Min(1) page?: number
     @IsOptional() @Type(() => Number) @IsInt() @Min(1) limit?: number
   }
   ```
2. **`products.service.ts`** — переписати `findAll()` (зараз рядки 19–28, `findMany` без `take`) на пагінований варіант:
   ```ts
   async findAll(q: ProductListQueryDto) {
     const page = q.page ?? 1
     const limit = Math.min(q.limit ?? 20, 100)
     const where: Prisma.ProductWhereInput = {}
     const term = q.q?.trim()
     if (term) where.OR = [
       { name: { contains: term, mode: 'insensitive' } },
       { sku:  { contains: term, mode: 'insensitive' } }
     ]
     const [items, total] = await this.prisma.$transaction([
       this.prisma.product.findMany({
         where, orderBy: { createdAt: 'desc' },
         skip: (page - 1) * limit, take: limit,
         include: {
           category: { select: { id: true, name: true } },
           images: { where: { isLive: false }, orderBy: { sortOrder: 'asc' }, take: 1 },
           _count: { select: { fitment: true } }
         }
       }),
       this.prisma.product.count({ where })
     ])
     return { items, total, page, limit }
   }
   ```
   > name/sku вже мають trigram GIN-індекси (`schema.prisma:140–141`) — `contains insensitive` швидкий.
3. **`products.controller.ts`** — метод `findAll` (рядки 19–21):
   ```ts
   @Get()
   findAll(@Query() q: ProductListQueryDto) { return this.products.findAll(q) }
   ```
   (додати `Query` в імпорт `@nestjs/common`).

### 2B. Backend — admin `GET /leads` (пагінація + пошук) — опційно, той самий патерн
- Аналогічно `leads.service.ts:39–45` `findAll(status)` → приймати `{ status?, q?, page?, limit? }`, повертати `{ items, total, page, limit }`. Пошук — за телефоном/email/name зі снапшоту ліда (перевірити поля моделі `Lead` у `schema.prisma:309`).
- **Індекс під сортування:** додати `@@index([createdAt])` в `model Lead` (і `model Order`) → нова міграція `npx prisma migrate dev --name lead_order_created_at_index`. Зараз індексів `createdAt` немає (є лише `status,type`).

### 2C. Admin — products/page.tsx
1. **`src/common/types/product.type.ts`** — додати тип відповіді:
   ```ts
   export interface ProductListResponse {
     items: ProductListItem[]; total: number; page: number; limit: number
   }
   ```
2. **`src/common/services/products.api.ts`** — замінити `list` (рядок 31). Будувати query-string як в `orders.api.ts`/`wishlist.api.ts`:
   ```ts
   list: (params: { q?: string; page?: number; limit?: number } = {}) => {
     const s = new URLSearchParams()
     if (params.q) s.set('q', params.q)
     if (params.page) s.set('page', String(params.page))
     if (params.limit) s.set('limit', String(params.limit))
     const qs = s.toString()
     return httpService.get<ProductListResponse, unknown>(
       `${API_URLS.PRODUCTS.BASE}${qs ? `?${qs}` : ''}`
     )
   },
   ```
3. **`src/app/(dashboard)/products/page.tsx`** — за зразком `orders/page.tsx:44–110`:
   - `const LIMIT = 20`
   - стан `search`/`q`/`page`, debounce-`useEffect` (~400 мс, скидає `page=1`) — скопіювати з orders.
   - `useQuery({ queryKey: ['products', { q, page }], queryFn: () => productsApi.list({ q: q||undefined, page, limit: LIMIT }), placeholderData: keepPreviousData })`.
   - Рендерити `data.items` (а не `products`), додати `<Input>` пошуку (Search-іконка) + пагінатор `ChevronLeft/ChevronRight` з `totalPages = Math.max(1, Math.ceil(data.total/data.limit))`.
   - **RHF-застереження:** якщо форма поруч використовує `reset()` — памʼятати про `'use no memo'` (React Compiler × RHF), але тут це список, не форма.

### 2D. Admin — wishlist/page.tsx і leads/page.tsx
- **wishlist** (`page.tsx:24`): `wishlistApi.adminList()` вже підтримує `{ page, limit }` (`wishlist.api.ts:12`), а відповідь має `total/page/pages` — просто підключити стан `page` і пагінатор (UI з orders), передати `adminList({ page, limit })`.
- **leads** (`page.tsx:26`): після 2B передати `{ q, page, limit }`; додати пошук+пагінатор.

### Перевірка
- Backend: `GET /api/products?q=<sku>&page=1&limit=5` повертає `{items,total,page,limit}`; `npm run build` чистий; міграція застосована.
- Admin: у товарах працює пошук за SKU/назвою, перемикання сторінок; wishlist/leads показують записи поза 1-ю сторінкою.

---

## 3. Frontend: динамічний sitemap + сторінки /pro-nas, /kontakty (ContentBlock), Blog відкладено
**Репо:** `repos/tesla-frontend` + `repos/tesla-backend`.

### ✅ Рішення (зафіксовано користувачем 2026-07-06)
- **Про нас** (`/pro-nas`) і **Контакти** (`/kontakty`) — **реалізувати через `ContentBlock`** (ADR-0009). URL-slug'и — **українські**, як на старому сайті (SEO-наступність, ADR-0001).
- **Blog** — **відкласти** окремою задачею (повноцінна фіча: модель `BlogPost` є, але немає API/адмінки/фронту). Зараз лінк прибрати.
- `delivery_payment`/`warranty` лишаються наскрізними блоками на сторінці товару (окремих сторінок `/delivery`,`/returns` не робимо в цій задачі).

Тобто задача 3 = **3A backend (2 нові ключі ContentBlock)** + **3B frontend (2 сторінки)** + **3C sitemap/лінки**.

### 3A. Backend — додати ключі `about` і `contacts`
1. **`src/modules/content-blocks/content-blocks.constants.ts`** — розширити масив (зараз лише `warranty`, `delivery_payment`):
   ```ts
   export const CONTENT_BLOCKS = [
     { key: 'warranty', title: 'Гарантія' },
     { key: 'delivery_payment', title: 'Доставка та оплата' },
     { key: 'about', title: 'Про нас' },
     { key: 'contacts', title: 'Контакти' }
   ] as const
   ```
2. **Створити рядки в БД** — seed уже робить `upsert` по `CONTENT_BLOCKS` (`seed.ts:163`), тому достатньо: `npx prisma db seed` (або `npm run seed` — перевірити скрипт у `package.json`). Без цього `PATCH /content-blocks/:key` кине 404 (update вимагає наявний блок — `content-blocks.service.ts:23`).
   > **Важливо:** поточний seed створює блок лише з `key`+`title`, **без body** (`seed.ts:166`, `create: { key, title }`). Тобто одразу після seed `bodyHtml === null`. Щоб лінки в Header не давали 404 до заповнення в адмінці — **обрати одне з двох**: (а) розширити seed, задавши стартовий `bodyJson`/`bodyHtml` для `about`/`contacts` (текст із п.3); **або** (б) на фронті **не** робити `notFound()` на порожній блок, а рендерити `title` + плейсхолдер. Рекомендація — (а): сторінка робоча одразу.
   > API/адмінка змін не потребують: `GET /content-blocks/:key` публічний, редагування в наявній `content/page.tsx` (TipTap) підхопить нові блоки автоматично (`findAll` тягне всі з БД).
3. **Початковий контент** — заповнити в адмінці (TipTap) після деплою. Готовий текст зі старого сайту для вставки:
   - **Про нас:** «Tesla Lviv — це спеціалізований центр для власників та майбутніх власників автомобілів Tesla. Наша команда зосереджена виключно на бренді Tesla… Ми пропонуємо: оригінальні та аналогові запчастини; нові, вживані та відновлені комплектуючі; діагностику та ремонт; допомогу після ДТП; консультації щодо сумісності; продаж авто Tesla; доставку по всій Україні.» (+ абзаци про сервіс і досвід — див. `todo/` нотатки або оригінал `teslalviv.com/pro-nas`).
   - **Контакти:** «Україна, м. Львів · 073 725 18 81 · teslashoplviv@gmail.com».

### 3B. Frontend — сторінки /pro-nas і /kontakty
1. **`src/common/constants/ui-routes.constants.ts`** — оновити на реальні slug'и, прибрати мертві:
   ```ts
   ABOUT: '/pro-nas',
   CONTACTS: '/kontakty',
   // видалити: BLOG, DELIVERY, RETURNS, OFFER, CATEGORY, SUBCATEGORY (маршрутів немає)
   ```
2. **`src/app/pro-nas/page.tsx`** і **`src/app/kontakty/page.tsx`** — SSR-сторінки, що читають блок і рендерять `bodyHtml`. Патерн — як на сторінці товару (`app/product/[slug]/page.tsx:42` фетчить `catalogApi.contentBlock('warranty')`, рядки 197–207 рендерять через компонент `html={block.bodyHtml}`). Приклад:
   ```tsx
   import type { Metadata } from 'next'
   import { notFound } from 'next/navigation'
   import { catalogApi } from '@/common/services/catalog.api'
   import { SITE_URL } from '@/common/constants/seo.constants'

   export const metadata: Metadata = {
     title: 'Про нас — Tesla Spare Parts Lviv',
     description: 'Спеціалізований центр запчастин та обслуговування Tesla у Львові.',
     alternates: { canonical: `${SITE_URL}/pro-nas` }
   }

   export default async function AboutPage() {
     const block = await catalogApi.contentBlock('about')
     if (!block) notFound() // блока взагалі немає в БД (seed не запускали)
     return (
       <div className='mx-auto max-w-[1240px] px-6 py-12'>
         <h1 className='font-display mb-6 text-3xl font-medium tracking-tight'>{block.title}</h1>
         {/* bodyHtml санітизований на бекенді (ADR-0006); той самий рендер, що на сторінці товару */}
         {block.bodyHtml
           ? <div className='prose max-w-none' dangerouslySetInnerHTML={{ __html: block.bodyHtml }} />
           : <p className='text-muted-foreground'>Контент готується.</p>}
       </div>
     )
   }
   ```
   > `catalogApi.contentBlock(key)` (catalog.api.ts:37) повертає `null` на не-ok. **Не** робити `notFound()` на порожній `bodyHtml` (див. 3A.2, п.б) — інакше Header-лінк 404-иться до заповнення. `/kontakty` — аналогічно з `contentBlock('contacts')` і своїм canonical. Опційно для About: статичний блок «Наші переваги» + наявна `LeadButton` (лід-форма) — не обов'язково для P1.
3. **Header** (`Header.tsx:49–50`) — лінки `ABOUT`/`CONTACTS` **лишаються** (тепер валідні, ведуть на `/pro-nas`, `/kontakty`).
4. **Footer** (`Footer.tsx:19–33`) — **прибрати посилання `BLOG`, `DELIVERY`, `RETURNS`, `OFFER`** (їхні константи видаляються в п.1 — інакше **білд впаде** на неіснуючих `UI_ROUTES.*`). Лишити реальні: Магазин, Прайс-лист, Про нас, Контакти. `delivery_payment`/`warranty` окремих сторінок не мають — показуються лише на сторінці товару, тож із Footer не лінкуються. **Порядок:** видаляти константи (п.1) і чистити Footer — одним заходом, звірити `grep -rn "UI_ROUTES\.\(BLOG\|DELIVERY\|RETURNS\|OFFER\|CATEGORY\|SUBCATEGORY\)" src` = порожньо перед білдом.

### 3C. Sitemap — динамічний + нові статичні сторінки
1. **`src/app/sitemap.ts`** — зробити async і тягнути товари/категорії з API (патерн graceful-fallback — як `app/page.tsx:14–21`, `.catch`):
   ```ts
   import type { MetadataRoute } from 'next'
   import { SITE_URL } from '@/common/constants/seo.constants'
   import { catalogApi } from '@/common/services/catalog.api'
   import { UI_ROUTES } from '@/common/constants'

   export default async function sitemap(): Promise<MetadataRoute.Sitemap> {
     // тягнемо всі активні товари (пагінація по 60 — MAX_LIMIT бекенда)
     const products: { slug: string }[] = []
     try {
       let page = 1, pages = 1
       do {
         const res = await catalogApi.products(`page=${page}&limit=60`)
         products.push(...res.items.map(i => ({ slug: i.slug })))
         pages = res.pages; page++
       } while (page <= pages)
     } catch {}
     const categories = await catalogApi.categories().catch(() => [])

     const now = new Date()
     const staticRoutes = ['', UI_ROUTES.SHOP, UI_ROUTES.PRICE_SHEET, UI_ROUTES.ABOUT, UI_ROUTES.CONTACTS].map(r => ({
       url: `${SITE_URL}${r}`, lastModified: now,
       changeFrequency: 'weekly' as const, priority: r === '' ? 1 : 0.8
     }))
     const productRoutes = products.map(p => ({
       url: `${SITE_URL}${UI_ROUTES.PRODUCT(p.slug)}`, lastModified: now,
       changeFrequency: 'weekly' as const, priority: 0.7
     }))
     const categoryRoutes = categories.map(c => ({
       url: `${SITE_URL}${UI_ROUTES.SHOP}?category=${c.slug}`, lastModified: now,
       changeFrequency: 'weekly' as const, priority: 0.6
     }))
     return [...staticRoutes, ...productRoutes, ...categoryRoutes]
   }
   ```
   > `CatalogResponse` має `items[].slug`, `pages`, `total` (`catalog.type.ts:28`). У товарі **немає `updatedAt`** — тому `lastModified: now`. Якщо потрібен точний `lastModified` — окрема задача (додати `updatedAt` у `CARD_SELECT` на бекенді). `UI_ROUTES.ABOUT`/`CONTACTS` після 3B = `/pro-nas`/`/kontakty`.
   > Мертві маршрути `/blog`, `/delivery`, `/returns`, `/offer` до sitemap **не** додаємо.

### Перевірка (вся задача 3)
- Backend: після seed `GET /api/content-blocks/about` і `/contacts` повертають блок (не 404).
- Frontend: `/pro-nas` і `/kontakty` відкриваються, рендерять контент із адмінки; порожній блок → дружній fallback/notFound, не 500.
- `curl localhost:3040/sitemap.xml` містить `/product/<slug>`, `/shop?category=…`, `/pro-nas`, `/kontakty`; **не** містить `/about`, `/blog`, `/delivery`, `/returns`, `/offer`.
- Header/Footer: усі посилання ведуть на реальні сторінки (жодного 404); лінк на Blog прибрано.
- Redirect (ADR-0001): старі WordPress-адреси `/pro-nas/`, `/kontakty/` вже збігаються за slug — окремі редіректи не потрібні (лише нормалізація trailing slash, якщо є).

---

## 4. Frontend: error.tsx / loading.tsx для каталогу
**Репо:** `repos/tesla-frontend`. **Причина:** `catalog.api.ts:14` кидає на 5xx → падіння бекенда на `/shop` і `/product/[slug]` показує сирий екран Next.

### Кроки
1. **`src/app/global-error.tsx`** (кореневий, ловить усе, обгортає `<html>`):
   ```tsx
   'use client'
   export default function GlobalError({ reset }: { error: Error; reset: () => void }) {
     return (
       <html lang='uk'><body>
         <div className='mx-auto flex min-h-screen max-w-[1240px] flex-col items-center justify-center gap-4 px-6 text-center'>
           <h1 className='font-display text-2xl font-medium'>Щось пішло не так</h1>
           <p className='text-muted-foreground'>Не вдалося завантажити сторінку. Спробуйте ще раз.</p>
           <button onClick={reset} className='rounded-full bg-primary px-5 py-2 text-primary-foreground'>Спробувати ще раз</button>
         </div>
       </body></html>
     )
   }
   ```
2. **`src/app/shop/error.tsx`** і **`src/app/product/[slug]/error.tsx`** — те саме, але `'use client'` без `<html>` (успадкує layout):
   ```tsx
   'use client'
   export default function Error({ reset }: { error: Error; reset: () => void }) {
     return (
       <div className='mx-auto flex max-w-[1240px] flex-col items-center gap-4 px-6 py-24 text-center'>
         <h2 className='font-display text-xl font-medium'>Каталог тимчасово недоступний</h2>
         <p className='text-muted-foreground text-sm'>Сталася помилка при завантаженні. Спробуйте ще раз.</p>
         <button onClick={reset} className='rounded-full bg-primary px-5 py-2 text-sm text-primary-foreground'>Спробувати ще раз</button>
       </div>
     )
   }
   ```
3. **`src/app/shop/loading.tsx`** і **`src/app/product/[slug]/loading.tsx`** — скелетон:
   ```tsx
   export default function Loading() {
     return <div className='mx-auto max-w-[1240px] px-6 py-24 text-center text-muted-foreground'>Завантаження…</div>
   }
   ```
   (краще — скелетон-картки в стилі `ProductCard`, але текст-заглушка достатня для P1.)
   > Класи взяти з реальних сторінок: контейнер усюди `mx-auto max-w-[1240px] px-6` (див. `shop/page.tsx`, `app/page.tsx:10`). Перевірити реальні токени кольорів (`bg-primary`, `text-muted-foreground`) у `globals.css`/Tailwind-конфізі — назви можуть відрізнятися.

### Перевірка
- Зупинити backend → відкрити `/shop` → бачимо дружній екран з кнопкою, не Next-дефолт. Кнопка «Спробувати ще раз» після підняття бекенда відновлює сторінку.

---

## 5. Frontend: canonical + динамічні meta для /shop і /price-sheet
**Репо:** `repos/tesla-frontend`. **Причина:** статичний `metadata` для всіх `?category=&car=&page=` → сотні дублікатів, зʼїдають crawl budget.

### ✅ Рішення (SEO — узгоджено з ADR-0011 та seo-strategy:113–125; зафіксувати в seo-strategy.md)
**`/shop`:**
- Без параметрів або з `?category=` → **index**, canonical на чисту категорійну URL.
- `?car=`, `?sort=`, `?inStock=`, `?minPrice=`, `?page>1` тощо → **noindex,follow**, canonical на базову `/shop` (або `/shop?category=x`). Стратегія вже так каже про фасети (`seo-strategy.md:116–125`).
- ⓘ seo-strategy:113–114 передбачає для категорій **чистий шлях** (напр. `/category/model`, ADR-0001), але такого маршруту в коді **ще немає** — тому канонікалізуємо на наявний `/shop?category=x`. Перехід на clean-path — окрема задача ADR-0001, не блокує цю.

**`/price-sheet`** (ADR-0011 «Наслідки»: «окремий URL — власне SEO» → індексується як окрема сторінка, **не** canonical→/shop):
- База `/price-sheet` (без параметрів) → **index, self-canonical**, у sitemap. Унікальний title/H1 під інтент «прайс-лист / price list» + вступний абзац — щоб не був тонким дублем `/shop`.
- Будь-який фасет-параметр (`?car`, `?category`, `?sort`, `?inStock`, ціна, 2+ фасети) → **noindex,follow**, canonical на базову `/price-sheet`. Тобто **рівно одна індексована** price-sheet-URL; категорійні/фасетні індексовані сторінки належать `/shop`, price-sheet їх не дублює.
- Пагінаційного `?page` немає (ADR-0011: нескінченний скрол, `IntersectionObserver`) → canonical-питання пагінації тут не виникає.
- `robots.txt`: параметри price-sheet/shop **не** Disallow — керуємо через meta `noindex` (`seo-strategy.md:125`).

### Кроки
1. **`src/app/shop/page.tsx`** — прибрати статичний `export const metadata` (рядки 8–12), додати `generateMetadata`. Використати `SITE_URL` (`seo.constants.ts`) і назви категорії/авто. Категорії/авто вже фетчаться в компоненті — у `generateMetadata` дофетчити `catalogApi.categories()/cars()` (кешується `revalidate:300`), щоб взяти людську назву за slug:
   ```ts
   import type { Metadata } from 'next'
   import { SITE_URL } from '@/common/constants/seo.constants'
   import { catalogApi } from '@/common/services/catalog.api'
   import { UI_ROUTES } from '@/common/constants'

   export async function generateMetadata({ searchParams }: {
     searchParams: Promise<Record<string, string | string[] | undefined>>
   }): Promise<Metadata> {
     const sp = await searchParams
     const s = (k: string) => (typeof sp[k] === 'string' ? (sp[k] as string) : undefined)
     const categorySlug = s('category'); const carSlug = s('car'); const page = s('page')

     let title = 'Каталог запчастин Tesla'
     const parts: string[] = []
     if (categorySlug) {
       const cats = await catalogApi.categories().catch(() => [])
       const c = cats.find(x => x.slug === categorySlug)
       if (c) { title = `${c.name} — запчастини Tesla`; parts.push(c.name) }
     }
     if (carSlug) {
       const cars = await catalogApi.cars().catch(() => [])
       const car = cars.find(x => x.slug === carSlug)
       if (car) parts.push(car.generation ?? car.model)
     }
     if (page && page !== '1') title += ` — сторінка ${page}`

     // canonical: лише category → на категорійну базу; інші фасети → на чисту /shop
     const canonical = categorySlug
       ? `${SITE_URL}${UI_ROUTES.SHOP}?category=${categorySlug}`
       : `${SITE_URL}${UI_ROUTES.SHOP}`

     // фасети/сортування/пагінація → noindex,follow
     const isFaceted = Boolean(carSlug || s('sort') || s('inStock') || s('minPrice') || s('maxPrice') || s('type') || s('condition') || (page && page !== '1'))

     return {
       title,
       description: parts.length
         ? `Запчастини Tesla ${parts.join(' · ')} — фільтри за моделлю, типом, наявністю та ціною.`
         : 'Оригінальні та аналогові запчастини Tesla (Model 3 · Y · S · X).',
       alternates: { canonical },
       robots: isFaceted ? { index: false, follow: true } : undefined
     }
   }
   ```
2. **`src/app/price-sheet/page.tsx`** — прибрати статичний `metadata` (рядки 7–11), додати `generateMetadata`:
   - `canonical` **завжди** `${SITE_URL}/price-sheet` (навіть за фасетів — консолідуємо на базу).
   - `robots`: базова (без параметрів) → без `noindex` (індексується); будь-який фасет-параметр присутній → `{ index: false, follow: true }`. Прапорець `isFaceted` — так само, як у `/shop` (перевірити `car/category/sort/inStock/minPrice/maxPrice/type/condition`).
   - `title`/`description` — **окремі від `/shop`**, під інтент «прайс-лист»: напр. `title: 'Прайс-лист запчастин Tesla — артикули, сумісність, ціни'`. H1 і вступний абзац на самій сторінці теж мають відрізнятись (проти тонкого дубля).
3. Після коду — оновити `docs/seo-strategy.md`: додати блок «/price-sheet» (одна індексована база + noindex-фасети, з посиланням на ADR-0011) і явні canonical-правила `/shop`; підняти версію документа. Закриває P3-docs-seo-strategy-gaps.

### Перевірка
- `/shop` → `<link rel="canonical" href=".../shop">`, індексується.
- `/shop?car=model-3&sort=price_asc` → canonical на `/shop`, `<meta name="robots" content="noindex,follow">`.
- `/shop?category=hamuvna-systema` → canonical на себе, індексується, title містить назву категорії.
- `View source` кожного стану — коректні title/description/canonical.

---

## Крос-репо примітки
- **Типи `CatalogResponse`** (`items`, `pages`, `total`) — джерело правди `frontend/src/common/types/catalog.type.ts:28`.
- **Backend admin `GET /products`** зараз повертає **масив**, після задачі 2 — обʼєкт `{items,…}`. Це **breaking change** для admin — робити 2A і 2C **разом**, інакше admin-список зламається.
- Після кожної задачі: `npm run build` у відповідному репо (обидва фронти strict-чисті — тримати так). Тести фронта/адмінки відсутні (окрема P2).
- **Не комітити** без явної згоди користувача (ADR/CLAUDE.md).
