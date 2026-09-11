CREATE TABLE mineral_production (
    id SERIAL PRIMARY KEY,
    year VARCHAR(10),
    state VARCHAR(100),
    mineral VARCHAR(100),
    production NUMERIC(20,2),
    unit VARCHAR(50)
);

  select *
  from mineral_production 
  limit 10;

	select *
	 from mineral_production
	 where state <> 'India';

	 
-- 1. ANALYTICAL QUERIES
-- ============================================================

-- (a) Year-over-year growth % by state and mineral
-- Uses LAG() to pull the previous year's production into the same row
WITH yearly AS (
    SELECT
        state,
        mineral,
        year as fin_year,
        production,
        LAG(production) OVER (
            PARTITION BY state, mineral
            ORDER BY year
        ) AS prev_year_production
    FROM mineral_production
	where state <>'India'
)
SELECT
    state,
    mineral,
    fin_year,
    production,
    prev_year_production,
    ROUND(
        100.0 * (production - prev_year_production) / NULLIF(prev_year_production, 0),
        2
    ) AS yoy_growth_pct
FROM yearly
WHERE prev_year_production IS NOT NULL
ORDER BY mineral, state, fin_year;


-- (b) Top 5 producing states per mineral, for the latest year
-- Uses DENSE_RANK() to handle ties cleanly
WITH latest_year AS (
    SELECT MAX(year) AS yr FROM mineral_production
),
ranked AS (
    SELECT
        mp.mineral,
        mp.state,
        mp.production,
        DENSE_RANK() OVER (
            PARTITION BY mp.mineral
            ORDER BY mp.production DESC
        ) AS rank_in_mineral
    FROM mineral_production mp, latest_year ly
    WHERE mp.year = ly.yr and mp.state <>'India' 
)
SELECT *
FROM ranked
WHERE rank_in_mineral <= 5
ORDER BY mineral, rank_in_mineral;


-- (c) States with declining production for every year in the dataset
-- (i.e. production strictly decreased each consecutive year — flags a shrinking producer)
WITH yearly AS (
    SELECT
        state,
        mineral,
        year as fin_year,
        production,
        LAG(production) OVER (
            PARTITION BY state, mineral
            ORDER BY year
        ) AS prev_year_production
    FROM mineral_production
	where state <>'India'
),
flagged AS (
    SELECT
        state,
        mineral,
        fin_year,
        production,
        prev_year_production,
        CASE WHEN production < prev_year_production THEN 1 ELSE 0 END AS declined
    FROM yearly
    WHERE prev_year_production IS NOT NULL
)
SELECT
    state,
    mineral,
    COUNT(*)               AS years_compared,
    SUM(declined)           AS years_declined
FROM flagged
GROUP BY state, mineral
HAVING SUM(declined) = COUNT(*)   -- declined in every year-over-year comparison available
ORDER BY mineral, state;


-- (d) National totals per mineral per year (useful for a Power BI trend line / KPI card)
SELECT
    mineral,
    year as fin_year,
    production AS total_national_production,
    unit
FROM mineral_production
where state <>'India'
ORDER BY mineral, fin_year;


-- (e) Each state's share (%) of national production, per mineral, latest year
-- Good for a Power BI map / donut chart
WITH latest_year AS (
    SELECT MAX(year) AS yr
    FROM mineral_production
),

national AS (
    SELECT
        mineral,
        production AS national_total
    FROM mineral_production mp
    CROSS JOIN latest_year ly
    WHERE mp.year = ly.yr
      AND mp.state = 'India'
)

SELECT
    mp.mineral,
    mp.state,
    mp.production,
    n.national_total,
    ROUND(
        100.0 * mp.production / NULLIF(n.national_total, 0),
        2
    ) AS pct_of_national
FROM mineral_production mp
JOIN national n
    ON mp.mineral = n.mineral
CROSS JOIN latest_year ly
WHERE mp.year = ly.yr
  AND mp.state <> 'India'
ORDER BY mp.mineral, pct_of_national DESC;

--f. Highest-Growth State & Mineral
WITH yearly AS (
    SELECT
        state,
        mineral,
        year AS fin_year,
        production,
        LAG(production) OVER (
            PARTITION BY state, mineral
            ORDER BY year
        ) AS prev_year_production
    FROM mineral_production
    WHERE state <> 'India'
),
growth AS (
    SELECT
        state,
        mineral,
        fin_year,
        production,
        prev_year_production,
        ROUND(
            100.0 * (production - prev_year_production)
            / NULLIF(prev_year_production, 0),
            2
        ) AS growth_pct
    FROM yearly
    WHERE prev_year_production IS NOT NULL
)
SELECT *
FROM growth
ORDER BY growth_pct DESC
LIMIT 10;

--g. Biggest Production Decline

WITH yearly AS (
    SELECT
        state,
        mineral,
        year AS fin_year,
        production,
        LAG(production) OVER (
            PARTITION BY state, mineral
            ORDER BY year
        ) AS prev_year_production
    FROM mineral_production
    WHERE state <> 'India'
)
SELECT
    state,
    mineral,
    fin_year,
    production,
    prev_year_production,
    ROUND(
        100.0 * (production - prev_year_production)
        / NULLIF(prev_year_production, 0),
        2
    ) AS decline_pct
FROM yearly
WHERE prev_year_production IS NOT NULL
  AND production < prev_year_production
ORDER BY decline_pct ASC
LIMIT 10;


	 