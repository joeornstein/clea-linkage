#' ---
#' Post-merge validation: label flagged observations case-by-case
#' ---
#'
#' Labels are defined in the `case_labels` lookup table below.
#' Join key: ctr_n + str_to_lower(cst_n)
#'
#' Label categories:
#'   clea_sub_error      - CLEA `sub` field assigns constituency to wrong province/region
#'   clea_name_abbrev    - CLEA uses abbreviated name that prevented a good match
#'   clea_data_error     - Typo or other data error in CLEA constituency name
#'   historical_territory - Historical territory/state with no current ISO subdivision
#'   multi_territory     - Historical riding spanning multiple ISO subdivisions;
#'                         no single code applies
#'   low_confidence      - Match found but probability below threshold; likely correct

library(tidyverse)
library(here)


## Load and combine all per-country output files ----

output_files <- list.files(
  here('_data', 'output'),
  pattern = '\\.RData$',
  full.names = TRUE
)

all_results <- map(output_files, \(f) {
  load(f)
  # fuzzylink() produces ctr_n.x/ctr_n.y when blocking.variables is not set;
  # normalise to a single ctr_n column for consistency across output files
  if("ctr_n.x" %in% names(df) && !"ctr_n" %in% names(df)){
    df <- rename(df, ctr_n = ctr_n.x)
  }
  df
}) |> list_rbind()


## Case-by-case labels for flagged observations ----

case_labels <- tribble(
  ~ctr_n,    ~cst_n_lower,                                       ~label,                ~notes,

  # --- Canada ---

  # CLEA `sub` field is wrong; constituency belongs to a different province
  "Canada",  "sherwood park--fort saskatchewan",                  "clea_sub_error",      "sub=Saskatchewan; constituency is in Alberta",
  "Canada",  "battle river--crowfoot",                            "clea_sub_error",      "sub=British Columbia; constituency is in Alberta",
  "Canada",  "charleswood--st. james--assiniboia--headingley",    "clea_sub_error",      "sub=British Columbia; constituency is in Manitoba",
  "Canada",  "west nova",                                         "clea_sub_error",      "sub=Ontario; constituency is in Nova Scotia",

  # Historical ridings spanning multiple territories; no single ISO code applies
  "Canada",  "nunavut",                                           "multi_territory",     "Nunavut was part of NWT before 1999; no single ISO subdivision applies",
  "Canada",  "yukon--mackenzie river",                            "multi_territory",     "1949 multi-territory riding spanning Yukon and Mackenzie district",

  # Match found but probability near zero; likely correct given constituency name
  "Canada",  "muskoka--ontario",                                  "low_confidence",      "Matched CA-ON with near-zero probability; province name embedded in constituency name may have confused the model",

  # --- Brazil ---

  # CLEA uses abbreviated state names that the model could not reliably match
  "Brazil",  "ceará",                                             "clea_name_abbrev",    "Lowercase/abbreviated; likely maps to BR-CE (Ceará)",
  "Brazil",  "r, g, do norte",                                    "clea_name_abbrev",    "Abbreviated 'Rio Grande do Norte'; likely maps to BR-RN",
  "Brazil",  "r, g, do sul",                                      "clea_name_abbrev",    "Abbreviated 'Rio Grande do Sul'; likely maps to BR-RS (matched at 0.197, just under threshold)",
  "Brazil",  "m, g, do sul",                                      "clea_name_abbrev",    "Abbreviated 'Mato Grosso do Sul'; likely maps to BR-MS",

  # Historical territories or defunct states with no current ISO subdivision
  "Brazil",  "rio branco",                                        "historical_territory","Territory of Rio Branco (1943-1962), now Roraima (BR-RR)",
  "Brazil",  "t, rio branco (rr)",                                "historical_territory","Territory of Rio Branco (1943-1962), now Roraima (BR-RR)",
  "Brazil",  "guaporé",                                           "historical_territory","Territory of Guaporé (1943-1956), now Rondônia (BR-RO)",
  "Brazil",  "t, guaporé (ro)",                                   "historical_territory","Territory of Guaporé (1943-1956), now Rondônia (BR-RO)",
  "Brazil",  "guanabara/dto federal",                             "historical_territory","Federal District / Guanabara state (1960-1975), merged into Rio de Janeiro",
  "Brazil",  "guanabara",                                         "historical_territory","Guanabara state (1960-1975), merged into Rio de Janeiro (BR-RJ)",

  # --- United States ---

  # Typos in CLEA constituency names prevented matching
  "United States", "califronia 40",                               "clea_data_error",     "Typo: 'Califronia' should be 'California'; likely maps to CA-40",
  "United States", "georigia 10",                                 "clea_data_error",     "Typo: 'Georigia' should be 'Georgia'; likely maps to GA-10",
)


## Apply labels ----

validated <- all_results |>
  mutate(cst_n_lower = str_to_lower(cst_n)) |>
  left_join(case_labels, by = c("ctr_n", "cst_n_lower")) |>
  select(-cst_n_lower)


## Summary ----

cat("=== Flagged row summary ===\n\n")

validated |>
  filter(flag == 1) |>
  count(ctr_n, label) |>
  print(n = Inf)

unlabeled <- validated |>
  filter(flag == 1, is.na(label))

if(nrow(unlabeled) > 0){
  cat(glue::glue("\n{nrow(unlabeled)} flagged row(s) have no label yet:\n\n"))
  unlabeled |>
    select(ctr_n, A, cst_n, yr, match_probability) |>
    print(n = Inf)
} else {
  cat("\nAll flagged rows have been labelled.\n")
}


## Save ----

save(validated, file = here('_data', 'temp', 'validated.RData'))
