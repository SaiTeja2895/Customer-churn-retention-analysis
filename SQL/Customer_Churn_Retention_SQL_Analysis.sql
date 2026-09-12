-- ============================================================
-- Customer Churn & Retention Analysis
-- SQL Analysis Script
-- Dataset: cleaned synthetic customer churn data
-- Tables:
--   churn
--   customer_activity
--   subscriptions
--
-- Validation:
--   All analytical queries in this file were executed successfully
--   against the uploaded cleaned datasets using SQLite.
-- ============================================================

-- ============================================================
-- 1. DATA QUALITY CHECKS
-- ============================================================

-- 1.1 Row counts
SELECT 'churn' AS table_name, COUNT(*) AS row_count FROM churn
UNION ALL
SELECT 'customer_activity', COUNT(*) FROM customer_activity
UNION ALL
SELECT 'subscriptions', COUNT(*) FROM subscriptions;

-- 1.2 Duplicate customer IDs in churn
SELECT customer_id, COUNT(*) AS duplicate_count
FROM churn
GROUP BY customer_id
HAVING COUNT(*) > 1;

-- 1.3 Duplicate customer IDs in customer activity
SELECT customer_id, COUNT(*) AS duplicate_count
FROM customer_activity
GROUP BY customer_id
HAVING COUNT(*) > 1;

-- 1.4 Duplicate customer IDs in subscriptions
SELECT customer_id, COUNT(*) AS duplicate_count
FROM subscriptions
GROUP BY customer_id
HAVING COUNT(*) > 1;

-- 1.5 Missing values in key churn fields
SELECT
    SUM(CASE WHEN customer_id IS NULL OR TRIM(customer_id) = '' THEN 1 ELSE 0 END) AS missing_customer_id,
    SUM(CASE WHEN churn_flag IS NULL THEN 1 ELSE 0 END) AS missing_churn_flag,
    SUM(CASE WHEN churn_flag = 1 AND churn_date IS NULL THEN 1 ELSE 0 END) AS churned_without_date,
    SUM(CASE WHEN churn_flag = 1 AND (churn_reason IS NULL OR TRIM(churn_reason) = '') THEN 1 ELSE 0 END) AS churned_without_reason
FROM churn;

-- 1.6 Basic range checks for customer activity
SELECT
    SUM(CASE WHEN age < 0 THEN 1 ELSE 0 END) AS invalid_age,
    SUM(CASE WHEN monthly_charge < 0 THEN 1 ELSE 0 END) AS invalid_monthly_charge,
    SUM(CASE WHEN login_count < 0 THEN 1 ELSE 0 END) AS invalid_login_count,
    SUM(CASE WHEN support_tickets < 0 THEN 1 ELSE 0 END) AS invalid_support_tickets,
    SUM(CASE WHEN avg_session_minutes < 0 THEN 1 ELSE 0 END) AS invalid_session_minutes,
    SUM(CASE WHEN monthly_usage < 0 THEN 1 ELSE 0 END) AS invalid_monthly_usage,
    SUM(CASE WHEN tenure_months < 0 THEN 1 ELSE 0 END) AS invalid_tenure
FROM customer_activity;

-- ============================================================
-- 2. OVERALL CHURN KPIs
-- ============================================================

-- 2.1 Overall customers, churned customers, and churn rate
SELECT
    COUNT(*) AS total_customers,
    SUM(churn_flag) AS churned_customers,
    COUNT(*) - SUM(churn_flag) AS retained_customers,
    ROUND(100.0 * SUM(churn_flag) / COUNT(*), 2) AS churn_rate_pct
FROM churn;

-- 2.2 Retention rate
SELECT
    ROUND(100.0 * SUM(CASE WHEN churn_flag = 0 THEN 1 ELSE 0 END) / COUNT(*), 2) AS retention_rate_pct
FROM churn;

-- 2.3 Churned vs retained customer count
SELECT
    CASE WHEN churn_flag = 1 THEN 'Churned' ELSE 'Retained' END AS customer_status,
    COUNT(*) AS customers,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS percentage
