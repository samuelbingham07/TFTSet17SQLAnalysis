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
