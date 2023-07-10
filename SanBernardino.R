##Warehouse Map App V1
##Created by Mike McCarthy, Radical Research LLC
##San Bernardino County Data Import and Processing Steps
##First created July, 2023
##Last modified July, 2023

library(tidyverse)
library(sf)

SBD_dir <- paste0(warehouse_dir, '/SBD_Parcel')

##Read and import property record files for San Bernadino County
sf::st_layers(dsn = SBD_dir)
SBD_parcels <- sf::st_read(dsn=SBD_dir, quiet = TRUE, type = 3)
#class(st_geometry(SBD_parcels))

##parse SBD data codes
setwd(warehouse_dir)
SBD_codes <- readxl::read_excel('Assessor Use Codes 05-21-2012.xls') |>
  janitor::clean_names() |>
  mutate(description = str_to_lower(description),
         use_code = as.numeric(use_code)) |>
  mutate(type = case_when(
    str_detect(description, 'warehouse') ~ 'warehouse',
    str_detect(description, 'light industrial') ~'other',
    str_detect(description, 'flex') ~ 'other',
    str_detect(description, 'storage') ~ 'other',
    TRUE ~ 'Unselected'
  )) |>
  filter(type %in% c('warehouse', 'other'))  |>
  rename(class = description) |>
  filter(class %ni% c('retail warehouse', 'lumber storage', 'mini storage (public)',
                      'storage yard', 'auto storage yard', 'boat storage yard', 
                      'grain storage', 'potato storage', 'bulk fertilizer storage',
                      'mini-storage warehouse')) #|>

##Filter SBDCO data by warehouse and light industrial, filter by size threshold
##Fix coordinate projection
SBD_warehouse_ltInd <- inner_join(SBD_parcels, SBD_codes, by = c('TYPEUSE' = 'use_code' )) |>
  mutate(threshold_maybeWH = ifelse(SHAPE_AREA > sq_ft_threshold_maybeWH, 1,0)) |>
  mutate(exclude = ifelse(type == 'warehouse', 0,
                          ifelse(threshold_maybeWH == 1, 0, 1))) |>
  filter(exclude == 0) |>
  st_transform("+proj=longlat +ellps=WGS84 +datum=WGS84") |>
  mutate(type = as.factor(type))


## add year built and county columns
## select key columns
narrow_SBDCo_parcels <- SBD_warehouse_ltInd |>
  mutate(year_built = BASE_YEAR) |>
  dplyr::select(APN, SHAPE_AREA, class, type, geometry, year_built) |>
  janitor::clean_names() |>
  mutate(county = 'San Bernardino')

# Import DataTree Year_built info
DataTree <- readxl::read_excel('SBDCo_warehouse_list2_Output.xlsx') |> 
  janitor::clean_names() |> 
  select(apn_formatted, apn_unformatted, year_built, year_built_effective)

#identify and fix bad year built parcels for SBDCo
noYearValue <- DataTree |> 
  filter(is.na(year_built) | year_built == 0)

wYearValue <- DataTree |> 
  filter(!is.na(year_built)) |> 
  distinct() |> 
  filter(year_built > 1850)

compare <- narrow_SBDCo_parcels |> 
  mutate(apn_formatted = str_c(str_sub(apn, 1, 4), '-',
                               str_sub(apn, 5, 7), '-',
                               str_sub(apn, 8, 9), '-',
                               '0000')) |>
  rename(year_base = year_built) |> 
  left_join(wYearValue, by = 'apn_formatted') |> 
  mutate(diff_yr = year_built - year_base) #|> 

narrow_SBDCo_parcels2 <- compare |> 
  mutate(year_built2 = ifelse(is.na(year_built), year_base, year_built)) |> 
  dplyr::select(apn, shape_area, class, type, geometry, year_built2, county) |> 
  rename(year_built = year_built2)

rm(ls = DataTree, compare, narrow_SBDCo_parcels, noYearValue, SBD_codes, SBD_parcels,
   SBD_warehouse_ltInd, wYearValue)

setwd(wd)
