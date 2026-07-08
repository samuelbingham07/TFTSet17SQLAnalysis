-- Weekly trend: is avg placement improving over the course of the tracked games?
SELECT
    strftime('%Y-%W', datetime(m.game_datetime / 1000, 'unixepoch')) AS year_week,
    COUNT(*) AS games,
    ROUND(AVG(p.placement), 2) AS avg_placement,
    ROUND(100.0 * SUM(CASE WHEN p.placement <= 4 THEN 1 ELSE 0 END) / COUNT(*), 1) AS top4_rate,
    ROUND(100.0 * SUM(CASE WHEN p.placement = 1 THEN 1 ELSE 0 END) / COUNT(*), 1) AS win_rate
FROM set17_participants_clean p
JOIN set17_matches m ON m.match_id = p.match_id
WHERE p.puuid = (SELECT puuid FROM me)
GROUP BY year_week
ORDER BY year_week;
