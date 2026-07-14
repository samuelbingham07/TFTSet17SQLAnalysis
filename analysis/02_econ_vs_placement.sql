-- Does gold left at elimination/game-end correlate with final placement?
-- Part 1: bucketed view (easy to read/chart)
SELECT
    CASE
        WHEN gold_left < 10 THEN '<10'
        WHEN gold_left BETWEEN 10 AND 19 THEN '10-19'
        WHEN gold_left BETWEEN 20 AND 29 THEN '20-29'
        ELSE '30+'
    END AS gold_left_bucket,
    COUNT(*)                    AS games,
    ROUND(AVG(placement), 2)    AS avg_placement,
    ROUND(100.0 * SUM(CASE WHEN placement <= 4 THEN 1 ELSE 0 END) / COUNT(*), 1) AS top4_rate
FROM set17_participants_clean
WHERE puuid = (SELECT puuid FROM me)
GROUP BY gold_left_bucket
ORDER BY MIN(gold_left);

-- Part 2: Pearson correlation coefficient between gold_left and placement
-- (r close to 0 = no linear relationship, positive r = more gold left -> worse/higher placement number)
SELECT ROUND((COUNT(*) * SUM(gold_left * placement) - SUM(gold_left) * SUM(placement)) / (SQRT(COUNT(*) * SUM(gold_left * gold_left) - SUM(gold_left) * SUM(gold_left)) * SQRT(COUNT(*) * SUM(placement * placement) - SUM(placement) * SUM(placement))), 3) AS pearson_r, COUNT(*) AS n
FROM set17_participants_clean
WHERE puuid = (SELECT puuid FROM me);
