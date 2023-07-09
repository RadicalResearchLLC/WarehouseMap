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

LA_warehouse_parcels <- LA_parcels %>%
  filter(UseDescription == 'Warehousing, Distribution, Storage') 

rm(ls = LA_parcels)
gc()
pryr::mem_used()

#Tidy the dataset but don't filter on size yet
LA_industrial_parcels <- LA_warehouse_parcels %>%
  #filter(UseType == 'Industrial') %>%
  mutate(type = ifelse(str_detect(str_to_lower(UseDescription), 'warehous'), 'warehouse', 
                       ifelse(str_detect(str_to_lower(UseDescription), 'industrial'), 'industrial', 'other')
  )
  ) %>%
  #filter(Shape_Area >= sq_ft_threshold) %>% 
  select(APN, YearBuilt1, Shape_Area, type, Shape, UseDescription, 
         #SitusAddress, SitusCity, SitusZIP
         ) %>%
  clean_names() %>%
  mutate(year_built = as.numeric(year_built1),
         class=use_description) %>%
  mutate(year_built = ifelse(is.na(year_built), 1910, 
                             ifelse(year_built < 1911, 1910, year_built))
  ) %>%
  select(apn, shape_area, class, type, year_built, Shape, 
         #situs_address, situs_city, situs_zip
         ) %>%
  st_transform("+proj=longlat +ellps=WGS84 +datum=WGS84")

rm(ls = LA_warehouse_parcels)
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
  select(-row)
 
LA_Multi <- LA_interMulti |> 
  st_join(LA_industrial_parcels, join = st_equals) |> 
  group_by(row, count, Shape, shape_area, class, type) |> 
  summarize(apn = max(apn), year_built = max(year_built), .groups = 'drop') |> 
  select(-row)

final_LA <- bind_rows(LA_unique, LA_Multi)

st_geometry(final_LA) <- 'geometry'

narrow_LA_parcels <- final_LA |> 
  mutate(type = as.factor(type), county = 'Los Angeles')

rm(ls = u, unique, LA_industrial_28k_parcels, LA_geometry, LA_industrial_parcels_10k,
   LA_parcels_precise, unique2, Geo_only, LA_warehouse_parcels,
   LA_industrial_parcels, LA_Multi, LA_unique, LA_interMulti, final_LA, uniqueParcel)  
   
setwd(LA_tidy)
unlink('LA_filtered_parcels.shp')
st_write(narrow_LA_parcels, 'LA_filtered_parcels.shp')
#st_write(final_LA, 'LA_address.geojson')

setwd(wd)

