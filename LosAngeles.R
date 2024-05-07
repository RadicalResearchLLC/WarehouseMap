##Warehouse Map App V1
##Created by Mike McCarthy, Radical Research LLC
##Inspired by Graham Brady and Susan Phillips at Pitzer College and their code
##located here: https://docs.google.com/document/d/16Op4GgmK0A_0mUHAf9qqXzT_aekbdLb_ZFtBaZKfj6w/edit
##First created May, 2022
##Last modified  July, 2023
##This script preprocesses LA shapefile data because it is very slow and 
##this is intended to avoid having to do it multiple times since it only updates quarterly
##Also now removes duplicate location APN parcels (~893 APNs)

#rm(list =ls()) # clear environment
#'%ni%' <- Negate('%in%') ## not in operator
gc()

## Probably only need these three libraries
library(tidyverse)
library(sf)
library(janitor)

##set working, data, and app directories
#wd <- getwd()
#warehouse_dir <- paste0(wd, '/Warehouse_data')
LA_raw <- paste0(warehouse_dir, '/LACounty_Parcels.gdb')
LA_tidy <- paste0(warehouse_dir, '/LAfiltered_shp')
#LA_raw2 <- paste0(warehouse_dir, '/LACounty.gdb')

## Import the data

#Set minimum size for analysis in thousand sq.ft. for non-warehouse classified
#sq_ft_threshold <- 28000

#Import raw LA County parcel data
sf::st_layers(dsn = LA_raw)
LA_parcels <- sf::st_read(dsn = LA_raw, quiet = TRUE, type = 3)
#LA_parcels_row1 <- sf::st_read(dsn = paste0(warehouse_dir, '/Assessor_Parcel_Data.csv'),
#                              query = 'SELECT * FROM "Assessor_Parcel_Data" WHERE FID = 1')
# land-use codes 3300, 3310, 3320, 3330, 3340, possibly 1340
# open storage = 3900

# UseCode_2 is 33 and UseDescription is 'Warehousing, Distribution, Storage' are identical
# Open storage is NOT included - useCode 39
## FIXME - need to check on generic industrial parcels 'NA' use_code_3rd_digit and 
# 'Industrial' use_code_2nd_digit

LA_2021_present_rolls <- read_csv(paste0(warehouse_dir, '/Parcel_data_2021_Table_8468414499611436475.csv'),
                                  col_types = 'cccncc?' ) |> 
  janitor::clean_names()  |> 
  filter(use_code_2nd_digit == 'Warehousing, Distribution, Storage') |> 
  filter(use_code_3rd_digit %in% c('Warehousing, Distribution, Under 10,000 SF',
                                   'Warehousing, Distribution, 10,000 to 24,999 SF',
                                   'Warehousing, Distribution, 25,000 to 50,000 SF',
                                   'Warehousing, Distribution, Over 50,000 SF')) |> 
  filter(roll_year == 2023)

gc()

# use license and terms - and citation guidelines
## https://egis-lacounty.hub.arcgis.com/pages/terms-of-use

LA_warehouse_parcels1 <- LA_parcels |> 
  filter(UseDescription == 'Warehousing, Distribution, Storage') |> 
  st_transform(crs = 4326) |>
  st_make_valid() |> 
  janitor::clean_names() |> 
  select(ain, apn, year_built1, use_code, use_code_2, use_description, shape_area,
         Shape) 
  
names(LA_warehouse_parcels1)

LA_warehouse_parcels2 <- LA_parcels |> 
  inner_join(LA_2021_present_rolls, by = c('AIN' = 'ain')) |> 
  st_transform(crs = 4326) |> 
  st_make_valid()

## FIXME - right now I trust LA warehouse parcels 2 more as a conservative estimate
## FIXME - need to develop an app to go parcel by parcel on the 12,000 generic industrial parcels in LA.

rm(ls = LA_parcels)
gc()
pryr::mem_used()

