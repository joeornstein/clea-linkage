#' ---
#' Merge CLEA and ISO datasets with fuzzylink()
#' ---

library(tidyverse)
library(fuzzylink)
library(here)
library(glue)

load(here('_data', 'temp', 'cleaned.RData'))


## Loop through each country and fuzzylink() ----------------

for(country in unique(clea$ctr_n)){
  
  A <- clea |> 
    filter(ctr_n == country)
  
  B <- iso |> 
    filter(ctr_n == country)
  
  ## fuzzylink
  df <- fuzzylink(A, B, 
                  by = 'cst_n',
                  record_type = 'geographic area',
                  model = 'gpt-5.1',
                  instructions = glue("The first name is a historical election district in {country}. The second name is an ISO 3166-2 subdivision. Respond Yes if the former lies within, or is coterminus with, the latter.")
                  )
  
  save(df, file = here('_data', 'output', glue('{country}.RData')))
  
}