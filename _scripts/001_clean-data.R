#' ---
#' Clean CLEA and ISO datasets prior to record linkage
#' ---

library(tidyverse)
library(here)
library(glue)

## CLEA -----

load(here(
  '_data', 'raw', 'clea', 'clea_lc_20251015.RData'
))

clea <- clea_lc_20251015 |> 
  filter(yr >= 1945) |> 
  select(release, id, rg, ctr_n, ctr, yr, mn, sub, cst_n) |> 
  unique() |>
  # Correct known data-entry errors in the sub field.
  # These are cases where sub is an invalid or garbled string (not merely a
  # valid subdivision name assigned to the wrong constituency).
  mutate(sub = case_when(
    ctr_n == "Austria"  & sub == "Wine"                      ~ "Wien",
    ctr_n == "Liberia"  & sub == "Rivercress"                ~ "River Cess",
    ctr_n == "Thailand" & sub == "Bankgok"                   ~ "Bangkok",
    ctr_n == "Uganda"   & str_starts(sub, "LYAlliance")      ~ "LYANTONDE",
    ctr_n == "Zimbabwe" & sub == "Masonaland West"           ~ "Mashonaland West",
    TRUE ~ sub
  )) |>
  # Construct constituency name from cst_n only.
  # Exception: when cst_n is purely numeric and sub is a place name (not a number),
  # the constituency name is split across both fields (e.g. Bolivia: "CHUQUISACA - 1").
  mutate(constituency = case_when(
    str_detect(sub, '-9') ~ cst_n,
    str_detect(str_to_upper(cst_n), str_to_upper(sub)) ~ cst_n,
    str_detect(str_trim(cst_n), '^\\d+$') & !str_detect(str_trim(sub), '^-?\\d+$') ~ glue('{sub} - {cst_n}'),
    TRUE ~ cst_n))
    
## ISO codes -----

iso <- read_csv(
  here('_data', 'raw', 'ISO.csv'),
  locale = locale(encoding = "latin1")
) |>
  # ISO provides multiple language variants per subdivision for 58 countries.
  # Keep one row per code, preferring English; fall back to the first available row.
  group_by(ISO3166_2.code) |>
  arrange(desc(Language.code == "en"), .by_group = TRUE) |>
  slice(1) |>
  ungroup()


# save cleaned data to temp/
save(clea, iso, file = here('_data', 'temp', 'cleaned.RData'))
