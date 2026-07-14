-- Average placement by active trait (Set 17, this player's games only).
-- "Active" means the trait was actually breakpointed (tier_current > 0),
-- not just present with a unit or two that never turned it on.
SELECT
    t.name                                          AS trait,
    COUNT(*)                                        AS games_played,
    ROUND(AVG(p.placement), 2)                      AS avg_placement,
    ROUND(100.0 * SUM(CASE WHEN p.placement <= 4 THEN 1 ELSE 0 END) / COUNT(*), 1) AS top4_rate,
    ROUND(100.0 * SUM(CASE WHEN p.placement = 1 THEN 1 ELSE 0 END) / COUNT(*), 1)  AS win_rate
FROM set17_participants_clean p
JOIN real_traits t ON t.participant_id = p.participant_id
WHERE p.puuid = (SELECT puuid FROM me)
  AND t.tier_current > 0
GROUP BY t.name
HAVING games_played >= 10
ORDER BY avg_placement ASC;
