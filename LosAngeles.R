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
'%ni%' <- Negate('%in%') ## not in operator
gc()

## Probably only need these three libraries
library(tidyverse)
library(sf)
library(janitor)

##set working, data, and app directories
wd <- getwd()
app_dir <- paste0(wd, '/WarehouseCITY')
warehouse_dir <- paste0(wd, '/Warehouse_data')
output_dir <- paste0(wd, '/exports_other')
## Raw parcel data from https://data.lacounty.gov/documents/4d67b154ae614d219c58535659128e71/about

LA_raw <- paste0(warehouse_dir, '/LACounty_Parcels.gdb')
LA_tidy <- paste0(warehouse_dir, '/LAfiltered_shp')
#LA_raw2 <- paste0(warehouse_dir, '/LACounty.gdb')

## Import the data

#Set minimum size for analysis in thousand sq.ft. for non-warehouse classified
#sq_ft_threshold <- 28000


#LA_parcels_row1 <- sf::st_read(dsn = paste0(warehouse_dir, '/Assessor_Parcel_Data.csv'),
#                              query = 'SELECT * FROM "Assessor_Parcel_Data" WHERE FID = 1')
# land-use codes 3300, 3310, 3320, 3330, 3340, possibly 1340
# open storage = 3900

# UseCode_2 is 33 and UseDescription is 'Warehousing, Distribution, Storage' are identical
# Open storage is NOT included - useCode 39

##### Lines 46 through 70 commented out because they are not needed
#LA_2021_present_geojson <- sf::st_read(paste0(warehouse_dir, '/Parcel_Data_2021_LACounty.geojson')) |>
  #janitor::clean_names() #|> 
#  filter(RollYear == 2024) |> 
#  dplyr::filter(UseCodeDescChar3 %in% c('Warehousing, Distribution, Under 10,000 SF',
#                                 'Warehousing, Distribution, 10,000 to 24,999 SF',
#                                 'Warehousing, Distribution, 25,000 to 50,000 SF',
#                                 'Warehousing, Distribution, Over 50,000 SF')) |> 
#  select(AIN, RollYear, UseType, UseCodeDescChar3, UseCode, YearBuilt) |> 
#  st_set_geometry(value = NULL)
  #st_collection_extract('POLYGON') 

#category_check <- sf::st_read(paste0(warehouse_dir, '/Parcel_Data_2021_LACounty.geojson')) |>
  #janitor::clean_names() #|> 
#  filter(RollYear == 2024) |> 
#  filter(UseCodeDescChar2 == 'Warehousing, Distribution, Storage') |> 
#  select(AIN, RollYear, UseType, UseCodeDescChar3, UseCode, YearBuilt) |> 
#  st_set_geometry(value = NULL) |> 
#  group_by(UseCode, UseCodeDescChar3) |> 
#  summarize(count = n(), .groups ='drop')

#categories1 <- LA_2021_present_geojson |>
#  group_by(UseCode, UseCodeDescChar3) |> 
#  summarize(count = n(), .groups = 'drop')

#gc()

#Import raw LA County parcel data
sf::st_layers(dsn = LA_raw)
LA_parcels <- sf::st_read(dsn = LA_raw, quiet = TRUE, type = 3)

# use license and terms - and citation guidelines
## https://egis-lacounty.hub.arcgis.com/pages/terms-of-use

LA_warehouse_parcels1 <- LA_parcels |> 
  filter(UseDescription == 'Warehousing, Distribution, Storage') |> 
   st_transform(crs = 4326) |>
  st_make_valid() |> 
  janitor::clean_names() |> 
  select(ain, apn, year_built1, use_code, use_code_2, use_description, shape_area,
         Shape) 

LA_warehouse_parcels <- LA_warehouse_parcels1 |> 
  mutate(use_code3 = str_sub(use_code, 1, 3)) |> 
  filter(use_code3 %ni% c('334', '335', '33T')) |> 
  select(ain, year_built1, use_code, use_description, shape_area, Shape) |> 
  rename(apn = ain,
         year_built = year_built1,
         class = use_description) |> 
  mutate(type = 'warehouse') |> 
  mutate(year_built = ifelse(is.na(year_built), 1910, 
                             ifelse(year_built < 1911, 1910, year_built))
  ) 

gc()

#categories <- LA_warehouse_parcels1 |> 
#  st_set_geometry(value = NULL) |> 
#  group_by(use_code, use_code_2, use_description) |> 
#  summarize(count = n())

#categories2 <- full_join(category_check, categories1, by = c('UseCode'))

## BOTTOM LINE of all this is that the only thing we need is UseCode 330, 331, 332, and 333 series
## Remove all 334 and 335 use codes.

#names(LA_warehouse_parcels1)
#names(LA_2021_present_geojson)

