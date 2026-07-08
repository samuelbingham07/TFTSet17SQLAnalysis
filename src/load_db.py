import json
import os
import sqlite3
from pathlib import Path

from dotenv import load_dotenv

from riot_api import get_puuid

load_dotenv()

DATA_DIR = Path(__file__).parent.parent / "data" / "raw"
DB_PATH = Path(__file__).parent.parent / "data" / "tft.db"
SCHEMA_PATH = Path(__file__).parent / "schema.sql"


def init_db(conn):
    conn.executescript(SCHEMA_PATH.read_text())


def load_match(conn, match):
    info = match["info"]
    match_id = match["metadata"]["match_id"]

    conn.execute(
        """INSERT OR IGNORE INTO matches
           (match_id, game_datetime, game_length, game_version, set_number, queue_id)
           VALUES (?, ?, ?, ?, ?, ?)""",
        (
            match_id,
            info.get("game_datetime"),
            info.get("game_length"),
            info.get("game_version"),
            info.get("tft_set_number"),
            info.get("queue_id"),
        ),
    )

    for p in info["participants"]:
        cur = conn.execute(
            """INSERT INTO participants
               (match_id, puuid, placement, level, gold_left, last_round,
                players_eliminated, total_damage_to_players, time_eliminated)
               VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)""",
            (
                match_id,
                p.get("puuid"),
                p.get("placement"),
                p.get("level"),
                p.get("gold_left"),
                p.get("last_round"),
                p.get("players_eliminated"),
                p.get("total_damage_to_players"),
                p.get("time_eliminated"),
            ),
        )
        participant_id = cur.lastrowid

        for u in p.get("units", []):
            ucur = conn.execute(
                """INSERT INTO units (participant_id, character_id, tier, rarity, chosen)
                   VALUES (?, ?, ?, ?, ?)""",
                (
                    participant_id,
                    u.get("character_id"),
                    u.get("tier"),
                    u.get("rarity"),
                    1 if u.get("chosen") else 0,
                ),
            )
            unit_id = ucur.lastrowid
            for item_name in u.get("itemNames", []):
                conn.execute(
                    "INSERT INTO unit_items (unit_id, item_name) VALUES (?, ?)",
                    (unit_id, item_name),
                )

        for t in p.get("traits", []):
            conn.execute(
                """INSERT INTO traits (participant_id, name, num_units, style, tier_current)
                   VALUES (?, ?, ?, ?, ?)""",
                (
                    participant_id,
                    t.get("name"),
                    t.get("num_units"),
                    t.get("style"),
                    t.get("tier_current"),
                ),
            )


def main():
    conn = sqlite3.connect(DB_PATH)
    init_db(conn)

    puuid = get_puuid(os.environ["RIOT_GAME_NAME"], os.environ["RIOT_TAG_LINE"])
    conn.execute("INSERT OR REPLACE INTO me (puuid) VALUES (?)", (puuid,))

    files = sorted(DATA_DIR.glob("*.json"))
    print(f"loading {len(files)} matches into {DB_PATH}")

    loaded = 0
    for path in files:
        match = json.loads(path.read_text())
        existing = conn.execute(
            "SELECT 1 FROM matches WHERE match_id = ?",
            (match["metadata"]["match_id"],),
        ).fetchone()
        if existing:
            continue
        load_match(conn, match)
        loaded += 1

    conn.commit()
    conn.close()
    print(f"loaded {loaded} new matches.")


if __name__ == "__main__":
    main()
