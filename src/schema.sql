CREATE TABLE IF NOT EXISTS matches (
    match_id      TEXT PRIMARY KEY,
    game_datetime INTEGER,
    game_length   REAL,
    game_version  TEXT,
    set_number    INTEGER,
    queue_id      INTEGER
);

CREATE TABLE IF NOT EXISTS participants (
    participant_id           INTEGER PRIMARY KEY AUTOINCREMENT,
    match_id                 TEXT REFERENCES matches(match_id),
    puuid                    TEXT,
    placement                INTEGER,
    level                    INTEGER,
    gold_left                INTEGER,
    last_round               INTEGER,
    players_eliminated       INTEGER,
    total_damage_to_players  INTEGER,
    time_eliminated          REAL
);

CREATE TABLE IF NOT EXISTS units (
    unit_id       INTEGER PRIMARY KEY AUTOINCREMENT,
    participant_id INTEGER REFERENCES participants(participant_id),
    character_id  TEXT,
    tier          INTEGER,
    rarity        INTEGER,
    chosen        INTEGER  -- 1 if this was the "chosen" unit, else 0
);

CREATE TABLE IF NOT EXISTS unit_items (
    unit_item_id INTEGER PRIMARY KEY AUTOINCREMENT,
    unit_id      INTEGER REFERENCES units(unit_id),
    item_name    TEXT
);

CREATE TABLE IF NOT EXISTS traits (
    trait_row_id   INTEGER PRIMARY KEY AUTOINCREMENT,
    participant_id INTEGER REFERENCES participants(participant_id),
    name           TEXT,
    num_units      INTEGER,
    style           INTEGER,
    tier_current   INTEGER
);

CREATE INDEX IF NOT EXISTS idx_participants_puuid ON participants(puuid);
CREATE INDEX IF NOT EXISTS idx_units_participant ON units(participant_id);
CREATE INDEX IF NOT EXISTS idx_traits_participant ON traits(participant_id);

-- Holds this player's own puuid so analysis queries can reference `(SELECT puuid FROM me)`
-- instead of a hardcoded literal (puuids are account identifiers and shouldn't be committed).
CREATE TABLE IF NOT EXISTS me (
    puuid TEXT PRIMARY KEY
);

-- Riot's traits array mixes real, player-facing traits with internal engine
-- classification tags (role/stat labels used for backend logic, never shown
-- in the trait bar). Identified by naming convention: every real trait has
-- either a proper name (DRX, Fateweaver, Stargazer_*) or the per-champion
-- <Name>UniqueTrait pattern; these instead are bare stat/role words, and
-- were confirmed as not real by checking against actual in-game trait names.
CREATE TABLE IF NOT EXISTS excluded_trait_tags (name TEXT PRIMARY KEY);
INSERT OR IGNORE INTO excluded_trait_tags (name) VALUES
    ('TFT17_ManaTrait'),
    ('TFT17_APTrait'),
    ('TFT17_ASTrait'),
    ('TFT17_AssassinTrait'),
    ('TFT17_MeleeTrait'),
    ('TFT17_RangedTrait'),
    ('TFT17_HPTank'),
    ('TFT17_ShieldTank'),
    ('TFT17_ResistTank'),
    ('TFT17_SummonTrait'),
    ('TFT17_FlexTrait');

CREATE VIEW IF NOT EXISTS real_traits AS
    SELECT * FROM traits WHERE name NOT IN (SELECT name FROM excluded_trait_tags);

-- Analysis is scoped to Set 17; these views keep that filter out of every query.
CREATE VIEW IF NOT EXISTS set17_matches AS
    SELECT * FROM matches WHERE set_number = 17;

CREATE VIEW IF NOT EXISTS set17_participants AS
    SELECT p.* FROM participants p
    JOIN set17_matches m ON p.match_id = m.match_id;

-- Excludes games that don't reflect normal play, so comp/trait performance
-- isn't skewed by non-representative outcomes:
--   * unit_count <= 4: final board was gutted to hyper-roll for a 3-star 5-cost
--     (natural gap in the data: 5 games at 3-4 units, zero at 5, then 6+ normally)
--   * unit_count <= 6 AND 3+ copies of one 5-cost (rarity=6) champion: same hyper-roll
--     pattern caught on a slightly less-gutted board. Requires the low unit_count too,
--     since 3+ copies of a 5-cost on a full 9-11 unit board is just a strong legitimate
--     comp, not a reroll gamble (seen in this data: a 9-unit board running 3x Bard + 3x Vex).
--   * gold_left >= 100: game was conceded/abandoned rather than played out
--     (occurs exactly once across all 563 Set 17 games)
CREATE VIEW IF NOT EXISTS set17_participants_clean AS
    SELECT p.* FROM set17_participants p
    WHERE (SELECT COUNT(*) FROM units u WHERE u.participant_id = p.participant_id) > 4
      AND p.gold_left < 100
      AND (
        (SELECT COUNT(*) FROM units u WHERE u.participant_id = p.participant_id) > 6
        OR COALESCE((
            SELECT MAX(cnt) FROM (
                SELECT COUNT(*) AS cnt FROM units u2
                WHERE u2.participant_id = p.participant_id AND u2.rarity = 6
                GROUP BY u2.character_id
            )
        ), 0) < 3
      );
