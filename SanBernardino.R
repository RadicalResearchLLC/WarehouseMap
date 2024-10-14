##Warehouse Map App V1
##Created by Mike McCarthy, Radical Research LLC
##San Bernardino County Data Import and Processing Steps
##First created July, 2023
##Last modified September, 2024

library(tidyverse)
library(sf)

SBD_dir <- paste0(warehouse_dir, '/SBD_Parcel')
## Data from https://open.sbcounty.gov/datasets/countywide-parcels/about
## Not SBCoPolygons!
## Read and import property record files for San Bernardino County
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
    str_detect(description, 'associated') ~ 'other',
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

partialParcels <- c('111804107', '111804108', '111804109', '111804110',
                  '111804111', '111804113', '111804114', '111804115',
                  '111804116', '111804117', '111804118', '111804119',
                  '111804120', '111804121', '111804122', '024026175',
                  '024018154', '013634172', '014143124', '025508155',
                  '023718113', '023716114', '023713112', '023710141',
                  '023710138', '025601133', '025601110', '045946103',
                  '045946104', '045946102', '045946127', '029207219',
                  '013635112', '026002153', '026002142', '012815141',
                  '024023136', '023418109', '023617202', '023617193',
                  '023713126', '023713127', '023712219', '023713120',
                  '023710139', '023814410', '023814314', '023814315', 
                  '023811131', '023808144', '023808156', '021127541',
                  '102212109', '102212112', '102242118', '102253112',
                  '102254108', '102246107', '102163103', '102163104', 
                  '102851108', '102851106', '102851105',
                  '025215196', '025215198',
                  '045919310',# VCV site
                  '102610102',#says it is part of state prison?
                  '102708103' # part of majestic chino 
                  )

SBD_warehouse_2 <- SBD_parcels |> 
  filter(APN %in% partialParcels) |> 
  st_transform(crs = 4326) |>
  left_join(SBD_codes, by = c('TYPEUSE' = 'use_code' )) |> 
  mutate(threshold_maybeWH = ifelse(SHAPE_AREA > sq_ft_threshold_maybeWH, 1,0)) |>
  mutate(exclude = ifelse(type == 'warehouse', 0,
                          ifelse(threshold_maybeWH == 1, 0, 1))) |>
  mutate(type = as.factor(type))

#assd_parcels <- SBD_parcels |> 
#  left_join(SBD_codes, by = c('TYPEUSE' = 'use_code' )) |> 
#  filter(TYPEUSE == 3) |> 
#  st_transform(crs = 4326)

#FIXME - draw Amazon Air Hub

## add year built and county columns
## select key columns
narrow_SBDCo_parcels <- SBD_warehouse_ltInd |>
  bind_rows(SBD_warehouse_2) |> 
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

SBD_airhub <- sf::st_read(dsn = 'SBD_AmazonAirHub.geojson') |> 
  st_transform(crs = 4326) |> 
  rename(apn = name) |> 
  mutate(class = 'aviation warehouse',
         year_built = 2020,
         county = 'San Bernardino',
         type = 'warehouse',
         shape_area = 4229700)

narrow_SBDCo_parcels2 <- compare |> 
  mutate(year_built2 = ifelse(is.na(year_built), year_base, year_built)) |> 
  dplyr::select(apn, shape_area, class, type, geometry, year_built2, county) |> 
  rename(year_built = year_built2) |> 
  filter(apn %ni% not_warehouse) |> 
  bind_rows(SBD_airhub)

rm(ls = DataTree, compare, narrow_SBDCo_parcels, noYearValue, SBD_codes, SBD_parcels,
   SBD_warehouse_ltInd, wYearValue, SBD_warehouse_2, SBD_airhub)


setwd(wd)
