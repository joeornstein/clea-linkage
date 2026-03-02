#' ---
#' Stage 1: Assign ISO 3166-2 codes via string matching on the sub field
#' ---
#'
#' Normalises CLEA sub values and ISO Subdivision.names, then left-joins to
#' assign ISO codes directly — without LLM involvement — to any row whose sub
#' field resolves to an unambiguous subdivision name.
#'
#' Rows where sub is absent, a sentinel value, or does not match any ISO name
#' are written to stage2_input and passed on to 003_fuzzy-link.R.
#'
#' Output: _data/temp/stage1.RData  (stage1_matched, stage2_input)

library(tidyverse)
library(here)
library(glue)

load(here('_data', 'temp', 'cleaned.RData'))


## Normalisation helper -------------------------------------------------------
## Strips diacritics, lowercases, collapses non-alphanumeric characters to a
## single space. Applied to both CLEA sub and ISO Subdivision.name to
## accommodate differences in case, punctuation, and accents.

normalise <- function(x) {
  x |>
    stringi::stri_trans_general("Latin-ASCII") |>
    str_to_lower() |>
    str_replace_all("[^a-z0-9]", " ") |>
    str_squish()
}


## Build ISO lookup keyed on normalised Subdivision.name ----------------------

iso_lookup <- iso |>
  mutate(sub_norm = normalise(Subdivision.name)) |>
  select(
    ctr_n, sub_norm,
    Subdivision.category, ISO3166_2.code, star, Subdivision.name,
    Local.variant, Language.code, Romanization.system,
    Parent.subdivision, Country_code, Constituent_code
  )


## String match ---------------------------------------------------------------

stage1_all <- clea |>
  mutate(sub_norm = normalise(sub)) |>
  left_join(iso_lookup, by = c("ctr_n", "sub_norm")) |>
  select(-sub_norm) |>
  mutate(
    A                 = sub,
    B                 = Subdivision.name,
    match_probability = if_else(!is.na(ISO3166_2.code), 1, NA_real_),
    flag              = as.integer(is.na(ISO3166_2.code))
  )

stage1_matched <- stage1_all |> filter(!is.na(ISO3166_2.code))
stage2_input   <- stage1_all |> filter( is.na(ISO3166_2.code))

message(glue(
  "Stage 1: {nrow(stage1_matched)} rows matched ",
  "({n_distinct(stage1_matched$ctr_n)} countries)\n",
  "Stage 2: {nrow(stage2_input)} rows to fuzzy-link ",
  "({n_distinct(stage2_input$ctr_n)} countries)"
))


## Save -----------------------------------------------------------------------

save(stage1_matched, stage2_input,
     file = here('_data', 'temp', 'stage1.RData'))
