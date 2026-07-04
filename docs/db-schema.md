# Модель бази даних — Tesla Lviv (PostgreSQL + Prisma)

**Версія:** 1.1
**Дата:** 27.06.2026
**Статус:** Draft
**Пов'язано:** [FRD §6](FRD.md) · [ADR-0002](adr/0002-catalog-compatibility-architecture.md) (каталог/сумісність) · [ADR-0003](adr/0003-database-postgresql.md) (PostgreSQL)

> Реляційна схема під архітектуру ADR-0002: **сумісність відокремлена від таксономії** (довідник авто `Car` + M2M `ProductFitment`), категорії — глобальний довідник, товар — один canonical-запис. ORM — **Prisma** (схема нижче в нотації Prisma). JSONB (`Json`) — для гнучких полів.

---

## 1. ER-діаграма

```mermaid
erDiagram
  Car             ||--o{ ProductFitment : "сумісність"
  Product         ||--o{ ProductFitment : "сумісність"
  Category        ||--o{ Product        : "категорія"
  Product         ||--o{ ProductImage   : "фото"
  Product         ||--o{ OrderItem      : ""
  Order           ||--o{ OrderItem      : "позиції"
  User            ||--o{ Order          : "замовлення"
  User            ||--o{ Address        : "адреси"
  Product         ||--o{ Lead           : "по товару"
  User            ||--o{ WishlistItem   : "обране"
  Product         ||--o{ WishlistItem   : "обране"

  Car {
    bigint id PK
    string brand
    string model
    string generation
    string slug UK
    string imageUrl
    date   productionStart
    date   productionEnd
  }
  Category {
    bigint id PK
    string slug UK
    string name
    int    sortOrder
  }
  Product {
    bigint id PK
    string slug UK
    string sku UK
    string name
    decimal price
    decimal oldPrice
    bool   onSale
    enum   condition
    enum   type
    int    stockQty
    bigint categoryId FK
    json   attributes
  }
  ProductFitment {
    bigint productId FK
    bigint carId FK
    int    yearFrom
    int    yearTo
  }
  Order {
    bigint id PK
    string orderNumber UK
    bigint userId FK
    json   customer
    json   delivery
    enum   deliveryMethod
    enum   paymentMethod
    enum   paymentStatus
    decimal total
    enum   status
  }
  OrderItem {
    bigint id PK
    bigint orderId FK
    bigint productId FK
    string sku
    decimal price
    int    qty
  }
  User {
    bigint id PK
    string email UK
    enum   role
  }
  Address {
    bigint id PK
    bigint userId FK
    enum   method
    string city
    string warehouse
  }
  Lead {
    bigint id PK
    enum   type
    string vin
    bigint productId FK
    enum   status
  }
  WishlistItem {
    bigint userId FK
    bigint productId FK
    datetime createdAt
  }
```

---

## 2. Prisma-схема (`schema.prisma`)

