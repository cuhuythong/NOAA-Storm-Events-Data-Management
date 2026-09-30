options(repos = c(CRAN = "https://cloud.r-project.org"))

# Lists required packages
packages <- c("janitor","DBI","RSQLite","dplyr","readr","ggplot2","forcats","scales","stringr")

installed <- rownames(installed.packages())

# Install missing packages and loads them
for (p in packages) {
  if (!(p %in% installed)) install.packages(p)
  library(p, character.only = TRUE)
}

# Load packages while hiding startup messages
suppressPackageStartupMessages({
  library(readr)
  library(dplyr)
  library(stringr)
  library(DBI)
  library(RSQLite)
  library(janitor)
})

# Create folder to store downloaded NOAA files
dir.create("data", showWarnings = FALSE)
# Create folder to store the SQLite database
dir.create("output", showWarnings = FALSE)

# Define years and NOAA file URLs
years <- 2016:2025
base_url <- "https://www.ncei.noaa.gov/pub/data/swdi/stormevents/csvfiles"
correction_tag <- function(y) {
  if (y == 2024) "c20260421" else "c20260323"
}
urls <- sprintf("%s/StormEvents_details-ftp_v1.0_d%d_%s.csv.gz", base_url, years, vapply(years, correction_tag, character(1)))
local_files <- file.path("data", basename(urls))

# Download files
for (i in seq_along(urls)) {
  if (!file.exists(local_files[i])) {
    message("Downloading ", basename(local_files[i]))
    download.file(urls[i], local_files[i], mode = "wb", quiet = FALSE)
  }
}

# Convert damage values
parse_damage <- function(x) {
  x <- toupper(trimws(as.character(x)))
  x[x == "" | is.na(x)] <- "0"
  mult <- case_when(
    str_detect(x, "K$") ~ 1e3,
    str_detect(x, "M$") ~ 1e6,
    str_detect(x, "B$") ~ 1e9,
    TRUE ~ 1
  )
  num <- suppressWarnings(as.numeric(str_remove_all(x, "[KMB,]")))
  num[is.na(num)] <- 0
  num * mult
}

# Read and clean one file
read_one <- function(path) {
  read_csv(path, show_col_types = FALSE, progress = FALSE) |>
    clean_names() |>
    transmute(
      event_id = as.integer(event_id),
      year = as.integer(year),
      begin_month = as.character(month_name),
      month_num = as.integer(substr(as.character(begin_yearmonth), 5, 6)),
      state = as.character(state),
      event_type = as.character(event_type),
      deaths_direct = coalesce(as.integer(deaths_direct), 0L),
      deaths_indirect = coalesce(as.integer(deaths_indirect), 0L),
      damage_property = parse_damage(damage_property),
      damage_crops = parse_damage(damage_crops)
    ) |>
    filter(!is.na(event_id), !is.na(year), !is.na(event_type))
}

# Combine all years
storm_events <- bind_rows(lapply(local_files, read_one)) |>
  distinct(event_id, .keep_all = TRUE)

# Connect to SQLite database
con <- dbConnect(SQLite(), "output/storm_events_2016_2025.sqlite")
# Close the database connection when the script ends
on.exit(dbDisconnect(con), add = TRUE)

# Write table
dbExecute(con, "DROP TABLE IF EXISTS storm_events")
dbWriteTable(con, "storm_events", storm_events, overwrite = TRUE)

# Create indexes
dbExecute(con, "CREATE INDEX IF NOT EXISTS idx_storm_year ON storm_events(year)")
dbExecute(con, "CREATE INDEX IF NOT EXISTS idx_storm_month ON storm_events(month_num)")
dbExecute(con, "CREATE INDEX IF NOT EXISTS idx_storm_state ON storm_events(state)")
dbExecute(con, "CREATE INDEX IF NOT EXISTS idx_storm_event_type ON storm_events(event_type)")

# Message to confirm that the database was successfully created
message("Database written to output/storm_events_2016_2025.sqlite")
