##Warehouse Map App V1
##Created by Mike McCarthy, Radical Research LLC
##Riverside County Data Import and Processing Steps
##First created July, 2023
##Last modified December, 2023

library(tidyverse)
library(sf)

# Data from https://rcitgis-countyofriverside.hub.arcgis.com/pages/6bfb06af75af4addbf79b8cb421facb9
RivCo1_dir <- paste0(warehouse_dir, '/CREST_tables.gdb')
RivCo2_dir <- paste0(warehouse_dir, '/ParcelAttributed.gdb')


##Import parcels and property record files for Riverside County
##st_read(type=1) is attempting to create the same sfc type for both counties
##FIXME - crest property just a table?
crest_property <- sf::st_read(dsn = RivCo1_dir, layer = 'CREST_PROPERTY_CHAR')
parcels <- sf::st_read(dsn = RivCo2_dir, layer = 'PARCELS_CREST', quiet = TRUE, type = 3)
#class(st_geometry(parcels))

######Tidy up the data for use
##select just property number and year built for riverside county CREST
crest_property_slim <- crest_property |>
  dplyr::select(PIN, YEAR_BUILT) |>
  dplyr::distinct()

crest_property_dups <- crest_property_slim |>
  select(PIN) |>
  group_by(PIN) |>
  summarize(count = n()) |>
  filter(count > 1) |>
  left_join(crest_property_slim) |>
  mutate(unk = ifelse(is.na(YEAR_BUILT), 1,
                      ifelse(YEAR_BUILT < 1911, 1, 0))) |>
  filter(unk == 0) |>
  group_by(PIN) |>
  reframe(PIN, YEAR_BUILT = min(YEAR_BUILT), .groups = 'drop') |>
  unique()

crest_property_dups2 <- crest_property_slim |>
  select(PIN) |>
  group_by(PIN) |>
  summarize(count = n()) |>
  filter(count > 1) |>
  left_join(crest_property_dups) 

crest_property_solo <- crest_property_slim |>
  dplyr::select(PIN) |>
  group_by(PIN) |>
  summarize(count = n(), .groups = 'drop') |>
  filter(count == 1) |>
  left_join(crest_property_slim)

crest_property_tidy <- bind_rows(crest_property_solo, crest_property_dups2)

##filter on warehouses and light-industrial for Riverside County
##transform coordinates from Northing-Easting to Lat-Long
parcels_warehouse <- parcels |>
  mutate(class = stringr::str_to_lower(CLASS_CODE)) |>
  filter(str_detect(class, 'warehouse')) |>
  st_transform(crs = 4326)

source(paste0(wd, '/QA_list2.R'))

parcels_manual_wh <- parcels |> 
  mutate(class = stringr::str_to_lower(CLASS_CODE)) |>
  filter(APN %in% add_as_warehouse) |>
  st_transform(crs = 4326)

parcels_lightIndustry <- parcels |>
  mutate(class = stringr::str_to_lower(CLASS_CODE)) |>
  filter(str_detect(class, 'light industrial')) |>
  filter(SHAPE_Area > sq_ft_threshold_maybeWH) |>
  st_transform(crs = 4326)

##Bind two Riv.co. datasets together
##Create a type category for the warehouse and industrial designation parcels

parcels_join_yr <- bind_rows(parcels_warehouse, parcels_lightIndustry, parcels_manual_wh) |>
  left_join(crest_property_tidy, by =c('APN' = 'PIN')) |>
  unique() |>
  mutate(YEAR_BUILT = ifelse(is.na(YEAR_BUILT), 1776, YEAR_BUILT)) |>
  mutate(type = as.factor(ifelse(str_detect(class, 'warehouse'), 'warehouse', 'other')))

##combine spatial data frames for display
##Select and rename columns to make everything match
##Note that we can always add other columns if they are useful for display 
narrow_RivCo_parcels <- parcels_join_yr |>
  dplyr::select(APN, SHAPE_Area, class, type, SHAPE, YEAR_BUILT) |>
  janitor::clean_names() |>
  st_cast(to = 'POLYGON') |> 
  mutate(county = 'Riverside') |> 
  filter(apn %ni% not_warehouse)

st_geometry(narrow_RivCo_parcels) <- 'geometry'

#narrow_RivCo_parcels <- rename_geometry(narrow_RivCo_parcels, 'geometry') |>
#  mutate(county = 'Riverside')
names(narrow_RivCo_parcels)

rm(ls = crest_property, crest_property_dups, crest_property_dups2, crest_property_slim)
rm(ls = crest_property_solo, crest_property_tidy, parcels, parcels_join_yr, parcels_manual_wh,
   parcels_warehouse, parcels_lightIndustry)
