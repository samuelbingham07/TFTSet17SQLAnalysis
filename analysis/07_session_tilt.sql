-- Does placement get worse the longer a play session runs?
-- A "session" is a run of games with no gap >= 45 minutes between them
-- (a single TFT game runs ~35-40 min; the gap distribution shows a clean
-- break there -- most back-to-back games are <45min apart, then a real
-- jump to 45min-2hr+ gaps for actual breaks).
WITH ordered_games AS (
    SELECT
        p.participant_id,
        p.placement,
        m.game_datetime,
        (m.game_datetime - LAG(m.game_datetime) OVER (ORDER BY m.game_datetime)) / 60000.0 AS gap_minutes
    FROM set17_participants_clean p
    JOIN set17_matches m ON m.match_id = p.match_id
    WHERE p.puuid = (SELECT puuid FROM me)
),
sessions AS (
    SELECT
        participant_id,
        placement,
        game_datetime,
        SUM(CASE WHEN gap_minutes IS NULL OR gap_minutes >= 45 THEN 1 ELSE 0 END)
            OVER (ORDER BY game_datetime) AS session_id
    FROM ordered_games
),
session_positions AS (
    SELECT
        participant_id,
        placement,
        session_id,
        ROW_NUMBER() OVER (PARTITION BY session_id ORDER BY game_datetime) AS game_num_in_session,
        COUNT(*) OVER (PARTITION BY session_id) AS session_length
    FROM sessions
)
-- Part 1: placement by position within a session
SELECT
    CASE
        WHEN game_num_in_session = 1 THEN '1st game'
        WHEN game_num_in_session = 2 THEN '2nd game'
        WHEN game_num_in_session = 3 THEN '3rd game'
        WHEN game_num_in_session BETWEEN 4 AND 5 THEN '4th-5th game'
        WHEN game_num_in_session BETWEEN 6 AND 8 THEN '6th-8th game'
        ELSE '9th+ game'
    END AS position_in_session,
    COUNT(*) AS games,
    ROUND(AVG(placement), 2) AS avg_placement,
    ROUND(100.0 * SUM(CASE WHEN placement <= 4 THEN 1 ELSE 0 END) / COUNT(*), 1) AS top4_rate
FROM session_positions
GROUP BY position_in_session
ORDER BY MIN(game_num_in_session);
