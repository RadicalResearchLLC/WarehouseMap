#Warehouse Map App V1
#Created by Mike McCarthy, Radical Research LLC
#Inspired by Graham Brady and Susan Phillips at Pitzer College and their code
#located here: https://docs.google.com/document/d/16Op4GgmK0A_0mUHAf9qqXzT_aekbdLb_ZFtBaZKfj6w/edit
#First created May, 2022
#Last modified May, 2022
#This script acquires and tidy parcel data for the app

rm(list =ls()) # clear environment
#'%ni%' <- Negate('%in%') ## not in operator

#Libraries used in data acquisition
library(RCurl)

#Libraries used in data processing and visualization
library(tidyverse)
library(janitor)
#library(data.table)
#library(readxl)
#library(lubridate)

#spatial libraries and visualization annotation
library(leaflet)
library(sf)
library(rgdal)
#library(spatstat)
#library(raster)
#library(htmltools)

#windrose tool
#library(openair)

#set working, data, and app directories
wd <- getwd()

#set data, app, and export subdirectories

#metdata_dir <- paste0(wd, '/met_data' )
#trafficdata_dir <- paste0(wd, '/traffic_data')
#truckdata_dir <- paste0(wd, '/truck_data')
app_dir <- paste0(wd, '/Warehouse Map App')
warehouse_dir <- paste0(wd, '/Warehouse_data')
output_dir <- paste0(wd, '/exports_other')
#aqdata_dir <- paste0(wd, '/air_quality_data')


# Acquire warehouse data files
setwd(warehouse_dir)
download.file('https://gis2.rivco.org/Portals/0/Documents/downloads/Assessor_Tables0522.zip', 
              destfile = 'Assessor_Tables0522.zip')
download.file('https://gis2.rivco.org/Portals/0/Documents/downloads/ParcelAttributed0522.zip',
              destfile = 'ParcelAttributed0522.zip')
unzip('Assessor_Tables0522.zip')
unzip('ParcelAttributed0522.zip')

crest_dir <- paste0(warehouse_dir, '/CREST_tables.gdb')
parcel_dir <- paste0(warehouse_dir, '/ParcelAttributed.gdb')

# List the GDB files
sf::st_layers(dsn = crest_dir)
sf::st_layers(dsn = parcel_dir)
#crest_general <- sf::st_read(dsn = crest_dir, layer = 'CREST_GENERAL')
crest_property <- sf::st_read(dsn = crest_dir, layer = 'CREST_PROPERTY_CHAR')
#crest_tax <- sf::st_read(dsn = crest_dir, layer = 'CREST_TAXYEAR')
#crest_book <- sf::st_read(dsn = crest_dir, layer = 'CREST_RECORDED_BOOK')
parcels <- sf::st_read(dsn = parcel_dir, layer = 'PARCELS_CREST')

crest_property_slim <- crest_property %>%
  dplyr::select(PIN, YEAR_BUILT) %>%
  dplyr::distinct()

#filter on warehouses
#transform coordinates from Northing-Easting to Lat-Long
parcels_warehouse <- parcels %>%
  mutate(class = stringr::str_to_lower(CLASS_CODE)) %>%
  filter(str_detect(class, 'warehouse')) %>%
  filter(SHAPE_Area > 250000) %>%
  st_transform("+proj=longlat +ellps=WGS84 +datum=WGS84")

parcels_lightIndustry <- parcels %>%
  mutate(class = stringr::str_to_lower(CLASS_CODE)) %>%
  filter(str_detect(class, 'light industrial')) %>%
  filter(SHAPE_Area > 250000) %>%
  st_transform("+proj=longlat +ellps=WGS84 +datum=WGS84")

#Bind two datasets together
#Create a type category for the warehouse and industrial designation parcels

parcels_join_yr <- bind_rows(parcels_warehouse, parcels_lightIndustry) %>%
  left_join(crest_property_slim, by =c('APN' = 'PIN')) %>%
  unique() %>%
  mutate(YEAR_BUILT = ifelse(is.na(YEAR_BUILT), 1776, YEAR_BUILT)) %>%
  mutate(type = as.factor(ifelse(str_detect(class, 'warehouse'), 'warehouse', 'industrial')))

# save .RData file to app directory
rm(ls = parcels, crest_property, crest_property_slim)

setwd(app_dir)
save.image('.RData')

palette <- colorFactor( palette = c('Blue', 'Brown'),
                        levels = c('warehouse', 'industrial'))

#str(parcels_join_yr)
map1 <- leaflet(data = parcels_join_yr) %>%
  addTiles() %>%
  setView(lat = 33.92, lng = -117.30, zoom = 12) %>%
  addProviderTiles("Esri.WorldImagery", 
                   group = 'Imagery') %>%
  addLayersControl(baseGroups = c('Basemap', 'Imagery'),
                   overlayGroups =c('Warehouses')) %>%
  addPolygons(color = ~palette(type), 
              group = 'Warehouses') %>%
  addLegend(pal = palette, values = c('warehouse', 'industrial'))

map1

setwd(app_dir)
save.image('.RData')
