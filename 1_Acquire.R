##Warehouse Map App V1
##Created by Mike McCarthy, Radical Research LLC
##Inspired by Graham Brady and Susan Phillips at Pitzer College and their code
##located here: https://docs.google.com/document/d/16Op4GgmK0A_0mUHAf9qqXzT_aekbdLb_ZFtBaZKfj6w/edit
##First created May, 2022
##Last modified July, 2022
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
library(spdplyr)
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
OC_dir <- paste0(warehouse_dir, '/OC_parcels')
LA_dir <- paste0(warehouse_dir, '/LACounty_Parcels.gdb')
AQMD_dir <- paste0(wd, '/SCAQMD_shp')
city_dir <- paste0(wd, '/cities')
#aqdata_dir <- paste0(wd, '/air_quality_data')
#metdata_dir <- paste0(wd, '/met_data' )
#trafficdata_dir <- paste0(wd, '/traffic_data')
#truck_dir <- paste0(wd, '/TruckTrafficData')

## Acquire warehouse data files
setwd(warehouse_dir)

gc()
##Set minimum size for analysis in thousand sq.ft. for non-warehouse classified
sq_ft_threshold <- 100000

##Try to import LA County data
sf::st_layers(dsn = LA_dir)
LA_parcels <- sf::st_read(dsn = LA_dir, quiet = TRUE, type = 3)

LA_100k_parcels <- LA_parcels %>%
  filter(UseType == 'Industrial')
names(LA_100k_parcels)

rm(ls = LA_parcels)
memory.size()
gc()

#now misnamed - not 100k
LA_industrial_100k_parcels <- LA_100k_parcels %>%
  #filter(UseType == 'Industrial') %>%
  mutate(type = ifelse(str_detect(str_to_lower(UseDescription), 'warehous'), 'warehouse', 
                        ifelse(str_detect(str_to_lower(UseDescription), 'industrial'), 'industrial', 'other')
                               )
  ) %>%
  select(APN, YearBuilt1, Shape_Area, type, Shape, UseDescription) %>%
  filter(type %in% c('warehouse' #,'industrial'
                     )) %>%
  clean_names() %>%
  mutate(year_built = as.numeric(year_built1),
         class=use_description) %>%
  mutate(year_built = ifelse(is.na(year_built), 1910, 
                             ifelse(year_built < 1911, 1910, year_built))
         ) %>%
  select(apn, shape_area, class, type, year_built, Shape) %>%
  st_transform("+proj=longlat +ellps=WGS84 +datum=WGS84")


#rm(ls = LA_100k_parcels)
gc()

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

######Tidy up the data for use
##select just property number and year built for riverside county CREST
crest_property_slim <- crest_property %>%
  dplyr::select(PIN, YEAR_BUILT) %>%
  dplyr::distinct()

crest_property_dups <- crest_property_slim %>%
  select(PIN) %>%
  group_by(PIN) %>%
  summarize(count = n()) %>%
  filter(count > 1) %>%
  left_join(crest_property_slim) %>%
  mutate(unk = ifelse(is.na(YEAR_BUILT), 1,
                ifelse(YEAR_BUILT < 1911, 1, 0))) %>%
  filter(unk == 0) %>%
  group_by(PIN) %>%
  summarize(PIN, YEAR_BUILT = min(YEAR_BUILT), .groups = 'drop') %>%
  unique()

crest_property_dups2 <- crest_property_slim %>%
  select(PIN) %>%
  group_by(PIN) %>%
  summarize(count = n()) %>%
  filter(count > 1) %>%
  left_join(crest_property_dups) 

crest_property_solo <- crest_property_slim %>%
  dplyr::select(PIN) %>%
  group_by(PIN) %>%
  summarize(count = n(), .groups = 'drop') %>%
  filter(count == 1) %>%
  left_join(crest_property_slim)

crest_property_tidy <- bind_rows(crest_property_solo, crest_property_dups2)

##filter on warehouses and light-industrial for Riverside County
##transform coordinates from Northing-Easting to Lat-Long
parcels_warehouse <- parcels %>%
  mutate(class = stringr::str_to_lower(CLASS_CODE)) %>%
  filter(str_detect(class, 'warehouse')) %>%
 # filter(SHAPE_Area > sq_ft_threshold) %>%
  st_transform("+proj=longlat +ellps=WGS84 +datum=WGS84")

parcels_lightIndustry <- parcels %>%
  mutate(class = stringr::str_to_lower(CLASS_CODE)) %>%
  filter(str_detect(class, 'light industrial')) %>%
  filter(SHAPE_Area > sq_ft_threshold) %>%
  st_transform("+proj=longlat +ellps=WGS84 +datum=WGS84")

##Bind two Riv.co. datasets together
##Create a type category for the warehouse and industrial designation parcels