FROM churn
GROUP BY churn_flag
ORDER BY churn_flag DESC;

-- ============================================================
-- 3. CHURN BY CUSTOMER SEGMENT
-- ============================================================

-- 3.1 Churn rate by customer segment
SELECT
    a.customer_segment,
    COUNT(*) AS total_customers,
    SUM(c.churn_flag) AS churned_customers,
    ROUND(100.0 * SUM(c.churn_flag) / COUNT(*), 2) AS churn_rate_pct
FROM customer_activity a
JOIN churn c ON a.customer_id = c.customer_id
GROUP BY a.customer_segment
ORDER BY churn_rate_pct DESC;

-- 3.2 Segment contribution to total churn
SELECT
    a.customer_segment,
    SUM(c.churn_flag) AS churned_customers,
    ROUND(
        100.0 * SUM(c.churn_flag) /
        NULLIF((SELECT SUM(churn_flag) FROM churn), 0),
        2
    ) AS share_of_total_churn_pct
FROM customer_activity a
JOIN churn c ON a.customer_id = c.customer_id
GROUP BY a.customer_segment
ORDER BY churned_customers DESC;

-- ============================================================
-- 4. CHURN BY CONTRACT AND SUBSCRIPTION
-- ============================================================

-- 4.1 Churn rate by contract type
SELECT
    a.contract_type,
    COUNT(*) AS total_customers,
    SUM(c.churn_flag) AS churned_customers,
    ROUND(100.0 * SUM(c.churn_flag) / COUNT(*), 2) AS churn_rate_pct
FROM customer_activity a
JOIN churn c ON a.customer_id = c.customer_id
GROUP BY a.contract_type
ORDER BY churn_rate_pct DESC;

-- 4.2 Churn rate by subscription type
SELECT
    s.subscription_type,
    COUNT(*) AS total_customers,
    SUM(c.churn_flag) AS churned_customers,
    ROUND(100.0 * SUM(c.churn_flag) / COUNT(*), 2) AS churn_rate_pct
FROM subscriptions s
JOIN churn c ON s.customer_id = c.customer_id
GROUP BY s.subscription_type
ORDER BY churn_rate_pct DESC;

-- 4.3 Churn rate by payment method
SELECT
    a.payment_method,
    COUNT(*) AS total_customers,
    SUM(c.churn_flag) AS churned_customers,
    ROUND(100.0 * SUM(c.churn_flag) / COUNT(*), 2) AS churn_rate_pct
FROM customer_activity a
JOIN churn c ON a.customer_id = c.customer_id
GROUP BY a.payment_method
ORDER BY churn_rate_pct DESC;

-- ============================================================
-- 5. CUSTOMER BEHAVIOR AND CHURN
-- ============================================================

-- 5.1 Compare average activity metrics for churned vs retained
SELECT
    CASE WHEN c.churn_flag = 1 THEN 'Churned' ELSE 'Retained' END AS customer_status,
    COUNT(*) AS customers,
    ROUND(AVG(a.login_count), 2) AS avg_login_count,
    ROUND(AVG(a.support_tickets), 2) AS avg_support_tickets,
    ROUND(AVG(a.avg_session_minutes), 2) AS avg_session_minutes,
    ROUND(AVG(a.monthly_usage), 2) AS avg_monthly_usage,
    ROUND(AVG(a.monthly_charge), 2) AS avg_monthly_charge,
    ROUND(AVG(a.tenure_months), 2) AS avg_tenure_months
FROM customer_activity a
JOIN churn c ON a.customer_id = c.customer_id
GROUP BY c.churn_flag
ORDER BY c.churn_flag DESC;

-- 5.2 Churn rate by login activity band
WITH login_bands AS (
    SELECT
        customer_id,
        CASE
            WHEN login_count <= 5 THEN '0-5'
            WHEN login_count <= 10 THEN '6-10'
            WHEN login_count <= 15 THEN '11-15'
            ELSE '16+'
        END AS login_band
    FROM customer_activity
)
SELECT
    l.login_band,
    COUNT(*) AS customers,
    SUM(c.churn_flag) AS churned_customers,
    ROUND(100.0 * SUM(c.churn_flag) / COUNT(*), 2) AS churn_rate_pct
