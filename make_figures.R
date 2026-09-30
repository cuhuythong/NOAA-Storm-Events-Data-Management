# Load packages
suppressPackageStartupMessages({
  library(DBI); library(RSQLite); library(dplyr); library(readr); library(ggplot2); library(forcats); library(scales)
})

# Create output folders for tables and figures
dir.create("tables", showWarnings = FALSE)
dir.create("figures", showWarnings = FALSE)

# Connect to database
con <- dbConnect(SQLite(), "output/storm_events_2016_2025.sqlite")
on.exit(dbDisconnect(con), add = TRUE)

# Format function
format_table <- function(df) {
  df |>
    mutate(
      across(c(events, fatalities), ~ comma(.x)),
      across(c(damage), ~ comma(.x)),
      across(c(damage_billion), ~ comma(.x, accuracy = 0.1))
    )
}

# Monthly summary table
monthly <- dbGetQuery(con, "
  SELECT
    month_num,
    begin_month AS month,
    COUNT(*) AS events,
    SUM(deaths_direct + deaths_indirect) AS fatalities,
    SUM(damage_property + damage_crops) AS damage
  FROM storm_events
  GROUP BY month_num, begin_month
  ORDER BY month_num
") |> mutate(damage_billion = damage / 1e9)
write_csv(format_table(monthly), "tables/monthly_summary.csv")

# Event-type summary table
event_type <- dbGetQuery(con, "
  SELECT
    event_type,
    COUNT(*) AS events,
    SUM(deaths_direct + deaths_indirect) AS fatalities,
    SUM(damage_property + damage_crops) AS damage
  FROM storm_events
  GROUP BY event_type
  ORDER BY events DESC
") |> mutate(damage_billion = damage / 1e9)
write_csv(format_table(event_type), "tables/event_type_summary.csv")

# State summary table
state <- dbGetQuery(con, "
  SELECT
    state,
    COUNT(*) AS events,
    SUM(deaths_direct + deaths_indirect) AS fatalities,
    SUM(damage_property + damage_crops) AS damage
  FROM storm_events
  GROUP BY state
  ORDER BY events DESC
") |> mutate(damage_billion = damage / 1e9)
write_csv(format_table(state), "tables/state_summary.csv")

# Yearly summary table
yearly <- dbGetQuery(con, "
  SELECT
    year,
    COUNT(*) AS events,
    SUM(deaths_direct + deaths_indirect) AS fatalities,
    SUM(damage_property + damage_crops) AS damage
  FROM storm_events
  GROUP BY year
  ORDER BY year
") |> mutate(damage_billion = damage / 1e9)
write_csv(format_table(yearly), "tables/yearly_summary.csv")

# Aug–Sep event-type damage table
aug_sep <- dbGetQuery(con, "
  SELECT
    event_type,
    COUNT(*) AS events,
    SUM(deaths_direct + deaths_indirect) AS fatalities,
    SUM(damage_property + damage_crops) AS damage
  FROM storm_events
  WHERE month_num IN (8, 9)
  GROUP BY event_type
  ORDER BY damage DESC
  LIMIT 5
") |> mutate(damage_billion = damage / 1e9)

# States with largest Flash Flood and Hurricane damage
ff_hurricane_state_damage <- dbGetQuery(con, "
  SELECT
    state,
    event_type,
    COUNT(*) AS events,
    SUM(deaths_direct + deaths_indirect) AS fatalities,
    SUM(damage_property + damage_crops) AS damage
  FROM storm_events
  WHERE event_type IN ('Flash Flood', 'Hurricane (Typhoon)')
  GROUP BY state, event_type
  ORDER BY damage DESC
") |> mutate(damage_billion = damage / 1e9)
write_csv(format_table(ff_hurricane_state_damage),
  'tables/state_flash_flood_hurricane_damage.csv')

# States with largest fatalities from Excessive Heat and Heat
heat_state_fatalities <- dbGetQuery(con, "
  SELECT
    state,
    event_type,
    COUNT(*) AS events,
    SUM(deaths_direct + deaths_indirect) AS fatalities,
    SUM(damage_property + damage_crops) AS damage
  FROM storm_events
  WHERE event_type IN ('Excessive Heat', 'Heat')
  GROUP BY state, event_type
  ORDER BY fatalities DESC
") |> mutate(damage_billion = damage / 1e9)
write_csv(format_table(heat_state_fatalities),
  'tables/state_excessive_heat_heat_fatalities.csv')

# Function for monthly line plots
line_plot_month <- function(df, y, title, ylab, file) {
  p <- ggplot(df, aes(x = month_num, y = {{y}}, group = 1)) +    
    # Blue line and points
    geom_line(linewidth = 1, color = "blue") +
    geom_point(size = 2.5, color = "blue") +    
    # Proper month labels
    scale_x_continuous(breaks = 1:12, labels = month.abb) +
    # Titles and labels
    labs(title = title, x = "Month", y = ylab) +
    # Theme with outline frame
    theme_minimal(base_size = 12) +
    theme(
      plot.title = element_text(hjust = 0.5, face = "bold"), 
      panel.border = element_rect(color = "black", fill = NA, linewidth = 0.8),
      axis.title.x = element_text(margin = margin(t = 8)),
      axis.title.y = element_text(margin = margin(r = 8))
    )
  ggsave(file, plot = p, width = 7.5, height = 4.2, dpi = 200)
}

# Function for yearly line plots
line_plot_year <- function(df, y, title, ylab, file) {
  p <- ggplot(df, aes(x = year, y = {{y}}, group = 1)) +
    geom_line(linewidth = 1, color = "blue") +
    geom_point(size = 2.5, color = "blue") +
    scale_x_continuous(breaks = 2016:2025, labels = 2016:2025) +
    labs(title = title, x = "Year", y = ylab) +
    theme_minimal(base_size = 12) +
    theme(
      plot.title = element_text(hjust = 0.5, face = "bold"),
      panel.border = element_rect(color = "black", fill = NA, linewidth = 0.8),
      panel.grid.minor = element_blank(),
      axis.text.x = element_text(angle = 45, hjust = 1)
    )
  ggsave(file, plot = p, width = 7.5, height = 4.2, dpi = 200)
}

# Function for bar plots
bar_plot <- function(df, x, y, title, xlab, ylab, file) {
  p <- ggplot(df, aes(x = {{x}}, y = fct_reorder({{y}}, {{x}}))) +
    geom_col(fill = "blue") +
    labs(title = title, x = xlab, y = ylab) +
    theme_minimal(base_size = 12) +
    theme(
      plot.title = element_text(hjust = 0.5, face = "bold"),   
      panel.border = element_rect(color = "black", fill = NA, linewidth = 0.8),  
      panel.grid.minor = element_blank()
    )
  ggsave(file, plot = p, width = 7.5, height = 4.6, dpi = 200)
}

# Monthly plots
line_plot_month(
  monthly, 
  events, 
  "Number of storm-event records by month, 2016-2025", 
  "Number of events", 
  "figures/fig02_monthly_events.png")

line_plot_month(
  monthly, 
  fatalities, 
  "Fatalities by month, 2016-2025", 
  "Total fatalities", 
  "figures/fig03_monthly_fatalities.png")

line_plot_month(
  monthly, 
  damage_billion, 
  "Reported damage by month, 2016-2025", 
  "Damage (billion dollars)", 
  "figures/fig04_monthly_damage.png")

# Aug–Sep damage plot
bar_plot(
  aug_sep,
  damage_billion,
  event_type,
  "Event types driving high August and September losses",
  "Damage in Aug and Sep (billion dollars)",
  "Event type",
  "figures/fig05_aug_sep_event_damage.png")

# Event-type plots
bar_plot(
  slice_max(event_type, events, n = 10),
  events,
  event_type,
  "Most frequent event types, 2016-2025",
  "Number of events",
  "Event type",
  "figures/fig06_event_frequency.png")

bar_plot(
  slice_max(event_type, damage_billion, n = 10),
  damage_billion,
  event_type,
  "Largest damage by event type, 2016-2025",
  "Damage (billion dollars)",
  "Event type",
  "figures/fig07_event_damage.png")

bar_plot(
  slice_max(event_type, fatalities, n = 10),
  fatalities,
  event_type,
  "Largest fatalities by event type, 2016-2025",
  "Total fatalities",
  "Event type",
  "figures/fig08_event_fatalities.png")

# State plots
bar_plot(
  slice_max(state, events, n = 10),
  events,
  state,
  "Top states by storm-event count, 2016-2025",
  "Number of events",
  "State",
  "figures/fig09_state_events.png")

bar_plot(
  slice_max(state, damage_billion, n = 10),
  damage_billion,
  state,
  "Top states by reported storm damage, 2016-2025",
  "Damage (billion dollars)",
  "State",
  "figures/fig10_state_damage.png")

bar_plot(
  slice_max(state, fatalities, n = 10),
  fatalities,
  state,
  "Top states by fatalities, 2016-2025",
  "Total fatalities",
  "State",
  "figures/fig11_state_fatalities.png")

# Yearly plots
line_plot_year(
  yearly, 
  events, 
  "Yearly storm-event counts, 2016-2025", 
  "Number of events", 
  "figures/fig12_year_events.png")

line_plot_year(
  yearly, 
  fatalities, 
  "Yearly storm fatalities, 2016-2025", 
  "Total fatalities", 
  "figures/fig13_year_fatalities.png")

line_plot_year(
  yearly, 
  damage_billion, 
  "Yearly reported storm damage, 2016-2025", 
  "Damage (billion dollars)", 
  "figures/fig14_year_damage.png")