parcels_join_yr <- bind_rows(parcels_warehouse, parcels_lightIndustry) %>%
  left_join(crest_property_tidy, by =c('APN' = 'PIN')) %>%
  unique() %>%
  mutate(YEAR_BUILT = ifelse(is.na(YEAR_BUILT), 1776, YEAR_BUILT)) %>%
  mutate(type = as.factor(ifelse(str_detect(class, 'warehouse'), 'warehouse', 'light industrial')))

##parse SBD data codes
setwd(warehouse_dir)
SBD_codes <- read_excel('Assessor Use Codes 05-21-2012.xls') %>%
  clean_names() %>%
  mutate(description = str_to_lower(description),
         use_code = as.numeric(use_code)) %>%
  mutate(type = case_when(
    str_detect(description, 'warehouse') ~ 'warehouse',
    str_detect(description, 'light industrial') ~'light industrial',
    str_detect(description, 'flex') ~ 'warehouse',
    str_detect(description, 'storage') ~ 'warehouse',
    TRUE ~ 'other'
  )) %>%
  filter(type %in% c('warehouse', 'light industrial'))  %>%
  rename(class = description) %>%
  filter(class %ni% c('retail warehouse', 'lumber storage', 'mini storage (public)',
                      'storage yard', 'auto storage yard', 'boat storage yard', 
                      'grain storage', 'potato storage', 'bulk fertilizer storage',
                      'mini-storage warehouse')) #%>%

##Filter SBDCO data by warehouse and light industrial, filter by size threshold
##Fix coordinate projection
SBD_warehouse_ltInd <- inner_join(SBD_parcels, SBD_codes, by = c('TYPEUSE' = 'use_code' )) %>%
  mutate(threshold = ifelse(SHAPE_AREA > sq_ft_threshold, 1, 0)) %>%
  mutate(exclude = ifelse(type == 'warehouse', 0,
                    ifelse(threshold == 1, 0, 1))) %>%
  filter(exclude == 0) %>%
  st_transform("+proj=longlat +ellps=WGS84 +datum=WGS84") %>%
  mutate(type = as.factor(type))

##Import OC data - current parcels are useless
#sf::st_layers(dsn = OC_dir)
lu_codes <- c('1231', '1323', '1340', '1310')
OC_parcels <- sf::st_read(dsn=OC_dir, quiet = TRUE, type = 3) %>%
  clean_names() %>%
  select(apn, shape_are, year_adopt, county, scag_gp_co, lu16) %>%
  filter(lu16 %in% lu_codes)

class <- c('commercial storage', 'open storage', 'wholesaling and warehousing',
                          'light industrial')
type <- c('warehouse', 'warehouse', 'warehouse', 'light industrial')
code_desc <- data.frame(lu_codes, class, type)

## Need to convert OC parcel data from XYZ polygon to XY polygon
narrow_OC_parcels <- OC_parcels %>%
  left_join(code_desc, (by = c('lu16' = 'lu_codes'))) %>%
  mutate(shape_area = as.numeric(shape_are),
         year_built = as.numeric(lubridate::year(year_adopt))) %>%
  #select(apn, shape_area, class, type, geometry, year_built, county) %>%
  st_transform("+proj=longlat +ellps=WGS84 +datum=WGS84") %>%
  mutate(type = as.factor(type)) %>%
  st_zm() %>%
  mutate(threshold = ifelse(shape_area > sq_ft_threshold, 1, 0)) %>%
  mutate(exclude = ifelse(type == 'warehouse', 0,
                          ifelse(threshold == 1, 0, 1))) %>%
  filter(exclude == 0) %>%
  select(apn, shape_area, class, type, geometry, year_built, county) #%>%

##combine spatial data frames for display
##Select and rename columns to make everything match
##Note that we can always add other columns if they are useful for display 
narrow_RivCo_parcels <- parcels_join_yr %>%
  dplyr::select(APN, SHAPE_Area, class, type, SHAPE, YEAR_BUILT) %>%
  clean_names() %>%
  st_cast(to = 'POLYGON') #%>%

##Function required to rename sf column because sf package is dumb about this
rename_geometry <- function(g, name){
  current = attr(g, "sf_column")
  names(g)[names(g)==current] = name
  st_geometry(g)=name
  g
}

narrow_RivCo_parcels <- rename_geometry(narrow_RivCo_parcels, 'geometry') %>%
  mutate(county = 'Riverside')
names(narrow_RivCo_parcels)
  
narrow_SBDCo_parcels <- SBD_warehouse_ltInd %>%
  mutate(year_built = BASE_YEAR) %>%
  dplyr::select(APN, SHAPE_AREA, class, type, geometry, year_built) %>%
  clean_names() %>%
  mutate(county = 'San Bernadino')

## Remove big raw files and save .RData file to app directory

str(narrow_RivCo_parcels)
str(narrow_SBDCo_parcels)
str(LA_industrial_100k_parcels)
str(narrow_OC_parcels)

narrow_LA_parcels <- rename_geometry(LA_industrial_100k_parcels, 'geometry') %>%
  mutate(type = as.factor(type), county = 'Los Angeles')

