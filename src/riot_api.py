import os
import time

import requests
from dotenv import load_dotenv

load_dotenv()

API_KEY = os.environ["RIOT_API_KEY"]
REGION = os.environ.get("RIOT_REGION", "americas")

# Personal dev keys: 20 requests/sec, 100 requests/2min. Stay comfortably under both.
_MIN_INTERVAL = 1.3
_last_request_time = 0.0


def _get(url, params=None):
    global _last_request_time
    elapsed = time.monotonic() - _last_request_time
    if elapsed < _MIN_INTERVAL:
        time.sleep(_MIN_INTERVAL - elapsed)

    resp = requests.get(url, headers={"X-Riot-Token": API_KEY}, params=params)
    _last_request_time = time.monotonic()

    if resp.status_code == 429:
        retry_after = int(resp.headers.get("Retry-After", 5))
        time.sleep(retry_after + 1)
        return _get(url, params)

    resp.raise_for_status()
    return resp.json()


def get_puuid(game_name, tag_line):
    url = f"https://{REGION}.api.riotgames.com/riot/account/v1/accounts/by-riot-id/{game_name}/{tag_line}"
    return _get(url)["puuid"]


def get_match_ids(puuid, count=20, start=0):
    url = f"https://{REGION}.api.riotgames.com/tft/match/v1/matches/by-puuid/{puuid}/ids"
    return _get(url, params={"count": count, "start": start})


def get_match(match_id):
    url = f"https://{REGION}.api.riotgames.com/tft/match/v1/matches/{match_id}"
    return _get(url)
