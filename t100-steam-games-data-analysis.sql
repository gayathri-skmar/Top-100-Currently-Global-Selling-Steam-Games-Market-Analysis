SELECT *
FROM steam_data;

-- Module #1: Cleaning and Derived Metrics
UPDATE steam_data
SET firstReleaseDate = LEFT(firstReleaseDate, LOCATE('T', firstReleaseDate) - 1);

ALTER TABLE steam_data MODIFY COLUMN firstReleaseDate DATE;

ALTER TABLE steam_data 
ADD COLUMN estimated_gross_revenue DECIMAL(15,2)
GENERATED ALWAYS AS (copiesSold * price) STORED;

ALTER TABLE steam_data 
ADD COLUMN market_status VARCHAR(30);

UPDATE steam_data
SET market_status = CASE
	WHEN earlyAccess = 'true' THEN 'Beta-Phase'
    ELSE 'Full-Release'
END;

ALTER TABLE steam_data
DROP COLUMN steamUrl,
DROP COLUMN steamId,
DROP COLUMN unreleased,
DROP COLUMN earlyAccess;

-- Look at review score trends for each publisher with more than one game in the top 100 currently global selling steam games
WITH rankedGames AS
(
SELECT name, reviewScore, publishers,
	RANK() OVER(PARTITION BY publishers ORDER BY copiesSOLD DESC) AS sales_rank,
    COUNT(*) OVER(PARTITION BY publishers) as pub_game_count
FROM steam_data
)
SELECT name, reviewScore, publishers, sales_rank
FROM rankedGames
WHERE pub_game_count > 1;

-- Classifying which games into price tiers and then identifying which games tend to be scored higher in terms of the price tiers
WITH priceBuckets AS
(
SELECT name, reviewScore, copiesSold,
	CASE
		WHEN price = 0 THEN 'Free'
        WHEN price > 0 AND PRICE <= 19.99 THEN 'Budget'
        WHEN price BETWEEN 20 AND 49.99 THEN 'Mid-Tier'
        ELSE 'Premium'
	END AS price_tier
FROM steam_data
)
SELECT price_tier, AVG(reviewScore) AS avg_score, SUM(copiesSold) AS total_sold
FROM priceBuckets
GROUP BY price_tier
ORDER BY avg_score DESC;

-- Finding the rolling total sales over the years
WITH yearSales AS
(
	SELECT YEAR(firstReleaseDate) as releaseYear, SUM(copiesSold) AS yearly_sales,
    SUM(SUM(copiesSold)) OVER(ORDER BY YEAR(firstReleaseDate)) AS running_total_sales
	FROM steam_data
	GROUP BY releaseYear
	ORDER BY releaseYear
)
SELECT releaseYear, running_total_sales, yearly_sales
FROM yearSales
ORDER BY yearly_sales DESC;

-- Finding what games are in bottom 25% in copies sold but have substantial review scores
WITH quartileRank AS
(
SELECT name, reviewScore, copiesSold,
	PERCENT_RANK() OVER (ORDER BY copiesSold DESC) AS sale_percentile
FROM steam_data
)
SELECT name
FROM quartileRank
WHERE sale_percentile >= 0.75 AND reviewScore > 85
ORDER BY reviewScore DESC;