rm(ls = parcels, crest_property, crest_property_slim, SBD_parcels, crest_property_solo, 
   crest_property_dups, crest_property_dups2, crest_property_tidy, OC_parcels) #%>%

gc()
#memory.size()

#str(final_parcels)

##Bind two counties together and put in null 1776 year for missing or 0 warehouse year built dates
final_parcels <- bind_rows(narrow_RivCo_parcels, narrow_SBDCo_parcels, narrow_LA_parcels, narrow_OC_parcels) %>%
  mutate(year.built = ifelse(year_built <= 1910, 'unknown', year_built),
         year_built = ifelse(year_built <= 1910, 1910, year_built)) %>%
  mutate(floorSpace.sq.ft = round(shape_area*0.65, 1),
         shape_area = round(shape_area, 0)) %>%
  #filter(floorSpace.th.sq.ft > 100) %>%
  mutate(yr_bin = as.factor(case_when(
  year_built < 1972 & year_built > 1910 ~ '1911 - 1972',
  year_built >= 1972 & year_built < 1982 ~ '1972 - 1981',
  year_built >= 1982 & year_built < 1992 ~ '1982 - 1991',
  year_built >= 1992 & year_built < 2002 ~ '1992 - 2001',
  year_built >= 2002 & year_built < 2012 ~ '2002 - 2011',
  year_built >= 2012 & year_built <= 2022 ~ '2012 - 2022',
  year_built == 1910 ~ 'unknown'
))) %>%
  mutate(size_bin = as.factor(case_when(
    floorSpace.sq.ft < 100000 ~ '28,000 to 100,000',
    floorSpace.sq.ft >= 100000 & floorSpace.sq.ft < 250000 ~ '100,000 to 250,000',
    floorSpace.sq.ft >=250000 & floorSpace.sq.ft < 500000 ~ '250,000 to 500,000',
    floorSpace.sq.ft >=500000 & floorSpace.sq.ft < 1000000 ~'500,000 to 1,000,000',
    floorSpace.sq.ft >=1000000 ~ '1,000,000+'
  ))) %>%
  mutate(exclude = ifelse(
    type == 'warehouse', 0,
     ifelse(floorSpace.sq.ft > sq_ft_threshold, 0, 1))) %>%
  filter(exclude == 0)
  

final_parcels$yr_bin <- factor(final_parcels$yr_bin, 
                                   levels = c(  '1911 - 1972',
                                                '1972 - 1981',
                                                '1982 - 1991',
                                                '1992 - 2001',
                                                '2002 - 2011',
                                                '2012 - 2022',
                                                'unknown'))

final_parcels$size_bin <- factor(final_parcels$size_bin,
                                 levels = c('28,000 to 100,000',
                                   '100,000 to 250,000',
                                    '250,000 to 500,000',
                                    '500,000 to 1,000,000',
                                    '1,000,000+'))

#paletteYr <- colorFactor(palette = 'inferno',
#                       levels = final_parcels$yr_bin)

#paletteSize <- colorFactor(palette = 'YlOrBn', levels = final_parcels$size_bin)

#centroids <- final_parcels %>%
#  st_centroid()
  
summary_counts <- final_parcels %>%
  as.data.frame() %>%
  group_by(class, type) %>%
  summarize(count = n(), .groups = 'drop')

rm(ls = LA_100k_parcels, LA_industrial_100k_parcels, narrow_LA_parcels, narrow_RivCo_parcels, narrow_SBDCo_parcels,
   parcels_join_yr, parcels_lightIndustry, SBD_warehouse_ltInd, parcels_warehouse, OC_parcels, narrow_OC_parcels)
#str(final_parcels)

sf::st_layers(dsn = AQMD_dir)

AQMD_boundary <-  sf::st_read(dsn = AQMD_dir, quiet = TRUE, type = 3) %>%
  st_transform("+proj=longlat +ellps=WGS84 +datum=WGS84")

##Import QA list of warehouses and non-warehouses 
##FIXME - move this up for when we identify warehouses currently not on the list
setwd(wd) 
source('QA_list.R')

final_parcels <- final_parcels %>%
  filter(apn %ni% not_warehouse) %>%
##FIXME if 1 acre threshold is important
    filter(shape_area >= 43560)
#centroids <- centroids %>%
#  filter(apn %ni% not_warehouse)

gc()
##Import and clean city boundary data
setwd(city_dir)
#sf::st_layers(dsn = city_dir)
city_boundary <- sf::st_read(dsn = city_dir, quiet = TRUE, type = 3) %>%
  clean_names() %>%
  filter(county %ni% c('Ventura', 'Imperial')) %>%
  select(city, county, geometry, acres, shapearea)

city_names <- city_boundary %>%
  dplyr::select(city) %>%
  filter(city != 'Unincorporated') %>%
  arrange(city)

city_names$city

##Add variables for Heavy-duty diesel truck calculations
#Truck_trips_1000sqft <- 0.64
#DPM_VMT_2022_lbs <- 0.00037807

setwd(app_dir)
save.image('.RData')
setwd(warehouse_dir)
save.image('.RData')




