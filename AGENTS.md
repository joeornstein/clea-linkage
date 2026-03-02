
# clea-linkage Project Memory

## Project Goal

Link the Constituency-Level Elections Archive (CLEA) with ISO 3166-2 subdivision codes to enable consistent geographic identifiers for electoral analysis (e.g., volatility estimation).

## Directory Structure

```
_data/raw/clea/clea_lc_20251015.RData   # Raw CLEA dataset (33 MB)
_data/raw/ISO.csv                        # ISO 3166-2 subdivision codes (latin1 encoding)
_data/temp/cleaned.RData                 # Cleaned CLEA + ISO data (output of script 001)
_data/temp/stage1.RData                 # Stage 1 string-match results (output of script 002)
_data/temp/validated.RData              # Combined + labelled output across all countries (output of script 004)
_data/output/{country}.RData            # Per-country linked results (output of script 003)
_scripts/001_clean-data.R               # Cleaning script
_scripts/002_string-match.R             # Stage 1: ISO code assignment via sub field string matching
_scripts/003_fuzzy-link.R               # Stage 2: LLM-assisted fuzzy linkage for unmatched rows
_scripts/004_validate.R                 # Post-merge validation and flagged-row labelling
_reports/clea-data-quality.qmd          # Quarto report: all identified CLEA data entry problems
_reports/clea-data-quality.html         # Rendered HTML output of the above
```

## Data Schemas

**CLEA** (after cleaning): `release`, `id`, `rg`, `ctr_n`, `ctr`, `yr`, `mn`, `sub`, `cst_n`, `constituency`
- Filtered to `yr >= 1945`
- `constituency` field is `cst_n` only, except Bolivia-style cases where `cst_n` is purely
  numeric and `sub` is a place name (detected via `str_detect(str_trim(cst_n), '^\\d+$') &
  !str_detect(str_trim(sub), '^-?\\d+$')`), in which case `constituency = glue('{sub} - {cst_n}')`

**ISO.csv**: `ctr_n`, `Subdivision.category`, `ISO3166_2.code`, `star`, `Subdivision.name`, `Local.variant`, `Language.code`, `Romanization.system`, `Parent.subdivision`, `Country_code`, `Constituent_code`
- 6,285 records; read with `encoding = "latin1"`
- `constituency` field derived from `Subdivision.name`
- ISO provides multiple language variants per subdivision for 58 countries; script 001 deduplicates
  by `ISO3166_2.code`, preferring `Language.code == "en"`, falling back to the first available row
- **Known encoding issue**: 582 entries across 46 countries have literal `?` characters replacing
  diacritics (e.g. "Bih?r", "Karn?taka", "Gujar?t"). This is unrecoverable via re-encoding —
  the characters are lost in the source file. Affected entries fail Stage 1 string matching and
  fall through to fuzzylink. Countries most affected: Azerbaijan (54), Viet Nam (43), Slovenia (31),
  Czech Republic (30), Afghanistan (28), Iran (28), Lithuania (28), India (19).

**Output per country (`df`)**: linked records combining Stage 1 and Stage 2 results
- Stage 1 rows: `A = sub`, `B = Subdivision.name`, `match_probability = 1`, `flag = 0`
- Stage 2 rows: `A = constituency` (cst_n), `B = Subdivision.name`, `match_probability` from
  fuzzylink, `flag = 1` if multiple matches, no match, or match_probability < 0.2
- fuzzylink may produce `ctr_n.x`/`ctr_n.y`; script 003 normalises to `ctr_n`

**validated** (`_data/temp/validated.RData`): all per-country outputs combined, with `label` and `notes` columns added to flagged rows
- Labels: `clea_sub_error`, `clea_name_abbrev`, `clea_data_error`, `historical_territory`, `multi_territory`, `low_confidence`
- Unlabelled flagged rows (`label = NA`) indicate countries not yet reviewed in `case_labels`

## Processing Pipeline

1. Run `_scripts/001_clean-data.R` → produces `_data/temp/cleaned.RData`
   - Corrects known `sub` field typos (Austria "Wine"→"Wien", Thailand "Bankgok"→"Bangkok",
     Zimbabwe "Masonaland West"→"Mashonaland West", Liberia "Rivercress"→"River Cess",
     Uganda 2021 KABULA concatenation error)
   - `constituency` field is `cst_n` only (not sub+cst_n), except Bolivia-style cases where
     `cst_n` is purely numeric and `sub` is a place name
2. Run `_scripts/002_string-match.R` → produces `_data/temp/stage1.RData`
   - Normalises CLEA `sub` and ISO `Subdivision.name` (diacritics stripped, lowercased)
   - Pass 1: left-joins on `(ctr_n, sub_norm)` for exact normalised matches
   - Pass 2: contains-match for unmatched rows — accepts if sub_norm is a substring of
     an ISO name (or vice versa) and the match is unique within the country
   - Saves `stage1_matched` and `stage2_input`
3. Run `_scripts/003_fuzzy-link.R` → produces `_data/output/{country}.RData` per country
   - Loads `cleaned.RData` and `stage1.RData`
   - Defines `link_countries(countries, overwrite = FALSE)`
   - Call `link_countries(unique(clea$ctr_n))` to process all; skips existing output unless `overwrite = TRUE`
   - Uses `fuzzylink()` with `model = "gpt-5.2"` for rows in `stage2_input`
   - Combines Stage 1 matches with fuzzylink output and saves per country
