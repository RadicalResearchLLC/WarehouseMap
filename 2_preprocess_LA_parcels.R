##Warehouse Map App V1
##Created by Mike McCarthy, Radical Research LLC
##Inspired by Graham Brady and Susan Phillips at Pitzer College and their code
##located here: https://docs.google.com/document/d/16Op4GgmK0A_0mUHAf9qqXzT_aekbdLb_ZFtBaZKfj6w/edit
##First created May, 2022
##Last modified September, 2022
##This script preprocesses LA shapefile data because it is very slow and 
##this is intended to avoid having to do it multiple times since it only updates quarterly

rm(list =ls()) # clear environment
#'%ni%' <- Negate('%in%') ## not in operator
gc()

## Probably only need these two libraries
library(tidyverse)
library(sf)
library(janitor)

##set working, data, and app directories
wd <- getwd()
warehouse_dir <- paste0(wd, '/Warehouse_data')
LA_raw <- paste0(warehouse_dir, '/LACounty_Parcels.gdb')
LA_tidy <- paste0(warehouse_dir, '/LAfiltered_shp')

## Import the data

#Set minimum size for analysis in thousand sq.ft. for non-warehouse classified
sq_ft_threshold <- 28000

#Import raw LA County parcel data
#sf::st_layers(dsn = LA_raw)
LA_parcels <- sf::st_read(dsn = LA_raw, quiet = TRUE, type = 3)

LA_warehouse_parcels <- LA_parcels %>%
  filter(UseDescription == 'Warehousing, Distribution, Storage') 

rm(ls = LA_parcels)
gc()

#Filter only warehouses above 28k sq.ft.
LA_industrial_28k_parcels <- LA_warehouse_parcels %>%
  #filter(UseType == 'Industrial') %>%
  mutate(type = ifelse(str_detect(str_to_lower(UseDescription), 'warehous'), 'warehouse', 
                       ifelse(str_detect(str_to_lower(UseDescription), 'industrial'), 'industrial', 'other')
  )
  ) %>%
  filter(Shape_Area >= sq_ft_threshold) %>% 
  select(APN, YearBuilt1, Shape_Area, type, Shape, UseDescription) %>%
  clean_names() %>%
  mutate(year_built = as.numeric(year_built1),
         class=use_description) %>%
  mutate(year_built = ifelse(is.na(year_built), 1910, 
                             ifelse(year_built < 1911, 1910, year_built))
  ) %>%
  select(apn, shape_area, class, type, year_built, Shape) %>%
  st_transform("+proj=longlat +ellps=WGS84 +datum=WGS84")

rm(ls = LA_warehouse_parcels)
gc()

setwd(LA_tidy)
st_write(LA_industrial_28k_parcels, 'LA_filtered_parcels.shp')

setwd(wd)
