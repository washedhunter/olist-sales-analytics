# SQL Business Analysis: Results

12 business questions answered in PostgreSQL, from simple totals up to window functions and customer segmentation. Each query is in [`sql/analysis/`](../sql/analysis/), with comments explaining how it works.

**Scope (the same for every query):** delivered orders placed from **January 2017 to August 2018**, the 20 complete months. **Revenue** means the sum of item prices, excluding freight. All of this is defined once in the view [`delivered_orders`](../sql/03_create_views.sql), which adds up the items per order *before* joining, so revenue can't be double counted. Currency: Brazilian real (BRL, R$).

| # | Question | SQL concepts |
|---|---|---|
| [Q01](../sql/analysis/q01_business_overview.sql) | How big is the business? | `COUNT`, `SUM`, `AVG`, `COUNT(DISTINCT)` |
| [Q02](../sql/analysis/q02_monthly_trend.sql) | Is revenue growing month by month? | `GROUP BY`, `ORDER BY` |
| [Q03](../sql/analysis/q03_top_categories.sql) | Which categories earn the most? | 3-table `JOIN`, `LIMIT` |
| [Q04](../sql/analysis/q04_revenue_by_state.sql) | Where does revenue come from, and where is shipping expensive? | CTE, scalar subquery |
| [Q05](../sql/analysis/q05_payment_methods.sql) | How do customers pay? | `CASE` inside aggregates |
| [Q06](../sql/analysis/q06_delivery_by_state.sql) | Which states get slow or late deliveries? | `WHERE` vs `HAVING` |
| [Q07](../sql/analysis/q07_delivery_vs_reviews.sql) | Does late delivery hurt reviews? | `CASE` buckets, `CORR()` |
| [Q08](../sql/analysis/q08_mom_growth.sql) | Month-over-month and year-over-year growth | `LAG()`, running `SUM() OVER` |
| [Q09](../sql/analysis/q09_repeat_customers.sql) | How many customers come back, and when? | `ROW_NUMBER()`, `LEAD()`, `PARTITION BY` |
| [Q10](../sql/analysis/q10_top_categories_per_state.sql) | Top categories in each big state | `RANK() OVER (PARTITION BY)` |
| [Q11](../sql/analysis/q11_seller_performance.sql) | Seller concentration and seller scorecard | `NTILE()`, cumulative sum, fan-out control |
| [Q12](../sql/analysis/q12_rfm_segmentation.sql) | RFM customer segments | chained CTEs, `NTILE()` scoring |

---

## Q01 · Business overview
| Delivered orders | Unique customers | Revenue | Avg order value | Freight | Items per order | Orders per customer |
|---:|---:|---:|---:|---:|---:|---:|
| 96,211 | 93,104 | R$ 13.18 M | R$ 137.00 | R$ 2.19 M | 1.14 | 1.03 |

**What it means:** a typical order is one item of about R$137. "Orders per customer = 1.03" is the first sign of the retention problem in Q09.

## Q02 / Q08 · Revenue trend and growth
| | Jan–Aug 2017 | Jan–Aug 2018 | Change |
|---|---:|---:|---:|
| Revenue | R$ 2.99 M | R$ 7.22 M | **+141%** |

- 2017 grew fast, from R$112k in January to R$988k in November. **November 2017 is the peak (+52% vs October): Black Friday.**
- In 2018 revenue **plateaued** at R$0.83–0.98 M a month. From February to August, month-over-month growth swung between −12% and +15%, and year-over-year growth shrank from +253% (Feb) to +51% (Aug).

**What it means:** the early growth phase is over. Further growth has to come from retaining customers and getting them to spend more, not only from new buyers.

## Q03 · Top categories
| Category | Revenue | Orders | Avg item price | Avg review |
|---|---:|---:|---:|---:|
| health_beauty | R$ 1.23 M | 8,610 | R$ 130.50 | 4.18 |
| watches_gifts | R$ 1.16 M | 5,491 | R$ 198.71 | 4.06 |
| bed_bath_table | R$ 1.02 M | 9,267 | R$ 93.46 | **3.90** |
| sports_leisure | R$ 0.95 M | 7,513 | R$ 113.24 | 4.15 |
| computers_accessories | R$ 0.89 M | 6,518 | R$ 116.36 | 3.98 |

**What it means:** `bed_bath_table` has the most orders but the lowest rating in the top 5, so it's the category where improving quality would help the most customers. `watches_gifts` earns a lot from fewer orders because of its high price.

## Q04 · Revenue and freight by state
- **The Southeast earns 65% of revenue**, and São Paulo (SP) alone 38%. SP, RJ and MG together make 63%.
- **Freight is far more expensive away from SP:** 13.9% of the order value in SP, against 22–28% in many North and Northeast states (e.g. RR 27.8%, MA 26.2%).