FROM login_bands l
JOIN churn c ON l.customer_id = c.customer_id
GROUP BY l.login_band
ORDER BY
    CASE l.login_band
        WHEN '0-5' THEN 1
        WHEN '6-10' THEN 2
        WHEN '11-15' THEN 3
        ELSE 4
    END;

-- 5.3 Churn rate by support-ticket band
WITH ticket_bands AS (
    SELECT
        customer_id,
        CASE
            WHEN support_tickets = 0 THEN '0'
            WHEN support_tickets <= 2 THEN '1-2'
            WHEN support_tickets <= 5 THEN '3-5'
            ELSE '6+'
        END AS ticket_band
    FROM customer_activity
)
SELECT
    t.ticket_band,
    COUNT(*) AS customers,
    SUM(c.churn_flag) AS churned_customers,
    ROUND(100.0 * SUM(c.churn_flag) / COUNT(*), 2) AS churn_rate_pct
FROM ticket_bands t
JOIN churn c ON t.customer_id = c.customer_id
GROUP BY t.ticket_band
ORDER BY
    CASE t.ticket_band
        WHEN '0' THEN 1
        WHEN '1-2' THEN 2
        WHEN '3-5' THEN 3
        ELSE 4
    END;

-- 5.4 Churn rate by monthly usage band
WITH usage_bands AS (
    SELECT
        customer_id,
        CASE
            WHEN monthly_usage < 20 THEN '<20'
            WHEN monthly_usage < 40 THEN '20-39.9'
            WHEN monthly_usage < 60 THEN '40-59.9'
            ELSE '60+'
        END AS usage_band
    FROM customer_activity
)
SELECT
    u.usage_band,
    COUNT(*) AS customers,
    SUM(c.churn_flag) AS churned_customers,
    ROUND(100.0 * SUM(c.churn_flag) / COUNT(*), 2) AS churn_rate_pct
FROM usage_bands u
JOIN churn c ON u.customer_id = c.customer_id
GROUP BY u.usage_band
ORDER BY
    CASE u.usage_band
        WHEN '<20' THEN 1
        WHEN '20-39.9' THEN 2
        WHEN '40-59.9' THEN 3
        ELSE 4
    END;

-- ============================================================
-- 6. TENURE ANALYSIS
-- ============================================================

-- 6.1 Churn rate by tenure band
WITH tenure_bands AS (
    SELECT
        customer_id,
        CASE
            WHEN tenure_months < 12 THEN '<12 months'
            WHEN tenure_months < 24 THEN '12-23 months'
            WHEN tenure_months < 36 THEN '24-35 months'
            WHEN tenure_months < 48 THEN '36-47 months'
            ELSE '48+ months'
        END AS tenure_band
    FROM customer_activity
)
SELECT
    t.tenure_band,
    COUNT(*) AS customers,
    SUM(c.churn_flag) AS churned_customers,
    ROUND(100.0 * SUM(c.churn_flag) / COUNT(*), 2) AS churn_rate_pct
FROM tenure_bands t
JOIN churn c ON t.customer_id = c.customer_id
GROUP BY t.tenure_band
ORDER BY
    CASE t.tenure_band
        WHEN '<12 months' THEN 1
        WHEN '12-23 months' THEN 2
        WHEN '24-35 months' THEN 3
        WHEN '36-47 months' THEN 4
        ELSE 5
    END;

-- 6.2 Average tenure of churned vs retained customers
SELECT
    CASE WHEN c.churn_flag = 1 THEN 'Churned' ELSE 'Retained' END AS customer_status,
    ROUND(AVG(a.tenure_months), 2) AS avg_tenure_months,
    MIN(a.tenure_months) AS min_tenure_months,
    MAX(a.tenure_months) AS max_tenure_months