4. Run `_scripts/004_validate.R` → produces `_data/temp/validated.RData`
   - Loads `cleaned.RData` (for `iso` object used in ISO field correction)
   - Loads and combines all per-country output files
   - Joins `case_labels` lookup table (keyed on `ctr_n` + `str_to_lower(cst_n)`) onto all rows
   - Corrects ISO fields for any row where `case_labels` supplies a `true_iso_code` — this
     overwrites fuzzylink's match even when `B` is non-missing (e.g. `clea_sub_error` rows)
   - Prints a summary and lists any unlabeled flagged rows
   - Extend `case_labels` as new countries are processed

## Current Status (as of 2026-03-02)

- Pipeline redesigned: scripts renumbered 001–004; Stage 1 string-match split from fuzzy-link stage
- Script 001 regenerated: sub-field typo corrections added; `constituency` no longer embeds `sub`
- Script 002 (string-match) written; Stage 1 resolves ~86k rows across 87 countries
  (Pass 1 exact: ~67k; Pass 2 contains-match: ~19k additional)
- Script 003 (fuzzy-link) written; not yet re-run under new design
- Script 004 (validate) updated from former 003; not yet re-run under new design
- Existing per-country output files (Brazil, US, Canada, Australia, Germany) are stale — produced under the old pipeline and should be regenerated
- Data quality report updated (2026-03-02): added §Sub field typos documenting 5 new corrections

## Stage 2 Composition (as of last 002 run)

- **85,970 rows matched in Stage 1** across 87 countries
- **58,316 rows in Stage 2** across 183 countries
  - 62% sentinel subs (`-9`, `-990` etc.) — no subdivision recorded in CLEA
  - 38% unmatched sub values (naming mismatches, abbreviations, different geographic levels)
- **7 countries fully resolved by Stage 1** (no fuzzylink needed):
  Canada, Eswatini, Gabon, Micronesia, Togo, United States, Zimbabwe
- **Largest Stage 2 countries**: Japan (4,431 rows — uses regional blocks, not ISO prefectures),
  India (4,267 — ISO encoding issues + historical state names), UK (4,101 — ambiguous region
  strings), New Zealand/Greece/Bangladesh/Turkey/Sri Lanka (1,000–2,000 each — all sentinels)
- Japan uses 8 regional blocks (Kinki, Kyushu, Tokai, etc.) in `sub`; ISO codes at prefecture
  level — no string-match path exists, fuzzylink required
- Italy is 99% sentinel subs; not addressable via Stage 1 extension

## Known Data Quality Issues

### Sub field typos (corrected in script 001)

| Country | Erroneous `sub` | Correct value | Notes |
|---|---|---|---|
| Austria | `Wine` | `Wien` | Affects all Wien constituencies across all election years |
| Liberia | `Rivercress` | `River Cess` | ISO LR-RI is "River Cess" |
| Thailand | `Bankgok` | `Bangkok` | Typo; "Bangkok" also appears correctly in other years |
| Uganda | `LYAlliance for National Transformation` | `LYANTONDE` | Party name concatenated into sub field; KABULA constituency, 2021 only |
| Zimbabwe | `Masonaland West` | `Mashonaland West` | Missing "h"; ISO ZW-MW is "Mashonaland West" |

### Sub field errors — wrong province/region (corrected in script 004 via `case_labels`)

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
| Australia | 23 named divisions (e.g. barker, boothby, jagajaga, solomon…) | `low_confidence` | Federal division names have no textual similarity to state names; sub field corroborates match |
| Australia | `cowan`, `swan` | `low_confidence` | No match found; sub=WA determines AU-WA |
| Australia | `darwin` | `low_confidence` | Division of Darwin was a Tasmanian seat (named after Charles Darwin, not the NT city); sub=tasmania determines AU-TAS |
| Germany | ~53 constituencies | `clea_sub_error` | Systematic CLEA sub errors for East German Wahlkreise: Thüringen constituencies filed under Sachsen; MV constituencies filed under Brandenburg; Sachsen constituencies filed under Sachsen-Anhalt; etc. **Confined to 2002 and 2005 only** (94 rows); all other election years have correct sub values. Pattern is a 2-way swap (Brandenburg↔MV) plus a 3-way cyclic rotation (actual Sachsen→coded Sachsen-Anhalt→coded Thüringen→coded Sachsen). Six constituencies (Chemnitz, Börde, Burgenland, Harz, Mansfelder Land, Leipziger-Land–Muldentalkreis) were miscoded with high confidence and did not trigger `flag=1`; corrected via `true_iso_code`. |
| Germany | ~36 constituencies | `low_confidence` | Bundestag Wahlkreis names (numbered, district compound names) and party-list seats have no textual similarity to state names; matches corroborated by sub field |
| Germany | `münchen-süd` | `clea_sub_error` | sub field contains constituency name itself (not a valid state); Wahlkreis München-Süd is in Bayern (DE-BY). Only 1976 is a true sub error; all other years have sub=Bayern (correct) but label applied consistently. |

## Required R Packages

`tidyverse`, `fuzzylink`, `here`, `glue`, `stringi`, `knitr` (report rendering)
