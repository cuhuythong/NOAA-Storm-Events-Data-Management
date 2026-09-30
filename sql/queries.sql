-- Monthly summaries
SELECT
  month_num,
  begin_month AS month,
  COUNT(*) AS events,
  SUM(deaths_direct + deaths_indirect) AS fatalities,
  SUM(damage_property + damage_crops) AS damage
FROM storm_events
GROUP BY month_num, begin_month
ORDER BY month_num;

-- Event-type summaries
SELECT
  event_type,
  COUNT(*) AS events,
  SUM(deaths_direct + deaths_indirect) AS fatalities,
  SUM(damage_property + damage_crops) AS damage
FROM storm_events
GROUP BY event_type
ORDER BY events DESC;

-- Event types driving Aug-Sep damage
SELECT
  event_type,
  COUNT(*) AS events,
  SUM(deaths_direct + deaths_indirect) AS fatalities,
  SUM(damage_property + damage_crops) AS damage
FROM storm_events
WHERE month_num IN (8, 9)
GROUP BY event_type
ORDER BY damage DESC
LIMIT 5;

-- State summaries
SELECT
  state,
  COUNT(*) AS events,
  SUM(deaths_direct + deaths_indirect) AS fatalities,
  SUM(damage_property + damage_crops) AS damage
FROM storm_events
GROUP BY state
ORDER BY events DESC;

-- States with largest Flash Flood and Hurricane (Typhoon) damage
SELECT
    state,
    event_type,
    COUNT(*) AS events,
    SUM(deaths_direct + deaths_indirect) AS fatalities,
    SUM(damage_property + damage_crops) AS damage
FROM storm_events
WHERE event_type IN ('Flash Flood', 'Hurricane (Typhoon)')
GROUP BY state, event_type
ORDER BY damage DESC;

-- States with largest fatalities from Excessive Heat and Heat
SELECT
    state,
    event_type,
    COUNT(*) AS events,
    SUM(deaths_direct + deaths_indirect) AS fatalities,
    SUM(damage_property + damage_crops) AS damage
FROM storm_events
WHERE event_type IN ('Excessive Heat', 'Heat')
GROUP BY state, event_type
ORDER BY fatalities DESC;

-- Yearly summaries
SELECT
  year,
  COUNT(*) AS events,
  SUM(deaths_direct + deaths_indirect) AS fatalities,
  SUM(damage_property + damage_crops) AS damage
FROM storm_events
GROUP BY year
ORDER BY year;
