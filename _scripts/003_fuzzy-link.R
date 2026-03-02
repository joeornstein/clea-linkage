#' ---
#' Stage 2: LLM-assisted fuzzy linkage via fuzzylink()
#' ---
#'
#' Processes rows not resolved by Stage 1 string matching. For each country,
#' combines Stage 1 matches with Stage 2 fuzzylink() results and saves a
#' per-country output file to _data/output/{country}.RData.
#'
#' Inputs:
#'   _data/temp/cleaned.RData   (clea, iso)
#'   _data/temp/stage1.RData    (stage1_matched, stage2_input)
#'
#' Output: _data/output/{country}.RData  (df)

library(tidyverse)
library(fuzzylink)
library(here)
library(glue)

load(here('_data', 'temp', 'cleaned.RData'))
load(here('_data', 'temp', 'stage1.RData'))


## Link function --------------------------------------------------------------
#'
#' @param countries Character vector of country names to process (must match
#'   `ctr_n` values in `clea`).
#' @param overwrite If FALSE (default), skips countries whose output file
#'   already exists in `_data/output/`.
#' @return Invisibly returns a character vector of any countries that failed.

link_countries <- function(countries, overwrite = FALSE) {

  failed <- character(0)

  for (i in seq_along(countries)) {

    country  <- countries[i]
    out_file <- here('_data', 'output', glue('{country}.RData'))

    if (file.exists(out_file) && !overwrite) {
      message(glue('[{i}/{length(countries)}] Skipping (already done): {country}'))
      next
    }

    # Stage 1 matches for this country
    s1 <- stage1_matched |> filter(ctr_n == country)

    # CLEA rows requiring fuzzy linkage; drop the NA ISO columns added in Stage 1
    s2_A <- stage2_input |>
      filter(ctr_n == country) |>
      select(all_of(names(clea)))

    # ISO B table for this country
    s2_B <- iso |> filter(ctr_n == country)

    if (nrow(s2_B) == 0) {
      message(glue('[{i}/{length(countries)}] No ISO entries for {country}; saving Stage 1 only.'))
      df <- s1
      save(df, file = out_file)
      next
    }

    if (nrow(s2_A) == 0) {
      message(glue('[{i}/{length(countries)}] {country}: all rows matched in Stage 1.'))
      df <- s1
      save(df, file = out_file)
      next
    }

    message(glue('[{i}/{length(countries)}] Fuzzy-linking {nrow(s2_A)} rows for: {country}'))

    tryCatch({

      s2 <- fuzzylink(
        s2_A, s2_B,
        by           = 'constituency',
        record_type  = 'geographic area',
        model        = 'gpt-5.2',
        instructions = glue(
          "The first name is a historical election district in {country}. ",
          "The second name is an ISO 3166-2 subdivision. ",
          "Respond Yes if the former lies within, or is coterminous with, the latter."
        )
      ) |>
        group_by(A, id) |>
        mutate(flag = as.integer(n() > 1)) |>
        ungroup() |>
        mutate(flag = if_else(is.na(B) | match_probability < 0.2, 1L, flag))

      # fuzzylink may produce ctr_n.x / ctr_n.y when both A and B contain ctr_n
      if ("ctr_n.x" %in% names(s2) && !"ctr_n" %in% names(s2)) {
        s2 <- rename(s2, ctr_n = ctr_n.x)
      }

      df <- bind_rows(s1, s2)
      save(df, file = out_file)

    }, error = function(e) {
      message(glue('  ERROR linking {country}: {conditionMessage(e)}'))
      failed <<- c(failed, country)
    })

  }

  if (length(failed) > 0) {
    message('\nThe following countries failed and should be retried:')
    message(paste(failed, collapse = '\n'))
  }

  invisible(failed)

}


## Run ------------------------------------------------------------------------

# All countries (skips already-processed):
# link_countries(unique(clea$ctr_n))

# Specific countries:
# link_countries("Canada", overwrite = TRUE)
