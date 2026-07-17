#!/usr/bin/env Rscript
# Generators with Engine Type unset: % breakdown by raw Zone value.
# Split pre-2019, post-2018, all.

library(readr)
library(dplyr)

audits <- read_delim("input_data/audits.txt", delim = "\t", show_col_types = FALSE) %>%
  mutate(year = as.integer(format(as.Date(Date, format = "%d/%m/%Y"), "%Y")))

unset_gen <- audits %>%
  filter(`Machine Type` == "Generator", !`Engine Type` %in% c("Constant", "Variable"))

summarise_period <- function(df, label) {
  df %>% count(Zone) %>%
    mutate(period = label, pct = round(100 * n / sum(n), 1))
}

print(bind_rows(
  summarise_period(filter(unset_gen, year < 2019),  "Pre-2019"),
  summarise_period(filter(unset_gen, year >= 2019), "Post-2018"),
  summarise_period(unset_gen,                       "All")
))