FROM customer_activity a
JOIN churn c ON a.customer_id = c.customer_id
GROUP BY c.churn_flag
ORDER BY c.churn_flag DESC;

-- ============================================================
-- 7. DEMOGRAPHIC AND GEOGRAPHIC ANALYSIS
-- ============================================================

-- 7.1 Churn rate by gender
SELECT
    a.gender,
    COUNT(*) AS customers,
    SUM(c.churn_flag) AS churned_customers,
    ROUND(100.0 * SUM(c.churn_flag) / COUNT(*), 2) AS churn_rate_pct
FROM customer_activity a
JOIN churn c ON a.customer_id = c.customer_id
GROUP BY a.gender
ORDER BY churn_rate_pct DESC;

-- 7.2 Churn rate by city
SELECT
    a.city,
    COUNT(*) AS customers,
    SUM(c.churn_flag) AS churned_customers,
    ROUND(100.0 * SUM(c.churn_flag) / COUNT(*), 2) AS churn_rate_pct
FROM customer_activity a
JOIN churn c ON a.customer_id = c.customer_id
GROUP BY a.city
HAVING COUNT(*) >= 50
ORDER BY churn_rate_pct DESC;

-- 7.3 Churn rate by age band
WITH age_bands AS (
    SELECT
        customer_id,
        CASE
            WHEN age < 25 THEN '<25'
            WHEN age < 35 THEN '25-34'
            WHEN age < 45 THEN '35-44'
            WHEN age < 55 THEN '45-54'
            WHEN age < 65 THEN '55-64'
            ELSE '65+'
        END AS age_band
    FROM customer_activity
)
SELECT
    a.age_band,
    COUNT(*) AS customers,
    SUM(c.churn_flag) AS churned_customers,
    ROUND(100.0 * SUM(c.churn_flag) / COUNT(*), 2) AS churn_rate_pct
FROM age_bands a
JOIN churn c ON a.customer_id = c.customer_id
GROUP BY a.age_band
ORDER BY
    CASE a.age_band
        WHEN '<25' THEN 1
        WHEN '25-34' THEN 2
        WHEN '35-44' THEN 3
        WHEN '45-54' THEN 4
        WHEN '55-64' THEN 5
        ELSE 6
    END;

-- ============================================================
-- 8. CHURN REASONS AND CHURN TIMING
-- ============================================================

-- 8.1 Churn reason distribution
SELECT
    churn_reason,
    COUNT(*) AS churned_customers,
    ROUND(
        100.0 * COUNT(*) /
        NULLIF((SELECT COUNT(*) FROM churn WHERE churn_flag = 1), 0),
        2
    ) AS share_of_churn_pct
FROM churn
WHERE churn_flag = 1
GROUP BY churn_reason
ORDER BY churned_customers DESC;

-- 8.2 Monthly churn trend
SELECT
    substr(churn_date, 1, 7) AS churn_month,
    COUNT(*) AS churned_customers
FROM churn
WHERE churn_flag = 1
  AND churn_date IS NOT NULL
GROUP BY substr(churn_date, 1, 7)
ORDER BY churn_month;

-- 8.3 Churn by year
SELECT
    substr(churn_date, 1, 4) AS churn_year,
    COUNT(*) AS churned_customers
FROM churn
WHERE churn_flag = 1
  AND churn_date IS NOT NULL
GROUP BY substr(churn_date, 1, 4)
ORDER BY churn_year;

-- ============================================================
-- 9. REVENUE AT RISK AND HIGH-RISK CUSTOMERS
-- ============================================================

-- 9.1 Monthly recurring revenue lost from churned customers
SELECT
    COUNT(*) AS churned_customers,
    ROUND(SUM(a.monthly_charge), 2) AS monthly_revenue_at_risk
FROM customer_activity a
JOIN churn c ON a.customer_id = c.customer_id
WHERE c.churn_flag = 1;

