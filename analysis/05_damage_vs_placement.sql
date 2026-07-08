-- Does total damage dealt to other players correlate with placement?
-- (proxy for overall board strength/tempo across the game, not just final fight)
-- Part 1: bucketed view
SELECT
    CASE
        WHEN total_damage_to_players < 50 THEN '<50'
        WHEN total_damage_to_players < 100 THEN '50-99'
        WHEN total_damage_to_players < 150 THEN '100-149'
        WHEN total_damage_to_players < 200 THEN '150-199'
        ELSE '200+'
    END AS damage_bucket,
    COUNT(*) AS games,
    ROUND(AVG(placement), 2) AS avg_placement,
    ROUND(100.0 * SUM(CASE WHEN placement <= 4 THEN 1 ELSE 0 END) / COUNT(*), 1) AS top4_rate
FROM set17_participants_clean
WHERE puuid = (SELECT puuid FROM me)
GROUP BY damage_bucket
ORDER BY MIN(total_damage_to_players);

-- Part 2: Pearson correlation between damage dealt and placement
SELECT ROUND((COUNT(*) * SUM(total_damage_to_players * placement) - SUM(total_damage_to_players) * SUM(placement)) / (SQRT(COUNT(*) * SUM(total_damage_to_players * total_damage_to_players) - SUM(total_damage_to_players) * SUM(total_damage_to_players)) * SQRT(COUNT(*) * SUM(placement * placement) - SUM(placement) * SUM(placement))), 3) AS pearson_r, COUNT(*) AS n
FROM set17_participants_clean
WHERE puuid = (SELECT puuid FROM me);
