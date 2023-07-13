##Warehouse Map App V1
##Created by Mike McCarthy, Radical Research LLC
##Inspired by Graham Brady and Susan Phillips at Pitzer College and their code
##located here: https://docs.google.com/document/d/16Op4GgmK0A_0mUHAf9qqXzT_aekbdLb_ZFtBaZKfj6w/edit
##First created May, 2022
##Last modified July, 2023
##This script acquires and tidy parcel data for the app

#rm(list =ls()) # clear environment
'%ni%' <- Negate('%in%') ## not in operator
gc()


##Libraries used in data processing and visualization
library(tidyverse)
library(janitor)
library(readxl)

##spatial libraries and visualization annotation
#library(leaflet)
library(sf)
#library(htmltools)
library(rmapshaper)

##set working, data, and app directories
wd <- getwd()

###set data, app, and export subdirectories
app_dir <- paste0(wd, '/WarehouseCITY')
warehouse_dir <- paste0(wd, '/Warehouse_data')
output_dir <- paste0(wd, '/exports_other')
calEJScreen_dir <- paste0(wd, '/calenviroscreen40')
shapefile_dir <- paste0(app_dir, '/shapefile')
geojson_dir <- paste0(app_dir, '/geoJSON')
jurisdiction_jur <- paste0(wd, '/community_geojson/')
#aqdata_dir <- paste0(wd, '/air_quality_data')
#metdata_dir <- paste0(wd, '/met_data' )
#trafficdata_dir <- paste0(wd, '/traffic_data')
#truck_dir <- paste0(wd, '/TruckTrafficData')

##Set minimum size for analysis in thousand sq.ft. for non-warehouse classified
##FIXME - should be acreage based
sq_ft_threshold_WH <- 28000
sq_ft_threshold_maybeWH <- 150000

## Process County Data using County Scripts

source('Riverside.R')
source('SanBernardino.R')
source('LosAngeles.R')
source('Orange.R')

gc()

## Remove big raw files and save .RData file to app directory

str(narrow_RivCo_parcels)
str(narrow_SBDCo_parcels2)
str(narrow_LA_parcels)
str(narrow_OC_parcels)

gc()


#str(final_parcels)

##Bind two counties together and put in null 1776 year for missing or 0 warehouse year built dates
joined_parcels <- bind_rows(narrow_RivCo_parcels, narrow_SBDCo_parcels2, narrow_LA_parcels, narrow_OC_parcels) |>
  mutate(year_chr = ifelse(year_built <= 1910, 'unknown', year_built),
         year_built = ifelse(year_built <= 1980, 1980, year_built)) |>
  mutate(floorSpace.sq.ft = round(shape_area*0.55, 1),
         shape_area = round(shape_area, 0)) |>
  #filter(floorSpace.th.sq.ft > 100) |>
  mutate(yr_bin = as.factor(case_when(
  year_built > 1910 & year_built < 1982 ~ '1910 - 1981',
  year_built >= 1982 & year_built < 1992 ~ '1982 - 1991',
  year_built >= 1992 & year_built < 2002 ~ '1992 - 2001',
  year_built >= 2002 & year_built < 2012 ~ '2002 - 2011',
  year_built >= 2012 & year_built <= 2023 ~ '2012 - 2023',
  year_built == 1910 ~ 'unknown'
))) |>
  mutate(size_bin = as.factor(case_when(
    floorSpace.sq.ft < 100000 ~ '28,000 to 100,000',
    floorSpace.sq.ft >= 100000 & floorSpace.sq.ft < 250000 ~ '100,000 to 250,000',
    floorSpace.sq.ft >=250000 & floorSpace.sq.ft < 500000 ~ '250,000 to 500,000',
    floorSpace.sq.ft >=500000 & floorSpace.sq.ft < 1000000 ~'500,000 to 1,000,000',
    floorSpace.sq.ft >=1000000 ~ '1,000,000+'
  ))) |>
  mutate(exclude = ifelse(floorSpace.sq.ft > sq_ft_threshold_WH, 0, 1)) #|>
 # filter(exclude == 0)

