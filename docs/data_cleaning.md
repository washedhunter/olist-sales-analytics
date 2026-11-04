# Data Cleaning: Decisions and Reasons

How the raw Kaggle CSVs become 8 clean tables in PostgreSQL, and why each change was made.

| File | Role |
|---|---|
| [`scripts/load_data.py`](../scripts/load_data.py) | Reads the CSVs, cleans them, and loads them in one transaction |
| [`sql/01_create_tables.sql`](../sql/01_create_tables.sql) | Table design: data types, keys, links and rules |
| [`sql/02_data_quality_checks.sql`](../sql/02_data_quality_checks.sql) | Checks run after loading |

```
data/raw/*.csv  ──►  scripts/load_data.py  ──►  PostgreSQL database "olist"
                     read as text → clean      8 tables, keys + foreign keys enforced
```

## Result

| Table | Raw rows | Clean rows | What changed |
|---|---:|---:|---|
| `geolocation` | 1,000,163 | 19,010 | One row per zip prefix |
| `customers` | 99,441 | 99,441 | None |
| `sellers` | 3,095 | 3,095 | None |
| `products` | 32,951 | 32,951 | English category added, typos fixed |
| `product_category_name_translation` | 71 | merged into `products` | |
| `orders` | 99,441 | 99,441 | Dates stored as timestamps |
| `order_items` | 112,650 | 112,650 | Prices stored as exact numbers |
| `order_payments` | 103,886 | 103,886 | None |
| `order_reviews` | 100,000 | 99,441 | One review per order |

## Cleaning decisions

| # | Problem found | Decision | Why |
|---|---|---|---|
| 1 | 24% of customer zip codes start with `0` (e.g. `09790`). Read as numbers, they lose the zero. | Read every column as text first, and store zip codes as `VARCHAR(5)`. | A zip code is a label, not a quantity. Without the zero it no longer matches the geolocation table. |
| 2 | `geolocation` has 1,000,163 rows for only 19,015 zip prefixes, including 261,831 exact duplicates and 42 points outside Brazil. | Remove duplicates and out-of-Brazil points, then keep one row per prefix: the average latitude/longitude and the most common city/state spelling. | A lookup table needs one row per key. Otherwise every join multiplies rows. 5 prefixes had only bad points, which leaves 19,010. |
| 3 | Category names are in Portuguese. 2 categories (13 products) are missing from the translation file, and 610 products have no category at all. | Add the English name to `products` as `product_category`. Translate the 2 missing categories by hand, and label products with no category `uncategorized`. | Every chart gets English labels without an extra join. Labelling rather than deleting keeps those products' sales in the totals. |
| 4 | Column names `product_name_lenght` and `product_description_lenght` are misspelled in the source. | Rename them to `..._length`. | Clean, predictable names for SQL and Power BI. |
| 5 | 4 products have a weight of 0 g. | Set the weight to `NULL` (unknown). | The value is impossible, and guessing one (e.g. the average) would invent data. |
| 6 | 555 orders have 2–3 reviews, and in 209 of them the scores differ. | Keep the most recent review per order. | It reflects the customer's final opinion, and one review per order keeps "average score" correct. |
| 7 | Review comments have stray spaces, and some are blank. | Trim the spaces, and store blank comments as `NULL`. | "No comment" is stored one way instead of two. |
| 8 | Some order dates are missing: approval (160), handover to carrier (1,783), delivery to customer (2,965). | Keep them as `NULL`. | A missing date means the event never happened (canceled or still in transit). Filling it in would be false. |
| 9 | Small timestamp errors: 8 orders marked "delivered" have no delivery date, and 23 were "delivered" before reaching the carrier. | Keep these orders, and document the errors. | Delivery metrics use purchase date → delivery date, which has no errors. Deleting the orders would remove real sales. |
| 10 | 775 orders have no items (603 unavailable, 164 canceled, 8 other). | Keep them. | They are real orders that never shipped, so they count toward order volume and cancellations. Revenue isn't affected, because it comes from items. |
| 11 | Payment oddities: 3 payments of type `not_defined`, 2 with 0 installments, 9 of value 0. | Keep them, and document them. | Don't change values without a confirmed business rule. |
| 12 | For 249 orders, total payments differ from price + freight (installment interest, vouchers). | Calculate revenue from `order_items`, not `payments` (defined in Phase 3). | Item prices can be split by product, category and seller. Payments can't. |

## Note on dataset version

The reviews file used here has 100,000 rows. The current Kaggle release lists 99,224, so this copy appears to be an earlier release of the same dataset. Every other table matches Kaggle's documented row counts.

## Checks after loading

The database enforces primary keys, foreign keys and `CHECK` rules, so a successful load already proves that keys are unique, every link is valid, prices are positive and review scores are between 1 and 5. [`02_data_quality_checks.sql`](../sql/02_data_quality_checks.sql) re-checks these and the known issues above in one query:

| # | Check | Rows found | Expected |
|---:|---|---:|---|
| 1 | Duplicate `order_id` in orders | 0 | 0 |
| 2 | Orders with more than one review | 0 | 0 |
| 3 | Orders with no items | 775 | 775, kept: real orders that never shipped |
| 4 | Orders with no payment record | 1 | 1, kept |
| 5 | Customers whose zip has no GPS location | 279 | 279, kept (no map point) |
| 6 | Delivered orders missing a delivery date | 8 | 8, kept (excluded from delivery-time metrics) |
| 7 | Delivered to customer before purchase | 0 | 0 |
| 8 | Delivered to customer before handed to carrier | 23 | 23, kept (timestamp entry errors) |
| 9 | Products without a category | 610 | 610, labelled `uncategorized` |
| 10 | Item price zero or negative | 0 | 0 |

The load script is **idempotent**: running it again drops and rebuilds the tables and gives identical row counts. The full load takes about 90 seconds and produces a 141 MB database.
