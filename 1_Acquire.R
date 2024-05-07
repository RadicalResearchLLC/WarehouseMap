##Warehouse Map App V1
##Created by Mike McCarthy, Radical Research LLC
##Inspired by Graham Brady and Susan Phillips at Pitzer College and their code
##located here: https://docs.google.com/document/d/16Op4GgmK0A_0mUHAf9qqXzT_aekbdLb_ZFtBaZKfj6w/edit
##First created May, 2022
##Last modified April, 2024
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
#library(rmapshaper)
#library(pdftools)
#library(tesseract)
#library(tidygeocoder)

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
#source('LosAngeles.R')
#source('Orange.R')
narrow_OC_parcels <- sf::st_read('OC_whFixed.geojson') |> 
  select(-address2) |> 
  select(apn, shape_area, class, type, built_year, geometry, county) |> 
  rename(year_built = built_year)
narrow_LA_parcels <- sf::st_read(dsn = 'C:/Dev/WarehouseMap/Warehouse_data/LAfiltered_shp') |> 
  select(-count)

gc()

narrow_OC_parcels<- st_make_valid(narrow_OC_parcels) 

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
  mutate(floorSpace.sq.ft = round(shape_area*0.55, 0),
         shape_area = round(shape_area, 0)) |>
  #filter(floorSpace.th.sq.ft > 100) |>
  mutate(exclude = ifelse(floorSpace.sq.ft > sq_ft_threshold_WH, 0, 1)) #|>
 # filter(exclude == 0)

rm(ls = LA_warehouse_parcels, narrow_LA_parcels, narrow_RivCo_parcels, narrow_SBDCo_parcels, narrow_SBDCo_parcels2, narrow_OC_parcels)


##Import QA list of warehouses and non-warehouses 
##FIXME - move this up for when we identify warehouses currently not on the list
 
source('QA_list.R')

joined_parcels <- joined_parcels |>
  filter(apn %ni% not_warehouse) #|>
##Check for warehouse duplicates by location

sf_use_s2(FALSE)

area <- sf::st_area(joined_parcels)

sub1acre_warehouses <- joined_parcels |> 
  mutate(shape_area2 = round(as.numeric(area*10.76391), -2)) |> 
  select(-shape_area) |> 
  filter(exclude == 1)

final_parcels <- joined_parcels |> 
  mutate(shape_area2 = round(as.numeric(area*10.76391), -2)) |> 
  select(-shape_area) |> 
  filter(exclude == 0) |> 
  st_make_valid() |> 
  mutate(county = str_c(county, ' County'))

##import 
setwd(wd)
jurisdictions <- sf::st_read(dsn = paste0(jurisdiction_jur, 'SoCal_jurisdictions.geojson')) |> 
  clean_names()

##Import CalEnviroScreen
CalEJ4 <- sf::st_read(dsn = calEJScreen_dir, quiet = TRUE, type = 3) |>
  filter(County %in% c('Riverside', 'San Bernardino', 'Los Angeles', 'Orange')) |>
  select(Tract, TotPop19, ApproxLoc, CIscoreP, CIscore, geometry, DieselPM_P) |> 
  #filter(CIscoreP >= 75) |> 
  st_transform(crs = 4326)

#FIXME - will want this to be full tracked warehouses soon
plannedWH.url <- 'https://raw.githubusercontent.com/RadicalResearchLLC/PlannedWarehouses/main/CEQA_WH.geojson'
plannedWarehouses <- st_read(plannedWH.url) |> 
  st_transform(crs = 4326)

#shape_area <- st_area(plannedWarehouses)

planned_tidy <- plannedWarehouses |> 
  mutate(shape_area =  round(parcel_area, -3),
         class = stage_pending_approved,
         year_chr = 'future',
         year_built = 2025,
         type = 'warehouse',
         row = row_number()) |> 
  select(-parcel_area, -stage_pending_approved)

Counties <- sf::st_read(dsn = 'C:/Dev/WarehouseMap/community_geojson/California_County_Boundaries.geojson') |> 
  filter(COUNTY_NAME %in% c('Los Angeles', 'Orange', 'Riverside', 'San Bernardino')) |> 
  select(COUNTY_NAME, geometry) |> 
  rename(county = COUNTY_NAME) |> 
  mutate(county = str_c(county, ' County'))

planned_final <- planned_tidy |> 
  st_centroid() |> 
  st_join(Counties) |> 
  st_set_geometry(value = NULL) |> 
  inner_join(planned_tidy) |>
  #filter(row != 342) |> 
  st_as_sf() |> 
  st_transform(crs=4326)  |> 
  select(-row) |> 
  mutate(floorSpace.sq.ft = 0.55*shape_area) |> 
  rename(name = project)

setwd(output_dir)
unlink('final_parcels_gt1acre.geojson')
st_write(final_parcels, 'final_parcels_gt1acre.geojson')

combo1 <- final_parcels |> 
  mutate(category = 'Existing',
         unknown = ifelse(year_chr == 'unknown', TRUE, FALSE)) |> 
  select(apn, shape_area2, category, year_built, class, county, geometry, unknown) |> 
  rename(shape_area = shape_area2)
  
combo2 <- planned_final |> 
  mutate(class = ceqa_url, unknown = TRUE) |> 
  select(name, shape_area, category, year_built, class, county, geometry, unknown) |> 
  rename(apn = name)

rm(ls = plannedWarehouses, planned_tidy, plannedParcel1, plannedParcel2)
##Add data and stats for joining here

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
  rename(place_name = name) |> 
  filter(place_name %ni% c('Los Angeles County', 'Orange County', 
          'Riverside County', 'San Bernardino County'))

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
rm(ls = joined_parcels)

##Import Assembly and Senate Districts
assembly <- sf::st_read('C:/Dev/CA_spatial_data/SoCalLegislativePolygons.geojson') |> 
  st_transform(crs = 4326)
senate <- sf::st_read('C:/Dev/CA_spatial_data/SenateDistrictsCA.geojson') |> 
  st_transform(crs = 4326) |> 
  st_filter(Counties) |> 
  select(SenateDistrictLabel, geometry) |> 
  rename(DistrictLabel = SenateDistrictLabel) #|> 

districts <- bind_rows(assembly, senate)
rm(ls = assembly, senate)

##Include analysis of WAIRE NoV rules
source('WAIRE_NOV.R')

setwd(app_dir)
save.image('.RData')
setwd(warehouse_dir)
save.image('.RData')
setwd(shapefile_dir)
unlink('finalParcels.shp')
st_write(combo_final, 'finalParcels.shp', append = FALSE)
#st_write(planned_final, 'plannedParcels.shp', append = FALSE)

setwd(wd)


