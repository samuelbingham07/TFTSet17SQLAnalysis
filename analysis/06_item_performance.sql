-- Part 1: total items equipped across the whole final board vs. placement.
-- (a rough proxy for itemization depth/completeness, not item quality)
SELECT
    item_count,
    COUNT(*) AS games,
    ROUND(AVG(placement), 2) AS avg_placement
FROM (
    SELECT p.participant_id, p.placement, COUNT(ui.unit_item_id) AS item_count
    FROM set17_participants_clean p
    JOIN units u ON u.participant_id = p.participant_id
    JOIN unit_items ui ON ui.unit_id = u.unit_id
    WHERE p.puuid = (SELECT puuid FROM me)
    GROUP BY p.participant_id
)
GROUP BY item_count
ORDER BY item_count;

-- Part 2: per-item performance. Excludes emblem items tied to the fake
-- traits already excluded from the trait analysis (equipping an emblem
-- for a trait that doesn't exist isn't a real itemization choice).
WITH participant_items AS (
    SELECT DISTINCT p.participant_id, p.placement, ui.item_name
    FROM set17_participants_clean p
    JOIN units u ON u.participant_id = p.participant_id
    JOIN unit_items ui ON ui.unit_id = u.unit_id
    WHERE p.puuid = (SELECT puuid FROM me)
      AND ui.item_name NOT IN (
        'TFT17_Item_ASTraitEmblemItem', 'TFT17_Item_AssassinTraitEmblemItem',
        'TFT17_Item_DRXEmblemItem', 'TFT17_Item_FlexTraitEmblemItem',
        'TFT17_Item_HPTankEmblemItem', 'TFT17_Item_MeleeTraitEmblemItem',
        'TFT17_Item_RangedTraitEmblemItem', 'TFT17_Item_ResistTankEmblemItem',
        'TFT17_Item_ShieldTankEmblemItem', 'TFT17_Item_SummonTraitEmblemItem'
      )
)
SELECT
    item_name,
    COUNT(*) AS games_played,
    ROUND(AVG(placement), 2) AS avg_placement,
    ROUND(100.0 * SUM(CASE WHEN placement <= 4 THEN 1 ELSE 0 END) / COUNT(*), 1) AS top4_rate
FROM participant_items
GROUP BY item_name
HAVING games_played >= 15
ORDER BY avg_placement ASC;

-- Part 3: correction to Part 1 -- item count relative to the rest of the
-- lobby in the same game, instead of compared across different games of
-- different lengths. Controls for game-length variance across matches;
-- still doesn't fully control for survival time within a single match.
WITH my_games AS (
    SELECT p.participant_id, p.match_id, p.placement,
        (SELECT COUNT(*) FROM units u JOIN unit_items ui ON ui.unit_id = u.unit_id WHERE u.participant_id = p.participant_id) AS my_items
    FROM set17_participants_clean p
    WHERE p.puuid = (SELECT puuid FROM me)
),
lobby_avg AS (
    SELECT mg.participant_id, mg.placement, mg.my_items,
        (SELECT AVG(item_count) FROM (
            SELECT COUNT(ui2.unit_item_id) AS item_count
            FROM participants p2
            JOIN units u2 ON u2.participant_id = p2.participant_id
            JOIN unit_items ui2 ON ui2.unit_id = u2.unit_id
            WHERE p2.match_id = mg.match_id AND p2.participant_id != mg.participant_id
            GROUP BY p2.participant_id
        )) AS lobby_avg_items
    FROM my_games mg
)
SELECT
    CASE
        WHEN my_items - lobby_avg_items < -2 THEN 'well below lobby'
        WHEN my_items - lobby_avg_items < 0 THEN 'slightly below lobby'
        WHEN my_items - lobby_avg_items < 2 THEN 'slightly above lobby'
        ELSE 'well above lobby'
    END AS relative_itemization,
    COUNT(*) AS games,
    ROUND(AVG(placement), 2) AS avg_placement,
    ROUND(100.0 * SUM(CASE WHEN placement <= 4 THEN 1 ELSE 0 END) / COUNT(*), 1) AS top4_rate
FROM lobby_avg
GROUP BY relative_itemization
ORDER BY MIN(my_items - lobby_avg_items);