```prisma
generator client {
  provider = "prisma-client-js"
}

datasource db {
  provider = "postgresql"
  url      = env("DATABASE_URL")
}

// ───────── Enums ─────────
enum ProductType      { original analog }
enum ProductCondition { new used clearance }      // Новий / Б/у / Уцінка
enum OrderStatus      { new processing shipped done canceled }
enum DeliveryMethod   { np ukrposhta pickup }
enum PaymentMethod    { card cod iban cash }
enum PaymentStatus    { pending paid failed refunded }
enum NpWarehouseType  { branch postomat cargo }        // відділення / поштомат / вантажне (ADR-0014)
enum UserRole         { user admin superadmin }
enum LeadType         { fitment price_match price_subscribe contact }
enum LeadStatus       { new handled }

// ───────── Каталог ─────────
model Car {
  id              BigInt    @id @default(autoincrement())
  brand           String    @default("Tesla")
  model           String                                  // Model 3 / Model Y / Model S / Model X
  generation      String?                                 // Pre-facelift / Highland / Phase 1 / Juniper
  slug            String    @unique                       // model-3-highland
  imageUrl        String?   @map("image_url")
  productionStart DateTime  @map("production_start") @db.Date    // обовʼязкова (дата випуску)
  productionEnd   DateTime? @map("production_end")   @db.Date    // null = у виробництві
  fitment         ProductFitment[]
  @@map("cars")
}

model Category {
  id        BigInt    @id @default(autoincrement())
  slug      String    @unique                               // kuzov
  name      String                                          // Кузов
  sortOrder Int       @default(0) @map("sort_order")
  seo       Json      @default("{}")
  products  Product[]
  @@map("categories")
}
// Категорія — плоский глобальний список (ADR-0002). Авто — окремий вимір
// (фільтр сумісності через ProductFitment), а не рівень категорії.

model Product {
  id            BigInt           @id @default(autoincrement())
  slug          String           @unique
  sku           String           @unique                   // артикул / код запчастини
  name          String
  price         Decimal          @db.Decimal(12, 2)
  oldPrice      Decimal?         @map("old_price") @db.Decimal(12, 2)
  onSale        Boolean          @default(false) @map("on_sale")   // знижка активна (показувати стару ціну)
  condition     ProductCondition @default(new)             // new | used | clearance
  type          ProductType                                // original | analog
  stockQty      Int              @default(0)   @map("stock_qty")   // наявність = stockQty > 0
  categoryId    BigInt           @map("category_id")
  category      Category         @relation(fields: [categoryId], references: [id])
  attributes      Json           @default("{}")            // гнучкі характеристики
  descriptionJson Json?          @map("description_json")  // TipTap JSON — джерело правди (редагування)
  descriptionHtml String?        @map("description_html")  // згенерований санітизований HTML (сторфронт)
  seo           Json             @default("{}")            // { title, description, ogImage }
  isActive      Boolean          @default(true) @map("is_active")
  createdAt     DateTime         @default(now()) @map("created_at")
  updatedAt     DateTime         @updatedAt      @map("updated_at")

  fitment    ProductFitment[]
  images     ProductImage[]
  related    ProductRelated[] @relation("ProductRelated")
  relatedBy  ProductRelated[] @relation("RelatedProduct")
  orderItems OrderItem[]
  leads      Lead[]
  wishlist   WishlistItem[]

  @@index([categoryId])
  @@index([isActive, stockQty])
  @@index([price])
  @@map("products")
}

// M2M сумісність товар ↔ авто
model ProductFitment {
  productId BigInt  @map("product_id")
  carId     BigInt  @map("car_id")
  yearFrom  Int?    @map("year_from")                      // уточнення в межах покоління (опц.)
  yearTo    Int?    @map("year_to")
  product   Product @relation(fields: [productId], references: [id], onDelete: Cascade)
  car       Car     @relation(fields: [carId],     references: [id], onDelete: Cascade)
  @@id([productId, carId])
  @@index([carId])
  @@map("product_fitment")
}

model ProductImage {
  id        BigInt  @id @default(autoincrement())
  productId BigInt  @map("product_id")
  product   Product @relation(fields: [productId], references: [id], onDelete: Cascade)
  url       String                                         // S3 URL
  alt       String?
  sortOrder Int     @default(0) @map("sort_order")         // порядок у межах свого набору
  isLive    Boolean @default(false) @map("is_live")        // false = студійна галерея; true = «живі фото» (реальні знімки екземпляра, окремий блок на сторінці товару)
  @@index([productId, isLive])
  @@map("product_images")
}

model ProductRelated {
  productId BigInt  @map("product_id")
  relatedId BigInt  @map("related_id")
  product   Product @relation("ProductRelated", fields: [productId], references: [id], onDelete: Cascade)
  related   Product @relation("RelatedProduct", fields: [relatedId], references: [id], onDelete: Cascade)
  @@id([productId, relatedId])
  @@map("product_related")
}

// Наскрізні тексти (гарантія, доставка+оплата) — rich text, фіксований набір ключів.
model ContentBlock {
  id        BigInt   @id @default(autoincrement())
  key       String   @unique                       // warranty | delivery_payment
  title     String
  bodyJson  Json?    @map("body_json")             // TipTap JSON — джерело правди
  bodyHtml  String?  @map("body_html")             // згенерований санітизований HTML
  updatedAt DateTime @updatedAt @map("updated_at")
  @@map("content_blocks")
}

// Платіжні реквізити продавця (LiqPay + банк). Керує лише superadmin.
// liqpayPrivateKey зашифровано (AES-256-GCM, ключ PAYMENT_ENC_KEY); у відповідях маскується.
model PaymentRequisite {
  id               BigInt   @id @default(autoincrement())
  label            String                                    // назва/отримувач, «ФОП Іваненко Іван Іванович»
  taxId            String?  @map("tax_id")                   // ІПН / ЄДРПОУ
  iban             String?
  bankName         String?  @map("bank_name")
  liqpayPublicKey  String?  @map("liqpay_public_key")
  liqpayPrivateKey String?  @map("liqpay_private_key")       // зашифровано
  monopayToken     String?  @map("monopay_token")            // токен monobank, зашифровано
  ibanActive       Boolean  @default(false) @map("iban_active")    // канал IBAN (активний один)
  liqpayActive     Boolean  @default(false) @map("liqpay_active")  // канал LiqPay (активний один)
  monopayActive    Boolean  @default(false) @map("monopay_active") // канал Monopay (активний один)
  createdAt        DateTime @default(now()) @map("created_at")
  updatedAt        DateTime @updatedAt @map("updated_at")
  @@map("payment_requisites")
}

// ───────── Користувачі та замовлення ─────────
model User {
  id           BigInt    @id @default(autoincrement())
  email        String?   @unique
  phone        String?
  passwordHash String?   @map("password_hash")
  firstName    String?   @map("first_name")
  lastName     String?   @map("last_name")
  role         UserRole  @default(user)                    // user | admin | superadmin
  createdAt    DateTime  @default(now()) @map("created_at")
  addresses    Address[]
  orders       Order[]
  leads        Lead[]
  wishlist     WishlistItem[]
  @@map("users")
}

model Address {
  id        BigInt         @id @default(autoincrement())
  userId    BigInt         @map("user_id")
  user      User           @relation(fields: [userId], references: [id], onDelete: Cascade)
  label     String?
  method    DeliveryMethod
  city      String?
  warehouse String?
  recipient String?
  phone     String?
  isDefault Boolean        @default(false) @map("is_default")
  @@map("addresses")
}

model Order {
  id          BigInt      @id @default(autoincrement())
  orderNumber String      @unique @map("order_number")
  userId      BigInt?     @map("user_id")                  // null = гість
  user        User?       @relation(fields: [userId], references: [id], onDelete: SetNull)
  customer    Json                                         // снапшот { name, phone, email }
  delivery    Json                                         // снапшот { city, warehouse }
  // payment jsonb прибрано (ADR-0013): method/status у колонках; канал-деталі — колонкою за потреби
  deliveryMethod DeliveryMethod @map("delivery_method")    // винесено з delivery.method (ADR-0013)
  paymentMethod  PaymentMethod  @map("payment_method")     // винесено з payment.method (ADR-0013)
  paymentStatus  PaymentStatus  @default(pending) @map("payment_status") // винесено з payment.status (ADR-0013)
  total       Decimal     @db.Decimal(12, 2)
  status      OrderStatus @default(new)
  isOneClick  Boolean     @default(false) @map("is_one_click")
  comment     String?
  createdAt   DateTime    @default(now()) @map("created_at")
  items       OrderItem[]
  @@index([userId])
  @@index([status])
  @@index([paymentStatus])                                 // фільтр «неоплачені» в адмінці
  // пошук за customer.phone/email — trigram GIN на JSON-виразі (raw-міграція, див. §Індекси)
  @@map("orders")
}

model OrderItem {
  id        BigInt   @id @default(autoincrement())
  orderId   BigInt   @map("order_id")
  order     Order    @relation(fields: [orderId], references: [id], onDelete: Cascade)
  productId BigInt?  @map("product_id")
  product   Product? @relation(fields: [productId], references: [id], onDelete: SetNull)
  name      String                                         // снапшот на момент покупки
  sku       String
  price     Decimal  @db.Decimal(12, 2)
  qty       Int
  @@map("order_items")
}

// Обране (список бажань) — лише для авторизованих; сигнал інтересу для CRM (ADR-0012).
// Toggle ідемпотентний (складений PK); популярність товару = COUNT за productId.
model WishlistItem {
  userId    BigInt   @map("user_id")
  productId BigInt   @map("product_id")
  user      User     @relation(fields: [userId],    references: [id], onDelete: Cascade)
  product   Product  @relation(fields: [productId], references: [id], onDelete: Cascade)
  createdAt DateTime @default(now()) @map("created_at")
  @@id([userId, productId])
  @@index([productId])            // адмін: «хто хоче цей товар» + популярність
  @@index([userId, createdAt])    // сторінка обраного (новіші зверху)
  @@map("wishlist_items")
}

// ───────── Ліди та контент ─────────
model Lead {
  id          BigInt     @id @default(autoincrement())
  type        LeadType
  name        String
  phone       String
  email       String?
  vin         String?                                       // type = fitment
  link        String?                                       // type = price_match
  targetPrice Decimal?   @map("target_price") @db.Decimal(12, 2)  // type = price_subscribe
  productId   BigInt?    @map("product_id")
  product     Product?   @relation(fields: [productId], references: [id], onDelete: SetNull)
  userId      BigInt?    @map("user_id")                           // якщо лід від авторизованого
  user        User?      @relation(fields: [userId], references: [id], onDelete: SetNull)
  message     String?
  status      LeadStatus @default(new)
  createdAt   DateTime   @default(now()) @map("created_at")
  @@index([status, type])
  @@map("leads")
}

model BlogPost {
  id          BigInt    @id @default(autoincrement())
  slug        String    @unique
  title       String
  excerpt     String?
  contentJson Json?     @map("content_json")                // TipTap JSON — джерело правди
  contentHtml String?   @map("content_html")                // згенерований санітизований HTML
  coverImage  String?   @map("cover_image")
  author      String?
  category    String?
  status      String    @default("draft")                   // draft | published
  publishedAt DateTime? @map("published_at")
  seo         Json      @default("{}")
  @@map("blog_posts")
}

model Banner {
  id        BigInt  @id @default(autoincrement())
  image     String
  link      String?
  title     String?
  sortOrder Int     @default(0) @map("sort_order")
  isActive  Boolean @default(true) @map("is_active")
  @@map("banners")
}

// Карта 301-редиректів зі старого сайту (NFR-3, ADR-0001)
model Redirect {
  id       BigInt @id @default(autoincrement())
  fromPath String @unique @map("from_path")
  toPath   String @map("to_path")
  status   Int    @default(301)
  @@map("redirects")
}

// ───────── Nova Poshta — дзеркало довідника (ADR-0014) ─────────
// Автопідказки в чекауті беруться з цих таблиць, не з АПІ Пошти на кожен запит.
// Синхронізація: cron (RUN_CRON) + ручна кнопка superadmin. Trigram-GIN — raw-міграцією.
model NpCity {
  ref        String        @id                          // NP Ref (стабільний ключ)
  name       String
  area       String?                                     // область
  updatedAt  DateTime      @updatedAt @map("updated_at")
  warehouses NpWarehouse[]
  @@map("np_cities")                                     // + GIN(name gin_trgm_ops)
}

model NpWarehouse {
  ref         String          @id
  cityRef     String          @map("city_ref")
  city        NpCity          @relation(fields: [cityRef], references: [ref], onDelete: Cascade)
  number      String
  description String
  type        NpWarehouseType                            // branch | postomat | cargo
  maxWeight   Decimal?        @map("max_weight") @db.Decimal(10, 2)
  isActive    Boolean         @default(true) @map("is_active")
  updatedAt   DateTime        @updatedAt @map("updated_at")
  @@index([cityRef, type])
  @@map("np_warehouses")                                 // + GIN(description gin_trgm_ops)
}

// Стан останньої синхронізації (singleton id=1) — для кнопки/статусу в адмінці
model NpSyncState {
  id              Int       @id @default(1)
  status          String?                                // ok | error | running
  lastRunAt       DateTime? @map("last_run_at")
  citiesCount     Int       @default(0) @map("cities_count")
  warehousesCount Int       @default(0) @map("warehouses_count")
  error           String?
  @@map("np_sync_state")
}
```

