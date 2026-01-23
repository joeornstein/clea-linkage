#' ---
#' Clean CLEA and ISO datasets prior to record linkage
#' ---

library(tidyverse)
library(here)

## CLEA -----

load(here(
  '_data', 'raw', 'clea', 'clea_lc_20251015.RData'
))

clea <- clea_lc_20251015 |> 
  filter(yr >= 1945) |> 
  select(release, id, rg, ctr_n, ctr, yr, mn, sub, cst_n, cst) |> 
  unique() |> 
  mutate()

# TODO: clean cst_n so that it can handle odd edge cases like Bolivia, where the name is split between two 

## ISO codes -----

iso <- read_csv(
  here('_data', 'raw', 'ISO.csv'),
  locale = locale(encoding = "latin1")
) |> 
  rename(cst_n = Subdivision.name)


# save cleaned data to temp/
save(clea, iso, file = here('_data', 'temp', 'cleaned.RData'))