-- 9.2 Average monthly charge: churned vs retained
SELECT
    CASE WHEN c.churn_flag = 1 THEN 'Churned' ELSE 'Retained' END AS customer_status,
    COUNT(*) AS customers,
    ROUND(AVG(a.monthly_charge), 2) AS avg_monthly_charge,
    ROUND(SUM(a.monthly_charge), 2) AS total_monthly_charge
FROM customer_activity a
JOIN churn c ON a.customer_id = c.customer_id
GROUP BY c.churn_flag
ORDER BY c.churn_flag DESC;

-- 9.3 Top 20 churned customers by monthly charge
SELECT
    c.customer_id,
    a.customer_segment,
    a.contract_type,
    a.monthly_charge,
    a.login_count,
    a.support_tickets,
    a.monthly_usage,
    a.tenure_months,
    c.churn_date,
    c.churn_reason
FROM churn c
JOIN customer_activity a ON c.customer_id = a.customer_id
WHERE c.churn_flag = 1
ORDER BY a.monthly_charge DESC
LIMIT 20;

-- 9.4 High-value churned customers by segment
SELECT
    a.customer_segment,
    COUNT(*) AS churned_customers,
    ROUND(SUM(a.monthly_charge), 2) AS monthly_revenue_at_risk,
    ROUND(AVG(a.monthly_charge), 2) AS avg_monthly_charge
FROM customer_activity a
JOIN churn c ON a.customer_id = c.customer_id
WHERE c.churn_flag = 1
GROUP BY a.customer_segment
ORDER BY monthly_revenue_at_risk DESC;

-- ============================================================
-- 10. RETENTION / RISK SEGMENTATION
-- ============================================================

-- 10.1 Simple customer risk classification
WITH risk_scored AS (
    SELECT
        a.customer_id,
        a.customer_segment,
        a.contract_type,
        a.monthly_charge,
        a.login_count,
        a.support_tickets,
        a.monthly_usage,
        a.tenure_months,
        CASE
            WHEN a.login_count <= 5
                 AND a.support_tickets >= 3
                 AND a.monthly_usage < 20
                THEN 'High Risk'
            WHEN a.login_count <= 10
                 OR a.support_tickets >= 3
                 OR a.monthly_usage < 40
                THEN 'Medium Risk'
            ELSE 'Low Risk'
        END AS risk_level
    FROM customer_activity a
    WHERE NOT EXISTS (
        SELECT 1
        FROM churn c
        WHERE c.customer_id = a.customer_id
          AND c.churn_flag = 1
    )
)
SELECT
    risk_level,
    COUNT(*) AS retained_customers,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS share_of_retained_pct
FROM risk_scored
GROUP BY risk_level
ORDER BY
    CASE risk_level
        WHEN 'High Risk' THEN 1
        WHEN 'Medium Risk' THEN 2
        ELSE 3
    END;

-- 10.2 Customers with low engagement and no churn yet
SELECT
    a.customer_id,
    a.customer_segment,
    a.contract_type,
    a.monthly_charge,
    a.login_count,
    a.support_tickets,
    a.monthly_usage,
    a.last_login_date,
    a.tenure_months
FROM customer_activity a
JOIN churn c ON a.customer_id = c.customer_id
WHERE c.churn_flag = 0
  AND a.login_count <= 5
  AND a.monthly_usage < 20
ORDER BY a.monthly_charge DESC
LIMIT 50;

-- ============================================================
-- 11. CROSS-DIMENSION ANALYSIS
-- ============================================================

-- 11.1 Churn rate by segment and contract type
SELECT
    a.customer_segment,
    a.contract_type,
    COUNT(*) AS customers,
    SUM(c.churn_flag) AS churned_customers,
    ROUND(100.0 * SUM(c.churn_flag) / COUNT(*), 2) AS churn_rate_pct
FROM customer_activity a
JOIN churn c ON a.customer_id = c.customer_id
GROUP BY a.customer_segment, a.contract_type
ORDER BY churn_rate_pct DESC;

