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


## Pass 1: Exact normalised match ---------------------------------------------
## Join on (ctr_n, sub_norm). Resolves the majority of rows.

stage1_exact <- clea |>
  mutate(sub_norm = normalise(sub)) |>
  left_join(iso_lookup, by = c("ctr_n", "sub_norm")) |>
  select(-sub_norm)

exact_matched  <- stage1_exact |> filter(!is.na(ISO3166_2.code))
exact_unmatched <- stage1_exact |> filter( is.na(ISO3166_2.code))

message(glue("Pass 1 (exact):    {nrow(exact_matched)} rows matched"))


## Pass 2: Contains match ------------------------------------------------------
## For rows still unmatched, check whether sub_norm is a substring of an ISO
## name (or vice versa). Only accept unambiguous matches (exactly one ISO
## subdivision matches within the country). Requires sub_norm >= 3 chars to
## guard against spurious hits on very short strings.

iso_extended <- iso |>
  mutate(iso_sub_norm = normalise(Subdivision.name)) |>
  select(ctr_n, iso_sub_norm, Subdivision.category, ISO3166_2.code, star,
         Subdivision.name, Local.variant, Language.code, Romanization.system,
         Parent.subdivision, Country_code, Constituent_code)

# Unique sub_norms still needing a match (excludes sentinels and short strings)
unmatched_sub_norms <- exact_unmatched |>
  filter(!str_detect(sub, "^-")) |>
  distinct(ctr_n, sub_norm = normalise(sub)) |>
  filter(nchar(sub_norm) >= 3)

# For each, find all ISO names that contain sub_norm or are contained by it,
# then keep only those with a single candidate
contains_unique <- unmatched_sub_norms |>
  left_join(iso_extended, by = "ctr_n") |>
  filter(
    str_detect(iso_sub_norm, fixed(sub_norm)) |
    str_detect(sub_norm,     fixed(iso_sub_norm))
  ) |>
  group_by(ctr_n, sub_norm) |>
  filter(n() == 1) |>
  ungroup() |>
  select(-iso_sub_norm)

# Apply the extended matches back to the unmatched rows.
# Drop the NA ISO columns from exact_unmatched first to avoid name conflicts
# when joining with contains_unique (which supplies fresh ISO fields).
iso_data_cols <- setdiff(names(iso_lookup), c("ctr_n", "sub_norm"))

contains_matched <- exact_unmatched |>
  select(-all_of(iso_data_cols)) |>
  mutate(sub_norm = normalise(sub)) |>
  inner_join(contains_unique, by = c("ctr_n", "sub_norm")) |>
  select(-sub_norm)

contains_unmatched <- exact_unmatched |>
  select(-all_of(iso_data_cols)) |>
  mutate(sub_norm = normalise(sub)) |>
  anti_join(contains_unique, by = c("ctr_n", "sub_norm")) |>
  select(-sub_norm)

message(glue("Pass 2 (contains): {nrow(contains_matched)} rows matched"))


## Combine and attach match metadata ------------------------------------------

add_match_cols <- function(df, matched) {
  if (matched) {
    df |> mutate(A = sub, B = Subdivision.name, match_probability = 1, flag = 0L)
  } else {
    df |> mutate(A = sub, B = NA_character_, match_probability = NA_real_, flag = 1L)
  }
}

stage1_matched <- bind_rows(
  add_match_cols(exact_matched,    matched = TRUE),
  add_match_cols(contains_matched, matched = TRUE)
)

stage2_input <- add_match_cols(contains_unmatched, matched = FALSE)

message(glue(
  "\nStage 1 total: {nrow(stage1_matched)} rows matched ",
  "({n_distinct(stage1_matched$ctr_n)} countries)\n",
  "Stage 2:       {nrow(stage2_input)} rows to fuzzy-link ",
  "({n_distinct(stage2_input$ctr_n)} countries)"
))


## Save -----------------------------------------------------------------------

save(stage1_matched, stage2_input,
     file = here('_data', 'temp', 'stage1.RData'))
