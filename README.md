# Olist Brazilian E-Commerce Analytics Dashboard & Insights  
**End-to-End Data Analysis on 100K+ Orders from Brazil’s Largest Marketplace (2016-2018)**



## 🚀 Project Overview & Business Impact
Analyzed the full Olist public dataset (Brazilian e-commerce platform that connects small merchants to marketplaces) containing **100,000+ orders**, 3,000+ sellers, and 73,000+ customer reviews from 2016–2018.

Delivered actionable insights and recommendations that helped identify:
- Root causes of order fulfillment bottlenecks
- Massive business disruption in late 2018 (urgent investigation flagged)
- Customer segmentation & return-buyer behavior
- Seller performance gaps and geographic inefficiencies
- Product portfolio optimization using ABC classification

## 🎯 Business Questions Answered
- How healthy is Olist’s order fulfillment process compared to industry benchmarks?
- What caused the sharp decline in growth at the end of 2018?
- Which customer segments drive the majority of revenue (Pareto + HHI analysis)?
- How far are customers from sellers on average and what is the impact on delivery time & satisfaction?
- Which products/sellers are top performers and how should inventory be prioritized?

## 🛠️ Tools & Technologies
- **SQL** – Data extraction, cleaning, and normalization (9 original → 11 dimension/fact tables)
- **Python** – pandas, numpy, matplotlib, seaborn for feature engineering & visualization
- **Power BI / Tableau** – Interactive executive dashboard (you can specify which one you used)
- **dbt / Excel** – Optional for modeling (mention if used)

## 📊 Key Achievements & Insights
| Area                     | Key Finding                                                                 | Business Action Recommended                          |
|--------------------------|-----------------------------------------------------------------------------|-------------------------------------------------------|
| Order Fulfillment        | 97.29% delivered (excellent vs industry), cancellation rate <2%            | Healthy operations overall                           |
| Late 2018 Disruption     | Orders collapsed in Oct-Dec 2018 → needs urgent root-cause investigation   | Immediate executive attention                         |
| Customer Concentration   | Top 10 cities = ~45% of revenue, long-tail in 4,000+ cities (HHI calculated)| Focus acquisition on top states                      |
| Return Customers         | X% of customers repeat; average days between orders calculated             | Loyalty program potential                             |
| Delivery Performance     | Average carrier handoff, approval → delivery time engineered                | Optimize “invoiced” & “processing” stages             |
| Product Portfolio       | ABC classification of products by revenue & volume                         | Prioritize inventory for A-class items                |
| Customer-Seller Distance | Geographic distance feature engineered → impact on review scores           | Encourage same-state seller matching                  |

## 🔧 Feature Engineering Highlights
- Delivery time span, carrier handoff delay, order approval time
- Total order value, freight percentage of item value
- Customer distance to seller (using geolocation table)
- Installment categories, payment type grouping
- Return customer flag & days between orders
- Customer tier (revenue contribution %), state performance score

## 🗃️ Data Modeling
Transformed the original 9 raw tables into a clean **star schema** (Kimball dimensional modeling):
- Dimension tables: `dim_customer`, `dim_customer_geo`, `dim_seller`, `dim_seller_geo`, `dim_product`, `dim_date`, `dim_order_review`, etc.
- Fact tables: `fact_orders`, `fact_order_items`

Full **ERD diagram** included in repository.
<p align="center">
  <img src="image/Datamodel.png" alt="Logo" width="800"/>
</p>

## 📈 Visualizations & Dashboard
Interactive dashboard covering:
- Yearly/Monthly/Daily growth trends
- Geographic heatmaps (customer & seller density)
- Top 10 cities, products, sellers
- Review score vs delivery time scatter
- Pareto charts, ABC product classification

*(Add your .pbix / .twb file or screenshots folder)*

## 📁 Repository Structure
├── archive/                  # (raw & processed – optional, respect dataset license)
├── quary/                   # All mysql query for modeling and analysis
├── olist.docs/             # Project report msword
├── dashboard/             # Power BI / 
├── images/                # Screenshots, ERD, key charts
└── README.md


## 🎯 Who This Project is For
Perfect for hiring managers looking for analysts who can:
- Handle real-world messy datasets
- Perform proper data modeling (from raw → star schema)
- Translate numbers into business recommendations
- Build stakeholder-ready dashboards

Feel free to ⭐ the repo if you found it useful!

🔗 LinkedIn: linkedin.com/in/abu-sufian-data | Portfolio: [emptty]
