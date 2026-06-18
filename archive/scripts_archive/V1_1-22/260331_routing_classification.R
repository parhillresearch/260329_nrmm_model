# 260331_routing_classification.R
# Classify every audit record into compliance routing type (per outcomes table)
# and produce year-by-year stacked bar charts per group.
# Inputs:  260329_step1_ingestion.RData
# Outputs: 260331_routing_console.txt + 4 PNG plots

library(tidyverse)

load("260329_step1_ingestion.RData")

log_con <- file("260331_routing_console.txt", open = "wt")
sink(log_con, split = TRUE)

# ── Derived columns ───────────────────────────────────────────────────────────
comp_thresh <- list(
  A1 = c(Constant_Speed = 3L, CAZ_Plus = 4L, Rest_of_London = 3L),
  A2 = c(Constant_Speed = 3L, CAZ_Plus = 4L, Rest_of_London = 3L),
  B  = c(Constant_Speed = 6L, CAZ_Plus = 5L, Rest_of_London = 4L)
)

df$yr <- as.integer(format(df$Date, "%Y"))

df <- df %>%
  mutate(
    thresh = mapply(function(ph, grp) comp_thresh[[ph]][[grp]], Phase, Group),
    emissions_ok      = Initial.Stage >= thresh,
    init_compliant    = tolower(trimws(Initial.Machinery.Compliance)) == "compliant",
    final_outcome_raw = tolower(trimws(iconv(Final.Machinery.Compliance,
                                             to = "UTF-8", sub = ""))),
    final_driven      = grepl("^compliant$", final_outcome_raw),
    final_removed     = grepl("remov", final_outcome_raw),
    final_nc          = grepl("non-compliant|non compliant", final_outcome_raw)
  )

# ── Routing classification ────────────────────────────────────────────────────
# Based on compliance outcomes table rows 1-5:
#   Row 1: Self-compliant          — emissions OK, Initial.Machinery.Compliance compliant
#   Row 2: Driven compliant        — emissions OK, not compliant initially, driven compliant
#   Row 3: Non-compliant (reg)     — emissions OK, not compliant initially, not resolved
#   Row 4: Driven compliant (emis) — emissions not OK, driven compliant or removed
#   Row 5: Non-compliant (emis)    — emissions not OK, not resolved
# Additional: Compliant via exemption — emissions not OK but Initial.MC compliant

df <- df %>%
  mutate(
    routing = case_when(
      # Exemption/viability: Stage below threshold but recorded as compliant
      !emissions_ok &  init_compliant                        ~ "Compliant - exemption",
      # Self-compliant: Stage OK and compliant
       emissions_ok &  init_compliant                        ~ "Self-compliant",
      # Driven compliant via registration: Stage OK, not compliant, resolved
       emissions_ok & !init_compliant & final_driven         ~ "Driven compliant - registration",
      # Removed from site (registration route): Stage OK, not compliant, removed
       emissions_ok & !init_compliant & final_removed        ~ "Removed - registration",
      # Persistent non-compliant (registration): Stage OK, not resolved
       emissions_ok & !init_compliant                        ~ "Non-compliant - registration",
      # Driven compliant via emissions: Stage not OK, driven compliant
      !emissions_ok & !init_compliant & final_driven         ~ "Driven compliant - emissions",
      # Removed from site (emissions route): Stage not OK, removed
      !emissions_ok & !init_compliant & final_removed        ~ "Removed - emissions",
      # Persistent non-compliant (emissions): Stage not OK, not resolved
      !emissions_ok & !init_compliant                        ~ "Non-compliant - emissions",
      TRUE                                                    ~ "Unclassified"
    )
  )

# ── Summary counts ────────────────────────────────────────────────────────────
cat("══ ROUTING CLASSIFICATION — ALL RECORDS ══\n")
routing_summary <- df %>%
  count(routing, sort = TRUE) %>%
  mutate(pct = round(100 * n / sum(n), 1))
print(routing_summary)

cat("\n══ ROUTING BY GROUP × PHASE ══\n")
df %>%
  count(Group, Phase, routing) %>%
  arrange(Group, Phase, desc(n)) %>%
  head(60) %>% print()

# ── Year-by-year counts: all records ─────────────────────────────────────────
cat("\n══ YEAR-BY-YEAR ROUTING COUNTS (all records) ══\n")
yrly_all <- df %>%
  count(Group, yr, routing) %>%
  group_by(Group, yr) %>%
  mutate(pct = 100 * n / sum(n)) %>%
  ungroup()
print(yrly_all, n = 100)

# ── Year-by-year: warm fleet only ─────────────────────────────────────────────
cat("\n══ YEAR-BY-YEAR ROUTING COUNTS (warm fleet) ══\n")
yrly_warm <- df %>%
  filter(!Cold_Engaged) %>%
  count(Group, yr, routing) %>%
  group_by(Group, yr) %>%
  mutate(pct = 100 * n / sum(n)) %>%
  ungroup()
print(yrly_warm, n = 100)

