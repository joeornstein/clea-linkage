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


## Load cleaned data (needed for iso lookup) ----

load(here('_data', 'temp', 'cleaned.RData'))


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
  ~ctr_n,    ~cst_n_lower,                                       ~label,                ~notes,                                                                                                              ~true_iso_code,

  # --- Canada ---

  # CLEA `sub` field is wrong; constituency belongs to a different province.
  # true_iso_code gives the correct subdivision so B can be filled for unmatched rows.
  "Canada",  "sherwood park--fort saskatchewan",                  "clea_sub_error",      "sub=Saskatchewan; constituency is in Alberta",                                                                      "CA-AB",
  "Canada",  "battle river--crowfoot",                            "clea_sub_error",      "sub=British Columbia; constituency is in Alberta",                                                                  "CA-AB",
  "Canada",  "charleswood--st. james--assiniboia--headingley",    "clea_sub_error",      "sub=British Columbia; constituency is in Manitoba",                                                                 "CA-MB",
  "Canada",  "west nova",                                         "clea_sub_error",      "sub=Ontario; constituency is in Nova Scotia",                                                                       "CA-NS",

  # Historical ridings spanning multiple territories; no single ISO code applies
  "Canada",  "nunavut",                                           "multi_territory",     "Nunavut was part of NWT before 1999; no single ISO subdivision applies",                                           NA_character_,
  "Canada",  "yukon--mackenzie river",                            "multi_territory",     "1949 multi-territory riding spanning Yukon and Mackenzie district",                                                NA_character_,

  # Match found but probability near zero; likely correct given constituency name
  "Canada",  "muskoka--ontario",                                  "low_confidence",      "Matched CA-ON with near-zero probability; province name embedded in constituency name may have confused the model", NA_character_,

  # --- Brazil ---

  # CLEA uses abbreviated state names that the model could not reliably match
  "Brazil",  "ceará",                                             "clea_name_abbrev",    "Lowercase/abbreviated; likely maps to BR-CE (Ceará)",                                                              NA_character_,
  "Brazil",  "r, g, do norte",                                    "clea_name_abbrev",    "Abbreviated 'Rio Grande do Norte'; likely maps to BR-RN",                                                         NA_character_,
  "Brazil",  "r, g, do sul",                                      "clea_name_abbrev",    "Abbreviated 'Rio Grande do Sul'; likely maps to BR-RS (matched at 0.197, just under threshold)",                  NA_character_,
  "Brazil",  "m, g, do sul",                                      "clea_name_abbrev",    "Abbreviated 'Mato Grosso do Sul'; likely maps to BR-MS",                                                          NA_character_,

  # Historical territories or defunct states with no current ISO subdivision
  "Brazil",  "rio branco",                                        "historical_territory","Territory of Rio Branco (1943-1962), now Roraima (BR-RR)",                                                         NA_character_,
  "Brazil",  "t, rio branco (rr)",                                "historical_territory","Territory of Rio Branco (1943-1962), now Roraima (BR-RR)",                                                         NA_character_,
  "Brazil",  "guaporé",                                           "historical_territory","Territory of Guaporé (1943-1956), now Rondônia (BR-RO)",                                                           NA_character_,
  "Brazil",  "t, guaporé (ro)",                                   "historical_territory","Territory of Guaporé (1943-1956), now Rondônia (BR-RO)",                                                           NA_character_,
  "Brazil",  "guanabara/dto federal",                             "historical_territory","Federal District / Guanabara state (1960-1975), merged into Rio de Janeiro",                                       NA_character_,
  "Brazil",  "guanabara",                                         "historical_territory","Guanabara state (1960-1975), merged into Rio de Janeiro (BR-RJ)",                                                  NA_character_,

  # --- United States ---

  # Typos in CLEA constituency names prevented matching
  "United States", "califronia 40",                               "clea_data_error",     "Typo: 'Califronia' should be 'California'; likely maps to CA-40",                                                 NA_character_,
  "United States", "georigia 10",                                 "clea_data_error",     "Typo: 'Georigia' should be 'Georgia'; likely maps to GA-10",                                                      NA_character_,

  # --- Australia ---

  # Australian federal division names (e.g. Barker, Boothby, Jagajaga) are place
  # names / surnames with no textual similarity to state names.  The model matched
  # these correctly to the right state (corroborated by the sub field) but with
  # very low probability.
  "Australia", "barker",                                           "low_confidence",      "Division name has no textual similarity to state name; sub=SA corroborates AU-SA",              NA_character_,
  "Australia", "bean",                                             "low_confidence",      "Division name has no textual similarity to state name; sub=ACT corroborates AU-ACT",             NA_character_,
  "Australia", "boothby",                                          "low_confidence",      "Division name has no textual similarity to state name; sub=SA corroborates AU-SA",               NA_character_,
  "Australia", "brand",                                            "low_confidence",      "Division name has no textual similarity to state name; sub=WA corroborates AU-WA",               NA_character_,
  "Australia", "burt",                                             "low_confidence",      "Division name has no textual similarity to state name; sub=WA corroborates AU-WA",               NA_character_,
  "Australia", "canning",                                          "low_confidence",      "Division name has no textual similarity to state name; sub=WA corroborates AU-WA",               NA_character_,
  "Australia", "dunkley",                                          "low_confidence",      "Division name has no textual similarity to state name; sub=VIC corroborates AU-VIC",             NA_character_,
  "Australia", "forrest",                                          "low_confidence",      "Division name has no textual similarity to state name; sub=WA corroborates AU-WA",               NA_character_,
  "Australia", "goldstein",                                        "low_confidence",      "Division name has no textual similarity to state name; sub=VIC corroborates AU-VIC",             NA_character_,
  "Australia", "grey",                                             "low_confidence",      "Division name has no textual similarity to state name; sub=SA corroborates AU-SA",               NA_character_,
  "Australia", "groom",                                            "low_confidence",      "Division name has no textual similarity to state name; sub=QLD corroborates AU-QLD",             NA_character_,
  "Australia", "jagajaga",                                         "low_confidence",      "Division name has no textual similarity to state name; sub=VIC corroborates AU-VIC",             NA_character_,
  "Australia", "kingston",                                         "low_confidence",      "Division name has no textual similarity to state name; sub=SA corroborates AU-SA",               NA_character_,
  "Australia", "mayo",                                             "low_confidence",      "Division name has no textual similarity to state name; sub=SA corroborates AU-SA",               NA_character_,
  "Australia", "moncrieff",                                        "low_confidence",      "Division name has no textual similarity to state name; sub=QLD corroborates AU-QLD",             NA_character_,
  "Australia", "moore",                                            "low_confidence",      "Division name has no textual similarity to state name; sub=WA corroborates AU-WA",               NA_character_,
  "Australia", "o'connor",                                         "low_confidence",      "Division name has no textual similarity to state name; sub=WA corroborates AU-WA",               NA_character_,
  "Australia", "pearce",                                           "low_confidence",      "Division name has no textual similarity to state name; sub=WA corroborates AU-WA",               NA_character_,
  "Australia", "petrie",                                           "low_confidence",      "Division name has no textual similarity to state name; sub=QLD corroborates AU-QLD",             NA_character_,
  "Australia", "scullin",                                          "low_confidence",      "Division name has no textual similarity to state name; sub=VIC corroborates AU-VIC",             NA_character_,
  "Australia", "solomon",                                          "low_confidence",      "Division name has no textual similarity to state name; sub=NT corroborates AU-NT",               NA_character_,
  "Australia", "spence",                                           "low_confidence",      "Division name has no textual similarity to state name; sub=SA corroborates AU-SA",               NA_character_,
  "Australia", "tangney",                                          "low_confidence",      "Division name has no textual similarity to state name; sub=WA corroborates AU-WA",               NA_character_,

  # No match found; division name has no textual similarity to state name.
  # true_iso_code determined from the sub field.
  "Australia", "cowan",                                            "low_confidence",      "No match found; division name has no textual similarity to state name; sub=WA determines AU-WA", "AU-WA",
  "Australia", "swan",                                             "low_confidence",      "No match found; division name has no textual similarity to state name; sub=WA determines AU-WA", "AU-WA",
  # The Division of Darwin was a Tasmanian federal seat named after Charles Darwin
  # (not the NT city); active 1903-1955.
  "Australia", "darwin",                                           "low_confidence",      "No match found; Division of Darwin was a Tasmanian seat (named after Charles Darwin, not the NT city); sub=tasmania determines AU-TAS", "AU-TAS",

  # --- Germany ---

  # Bundestag state party-list seats (Landeslisten): sub = "Regional Constituency",
  # cst_n IS the state name. The model matched correctly but with very low
  # probability, likely because the match block included all 16 German states and
  # the model gave low confidence to an exact-name match.
  "Germany", "baden-württemberg",                                  "low_confidence",      "State party-list seat; cst_n is the state name; model matched correctly with low probability",  NA_character_,
  "Germany", "bayern",                                             "low_confidence",      "State party-list seat; cst_n is the state name; model matched correctly with low probability",  NA_character_,
  "Germany", "berlin",                                             "low_confidence",      "State party-list seat; cst_n is the state name; model matched correctly with low probability",  NA_character_,
  "Germany", "brandenburg",                                        "low_confidence",      "State party-list seat; cst_n is the state name; model matched correctly with low probability",  NA_character_,
  "Germany", "bremen",                                             "low_confidence",      "State party-list seat; cst_n is the state name; model matched correctly with low probability",  NA_character_,
  "Germany", "hamburg",                                            "low_confidence",      "State party-list seat; cst_n is the state name; model matched correctly with low probability",  NA_character_,
  "Germany", "hessen",                                             "low_confidence",      "State party-list seat; cst_n is the state name; model matched correctly with low probability",  NA_character_,
  "Germany", "mecklenburg-vorpommern",                             "low_confidence",      "State party-list seat; cst_n is the state name; model matched correctly with low probability",  NA_character_,
  "Germany", "niedersachsen",                                      "low_confidence",      "State party-list seat; cst_n is the state name; model matched correctly with low probability",  NA_character_,
  "Germany", "nordrhein-westfalen",                                "low_confidence",      "State party-list seat; cst_n is the state name; model matched correctly with low probability",  NA_character_,
  "Germany", "saarland",                                           "low_confidence",      "State party-list seat; cst_n is the state name; model matched correctly with low probability",  NA_character_,
  "Germany", "sachsen",                                            "low_confidence",      "State party-list seat; cst_n is the state name; model matched correctly with low probability",  NA_character_,
  "Germany", "sachsen-anhalt",                                     "low_confidence",      "State party-list seat; cst_n is the state name; model matched correctly with low probability",  NA_character_,
  "Germany", "schleswig-holstein",                                 "low_confidence",      "State party-list seat; cst_n is the state name; model matched correctly with low probability",  NA_character_,
  "Germany", "thüringen",                                          "low_confidence",      "State party-list seat; cst_n is the state name; model matched correctly with low probability",  NA_character_,

  # Named/numbered Bundestag Wahlkreise whose constituency names have no textual
  # similarity to the enclosing state name; sub field corroborates the match.
  "Germany", "023: hamburg-bergedorf – harburg",                   "low_confidence",      "Wahlkreis name has no textual similarity to state name; sub=Hamburg corroborates DE-HH",       NA_character_,
  "Germany", "060: brandenburg an der havel – potsdam-mittelmark i – havelland iii – teltow-fläming i", "low_confidence", "Wahlkreis name has no textual similarity to state name; sub=Brandenburg corroborates DE-BB", NA_character_,
  "Germany", "083: berlin-friedrichshain-kreuzberg – prenzlauer berg ost", "low_confidence", "Wahlkreis name has no textual similarity to state name; sub=Berlin corroborates DE-BE",    NA_character_,
  "Germany", "151: nordsachsen",                                   "low_confidence",      "Wahlkreis name has no textual similarity to state name; sub=Sachsen corroborates DE-SN",       NA_character_,
  "Germany", "161: mittelsachsen",                                  "low_confidence",      "Wahlkreis name has no textual similarity to state name; sub=Sachsen corroborates DE-SN",       NA_character_,
  "Germany", "213: erding – ebersberg",                            "low_confidence",      "Wahlkreis name has no textual similarity to state name; sub=Bayern corroborates DE-BY",        NA_character_,
  "Germany", "224: starnberg – landsberg am lech",                 "low_confidence",      "Wahlkreis name has no textual similarity to state name; sub=Bayern corroborates DE-BY",        NA_character_,
  "Germany", "altona (hamburg – altona)",                          "low_confidence",      "Wahlkreis name has no textual similarity to state name; sub=Hamburg corroborates DE-HH",       NA_character_,
  "Germany", "bergedorf (hamburg – bergedorf)",                    "low_confidence",      "Wahlkreis name has no textual similarity to state name; sub=Hamburg corroborates DE-HH",       NA_character_,
  "Germany", "eimsbüttel (hamburg – eimsbüttel)",                  "low_confidence",      "Wahlkreis name has no textual similarity to state name; sub=Hamburg corroborates DE-HH",       NA_character_,
  "Germany", "wandsbeck (hamburg – wandsbeck)",                    "low_confidence",      "Wahlkreis name has no textual similarity to state name; sub=Hamburg corroborates DE-HH",       NA_character_,
  "Germany", "ludwigslust- parchim ii - nordwestmecklenburg ii - landkreis rostock i", "low_confidence", "Wahlkreis name has no textual similarity to state name; sub=Land Mecklenburg-Vorpommern corroborates DE-MV", NA_character_,
  "Germany", "mecklenburgische seenplatte i - vorpommern-greifswald ii", "low_confidence", "Wahlkreis name has no textual similarity to state name; sub=Land Mecklenburg-Vorpommern corroborates DE-MV", NA_character_,
  "Germany", "mecklenburgische seenplatte ii - landkreis rostock iii", "low_confidence",  "Wahlkreis name has no textual similarity to state name; sub=Land Mecklenburg-Vorpommern corroborates DE-MV", NA_character_,
  "Germany", "rostock - landkreis rostock ii",                     "low_confidence",      "Wahlkreis name has no textual similarity to state name; sub=Land Mecklenburg-Vorpommern corroborates DE-MV", NA_character_,
  "Germany", "schwerin - ludwigslust-parchim i - nordwestmecklenburg i", "low_confidence", "Wahlkreis name has no textual similarity to state name; sub=Land Mecklenburg-Vorpommern corroborates DE-MV", NA_character_,
  "Germany", "vorpommern- rügen - vorpommern-greifswald i",        "low_confidence",      "Wahlkreis name has no textual similarity to state name; sub=Land Mecklenburg-Vorpommern corroborates DE-MV", NA_character_,
  "Germany", "mittelsachsen",                                       "low_confidence",      "Wahlkreis name has no textual similarity to state name; sub=Sachsen corroborates DE-SN",       NA_character_,
  "Germany", "weißenburg (in bayern)",                              "low_confidence",      "Wahlkreis name has no textual similarity to state name; sub=Bayern corroborates DE-BY",        NA_character_,
  "Germany", "weißenburg in bayern",                                "low_confidence",      "Wahlkreis name has no textual similarity to state name; sub=Bayern corroborates DE-BY",        NA_character_,

  # CLEA `sub` field assigns these constituencies to the wrong German state.
  # The model correctly identified the right state despite the sub error;
  # true_iso_code confirms/restores the correct ISO subdivision.
  "Germany", "bad doberan - güstrow - müritz",                     "clea_sub_error",      "sub=Brandenburg wrong; all three districts are in Mecklenburg-Vorpommern",                     "DE-MV",
  "Germany", "bernburg - bitterfeld - saalkreis",                   "clea_sub_error",      "sub=Thüringen wrong; Bernburg, Bitterfeld, and Saalkreis are all in Sachsen-Anhalt",           "DE-ST",
  "Germany", "eichsfeld - nordhausen",                              "clea_sub_error",      "sub=Sachsen wrong; Eichsfeld and Nordhausen are in Thüringen",                                 "DE-TH",
  "Germany", "eichsfeld - nordhausen - unstrut-hainich-kreis i",   "clea_sub_error",      "sub=Sachsen wrong; Eichsfeld, Nordhausen, and Unstrut-Hainich-Kreis are in Thüringen",        "DE-TH",
  "Germany", "eisenach - wartburgkreis - unstrut-hainich-kreis i",  "clea_sub_error",      "sub=Sachsen wrong; Eisenach, Wartburgkreis, and Unstrut-Hainich-Kreis are in Thüringen",      "DE-TH",
  "Germany", "eisenach - wartburgkreis - unstrut-hainich-kreis ii", "clea_sub_error",      "sub=Sachsen wrong; Eisenach, Wartburgkreis, and Unstrut-Hainich-Kreis are in Thüringen",      "DE-TH",
  "Germany", "elbe-havel-gebiet",                                   "clea_sub_error",      "sub=Thüringen wrong; Elbe-Havel region is in Sachsen-Anhalt",                                  "DE-ST",
  "Germany", "gera - jena - saale-holzland-kreis",                  "clea_sub_error",      "sub=Sachsen wrong; Gera, Jena, and Saale-Holzland-Kreis are in Thüringen",                    "DE-TH",
  "Germany", "gera - saale-holzland-kreis",                         "clea_sub_error",      "sub=Sachsen wrong; Gera and Saale-Holzland-Kreis are in Thüringen",                           "DE-TH",
  "Germany", "gotha - ilm-kreis",                                   "clea_sub_error",      "sub=Sachsen wrong; Gotha and Ilm-Kreis are in Thüringen",                                     "DE-TH",
  "Germany", "greifswald - demmin - ostvorpommern",                 "clea_sub_error",      "sub=Brandenburg wrong; Greifswald, Demmin, and Ostvorpommern are in Mecklenburg-Vorpommern",  "DE-MV",
  "Germany", "greiz - altenburger land",                            "clea_sub_error",      "sub=Sachsen wrong; Greiz and Altenburger Land are in Thüringen",                              "DE-TH",
  "Germany", "halle",                                               "clea_sub_error",      "sub=Thüringen wrong; Halle (Saale) is the capital of Sachsen-Anhalt",                         "DE-ST",
  "Germany", "jena - weimar - weimarer land",                       "clea_sub_error",      "sub=Sachsen wrong; Jena, Weimar, and Weimarer Land are in Thüringen",                         "DE-TH",
  "Germany", "neubrandenburg - mecklenburg-strelitz - uecker-randow", "clea_sub_error",    "sub=Brandenburg wrong; all three districts are in Mecklenburg-Vorpommern",                     "DE-MV",
  "Germany", "schwerin - ludwigslust",                              "clea_sub_error",      "sub=Brandenburg wrong; Schwerin and Ludwigslust are in Mecklenburg-Vorpommern",                "DE-MV",
  "Germany", "sonneberg - saalfeld-rudolstadt - saale-orla-kreis",  "clea_sub_error",      "sub=Sachsen wrong; Sonneberg, Saalfeld-Rudolstadt, and Saale-Orla-Kreis are in Thüringen",    "DE-TH",
  "Germany", "stralsund - nordvorpommern - rügen",                  "clea_sub_error",      "sub=Brandenburg wrong; Stralsund, Nordvorpommern, and Rügen are in Mecklenburg-Vorpommern",   "DE-MV",
  "Germany", "wismar - nordwestmecklenburg - parchim",              "clea_sub_error",      "sub=Brandenburg wrong; Wismar, Nordwestmecklenburg, and Parchim are in Mecklenburg-Vorpommern","DE-MV",

  # CLEA `sub` field assigns these constituencies to the wrong German state AND
  # no match was found. true_iso_code supplies the correct subdivision.
  "Germany", "altmark",                                             "clea_sub_error",      "sub=Thüringen wrong; Altmark is a historical region in Sachsen-Anhalt",                       "DE-ST",
  "Germany", "annaberg - aue-schwarzenberg",                        "clea_sub_error",      "sub=Sachsen-Anhalt wrong; Annaberg and Aue-Schwarzenberg are in Sachsen",                     "DE-SN",
  "Germany", "bautzen - weißwasser",                                "clea_sub_error",      "sub=Sachsen-Anhalt wrong; Bautzen and Weißwasser are in Sachsen",                             "DE-SN",
  "Germany", "brandenburg an der havel - potsdam-mittelmark i - havelland iii - teltow-fläming i", "clea_sub_error", "sub=Mecklenburg-Vorpommern wrong; all districts are in Brandenburg", "DE-BB",
  "Germany", "chemnitzer land - stollberg",                         "clea_sub_error",      "sub=Sachsen-Anhalt wrong; Chemnitzer Land and Stollberg are in Sachsen",                      "DE-SN",
  "Germany", "cottbus - spree-neiße",                               "clea_sub_error",      "sub=Mecklenburg-Vorpommern wrong; Cottbus and Spree-Neiße are in Brandenburg",                "DE-BB",
  "Germany", "dahme-spreewald - teltow-fläming iii - oberspreewald-lausitz i", "clea_sub_error", "sub=Mecklenburg-Vorpommern wrong; all districts are in Brandenburg",                    "DE-BB",
  "Germany", "delitzsch - torgau-oschatz - riesa",                  "clea_sub_error",      "sub=Sachsen-Anhalt wrong; Delitzsch, Torgau-Oschatz, and Riesa are in Sachsen",               "DE-SN",
  "Germany", "dresden i",                                           "clea_sub_error",      "sub=Sachsen-Anhalt wrong; Dresden is in Sachsen",                                             "DE-SN",
  "Germany", "dresden ii - meißen i",                               "clea_sub_error",      "sub=Sachsen-Anhalt wrong; Dresden and Meißen are in Sachsen",                                 "DE-SN",
  "Germany", "döbeln - mittweida - meißen ii",                      "clea_sub_error",      "sub=Sachsen-Anhalt wrong; Döbeln, Mittweida, and Meißen are in Sachsen",                      "DE-SN",
  "Germany", "elbe-elster - oberspreewald-lausitz ii",              "clea_sub_error",      "sub=Mecklenburg-Vorpommern wrong; Elbe-Elster and Oberspreewald-Lausitz are in Brandenburg",  "DE-BB",
  "Germany", "erfurt",                                              "clea_sub_error",      "sub=Sachsen wrong; Erfurt is in Thüringen",                                                   "DE-TH",
  "Germany", "erfurt - weimar - weimarer land ii",                  "clea_sub_error",      "sub=Sachsen wrong; Erfurt, Weimar, and Weimarer Land are in Thüringen",                       "DE-TH",
  "Germany", "frankfurt (oder) - oder-spree",                       "clea_sub_error",      "sub=Mecklenburg-Vorpommern wrong; Frankfurt (Oder) and Oder-Spree are in Brandenburg",        "DE-BB",
  "Germany", "freiberg - mittlerer erzgebirgskreis",                "clea_sub_error",      "sub=Sachsen-Anhalt wrong; Freiberg and Mittlerer Erzgebirgskreis are in Sachsen",             "DE-SN",
  "Germany", "kyffhäuserkreis - sömmerda - unstrut-hainich-kreis ii","clea_sub_error",     "sub=Sachsen wrong; Kyffhäuserkreis, Sömmerda, and Unstrut-Hainich-Kreis are in Thüringen",   "DE-TH",
  "Germany", "kyffhäuserkreis - sömmerda - weimarer land i",        "clea_sub_error",      "sub=Sachsen wrong; Kyffhäuserkreis, Sömmerda, and Weimarer Land are in Thüringen",            "DE-TH",
  "Germany", "leipzig i",                                           "clea_sub_error",      "sub=Sachsen-Anhalt wrong; Leipzig is in Sachsen",                                             "DE-SN",
  "Germany", "leipzig ii",                                          "clea_sub_error",      "sub=Sachsen-Anhalt wrong; Leipzig is in Sachsen",                                             "DE-SN",
  "Germany", "leipziger land - muldentalkreis",                     "clea_sub_error",      "sub=Sachsen-Anhalt wrong; Leipziger Land and Muldentalkreis are in Sachsen",                  "DE-SN",
  "Germany", "löbau-zittau - görlitz - niesky",                     "clea_sub_error",      "sub=Sachsen-Anhalt wrong; Löbau-Zittau, Görlitz, and Niesky are in Sachsen",                  "DE-SN",
  "Germany", "magdeburg",                                           "clea_sub_error",      "sub=Thüringen wrong; Magdeburg is the capital of Sachsen-Anhalt",                             "DE-ST",
  "Germany", "märkisch-oderland - barnim ii",                       "clea_sub_error",      "sub=Mecklenburg-Vorpommern wrong; Märkisch-Oderland and Barnim are in Brandenburg",           "DE-BB",
  "Germany", "münchen-süd",                                         "clea_sub_error",      "sub=München-Süd (constituency name used as sub); Wahlkreis München-Süd is in Bayern",         "DE-BY",
  "Germany", "oberhavel - havelland ii",                            "clea_sub_error",      "sub=Mecklenburg-Vorpommern wrong; Oberhavel and Havelland are in Brandenburg",                "DE-BB",
  "Germany", "potsdam - potsdam-mittelmark ii - teltow-fläming ii", "clea_sub_error",      "sub=Mecklenburg-Vorpommern wrong; Potsdam and surrounding districts are in Brandenburg",      "DE-BB",
  "Germany", "prignitz - ostprignitz-ruppin - havelland i",         "clea_sub_error",      "sub=Mecklenburg-Vorpommern wrong; Prignitz, Ostprignitz-Ruppin, and Havelland are in Brandenburg", "DE-BB",
  "Germany", "rostock",                                             "clea_sub_error",      "sub=Brandenburg wrong; Rostock is in Mecklenburg-Vorpommern",                                 "DE-MV",
  "Germany", "suhl - schmalkalden-meiningen - hildburghausen",      "clea_sub_error",      "sub=Sachsen wrong; Suhl, Schmalkalden-Meiningen, and Hildburghausen are in Thüringen",        "DE-TH",
  "Germany", "sächsische schweiz - weißeritzkreis",                 "clea_sub_error",      "sub=Sachsen-Anhalt wrong; Sächsische Schweiz and Weißeritzkreis are in Sachsen",              "DE-SN",
  "Germany", "uckermark - barnim i",                                "clea_sub_error",      "sub=Mecklenburg-Vorpommern wrong; Uckermark and Barnim are in Brandenburg",                   "DE-BB",
  "Germany", "vogtland - plauen",                                   "clea_sub_error",      "sub=Sachsen-Anhalt wrong; Vogtland and Plauen are in Sachsen",                                "DE-SN",
  "Germany", "zwickauer land - zwickau",                            "clea_sub_error",      "sub=Sachsen-Anhalt wrong; Zwickauer Land and Zwickau are in Sachsen",                         "DE-SN",

  # These six constituencies were NOT flagged in 2002/2005 because the model matched
  # with high confidence — but it was anchored by the wrong state name embedded in
  # the A string (constituency = sub + cst_n).  The sub rotation error caused the
  # model to match to the rotated-wrong state rather than the true state.
  "Germany", "chemnitz",                                            "clea_sub_error",      "sub=Sachsen-Anhalt wrong (2002/2005 rotation error); Chemnitz is in Sachsen",                 "DE-SN",
  "Germany", "leipziger-land - muldentalkreis",                     "clea_sub_error",      "sub=Sachsen-Anhalt wrong (2002/2005 rotation error); Leipziger Land and Muldentalkreis are in Sachsen", "DE-SN",
  "Germany", "harz",                                                "clea_sub_error",      "sub=Thüringen wrong (2002/2005 rotation error); Landkreis Harz is in Sachsen-Anhalt",          "DE-ST",
  "Germany", "börde",                                               "clea_sub_error",      "sub=Thüringen wrong (2002/2005 rotation error); Börde is in Sachsen-Anhalt",                   "DE-ST",
  "Germany", "burgenland",                                          "clea_sub_error",      "sub=Thüringen wrong (2002/2005 rotation error); Burgenlandkreis is in Sachsen-Anhalt",         "DE-ST",
  "Germany", "mansfelder land",                                     "clea_sub_error",      "sub=Thüringen wrong (2002/2005 rotation error); Mansfelder Land is in Sachsen-Anhalt",         "DE-ST",
)


