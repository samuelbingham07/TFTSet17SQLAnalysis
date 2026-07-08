# TFT Set 17 SQL Analysis

A SQL-driven case study of my own ranked Teamfight Tactics (Set 17) match history, pulled from Riot's TFT API into a normalized SQLite database. The goal: apply real SQL analysis to a dataset I have genuine expert context for interpreting, and treat the findings like a PM would — pose a question, run the query, interpret the result, and call out where a correlation isn't actually actionable.

563 ranked games were pulled (Set 17 only, filtered out of 1000 total fetched games that also included leftover Set 16 history). 7 games were further excluded as outliers that don't reflect normal play (see **Data Cleaning** below), leaving **556 games** in the analysis.

## Pipeline

```
src/fetch_matches.py   Riot API -> cached raw match JSON (data/raw/)
src/schema.sql         normalized SQLite schema + analysis views
src/load_db.py         parses cached JSON -> data/tft.db
analysis/*.sql         the actual analysis queries, one file per question
```

Schema: `matches`, `participants`, `units`, `unit_items`, `traits` (five tables), plus two views — `set17_matches`/`set17_participants` (scope everything to Set 17) and `set17_participants_clean` (excludes the outlier games described below). Augment data was part of the original plan but isn't present anywhere in Riot's current match-v1 response, so that analysis was dropped.

## Data Cleaning: Excluding Non-Representative Games

Two intentional playstyles show up in the data and would skew comp/trait performance if left in:

1. **Selling the board to hyper-roll for a 3-star 5-cost**, ending in 2nd/3rd. Signature: abnormally low final unit count (there's a clean gap in the data — games sit at 3-4 units or jump straight to 6+, nothing in between) combined with `gold_left` near 0 and a very late `last_round`.
2. **Conceding once 8th place was locked in**. Signature: `gold_left >= 100` at elimination (occurs exactly once across all 563 games) combined with a level too low for how far the game had progressed.

The exclusion logic (`set17_participants_clean`) requires the low-unit-count *and* a concentrated 5-cost signal together — a full 9-11 unit board running 3 copies of a 5-cost is just a strong legitimate comp, not a reroll gamble, and was correctly left in. **7 of 563 games (1.2%) were excluded.**

## Findings

### 1. Trait Performance

Average placement by active trait (tier_current > 0), min. 10 games played.

| Trait | Games | Avg Placement | Top4% | Win% |
|---|---|---|---|---|
| Morgana | 47 | 3.45 | 70.2 | 17.0 |
| Stargazer Medallion | 17 | 3.53 | 58.8 | 29.4 |
| Graves | 35 | 3.66 | 65.7 | 28.6 |
| Jhin | 104 | 3.67 | 67.3 | 21.2 |
| Fiora | 103 | 3.81 | 66.0 | 19.4 |
| ... | | | | |
| Miss Fortune | 16 | **5.56** | 18.8 | 6.3 |

Morgana, Graves, and Jhin comps are the strongest lines by a clear margin. Miss Fortune is a sharp outlier on the underperforming end — 5.56 avg placement and only 18.8% top-4 across 16 games, well below every other trait. Worth a closer look at *why* (itemization, positioning, or just a weak line in the current meta) before playing it again.

### 2. Economy vs. Placement

Does gold left at game-end/elimination predict placement?

| Gold Left | Games | Avg Placement | Top4% |
|---|---|---|---|
| 0 | 123 | 4.91 | 42.3 |
| 1-10 | 305 | 4.19 | 55.7 |
| 11-20 | 47 | 4.32 | 55.3 |
| 21-30 | 27 | 3.96 | 55.6 |
| 31+ | 54 | 4.52 | 51.9 |

Overall Pearson r = **-0.013** — essentially no linear relationship. But the shape isn't flat, it's a shallow U: both hoarding gold (31+) and hitting exactly 0 correlate with worse results than the 1-30 middle range. Digging into the 0-gold bucket specifically: splitting it by game stage shows the 5 games where gold hit 0 *early* (before round 25) despite a decent level all ended in 8th place (100%, 0% top-4) — a clean "forced all-in that failed" signal. The other 118 late-game 0-gold games are far more mixed (44.1% top-4), and notably **none of my 82 wins ever end with 0 gold left** — winning games keep gold banked. So "0 gold" isn't a single pattern, it's a forced-spend signal that's sometimes a stabilizing comeback and sometimes a death spiral.

### 3. Comp Identification

Grouping games by the exact set of active traits surfaces 8 distinct comps played 8+ times:

| Comp (core traits) | Games | Avg Placement | Top4% | Win% |
|---|---|---|---|---|
| Shen / Assassin / Astronaut / Fateweaver / Timebreaker | 13 | **3.08** | 84.6 | 38.5 |
| Fiora / Tahm Kench / AS / DRX / PsyOps / HP Tank | 10 | 3.30 | 90.0 | 10.0 |
| Blitzcrank / Dark Star / Space Groove / Admin | 8 | 3.75 | 75.0 | 12.5 |
| Rhaast / Dark Star / Space Groove / PsyOps | 11 | 4.09 | 54.5 | 18.2 |
| Vex / Sona / Blitzcrank / Dark Star / Space Groove | 12 | 4.25 | 58.3 | 8.3 |
| Rhaast / Astronaut / Assassin / Dark Star | 12 | 4.33 | 58.3 | 8.3 |
| Rhaast / DRX / Mecha / HP Tank | 12 | 4.50 | 50.0 | 25.0 |
| Fiora / Tahm Kench / DRX / PsyOps / HP Tank | 12 | 4.58 | 58.3 | **0.0** |

The Shen comp is clearly the strongest line (3.08 avg, 38.5% win rate) and worth prioritizing. The bottom comp is an interesting anomaly rather than a straightforwardly bad one: it hits top-4 more than half the time (58.3%) but has **never once converted to a win** in 12 games — a "safe podium, no late-game power" profile, useful for stabilizing a rough lobby but not for closing games out.

*Caveat: this groups by exact trait-set match, so two games that are "the same comp" with one flex-slot trait swapped won't merge — a simplification, not a bug.*

### 4. Performance Trend Over Time

Weekly avg placement across the tracked stretch (Set 17 launch through early July 2026):

| Week | Games | Avg Placement | Top4% |
|---|---|---|---|
| 15 | 35 | **3.63** | 68.6 |
| 16 | 65 | 4.42 | 49.2 |
| 17 | 63 | 4.52 | 49.2 |
| 18-26 | 386 | ~4.4 | ~52 |

Honest read: there's no clean "steady improvement" story here. Week 15 (right after launch) was the strongest stretch by a wide margin, then results settled into a flat plateau around 4.2-4.6 for the following three months with no clear upward trend since. That's a more useful finding than a forced positive narrative — it raises a real follow-up question (was week 15 a strong comp that later got weaker, or just small-sample variance?) rather than answering one.

### 5. Damage Output vs. Placement (and why it's a trap)

| Damage Bucket | Games | Avg Placement | Top4% |
|---|---|---|---|
| <50 | 67 | 7.64 | 0.0 |
| 50-99 | 209 | 5.99 | 11.5 |
| 100-149 | 169 | 3.08 | 92.3 |
| 150-199 | 86 | 1.43 | 100.0 |
| 200+ | 25 | 1.12 | 100.0 |

Pearson r = **-0.916**, by far the strongest correlation in the whole analysis — and the least useful one. `total_damage_to_players` accumulates every round you're still alive, so surviving longer (which *is* placement) mechanically produces more damage dealt, independent of whether the comp itself is actually strong. This is included deliberately as a contrast case: not every strong correlation is a lever you can pull. Trait choice, econ discipline, and comp selection are decisions; damage dealt is closer to a restatement of the outcome.

## Limitations

- Single-player dataset (563 games from one account) — findings describe this player's results with these comps in this meta, not general win rates.
- Augment data unavailable in the current Riot API response; the original plan included an augment-vs-placement analysis that had to be dropped.
- Comp identification uses exact trait-set matching, not fuzzy/clustered matching.
- Damage correlation is included as a methodological example, not a real finding.

## Reproducing

```bash
python3 -m venv venv && source venv/bin/activate
pip install -r requirements.txt
cp .env.example .env   # fill in RIOT_API_KEY, RIOT_GAME_NAME, RIOT_TAG_LINE
python src/fetch_matches.py
python src/load_db.py
sqlite3 data/tft.db < analysis/01_trait_performance.sql
```