#Tidy the dataset but don't filter on size yet
LA_industrial_parcels <- LA_warehouse_parcels2 %>%
  #filter(UseType == 'Industrial') %>%
  mutate(type = ifelse(str_detect(str_to_lower(UseDescription), 'warehous'), 'warehouse', 
                       ifelse(str_detect(str_to_lower(UseDescription), 'industrial'), 'industrial', 'other')
  )
  ) %>%
  #filter(Shape_Area >= sq_ft_threshold) %>% 
  select(APN, YearBuilt1, Shape_Area, type, Shape, UseDescription, 
         #SitusAddress, SitusCity, SitusZIP
         ) %>%
  janitor::clean_names() %>%
  mutate(year_built = as.numeric(year_built1),
         class=use_description) %>%
  mutate(year_built = ifelse(is.na(year_built), 1910, 
                             ifelse(year_built < 1911, 1910, year_built))
  ) %>%
  select(apn, shape_area, class, type, year_built, Shape, 
         #situs_address, situs_city, situs_zip
         ) %>%
  st_transform(crs = 4326) |> 
  st_make_valid()

rm(ls = LA_warehouse_parcels1, LA_warehouse_parcels2)
gc()

Geo_only <- LA_industrial_parcels |> 
  select(Shape)

sf_use_s2(FALSE)

uniqueParcel <- Geo_only |> 
  unique.data.frame() |> 
  mutate(row = row_number()) |> 
  st_make_valid()

LA_interMulti <- uniqueParcel |> 
  st_join(LA_industrial_parcels, join = st_equals) |> 
  st_set_geometry(value = NULL) |> 
  group_by(row) |>
  summarize(count = n()) |> 
  filter(count > 1) |> 
  left_join(uniqueParcel, by = 'row') |> 
  st_as_sf()

LA_unique <- uniqueParcel |> 
  st_join(LA_industrial_parcels, join = st_equals) |> 
  st_set_geometry(value = NULL) |> 
  group_by(row) |>
  summarize(count = n()) |> 
  filter(count == 1) |> 
  left_join(uniqueParcel, by = 'row') |> 
  st_as_sf() |> 
  st_join(LA_industrial_parcels, join = st_equals) |> 
  select(-row) |> 
  filter(!is.na(apn))
 
LA_Multi <- LA_interMulti |> 
  st_join(LA_industrial_parcels, join = st_equals) |> 
  group_by(row, count, Shape, shape_area, class, type) |> 
  summarize(apn = first(apn), year_built = min(year_built), .groups = 'drop') |> 
  select(-row)

final_LA <- bind_rows(LA_unique, LA_Multi)

st_geometry(final_LA) <- 'geometry'

narrow_LA_parcels <- final_LA |> 
  mutate(type = as.factor(type), county = 'Los Angeles')

LA_noAPN <- uniqueParcel |> 
  st_join(LA_industrial_parcels, join = st_equals) |> 
  st_set_geometry(value = NULL) |> 
  group_by(row) |>
  summarize(count = n()) |> 
  filter(count == 1) |> 
  left_join(uniqueParcel, by = 'row') |> 
  st_as_sf() |> 
  st_join(LA_industrial_parcels, join = st_equals) |> 
  #select(row) |> 
  filter(is.na(apn))

LA_noAPN2 <- LA_noAPN |> 
  select(row, Shape) |> 
  st_make_valid() |>
  st_join(LA_industrial_parcels, join = st_contains)

rm(ls = LA_geometry, LA_industrial_parcels_10k,
   LA_parcels_precise, unique2, Geo_only, LA_warehouse_parcels,
   LA_industrial_parcels, LA_Multi, LA_unique, LA_interMulti, final_LA, uniqueParcel)  
rm(ls = LA_noAPN, LA_noAPN2, noAPN, LA_use_type_code)
   
setwd(LA_tidy)
unlink('LA_filtered_parcels.shp')
st_write(narrow_LA_parcels, 'LA_filtered_parcels.shp')
#st_write(final_LA, 'LA_address.geojson')

setwd(wd)