---

## 3. Індекси та пошук

- Базові індекси задано в схемі через `@@index` / `@unique` (category, price, isActive+stockQty, fitment.carId, orders.status/paymentStatus/userId, leads.status+type).
- **Пошук за назвою та артикулом** (FR-4.1) — трграмні GIN-індекси `pg_trgm`. Prisma не виражає `gin_trgm_ops` у схемі, тому додаємо **raw-міграцією**:

```sql
-- prisma/migrations/<ts>_trgm/migration.sql
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE INDEX idx_products_name_trgm ON products USING gin (name gin_trgm_ops);
CREATE INDEX idx_products_sku_trgm  ON products USING gin (sku  gin_trgm_ops);
-- за потреби: GIN на attributes (jsonb)
CREATE INDEX idx_products_attrs ON products USING gin (attributes);
```

- **Пошук замовлень за контактом** (адмінка, ADR-0013) — trigram GIN на JSON-виразах `customer->>'phone'` / `customer->>'email'` (той самий підхід — raw-міграція):

```sql
CREATE INDEX orders_customer_phone_idx ON orders USING gin ((customer ->> 'phone') gin_trgm_ops);
CREATE INDEX orders_customer_email_idx ON orders USING gin ((customer ->> 'email') gin_trgm_ops);
```