-- 11.2 Churn rate by subscription type and payment method
SELECT
    s.subscription_type,
    s.payment_method,
    COUNT(*) AS customers,
    SUM(c.churn_flag) AS churned_customers,
    ROUND(100.0 * SUM(c.churn_flag) / COUNT(*), 2) AS churn_rate_pct
FROM subscriptions s
JOIN churn c ON s.customer_id = c.customer_id
GROUP BY s.subscription_type, s.payment_method
ORDER BY churn_rate_pct DESC;

-- 11.3 Churn rate by support tickets and customer segment
SELECT
    a.customer_segment,
    CASE
        WHEN a.support_tickets = 0 THEN '0'
        WHEN a.support_tickets <= 2 THEN '1-2'
        WHEN a.support_tickets <= 5 THEN '3-5'
        ELSE '6+'
    END AS ticket_band,
    COUNT(*) AS customers,
    SUM(c.churn_flag) AS churned_customers,
    ROUND(100.0 * SUM(c.churn_flag) / COUNT(*), 2) AS churn_rate_pct
FROM customer_activity a
JOIN churn c ON a.customer_id = c.customer_id
GROUP BY
    a.customer_segment,
    CASE
        WHEN a.support_tickets = 0 THEN '0'
        WHEN a.support_tickets <= 2 THEN '1-2'
        WHEN a.support_tickets <= 5 THEN '3-5'
        ELSE '6+'
    END
ORDER BY churn_rate_pct DESC;

-- ============================================================
-- 12. RANKING AND SUMMARY QUERIES
-- ============================================================

-- 12.1 Rank customer segments by churn rate
WITH segment_metrics AS (
    SELECT
        a.customer_segment,
        COUNT(*) AS total_customers,
        SUM(c.churn_flag) AS churned_customers,
        100.0 * SUM(c.churn_flag) / COUNT(*) AS churn_rate_pct
    FROM customer_activity a
    JOIN churn c ON a.customer_id = c.customer_id
    GROUP BY a.customer_segment
)
SELECT
    customer_segment,
    total_customers,
    churned_customers,
    ROUND(churn_rate_pct, 2) AS churn_rate_pct,
    RANK() OVER (ORDER BY churn_rate_pct DESC) AS churn_rate_rank
FROM segment_metrics
ORDER BY churn_rate_rank;

-- 12.2 Rank cities by churn rate
WITH city_metrics AS (
    SELECT
        a.city,
        COUNT(*) AS total_customers,
        SUM(c.churn_flag) AS churned_customers,
        100.0 * SUM(c.churn_flag) / COUNT(*) AS churn_rate_pct
    FROM customer_activity a
    JOIN churn c ON a.customer_id = c.customer_id
    GROUP BY a.city
    HAVING COUNT(*) >= 50
)
SELECT
    city,
    total_customers,
    churned_customers,
    ROUND(churn_rate_pct, 2) AS churn_rate_pct,
    RANK() OVER (ORDER BY churn_rate_pct DESC) AS churn_rate_rank
FROM city_metrics
ORDER BY churn_rate_rank;

-- 12.3 Overall executive summary
SELECT
    COUNT(*) AS total_customers,
    SUM(c.churn_flag) AS churned_customers,
    COUNT(*) - SUM(c.churn_flag) AS retained_customers,
    ROUND(100.0 * SUM(c.churn_flag) / COUNT(*), 2) AS churn_rate_pct,
    ROUND(100.0 * (COUNT(*) - SUM(c.churn_flag)) / COUNT(*), 2) AS retention_rate_pct,
    ROUND(SUM(CASE WHEN c.churn_flag = 1 THEN a.monthly_charge ELSE 0 END), 2) AS monthly_revenue_at_risk,
    ROUND(AVG(CASE WHEN c.churn_flag = 1 THEN a.monthly_charge END), 2) AS avg_churned_monthly_charge,
    ROUND(AVG(CASE WHEN c.churn_flag = 0 THEN a.monthly_charge END), 2) AS avg_retained_monthly_charge
FROM customer_activity a
JOIN churn c ON a.customer_id = c.customer_id;
