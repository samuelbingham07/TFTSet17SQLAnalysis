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

## Data Quality: Traits That Weren't Traits

Two passes here, not one. First pass: the raw `traits` array Riot's API returns mixes real, player-facing traits with internal engine classification tags — role/stat labels used for backend logic that never show up in the trait bar. Caught by naming convention (bare stat word vs. a real name) and confirmed against real in-game trait names: `ManaTrait`, `APTrait`, `ASTrait`, `AssassinTrait`, `MeleeTrait`, `RangedTrait`, `HPTank`, `ShieldTank`, `ResistTank`, `SummonTrait`, `FlexTrait` — eleven names, all excluded.

Second pass, prompted by more names not being recognized (`DRX`, `Admin`, `Stargazer Wolf` again): it turns out Riot's raw API identifiers frequently don't match the real in-game display name at all. Cross-referencing external trait databases (tactics.tools, blitz.gg) surfaced two distinct problems:

1. **Wrong labels on my part.** The champion-linked "unique" traits display under completely different names than the champion itself: Morgana → **Dark Lady**, Jhin → **Eradicator**, Fiora → **Divine Duelist**, Rhaast → **Redeemer**, Shen → **Bulwark**, Sona → **Commander**, Vex → **Doomer**, Blitzcrank → **Party Animal**, Tahm Kench → **Oracle**, Graves → **Factory New**, Miss Fortune → **Gun Goddess**. `Astronaut` isn't a champion reference at all — the real trait is **Meeple**. `Admin` is real too, as **Arbiter**.
2. **Genuinely fake.** `DRX` and `Stargazer_Wolf`/`Stargazer_Shield` don't exist in Set 17 at all, confirmed absent across three independent sources. The real Stargazer constellation set is Serpent, Huntress, Mountain, Altar, Medallion, Fountain, Boar — Wolf and Shield were never among them. These three are now excluded via `real_traits` the same way as the eleven engine tags; everything below uses the corrected names.

## Findings

### 1. Trait Performance

Average placement by active trait (tier_current > 0), min. 10 games played, after excluding all 14 non-real names above. Champion-linked traits are shown with the champion in parentheses.

| Trait | Games | Avg Placement | Top4% | Win% |
|---|---|---|---|---|
| Dark Lady (Morgana) | 47 | 3.45 | 70.2 | 17.0 |
| Stargazer (Medallion) | 17 | 3.53 | 58.8 | 29.4 |
| Factory New (Graves) | 35 | 3.66 | 65.7 | 28.6 |
| Eradicator (Jhin) | 104 | 3.67 | 67.3 | 21.2 |
| Divine Duelist (Fiora) | 103 | 3.81 | 66.0 | 19.4 |
| ... | | | | |
| Gun Goddess (Miss Fortune) | 16 | **5.56** | 18.8 | 6.3 |

