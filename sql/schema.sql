DROP TABLE IF EXISTS storm_events;
DROP TABLE IF EXISTS dim_year;
DROP TABLE IF EXISTS dim_state;
DROP TABLE IF EXISTS dim_event_type;

-- Create the main table storing all storm event records
CREATE TABLE storm_events (
  event_id INTEGER PRIMARY KEY,
  year INTEGER NOT NULL,
  begin_month TEXT,
  month_num INTEGER,
  state TEXT,
  event_type TEXT,
  deaths_direct INTEGER DEFAULT 0,
  deaths_indirect INTEGER DEFAULT 0,
  damage_property REAL DEFAULT 0,
  damage_crops REAL DEFAULT 0
);

-- Create indexes to speed up queries
CREATE INDEX IF NOT EXISTS idx_storm_year ON storm_events(year);
CREATE INDEX IF NOT EXISTS idx_storm_month ON storm_events(month_num);
CREATE INDEX IF NOT EXISTS idx_storm_state ON storm_events(state);
CREATE INDEX IF NOT EXISTS idx_storm_event_type ON storm_events(event_type);