#LA_warehouse_parcels2 <- LA_parcels |> 
#  inner_join(LA_2021_present_geojson, by = c('AIN')) |> 
#  st_transform(crs = 4326) |> 
#  st_make_valid() |> 
#  janitor::clean_names() |> 
#  select(ain, apn, year_built, use_code_x, use_code_2, use_description, shape_area,
#         Shape) 

## FIXME - right now I trust LA warehouse parcels 2 more as a conservative estimate
## FIXME - need to develop an app to go parcel by parcel on the 12,000 generic industrial parcels in LA.

rm(ls = LA_parcels, LA_warehouse_parcels1)
gc()

#Tidy the dataset but don't filter on size yet
#LA_industrial_parcels <- LA_warehouse_parcels2  |> 
  #filter(UseType == 'Industrial') |> 
#  mutate(type = ifelse(str_detect(str_to_lower(use_description), 'warehous'), 'warehouse', 
#                       ifelse(str_detect(str_to_lower(use_description), 'industrial'), 'industrial', 'other')
#  )
#  ) |> 
  #filter(Shape_Area >= sq_ft_threshold) |>  
#  select(ain, year_built, shape_area, type, Shape, use_description, 
         #SitusAddress, SitusCity, SitusZIP
#         ) |> 
#  mutate(year_built = as.numeric(year_built),
#         class=use_description) |> 
#  mutate(year_built = ifelse(is.na(year_built), 1910, 
#                             ifelse(year_built < 1911, 1910, year_built))
#  ) |> 
#  select(ain, shape_area, class, type, year_built, Shape, 
         #situs_address, situs_city, situs_zip
#         ) |> 
#  st_transform(crs = 4326) |> 
#  st_make_valid() |> 
#  rename(apn = ain)

#rm(ls = LA_warehouse_parcels1, LA_warehouse_parcels2)
gc()

Geo_only <- LA_warehouse_parcels |> 
  select(Shape)

sf_use_s2(FALSE)

uniqueParcel <- Geo_only |> 
  unique.data.frame() |> 
  mutate(row = row_number()) |> 
  st_make_valid()

LA_interMulti <- uniqueParcel |> 
  st_join(LA_warehouse_parcels, join = st_equals) |> 
  st_set_geometry(value = NULL) |> 
  group_by(row) |>
  summarize(count = n()) |> 
  filter(count > 1) |> 
  left_join(uniqueParcel, by = 'row') |> 
  st_as_sf()

LA_unique <- uniqueParcel |> 
  st_join(LA_warehouse_parcels, join = st_equals) |> 
  st_set_geometry(value = NULL) |> 
  group_by(row) |>
  summarize(count = n()) |> 
  filter(count == 1) |> 
  left_join(uniqueParcel, by = 'row') |> 
  st_as_sf() |> 
  st_join(LA_warehouse_parcels, join = st_equals) |> 
  select(-row) |> 
  filter(!is.na(apn))
 
LA_Multi <- LA_interMulti |> 
  st_join(LA_warehouse_parcels, join = st_equals) |> 
  group_by(row, count, Shape, shape_area, class, type) |> 
  summarize(apn = first(apn), year_built = min(year_built), .groups = 'drop') |> 
  select(-row)

final_LA <- bind_rows(LA_unique, LA_Multi)

st_geometry(final_LA) <- 'geometry'

narrow_LA_parcels <- final_LA |> 
  mutate(type = as.factor(type), county = 'Los Angeles')

LA_noAPN <- uniqueParcel |> 
  st_join(LA_warehouse_parcels, join = st_equals) |> 
  st_set_geometry(value = NULL) |> 
  group_by(row) |>
  summarize(count = n()) |> 
  filter(count == 1) |> 
  left_join(uniqueParcel, by = 'row') |> 
  st_as_sf() |> 
  st_join(LA_warehouse_parcels, join = st_equals) |> 
  #select(row) |> 
  filter(is.na(apn))

LA_noAPN2 <- LA_noAPN |> 
  select(row, Shape) |> 
  st_make_valid() |>
  st_join(LA_warehouse_parcels, join = st_contains)

rm(ls = LA_geometry, LA_industrial_parcels_10k,
   LA_parcels_precise, unique2, Geo_only, LA_warehouse_parcels,
   LA_industrial_parcels, LA_Multi, LA_unique, LA_interMulti, final_LA, uniqueParcel)  
rm(ls = LA_noAPN, LA_noAPN2, noAPN, LA_use_type_code)
   
setwd(LA_tidy)
unlink('LA_filtered_parcels.shp')
st_write(narrow_LA_parcels, 'LA_filtered_parcels.shp')
#st_write(final_LA, 'LA_address.geojson')

setwd(wd)

