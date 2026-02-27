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
  # create cleaned version of consituency name,
  # for edge cases (e.g. Bolivia) where 
  # name is split between sub and cst_n fields
  mutate(constituency = case_when(
    str_detect(sub, '-9') ~ cst_n, # no subdivision
    str_detect(str_to_upper(cst_n), str_to_upper(sub)) ~ cst_n, # subdivision name contained in cst_n
    TRUE ~ glue('{sub} - {cst_n}')))
    
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
  ungroup() |>
  mutate(constituency = Subdivision.name)


# save cleaned data to temp/
save(clea, iso, file = here('_data', 'temp', 'cleaned.RData'))
