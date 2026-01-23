#' ---
#' Merge CLEA and ISO datasets with fuzzylink()
#' ---

library(tidyverse)
library(fuzzylink)
library(here)
library(glue)

load(here('_data', 'temp', 'cleaned.RData'))


## Loop through each country and fuzzylink() ----------------
recompute <- FALSE
for(country in unique(clea$ctr_n)){
  
  if(file.exists(here('_data', 'output', glue('{country}.RData'))) & !recompute){
    next
  }
  
  A <- clea |> 
    filter(ctr_n == country)
  
  B <- iso |> 
    filter(ctr_n == country)
  
  ## fuzzylink
  df <- fuzzylink(A, B, 
                  by = 'cst_n',
                  blocking.variables = 'ctr_n',
                  record_type = 'geographic area',
                  model = 'gpt-5.2',
                  instructions = glue("The first name is a historical election district in {country}. The second name is an ISO 3166-2 subdivision. Respond Yes if the former lies within, or is coterminus with, the latter.")
                  )
  
  # flag rows with multiple matches
  df <- df |> 
    group_by(A, id) |> 
    mutate(flag = as.numeric(n() > 1)) |> 
    ungroup()
  
  save(df, file = here('_data', 'output', glue('{country}.RData')))
  
}


## TODO: flag duplicate matches