# ── Year-by-year: cold fleet only ─────────────────────────────────────────────
cat("\n══ YEAR-BY-YEAR ROUTING COUNTS (cold fleet) ══\n")
yrly_cold <- df %>%
  filter(Cold_Engaged) %>%
  count(Group, yr, routing) %>%
  group_by(Group, yr) %>%
  mutate(pct = 100 * n / sum(n)) %>%
  ungroup()
print(yrly_cold, n = 100)

# ── Colour palette ────────────────────────────────────────────────────────────
route_colours <- c(
  "Self-compliant"                  = "#1a9850",
  "Compliant - exemption"           = "#91cf60",
  "Driven compliant - registration" = "#d9ef8b",
  "Driven compliant - emissions"    = "#fee08b",
  "Removed - registration"          = "#fc8d59",
  "Removed - emissions"             = "#d73027",
  "Non-compliant - registration"    = "#bababa",
  "Non-compliant - emissions"       = "#4d4d4d",
  "Unclassified"                    = "#ffffff"
)

route_levels <- names(route_colours)

phase_bounds <- data.frame(x = c(2019, 2020.667))

# ── Plot function ─────────────────────────────────────────────────────────────
plot_routing <- function(yrly_df, title_suffix) {
  yrly_df %>%
    mutate(routing = factor(routing, levels = rev(route_levels))) %>%
    ggplot(aes(x = yr, y = pct, fill = routing)) +
    geom_bar(stat = "identity", width = 0.85) +
    geom_vline(data = phase_bounds, aes(xintercept = x),
               linetype = "dashed", colour = "grey30", linewidth = 0.4) +
    facet_wrap(~Group, ncol = 3) +
    scale_fill_manual(values = route_colours, name = NULL,
                      drop = FALSE) +
    scale_x_continuous(breaks = 2016:2024,
                       labels = function(x) substr(x, 3, 4)) +
    scale_y_continuous(limits = c(0, 100), expand = c(0, 0),
                       labels = function(x) paste0(x, "%")) +
    labs(title    = paste("Compliance routing by year —", title_suffix),
         subtitle = "Dashed lines: phase boundaries (Jan 2019; Sep 2020)",
         x = "Year", y = "% of audit records") +
    theme_minimal(base_size = 11) +
    theme(legend.position  = "bottom",
          legend.text      = element_text(size = 8),
          panel.grid.minor = element_blank(),
          axis.text.x      = element_text(angle = 45, hjust = 1),
          strip.text       = element_text(face = "bold")) +
    guides(fill = guide_legend(nrow = 3, reverse = TRUE))
}

# ── Generate and save plots ───────────────────────────────────────────────────
p_all  <- plot_routing(yrly_all,  "all records")
p_warm <- plot_routing(yrly_warm, "warm fleet")
p_cold <- plot_routing(yrly_cold, "cold fleet")

ggsave("260331_routing_all.png",  p_all,  width = 13, height = 5, dpi = 150)
ggsave("260331_routing_warm.png", p_warm, width = 13, height = 5, dpi = 150)
ggsave("260331_routing_cold.png", p_cold, width = 13, height = 5, dpi = 150)

# ── Combined plot: cold (top), warm (middle), all (bottom) ────────────────────
yrly_stacked <- bind_rows(
  mutate(yrly_cold, fleet = "Cold"),
  mutate(yrly_warm, fleet = "Warm"),
  mutate(yrly_all,  fleet = "All records")
) %>%
  mutate(routing = factor(routing, levels = rev(route_levels)),
         fleet   = factor(fleet, levels = c("Cold", "Warm", "All records")))

p_stacked <- ggplot(yrly_stacked, aes(x = yr, y = pct, fill = routing)) +
  geom_bar(stat = "identity", width = 0.85) +
  geom_vline(data = phase_bounds, aes(xintercept = x),
             linetype = "dashed", colour = "grey30", linewidth = 0.4) +
  facet_grid(fleet ~ Group) +
  scale_fill_manual(values = route_colours, name = NULL, drop = FALSE) +
  scale_x_continuous(breaks = c(2016, 2018, 2020, 2022, 2024),
                     labels = function(x) substr(x, 3, 4)) +
  scale_y_continuous(limits = c(0, 100), expand = c(0, 0),
                     labels = function(x) paste0(x, "%")) +
  labs(title    = "Compliance routing by year — cold (top), warm (middle), all records (bottom)",
       subtitle = "Dashed lines: phase boundaries (Jan 2019; Sep 2020)",
       x = "Year", y = "% of audit records") +
  theme_minimal(base_size = 10) +
  theme(legend.position  = "bottom",
        legend.text      = element_text(size = 8),
        panel.grid.minor = element_blank(),
        axis.text.x      = element_text(angle = 45, hjust = 1),
        strip.text       = element_text(face = "bold")) +
  guides(fill = guide_legend(nrow = 3, reverse = TRUE))

ggsave("260331_routing_stacked.png", p_stacked, width = 13, height = 11, dpi = 150)

cat("\nSaved: 260331_routing_all.png\n")
cat("Saved: 260331_routing_warm.png\n")
cat("Saved: 260331_routing_cold.png\n")
cat("Saved: 260331_routing_stacked.png\n")

sink(); close(log_con)
cat("Log written to: 260331_routing_console.txt\n")