- **Автопідказки Нової Пошти** (чекаут, ADR-0014) — trigram GIN на назві міста та адресі відділення:

```sql
CREATE INDEX np_cities_name_trgm_idx ON np_cities USING gin (name gin_trgm_ops);
CREATE INDEX np_warehouses_description_trgm_idx ON np_warehouses USING gin (description gin_trgm_ops);
```

---

## 4. Типові запити (Prisma Client)

```ts
// Товари для авто X у категорії Y (каталог /category/[model]/[category])
const products = await prisma.product.findMany({
  where: { isActive: true, categoryId, fitment: { some: { carId } } },
  orderBy: { createdAt: 'desc' },
  take: 24,
})

// Сумісність товару (картка: «Підходить до …»)
const fitment = await prisma.productFitment.findMany({
  where: { productId },
  include: { car: true },
})

// Пошук за назвою/артикулом (автодоповнення) — через trgm
const found = await prisma.$queryRaw`
  SELECT * FROM products
  WHERE is_active AND (name ILIKE ${q + '%'} OR sku ILIKE ${q + '%'})
  ORDER BY similarity(name, ${q}) DESC LIMIT 8`
```

---

## 5. Нотатки

- **Снапшот у замовленні:** `OrderItem` зберігає `name/sku/price` на момент покупки; `productId` лише для зв'язку (`onDelete: SetNull`).
- **Гостьовий кошик** — у `localStorage`; кошик авторизованого можна синхронізувати окремими моделями `Cart/CartItem` (за потреби; у MVP — клієнтський + відновлення).
- **Сумісність із роками:** `yearFrom/yearTo` уточнюють у межах покоління; зазвичай достатньо `carId` (покоління вже має дати).
- **VIN-підбір (Фаза 3):** VIN → `Car` → `ProductFitment` → товари.
- **Міграція (ADR-0002):** дедуплікація товарів за `sku`, побудова `ProductFitment` зі старих модельних категорій, наповнення `Car`, `Redirect`.
- **`price_subscribe`** (FR-3.10) реалізується через `Lead` (type=`price_subscribe`); за потреби — окрема модель із нотифікаціями.
- **Обране (wishlist)** — лише для авторизованих (`WishlistItem`, [ADR-0012](adr/0012-wishlist-auth-crm.md)): гість тисне ♡ → логін. Toggle ідемпотентний (upsert/delete за складеним PK). Адмін бачить попит («хто хоче цей товар» + контакт для дзвінка) — індекс за `productId`. Сторінка `/wishlist` — `noindex`.
- **BigInt id:** за бажанням можна замінити на `Int` для простоти (якщо обсяги не вимагають 64-біт).
