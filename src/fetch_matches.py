import json
import os
from pathlib import Path

from dotenv import load_dotenv

from riot_api import get_match, get_match_ids, get_puuid

load_dotenv()

DATA_DIR = Path(__file__).parent.parent / "data" / "raw"
DATA_DIR.mkdir(parents=True, exist_ok=True)


def fetch_all_matches(game_name, tag_line, max_matches=1000):
    puuid = get_puuid(game_name, tag_line)
    print(f"puuid: {puuid}")

    all_ids = []
    start = 0
    page_size = 20
    while len(all_ids) < max_matches:
        batch = get_match_ids(puuid, count=page_size, start=start)
        if not batch:
            break
        all_ids.extend(batch)
        start += page_size

    print(f"found {len(all_ids)} match ids")

    fetched, skipped = 0, 0
    for match_id in all_ids:
        out_path = DATA_DIR / f"{match_id}.json"
        if out_path.exists():
            skipped += 1
            continue
        match = get_match(match_id)
        out_path.write_text(json.dumps(match))
        fetched += 1
        if fetched % 10 == 0:
            print(f"fetched {fetched} matches...")

    print(f"done. fetched {fetched} new matches, skipped {skipped} already cached.")


if __name__ == "__main__":
    fetch_all_matches(
        os.environ["RIOT_GAME_NAME"],
        os.environ["RIOT_TAG_LINE"],
    )
