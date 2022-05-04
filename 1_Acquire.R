##Warehouse Map App V1
##Created by Mike McCarthy, Radical Research LLC
##Inspired by Graham Brady and Susan Phillips at Pitzer College and their code
##located here: https://docs.google.com/document/d/16Op4GgmK0A_0mUHAf9qqXzT_aekbdLb_ZFtBaZKfj6w/edit
##First created May, 2022
##Last modified May, 2022
##This script acquires and tidy parcel data for the app

rm(list =ls()) # clear environment
'%ni%' <- Negate('%in%') ## not in operator

##Libraries used in data acquisition
library(RCurl)

##Libraries used in data processing and visualization
library(tidyverse)
library(janitor)
#library(data.table)
library(readxl)
#library(lubridate)

##spatial libraries and visualization annotation
library(leaflet)
library(sf)
library(rgdal)
#library(spatstat)
#library(raster)
library(htmltools)

#windrose tool
#library(openair)

##set working, data, and app directories
wd <- getwd()

###set data, app, and export subdirectories
app_dir <- paste0(wd, '/WarehouseCITY')
warehouse_dir <- paste0(wd, '/Warehouse_data')
output_dir <- paste0(wd, '/exports_other')
crest_dir <- paste0(warehouse_dir, '/CREST_tables.gdb')
parcel_dir <- paste0(warehouse_dir, '/ParcelAttributed.gdb')
SBD_parcel_dir <- paste0(warehouse_dir, '/SBD_Parcel')
#aqdata_dir <- paste0(wd, '/air_quality_data')
#metdata_dir <- paste0(wd, '/met_data' )
#trafficdata_dir <- paste0(wd, '/traffic_data')
#truckdata_dir <- paste0(wd, '/truck_data')


## Acquire warehouse data files
setwd(warehouse_dir)
##Commented out to save processing time 
#download.file('https://gis2.rivco.org/Portals/0/Documents/downloads/Assessor_Tables0522.zip', 
#              destfile = 'Assessor_Tables0522.zip')
#download.file('https://gis2.rivco.org/Portals/0/Documents/downloads/ParcelAttributed0522.zip',
#              destfile = 'ParcelAttributed0522.zip')

##San Bernadino data is FTP - FIXME
#SBD.url <- 'ftp://gis1.sbcounty.gov/'
#rawSBD <- getURL(SBD.url, userpwd = userName.Password)
#userName.Password <- '<gisftp>:<1sbcftp1>'
#unzip('Assessor_Tables0522.zip')
#unzip('ParcelAttributed0522.zip')

#setwd(SBD_parcel_dir)
#unzip('countywide_parcels_05_02_2022.zip')

## List the GDB files
sf::st_layers(dsn = crest_dir)
sf::st_layers(dsn = parcel_dir)

##Import parcels and property record files for Riverside County
##st_read(type=1) is attempting to create the same sfc type for both counties
crest_property <- sf::st_read(dsn = crest_dir, layer = 'CREST_PROPERTY_CHAR')
parcels <- sf::st_read(dsn = parcel_dir, layer = 'PARCELS_CREST', quiet = TRUE, type = 3)
class(st_geometry(parcels))
##Read and import property record files for San Bernadino County
sf::st_layers(dsn = SBD_parcel_dir)
SBD_parcels <- sf::st_read(dsn=SBD_parcel_dir, quiet = TRUE, type = 3)
class(st_geometry(SBD_parcels))

##Set minimum warehouse size for analysis in sq.ft.
sq_ft_threshold <- 100000

######Tidy up the data for use
##select just property number and year built for riverside county CREST
crest_property_slim <- crest_property %>%
  dplyr::select(PIN, YEAR_BUILT) %>%
  dplyr::distinct()

##filter on warehouses and light-industrial for Riverside County
##transform coordinates from Northing-Easting to Lat-Long
parcels_warehouse <- parcels %>%
  mutate(class = stringr::str_to_lower(CLASS_CODE)) %>%
  filter(str_detect(class, 'warehouse')) %>%
  filter(SHAPE_Area > sq_ft_threshold) %>%
  st_transform("+proj=longlat +ellps=WGS84 +datum=WGS84")

parcels_lightIndustry <- parcels %>%
  mutate(class = stringr::str_to_lower(CLASS_CODE)) %>%
  filter(str_detect(class, 'light industrial')) %>%
  filter(SHAPE_Area > sq_ft_threshold) %>%
  st_transform("+proj=longlat +ellps=WGS84 +datum=WGS84")

##Bind two Riv.co. datasets together
##Create a type category for the warehouse and industrial designation parcels

parcels_join_yr <- bind_rows(parcels_warehouse, parcels_lightIndustry) %>%
  left_join(crest_property_slim, by =c('APN' = 'PIN')) %>%
  unique() %>%
  mutate(YEAR_BUILT = ifelse(is.na(YEAR_BUILT), 1776, YEAR_BUILT)) %>%
  mutate(type = as.factor(ifelse(str_detect(class, 'warehouse'), 'warehouse', 'light industrial')))

##parse San Bernadino data codes
setwd(warehouse_dir)
SBD_codes <- read_excel('Assessor Use Codes 05-21-2012.xls') %>%
  clean_names() %>%
  mutate(description = str_to_lower(description),
         use_code = as.numeric(use_code)) %>%
  mutate(type = case_when(
    str_detect(description, 'warehouse') ~ 'warehouse',
    str_detect(description, 'light industrial') ~'light industrial',
    TRUE ~ 'other'
  )) %>%
  filter(type %in% c('warehouse', 'light industrial'))  %>%
  rename(class = description)

##Filter SBDCO data by warehouse and light industrial, filter by size threshold
##Fix coordinate projection
SBD_warehouse_ltInd <- inner_join(SBD_parcels, SBD_codes, by = c('TYPEUSE' = 'use_code' )) %>%
  filter(SHAPE_AREA > sq_ft_threshold) %>%
  st_transform("+proj=longlat +ellps=WGS84 +datum=WGS84") %>%
  mutate(type = as.factor(type))

##combine RivCo and SBDCo spatial data frames for display
##Select and rename columns to make everything match

names(parcels_join_yr)
names(SBD_warehouse_ltInd)

##Note that we can always add other columns if they are useful for display 
narrow_RivCo_parcels <- parcels_join_yr %>%
  dplyr::select(APN, SHAPE_Area, class, type, SHAPE) %>%
  clean_names() %>%
  st_cast(to = 'POLYGON') #%>%

##Function required to rename sf column because sf package is dumb about this
rename_geometry <- function(g, name){
  current = attr(g, "sf_column")
  names(g)[names(g)==current] = name
  st_geometry(g)=name
  g
}
narrow_RivCo_parcels <- rename_geometry(narrow_RivCo_parcels, 'geometry')
names(narrow_RivCo_parcels)
  
narrow_SBDCo_parcels <- SBD_warehouse_ltInd %>%
  dplyr::select(APN, SHAPE_AREA, class, type, geometry) %>%
  clean_names() #%>%
  #st_cast(to = 'POLYGON')
  
str(narrow_RivCo_parcels)
str(narrow_SBDCo_parcels)

##FIXME do multipolygon and polygon sf geometries work together?
final_parcels <- bind_rows(narrow_RivCo_parcels, narrow_SBDCo_parcels)
str(final_parcels)
  
## Remove big raw files and save .RData file to app directory
rm(ls = parcels, crest_property, crest_property_slim, SBD_parcels)
setwd(app_dir)
save.image('.RData')




