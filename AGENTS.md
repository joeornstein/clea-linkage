
# clea-linkage Project Memory

## Project Goal

Link the Constituency-Level Elections Archive (CLEA) with ISO 3166-2 subdivision codes to enable consistent geographic identifiers for electoral analysis (e.g., volatility estimation).

## Directory Structure

```
_data/raw/clea/clea_lc_20251015.RData   # Raw CLEA dataset (33 MB)
_data/raw/ISO.csv                        # ISO 3166-2 subdivision codes (latin1 encoding)
_data/temp/cleaned.RData                 # Cleaned CLEA + ISO data (output of script 001)
_data/temp/validated.RData              # Combined + labelled output across all countries (output of script 003)
_data/output/{country}.RData            # Per-country linked results (output of script 002)
_scripts/001_clean-data.R               # Cleaning script
_scripts/002_link-data.R                # Fuzzy linkage script
_scripts/003_validate.R                 # Post-merge validation and flagged-row labelling
```

## Data Schemas

**CLEA** (after cleaning): `release`, `id`, `rg`, `ctr_n`, `ctr`, `yr`, `mn`, `sub`, `cst_n`, `constituency`
- Filtered to `yr >= 1945`
- `constituency` field constructed by combining `sub` and `cst_n` (handles "-9" edge case)

**ISO.csv**: `ctr_n`, `Subdivision.category`, `ISO3166_2.code`, `star`, `Subdivision.name`, `Local.variant`, `Language.code`, `Romanization.system`, `Parent.subdivision`, `Country_code`, `Constituent_code`
- 6,285 records; read with `encoding = "latin1"`
- `constituency` field derived from `Subdivision.name`
- ISO provides multiple language variants per subdivision for 58 countries; script 001 deduplicates by `ISO3166_2.code`, preferring `Language.code == "en"`, falling back to the first available row

**Output per country (`df`)**: linked records with match probabilities and flags
- `flag = 1` if multiple matches, no match (`B` is NA), or match probability < 0.2
- Note: countries processed before the ISO deduplication fix (pre-2026-02-27) may have `ctr_n` as a plain column; Canada (processed after the fix) has `ctr_n.x`/`ctr_n.y` — script 003 normalises this

**validated** (`_data/temp/validated.RData`): all per-country outputs combined, with `label` and `notes` columns added to flagged rows
- Labels: `clea_sub_error`, `clea_name_abbrev`, `clea_data_error`, `historical_territory`, `multi_territory`, `low_confidence`
- Unlabelled flagged rows (`label = NA`) indicate countries not yet reviewed in `case_labels`

## Processing Pipeline

1. Run `_scripts/001_clean-data.R` → produces `_data/temp/cleaned.RData`
2. Run `_scripts/002_link-data.R` → produces `_data/output/{country}.RData` per country
   - Defines `link_countries(countries, overwrite = FALSE)`
   - Call `link_countries(unique(clea$ctr_n))` to process all; skips existing output unless `overwrite = TRUE`
   - Uses `fuzzylink()` with `model = "gpt-5.2"`
3. Run `_scripts/003_validate.R` → produces `_data/temp/validated.RData`
   - Loads `cleaned.RData` (for `iso` object used in ISO field correction)
   - Loads and combines all per-country output files
   - Joins `case_labels` lookup table (keyed on `ctr_n` + `str_to_lower(cst_n)`) onto all rows
   - Corrects ISO fields for any row where `case_labels` supplies a `true_iso_code` — this
     overwrites fuzzylink's match even when `B` is non-missing (e.g. `clea_sub_error` rows)
   - Prints a summary and lists any unlabeled flagged rows
   - Extend `case_labels` as new countries are processed

## Current Status (as of 2026-02-28)

- Script 001 completed (`cleaned.RData` exists, regenerated with ISO deduplication fix)
- Script 002 partially run; completed countries: **Brazil**, **United States**, **Canada**, **Australia**, **Germany**
- Script 003 run; Brazil, United States, and Canada are fully labelled; Australia (203 flagged rows) and Germany (132 flagged rows) not yet reviewed in `case_labels`

## Known Data Quality Issues

| Country | `cst_n` (lower) | Label | Notes |
|---|---|---|---|
| Canada | `sherwood park--fort saskatchewan` | `clea_sub_error` | sub=Saskatchewan; constituency is in Alberta |
| Canada | `battle river--crowfoot` | `clea_sub_error` | sub=British Columbia; constituency is in Alberta |
| Canada | `charleswood--st. james--assiniboia--headingley` | `clea_sub_error` | sub=British Columbia; constituency is in Manitoba |
| Canada | `west nova` | `clea_sub_error` | sub=Ontario; constituency is in Nova Scotia |
| Canada | `nunavut` | `multi_territory` | Nunavut was part of NWT before 1999 |
| Canada | `yukon--mackenzie river` | `multi_territory` | 1949 riding spanning Yukon and Mackenzie district |
| Canada | `muskoka--ontario` | `low_confidence` | Province name embedded in constituency name may have confused the model |
| Brazil | `ceará`, `r, g, do norte`, `r, g, do sul`, `m, g, do sul` | `clea_name_abbrev` | Abbreviated state names; likely map to BR-CE, BR-RN, BR-RS, BR-MS respectively |
| Brazil | `rio branco`, `t, rio branco (rr)` | `historical_territory` | Territory of Rio Branco (now Roraima, BR-RR) |
| Brazil | `guaporé`, `t, guaporé (ro)` | `historical_territory` | Territory of Guaporé (now Rondônia, BR-RO) |
| Brazil | `guanabara/dto federal`, `guanabara` | `historical_territory` | Guanabara state (1960–1975), merged into Rio de Janeiro |
| United States | `califronia 40` | `clea_data_error` | Typo: "Califronia" → "California" |
| United States | `georigia 10` | `clea_data_error` | Typo: "Georigia" → "Georgia" |

## Required R Packages

`tidyverse`, `fuzzylink`, `here`, `glue`
