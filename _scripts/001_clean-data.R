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
  mutate(constituency = Subdivision.name)


# save cleaned data to temp/
save(clea, iso, file = here('_data', 'temp', 'cleaned.RData'))
