# DHW Agile price coverage fix — 28 October 2026

## Incident
The scheduled `com.richard.homely` launch agent pointed to an obsolete script path under `scripts/Octopus/homely`, resulting in `No such file or directory`. The installed LaunchAgent was replaced with the repository configuration, which invokes `run-homely-scheduled.sh` from `scripts/Homely`. The previous LaunchAgent was backed up locally.

The manual `--today` DHW run then failed with `Incomplete Agile price coverage for 2026-10-28; Homely schedule unchanged`. The Octopus API returned HTTP 200 with 46 consecutive half-hour prices, ending at 23:00 Europe/London, rather than the expected 48.

## Fix
`fetch_agile_prices()` now accepts `allow_trailing_gap`, passed only for `--today`. `validate_agile_day()` still rejects gaps, duplicates, overlaps, invalid half-hour lengths, and prices beyond the requested day. For `--today` alone, it accepts a contiguous prefix of the local day ending before midnight, logs a warning, and optimises using only the published slots. The normal next-day workflow retains strict full-day validation.

## Validation
- `python -m py_compile homely.py` passed.
- `git diff --check` passed.
- A `--all-profiles --today --dry-run` test succeeded for GrannyBarn, selecting 11:00–12:00 Wednesday (two consecutive half-hour slots) using solar-weighted prices.
- A live `--today` invocation reached `Sending updated hot-water schedule to Homely...`; its final API acknowledgement was not captured. The operator subsequently confirmed the issue fixed.

## Operational notes
- The daily launch agent runs at 23:00; its wrapper retries hourly when tomorrow's Agile prices have not been published.
- The partial-day exception is **not** enabled for the scheduled tomorrow run.
- A manual today run modifies the recurring weekday timetable, not just a one-off date. Check the resulting Homely schedule when changing it.
- Do not commit `homely.env`, API credentials, log files or local backups.