rm(ls = LA_warehouse_parcels, narrow_LA_parcels, narrow_RivCo_parcels, narrow_SBDCo_parcels, narrow_SBDCo_parcels2,
   parcels_join_yr, parcels_lightIndustry, SBD_warehouse_ltInd, parcels_warehouse, OC_parcels, narrow_OC_parcels,
   compare, DataTree, wYearValue, noYearValue)


##Import QA list of warehouses and non-warehouses 
##FIXME - move this up for when we identify warehouses currently not on the list
 
source('QA_list.R')

joined_parcels <- joined_parcels |>
  filter(apn %ni% not_warehouse) #|>
##Check for warehouse duplicates by location

sf_use_s2(FALSE)

#u <- st_equals(joined_parcels, retain_unique = TRUE)
#unique <- joined_parcels[-unlist(u),] |> 
#  st_set_geometry(value = NULL)
geoOnly <- joined_parcels |> 
  select(geometry) |> 
  unique.data.frame() |> 
  mutate(row = row_number()) |> 
  st_make_valid()
  
uniqueParcels <- geoOnly |> 
  st_join(joined_parcels, join = st_equals) |> 
  st_set_geometry(value = NULL) |> 
  group_by(row) |>
  summarize(count = n()) |> 
  filter(count == 1) |> 
  left_join(geoOnly, by = 'row') |> 
  st_as_sf() |> 
  st_join(joined_parcels, join = st_equals) |> 
  select(-row, - count.x, -count.y)

multiParcels1 <-  geoOnly |> 
  st_join(joined_parcels, join = st_equals) |> 
  st_set_geometry(value = NULL) |> 
  group_by(row) |>
  summarize(count = n()) |> 
  filter(count > 1) |> 
  left_join(geoOnly, by = 'row') |> 
  st_as_sf() |> 
  st_join(joined_parcels, join = st_equals)# |> 
 # select(-row)

##FIXME - not sure how to identify correct parcel - this fix just chooses a single polygon 
##while dropping the identifying info
##Happens for just ~25 parcels with multiples - small overall error only occurring 
#in OC and LA
multiParcels2 <- multiParcels1 |> 
  group_by(row, count.x, shape_area, class, type, size_bin, yr_bin, exclude) |> 
  summarize(apn = max(apn), year_built = max(year_built), .groups = 'drop') |>
  select(-row, -count.x) |> 
  distinct() |> 
  select(-type)

joined_parcels2 <- uniqueParcels |> 
  select(apn, shape_area, class, year_built, county, year_chr, exclude) |> 
  bind_rows(multiParcels2)

rm(ls = SBD_codes, parcels_manual_wh,
   multiParcels1, multiParcels2, uniqueParcels, joined_parcels, geoOnly)

area <- sf::st_area(joined_parcels2)

sub1acre_warehouses <- joined_parcels2 |> 
  mutate(shape_area2 = round(as.numeric(area*10.76391), -2)) |> 
  select(-shape_area) |> 
  filter(shape_area2 <= 43560)

final_parcels <- joined_parcels2 |> 
  mutate(shape_area2 = round(as.numeric(area*10.76391), -2)) |> 
  select(-shape_area) |> 
  filter(shape_area2 > 43560)

gc()

##import 
setwd(wd)
jurisdictions <- sf::st_read(dsn = paste0(jurisdiction_jur, 'SoCal_jurisdictions.geojson')) |> 
  clean_names()

##Import CalEnviroScreen
CalEJ4 <- sf::st_read(dsn = calEJScreen_dir, quiet = TRUE, type = 3) |>
  filter(County %in% c('Riverside', 'San Bernardino', 'Los Angeles', 'Orange')) |>
  select(Tract, TotPop19, ApproxLoc, CIscoreP, CIscore, geometry, DieselPM_P) |> 
  #filter(CIscoreP >= 75) |> 
  st_transform("+proj=longlat +ellps=WGS84 +datum=WGS84")

