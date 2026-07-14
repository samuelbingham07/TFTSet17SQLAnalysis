-- Identify most-played comps by the exact set of active traits (tier_current > 0)
-- per game, then compare placement across comps.
WITH comp_signature AS (
    SELECT
        p.participant_id,
        p.placement,
        GROUP_CONCAT(t.name, '+' ORDER BY t.name) AS comp
    FROM set17_participants_clean p
    JOIN real_traits t ON t.participant_id = p.participant_id AND t.tier_current > 0
    WHERE p.puuid = (SELECT puuid FROM me)
    GROUP BY p.participant_id
)
SELECT
    comp,
    COUNT(*) AS games_played,
    ROUND(AVG(placement), 2) AS avg_placement,
    ROUND(100.0 * SUM(CASE WHEN placement <= 4 THEN 1 ELSE 0 END) / COUNT(*), 1) AS top4_rate,
    ROUND(100.0 * SUM(CASE WHEN placement = 1 THEN 1 ELSE 0 END) / COUNT(*), 1) AS win_rate
FROM comp_signature
GROUP BY comp
HAVING games_played >= 8
ORDER BY avg_placement ASC;