Dark Lady, Factory New, and Eradicator (Morgana, Graves, and Jhin's traits) are the strongest lines by a clear margin. Gun Goddess is a sharp outlier on the underperforming end — 5.56 avg placement and only 18.8% top-4 across 16 games, well below every other trait. Worth a closer look at *why* (itemization, positioning, or just a weak line in the current meta) before playing it again.

### 2. Economy vs. Placement

Does gold left at game-end/elimination predict placement? Sub-10 gold is grouped as one bucket rather than splitting out exactly-zero — both represent the same underlying decision (capping out a board and spending down, knowing elimination might be close), so the meaningful split is low-gold vs. banked-gold, and early vs. late.

| Gold Left | Games | Avg Placement | Top4% |
|---|---|---|---|
| <10 | 423 | 4.39 | 52.2 |
| 10-19 | 45 | 4.49 | 51.1 |
| 20-29 | 31 | 3.96 | 54.8 |
| 30+ | 57 | 4.49 | 52.6 |

Overall Pearson r = **-0.013** — essentially no linear relationship, and the bucketed view is fairly flat too (everything within half a placement of everything else, aside from a 20-29 bucket that's only 31 games and could be noise). The real signal shows up when the low-gold bucket is split by game stage: the 18 times I hit under 10 gold *before* round 25, despite a reasonable level, average 7.83 placement with **zero top-4 finishes** (15 eighths, 3 sevenths) — a clean "capped out early and died anyway" pattern. The other 405 low-gold games, happening at round 25+, look completely different: 4.23 avg, 54.6% top-4 — roughly average or better. And the detail that actually surprised me: **60 of my 82 wins end with under 10 gold left** — a won board doesn't need banked economy, so of course a lot of the best games end with an empty bank. Low gold isn't good or bad on its own; early it's a death spiral, late it's often just what winning looks like.

### 3. Comp Identification

Grouping games by the exact set of active traits (with all 14 non-real names out and everything relabeled) surfaces 10 distinct comps played 8+ times:

| Comp (core traits) | Games | Avg Placement | Top4% | Win% |
|---|---|---|---|---|
| Meeple / Fateweaver / Bulwark / Timebreaker | 14 | **3.07** | 85.7 | 35.7 |
| Arbiter / Party Animal / Dark Star / Space Groove | 10 | 3.70 | 80.0 | 10.0 |
| Divine Duelist / Psionic / Oracle | 22 | 4.00 | 72.7 | 4.5 |
| Dark Star / Psionic / Redeemer / Space Groove | 11 | 4.09 | 54.5 | 18.2 |
| Meeple / Dark Star / Redeemer / Space Groove | 13 | 4.23 | 61.5 | 7.7 |
| Party Animal / Dark Star / Commander / Space Groove / Doomer | 12 | 4.25 | 58.3 | 8.3 |
| Mecha / Redeemer | 12 | 4.50 | 50.0 | 25.0 |
| Fateweaver / Stargazer Medallion / Timebreaker | 8 | 5.00 | 25.0 | 12.5 |
| Meeple / Fateweaver / Timebreaker | 13 | **5.69** | 15.4 | 7.7 |
| Meeple (alone) | 8 | **6.88** | 0.0 | 0.0 |

The best line is Meeple/Fateweaver/Bulwark/Timebreaker (3.07 avg, 85.7% top-4, 35.7% win). The bottom two rows isolate one trait at a time and are the standout finding: drop Bulwark and the same core (Meeple/Fateweaver/Timebreaker) falls to 5.69 avg, 15.4% top-4, 7.7% win across 13 games; drop Fateweaver and Timebreaker too and it's just Meeple alone — 8 games, 6.88 avg, zero top-4s, zero wins. Placement gets worse in a straight line as pieces of the comp are removed. I hadn't clocked how load-bearing Bulwark specifically was until DRX stopped contaminating the comp signature and let these variants separate into their own rows. Separately, Divine Duelist/Psionic/Oracle is my most-played comp on this list (22 games) and hits top-4 72.7% of the time, but converts to a win only 4.5% of the time — a comp with a ceiling, good for stabilizing a rough lobby but not for closing games out.

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

### 6. Item Performance

Total items equipped across the whole final board vs. placement:

| Items on Board | Games | Avg Placement |
|---|---|---|
| <10 | 71 | 6.38 |
| 10-12 | 186 | 5.13 |
| 13-15 | 192 | 3.73 |
| 16-18 | 86 | 2.98 |
| 19+ | 21 | 2.67 |

Same trap as damage: more items on board is a proxy for more time alive, and more time alive is placement by definition — not treated as a real lever for the same reason. The per-item breakdown (min. 15 games) is more useful. Top: `Ornn Infinity Force` (16 games, 3.06 avg, 81.3% top-4) — a forged artifact item, small sample but a real standout. Bottom, and unexpected: **four of the worst-performing items are emblems** — Psionic (5.73 avg, 20% top-4, the single worst item in the dataset), Favored (4.60), Meeple/Astronaut (4.74), Dark Star (4.88). I don't think the emblem itself is causing the bad placement — an emblem gets slammed when a comp is already missing a natural holder of that trait, which is a patch, not a plan. The bad result more likely reflects the compromised board state that made the emblem necessary in the first place, not the item.

A correction to the tautology point above: raw item count is only a proxy for time-alive when comparing across *different* games, which run wildly different lengths. A fairer cut is item count against the average of the other seven players in the same lobby, which controls for how fast or slow that specific game ran.

| Relative Itemization | Games | Avg Placement | Top4% |
|---|---|---|---|
| Well below lobby | 105 | 6.43 | 14.3 |
| Slightly below lobby | 124 | 5.17 | 36.3 |
| Slightly above lobby | 138 | 3.91 | 60.9 |
| Well above lobby | 189 | 3.07 | 77.8 |

Pearson r = **-0.541** (n=556) — weaker than the damage and raw item-count correlations, and for good reason: this version isn't just restating game length. Having comparatively better itemization than the seven other players actually in that lobby tracks placement more honestly than comparing across games of totally different lengths. Still not fully clean — whoever places first in a given lobby also gets more time in that same game to itemize than whoever gets eliminated in round 10 — but it's a real signal, not just the tautology above wearing a different label.

### 7. Session Length and Tilt

Grouped games into sessions using a window function: any gap of 45+ minutes between consecutive games starts a new session (a game runs ~35-40 min, and the gap distribution has a clean break there). 220 sessions total, averaging 2.53 games each, longest run 15 games.

| Position in Session | Games | Avg Placement | Top4% |
|---|---|---|---|
| 1st game | 220 | 4.55 | 49.5 |
| 2nd game | 119 | 4.11 | 56.3 |
| 3rd game | 78 | 4.55 | 46.2 |
| 4th-5th game | 83 | 4.52 | 54.2 |
| 6th-8th game | 42 | 4.05 | 59.5 |
| 9th+ game | 14 | 3.29 | 64.3 |

No tilt story here — placement doesn't trend worse the longer a session runs (the long tail, 9th+ game, is actually the best bucket, though only 14 games). The pattern that does hold up: **the first game of a session (4.55 avg) is consistently worse than the second (4.11 avg)**, across a much larger sample (220 vs. 119). Reads more like a warm-up effect than a tilt effect.

## Limitations

- Single-player dataset (563 games from one account) — findings describe this player's results with these comps in this meta, not general win rates.
- Augment data unavailable in the current Riot API response; the original plan included an augment-vs-placement analysis that had to be dropped.
- Comp identification uses exact trait-set matching, not fuzzy/clustered matching.
- Damage and item-count correlations are included as methodological examples, not real findings.

## Reproducing

```bash
python3 -m venv venv && source venv/bin/activate
pip install -r requirements.txt
cp .env.example .env   # fill in RIOT_API_KEY, RIOT_GAME_NAME, RIOT_TAG_LINE
python src/fetch_matches.py
python src/load_db.py
sqlite3 data/tft.db < analysis/01_trait_performance.sql
```