plannedWH.url <- 'https://raw.githubusercontent.com/RadicalResearchLLC/PlannedWarehouses/main/plannedWarehouses.geojson'
plannedWarehouses <- st_read(plannedWH.url) |> 
  st_transform("+proj=longlat +ellps=WGS84 +datum=WGS84")

shape_area <- st_area(plannedWarehouses)

planned_tidy <- plannedWarehouses |> 
  mutate(shape_area =  round(as.numeric(10.764*shape_area), -3),
         class = 'Planned and Approved',
         year_chr = 'future',
         year_built = 2025,
         type = 'warehouse',
         row = row_number())

Counties <- sf::st_read(dsn = 'C:/Dev/WarehouseMap/community_geojson/California_County_Boundaries.geojson') |> 
  filter(COUNTY_NAME %in% c('Los Angeles', 'Orange', 'Riverside', 'San Bernardino')) |> 
  select(COUNTY_NAME, geometry) |> 
  rename(county = COUNTY_NAME)

planned_final <- planned_tidy |> 
  st_centroid() |> 
  st_join(Counties) |> 
  st_set_geometry(value = NULL) |> 
  inner_join(planned_tidy) |>
  filter(row != 342) |> 
  st_as_sf() |> 
  st_transform(crs=4326)  |> 
  select(-row) |> 
  mutate(floorSpace.sq.ft = 0.55*shape_area) |> 
  rename(category = class)

setwd(output_dir)
unlink('final_parcels_gt1acre.geojson')
st_write(final_parcels, 'final_parcels_gt1acre.geojson')

rm(ls = plannedWarehouses, planned_tidy, plannedParcel1, plannedParcel2,
   final_parcels_28k)
##Add data and stats for joining here

combo1 <- final_parcels |> 
  mutate(category = 'Existing',
         unknown = ifelse(year_chr == 'unknown', TRUE, FALSE)) |> 
  select(apn, shape_area2, category, year_built, class, county, geometry, unknown) |> 
  rename(shape_area = shape_area2)
  
combo2 <- planned_final |> 
  mutate(class = 'TBD', unknown = TRUE) |> 
  select(name, shape_area, category, year_built, class, county, geometry, unknown) |> 
  rename(apn = name)

combo_final1 <- bind_rows(combo1, combo2)

#Generate centroids for warehouse joins
combo_centroids <- combo_final1 |> 
  st_centroid()
#join counties
County_centroids <- combo_centroids |> 
  rename(county1 = county) |> 
  st_join(Counties) |> 
  mutate(countyIssue = ifelse(county1 == county, 0, 1)) |> 
  select(-county1, -countyIssue)

#join cities/CDPs
narrow_jurisdiction <- jurisdictions |> 
  select(name, geometry) |> 
  rename(place_name = name)

Jurisdiction_list <- County_centroids |> 
  st_join(narrow_jurisdiction) |>
  mutate(place_name = ifelse(is.na(place_name), 'unincorporated', place_name)) |> 
  st_set_geometry(value = NULL)

#Final join
combo_final <- combo_final1 |> 
  left_join(Jurisdiction_list) |> 
  distinct()


setwd(geojson_dir)
unlink('finalParcels.geojson')
unlink('plannedParcels.geojson')
unlink('comboFinal.geojson')
st_write(final_parcels, 'finalParcels.geojson', append = FALSE)
st_write(planned_final, 'plannedParcels.geojson', append = FALSE)
st_write(combo_final, 'comboFinal.geojson', append = FALSE)
setwd(wd)

rm(ls = combo1, combo2, IEcounties, planned_final, final_parcels, combo_final1)
##FIXME put stats here
rm(ls = joined_parcels2, sub1acre_warehouses)
rm(ls = County_centroids, Jurisdiction_list, narrow_jurisdiction, combo_centroids)


setwd(app_dir)
save.image('.RData')
setwd(warehouse_dir)
save.image('.RData')
setwd(shapefile_dir)
unlink('finalParcels.shp')
st_write(combo_final, 'finalParcels.shp', append = FALSE)
#st_write(planned_final, 'plannedParcels.shp', append = FALSE)

setwd(wd)


