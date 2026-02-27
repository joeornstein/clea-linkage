#' ---
#' Merge CLEA and ISO datasets using fuzzylink()
#' ---

library(tidyverse)
library(fuzzylink)
library(here)
library(glue)

load(here('_data', 'temp', 'cleaned.RData'))


#' Link CLEA constituencies to ISO 3166-2 subdivisions via fuzzylink()
#'
#' @param countries Character vector of country names to process (must match
#'   `ctr_n` values in `clea` and `iso`).
#' @param overwrite If FALSE (default), skips countries whose output file
#'   already exists in `_data/output/`.
#'
#' @return Invisibly returns a character vector of any countries that failed.
link_countries <- function(countries, overwrite = FALSE) {
  
  failed <- character(0)
  
  for(i in seq_along(countries)){
    
    country  <- countries[i]
    out_file <- here('_data', 'output', glue('{country}.RData'))
    
    if(file.exists(out_file) && !overwrite){
      message(glue('[{i}/{length(countries)}] Skipping (already done): {country}'))
      next
    }
    
    message(glue('[{i}/{length(countries)}] Linking: {country}'))
    
    A <- clea |> filter(ctr_n == country)
    B <- iso  |> filter(ctr_n == country)
    
    if(nrow(B) == 0){
      message(glue('  Skipping {country}: no ISO entries found.'))
      next
    }
    
    tryCatch({
      
      df <- fuzzylink(A, B,
                      by = 'constituency',
                      record_type = 'geographic area',
                      model = 'gpt-5.2',
                      instructions = glue("The first name is a historical election district in {country}. The second name is an ISO 3166-2 subdivision. Respond Yes if the former lies within, or is coterminus with, the latter.")
                      )
      
      df <- df |>
        group_by(A, id) |>
        mutate(flag = as.numeric(n() > 1)) |>
        ungroup() |>
        mutate(flag = if_else(is.na(B) | match_probability < 0.2, 1, flag))
      
      save(df, file = out_file)
      
    }, error = function(e){
      message(glue('  ERROR linking {country}: {conditionMessage(e)}'))
      failed <<- c(failed, country)
    })
    
  }
  
  if(length(failed) > 0){
    message('\nThe following countries failed and should be retried:')
    message(paste(failed, collapse = '\n'))
  }
  
  invisible(failed)
  
}


## Run -----------------------------------------------------------------------

# All countries (skips already-processed):
# link_countries(unique(clea$ctr_n))

# Specific countries:
# link_countries("Canada", overwrite = TRUE)