**What it means:** customers in distant states pay up to twice as much for shipping relative to what they buy. That's a barrier to growing in those regions.

## Q05 · Payment methods
| Method | Share of amount paid | Avg instalments | Paid in instalments |
|---|---:|---:|---:|
| credit_card | 78.5% | 3.5 | 66.8% |
| boleto (bank slip) | 18.0% | 1.0 | 0% |
| voucher | 2.2% | 1.0 | 0% |
| debit_card | 1.4% | 1.0 | 0% |

**What it means:** two-thirds of card payments are split into instalments, so interest-free instalment offers are a key sales lever in Brazil.

## Q06 · Delivery by state
- **SP orders arrive in 8.7 days on average. AM takes 26.4 and AL 24.5**, about three times longer.
- Alagoas (AL) has the worst on-time rate (78.5%), and Maranhão (MA) and AL have the lowest reviews (3.81 and 3.83). SP, PR and MG combine fast delivery with the best reviews (4.18–4.23).

## Q07 · Late delivery vs review score ⭐ key finding
| Delivered vs promised date | Orders | Avg review | 1-star |
|---|---:|---:|---:|
| 10+ days early | 61,595 | 4.31 | 6.6% |
| 1–9 days early | 26,786 | 4.22 | 7.2% |
| on the promised day | 1,291 | 4.01 | 9.1% |
| 1–3 days late | 1,869 | 3.28 | 25.4% |
| 4–7 days late | 1,802 | 2.09 | 59.1% |
| 8+ days late | 2,860 | **1.69** | **69.9%** |

- Only **6.8%** of orders arrive late, but those orders average **2.26 stars against 4.28** for on-time orders, and **63% of them get 1–2 stars** (vs 9.5%).
- The correlation between days late and score is −0.27. That's moderate overall, because most orders arrive early, but the step down after the promised date is steep.

**What it means:** delivery reliability is the strongest lever on customer satisfaction. Reducing late deliveries would cut 1-star reviews more than anything else.

## Q09 · Repeat customers ⭐ key finding
| Customer type | Customers | Share | Share of revenue | Revenue per customer |
|---|---:|---:|---:|---:|
| one-time | 90,315 | **97.0%** | 94.5% | R$ 137.91 |
| repeat (2+ orders) | 2,789 | 3.0% | 5.5% | **R$ 260.08** |

- Repeat customers are worth about **1.9×** as much, but only 3% of customers come back.
- 30% of second orders happen on the **same day** as the first, which is really one shopping trip split into two orders. Only about **2.1%** of customers truly return later.

**What it means:** there's almost no customer retention. This is the biggest business opportunity in the data.

## Q10 · Top categories per state
The top 3 categories are much the same everywhere (bed_bath_table, health_beauty, watches_gifts), with a few regional differences. **RJ's #1 is watches_gifts, PR's is sports_leisure, and RS has furniture_decor and computers_accessories in its top 3.** National campaigns can stay broad, with small regional changes.

## Q11 · Seller performance
- **The top 10% of sellers (295) earn 67% of revenue, and the top 20% earn 82%.** That's the classic 80/20 pattern.
- Of the 15 biggest sellers, **4 are flagged "needs attention"**: an average review below 3.9, or more than 10% late deliveries. One has a 3.49 rating across 973 orders.

**What it means:** the business depends on a small group of sellers, so managing their service quality protects most of the revenue.

## Q12 · RFM segmentation
| Segment | Customers | Share | Avg spend | Days since last order | Share of revenue |
|---|---:|---:|---:|---:|---:|
| 1. Loyal & active | 1,193 | 1.3% | R$ 271 | 91 | 2.5% |
| 2. Loyal, at risk | 1,596 | 1.7% | R$ 252 | 320 | 3.0% |
| 3. New, high spend | 14,395 | 15.5% | R$ 267 | 94 | 29.2% |
| 4. New | 21,653 | 23.3% | R$ 56 | 92 | 9.1% |
| 5. High spend, slipping away | 13,898 | 14.9% | R$ 264 | 269 | **27.8%** |
| 6. Slipping away | 22,183 | 23.8% | R$ 56 | 270 | 9.4% |
| 7. Lost | 18,186 | 19.5% | R$ 138 | 472 | 19.0% |

**What it means:**
- **"High spend, slipping away"** is the priority win-back target: 13,898 customers who spent R$264 each (28% of revenue) and haven't ordered in about 9 months.
- **"New, high spend"** customers (15.5%) should get a second-order offer *now*, before they slip away too.