## Apply labels ----

validated <- all_results |>
  mutate(cst_n_lower = str_to_lower(cst_n)) |>
  left_join(case_labels, by = c("ctr_n", "cst_n_lower")) |>
  select(-cst_n_lower)


## Correct ISO fields for rows where case_labels supplies a true_iso_code ----
#
# When case_labels supplies a true_iso_code, join the corresponding ISO record
# and overwrite all ISO columns — regardless of whether B is already populated.
# This handles both unmatched rows (B is NA) and rows where fuzzylink found the
# wrong match (B is non-missing but incorrect, e.g. clea_sub_error cases).

iso_lookup <- iso |>
  select(
    true_iso_code        = ISO3166_2.code,
    B_true               = constituency,
    Subdivision.category_true = Subdivision.category,
    ISO3166_2.code_true  = ISO3166_2.code,
    star_true            = star,
    Subdivision.name_true     = Subdivision.name,
    Local.variant_true        = Local.variant,
    Language.code_true        = Language.code,
    Romanization.system_true  = Romanization.system,
    Parent.subdivision_true   = Parent.subdivision,
    Country_code_true         = Country_code,
    Constituent_code_true     = Constituent_code
  )

validated <- validated |>
  left_join(iso_lookup, by = "true_iso_code") |>
  mutate(
    B                    = if_else(!is.na(true_iso_code), B_true,                    B),
    Subdivision.category = if_else(!is.na(true_iso_code), Subdivision.category_true, Subdivision.category),
    ISO3166_2.code       = if_else(!is.na(true_iso_code), ISO3166_2.code_true,       ISO3166_2.code),
    star                 = if_else(!is.na(true_iso_code), star_true,                 star),
    Subdivision.name     = if_else(!is.na(true_iso_code), Subdivision.name_true,     Subdivision.name),
    Local.variant        = if_else(!is.na(true_iso_code), Local.variant_true,        Local.variant),
    Language.code        = if_else(!is.na(true_iso_code), Language.code_true,        Language.code),
    Romanization.system  = if_else(!is.na(true_iso_code), Romanization.system_true,  Romanization.system),
    Parent.subdivision   = if_else(!is.na(true_iso_code), Parent.subdivision_true,   Parent.subdivision),
    Country_code         = if_else(!is.na(true_iso_code), Country_code_true,         Country_code),
    Constituent_code     = if_else(!is.na(true_iso_code), Constituent_code_true,     Constituent_code)
  ) |>
  select(-ends_with("_true"), -true_iso_code)


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
