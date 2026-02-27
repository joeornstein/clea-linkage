# clea-linkage Project Memory

## Project Goal

Link the Constituency-Level Elections Archive (CLEA) with ISO 3166-2 subdivision codes to enable consistent geographic identifiers for electoral analysis (e.g., volatility estimation).

## Directory Structure

```
_data/raw/clea/clea_lc_20251015.RData   # Raw CLEA dataset (33 MB)
_data/raw/ISO.csv                        # ISO 3166-2 subdivision codes (latin1 encoding)
_data/temp/cleaned.RData                 # Cleaned CLEA + ISO data (output of script 001)
_data/output/{country}.RData            # Per-country linked results (output of script 002)
_scripts/001_clean-data.R               # Cleaning script
_scripts/002_link-data.R                # Fuzzy linkage script
```

## Data Schemas

**CLEA** (after cleaning): `release`, `id`, `rg`, `ctr_n`, `ctr`, `yr`, `mn`, `sub`, `cst_n`, `constituency`
- Filtered to `yr >= 1945`
- `constituency` field constructed by combining `sub` and `cst_n` (handles "-9" edge case)

**ISO.csv**: `ctr_n`, `Subdivision.category`, `ISO3166_2.code`, `star`, `Subdivision.name`, `Local.variant`, `Language.code`, `Romanization.system`, `Parent.subdivision`, `Country_code`, `Constituent_code`
- 6,285 records; read with `encoding = "latin1"`
- `constituency` field derived from `Subdivision.name`

**Output per country (`df`)**: linked records with match probabilities and flags
- `flag = 1` if multiple matches; flagged if match probability < 0.2

## Processing Pipeline

1. Run `_scripts/001_clean-data.R` → produces `_data/temp/cleaned.RData`
2. Run `_scripts/002_link-data.R` → produces `_data/output/{country}.RData` per country
   - Uses `fuzzylink()` with `model = "gpt-5.2"`, blocking on `ctr_n`
   - Skips already-processed countries unless `recompute = TRUE`

## Current Status (as of 2026-02-27)

- Script 001 completed (`cleaned.RData` exists)
- Script 002 partially run; completed countries: **Brazil**, **Canada**, **United States**
- Remaining countries not yet linked

## Known Issues / TODOs

- Language code handling for Canada needs attention (TODO comment in script 002, line ~47)

## Required R Packages

`tidyverse`, `fuzzylink`, `here`, `glue`
