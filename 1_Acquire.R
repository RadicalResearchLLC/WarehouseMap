##Warehouse Map App V1
##Created by Mike McCarthy, Radical Research LLC
##Inspired by Graham Brady and Susan Phillips at Pitzer College and their code
##located here: https://docs.google.com/document/d/16Op4GgmK0A_0mUHAf9qqXzT_aekbdLb_ZFtBaZKfj6w/edit
##First created May, 2022
##Last modified April, 2023
##This script acquires and tidy parcel data for the app

#rm(list =ls()) # clear environment
'%ni%' <- Negate('%in%') ## not in operator
gc()
##Libraries used in data acquisition
#library(RCurl)

##Libraries used in data processing and visualization
library(tidyverse)
library(janitor)
library(readxl)
library(googlesheets4)
##spatial libraries and visualization annotation
library(leaflet)
library(sf)
library(htmltools)
library(rmapshaper)

##set working, data, and app directories
wd <- getwd()

###set data, app, and export subdirectories
app_dir <- paste0(wd, '/WarehouseCITY')
warehouse_dir <- paste0(wd, '/Warehouse_data')
output_dir <- paste0(wd, '/exports_other')
RivCo1_dir <- paste0(warehouse_dir, '/CREST_tables.gdb')
RivCo2_dir <- paste0(warehouse_dir, '/ParcelAttributed.gdb')
SBD_dir <- paste0(warehouse_dir, '/SBD_Parcel')
OC_dir <- paste0(warehouse_dir, '/OC_parcels')
##LA data goes through a preprocessing script 2_preprocess_LA_parcels.R
##This saves time and precious memory in this script
LA_dir <- paste0(warehouse_dir, '/LAfiltered_shp')
#AQMD_dir <- paste0(wd, '/SCAQMD_shp')
#city_dir <- paste0(wd, '/cities')
calEJScreen_dir <- paste0(wd, '/calenviroscreen40')
shapefile_dir <- paste0(app_dir, '/shapefile')
geojson_dir <- paste0(app_dir, '/geoJSON')
jurisdiction_jur <- paste0(wd, '/community_geojson/')
#aqdata_dir <- paste0(wd, '/air_quality_data')
#metdata_dir <- paste0(wd, '/met_data' )
#trafficdata_dir <- paste0(wd, '/traffic_data')
#truck_dir <- paste0(wd, '/TruckTrafficData')

## Acquire warehouse data files
setwd(warehouse_dir)

gc()
##Set minimum size for analysis in thousand sq.ft. for non-warehouse classified
##FIXME - should be acreage based
sq_ft_threshold_WH <- 28000
sq_ft_threshold_maybeWH <- 150000

##Try to import LA County data
sf::st_layers(dsn = LA_dir)
LA_warehouse_parcels <- sf::st_read(dsn = LA_dir, quiet = TRUE, type = 3)  |> 
  st_transform("+proj=longlat +ellps=WGS84 +datum=WGS84")

gc()

##Import parcels and property record files for Riverside County
##st_read(type=1) is attempting to create the same sfc type for both counties
##FIXME - crest property just a table?
crest_property <- sf::st_read(dsn = RivCo1_dir, layer = 'CREST_PROPERTY_CHAR')
parcels <- sf::st_read(dsn = RivCo2_dir, layer = 'PARCELS_CREST', quiet = TRUE, type = 3)
class(st_geometry(parcels))
##Read and import property record files for San Bernadino County
sf::st_layers(dsn = SBD_dir)
SBD_parcels <- sf::st_read(dsn=SBD_dir, quiet = TRUE, type = 3)
class(st_geometry(SBD_parcels))

######Tidy up the data for use
##select just property number and year built for riverside county CREST
crest_property_slim <- crest_property |>
  dplyr::select(PIN, YEAR_BUILT) |>
  dplyr::distinct()

crest_property_dups <- crest_property_slim |>
  select(PIN) |>
  group_by(PIN) |>
  summarize(count = n()) |>
  filter(count > 1) |>
  left_join(crest_property_slim) |>
  mutate(unk = ifelse(is.na(YEAR_BUILT), 1,
                ifelse(YEAR_BUILT < 1911, 1, 0))) |>
  filter(unk == 0) |>
  group_by(PIN) |>
  summarize(PIN, YEAR_BUILT = min(YEAR_BUILT), .groups = 'drop') |>
  unique()

crest_property_dups2 <- crest_property_slim |>
  select(PIN) |>
  group_by(PIN) |>
  summarize(count = n()) |>
  filter(count > 1) |>
  left_join(crest_property_dups) 

crest_property_solo <- crest_property_slim |>
  dplyr::select(PIN) |>
  group_by(PIN) |>
  summarize(count = n(), .groups = 'drop') |>
  filter(count == 1) |>
  left_join(crest_property_slim)

crest_property_tidy <- bind_rows(crest_property_solo, crest_property_dups2)

##filter on warehouses and light-industrial for Riverside County
##transform coordinates from Northing-Easting to Lat-Long
parcels_warehouse <- parcels |>
  mutate(class = stringr::str_to_lower(CLASS_CODE)) |>
  filter(str_detect(class, 'warehouse')) |>
  st_transform("+proj=longlat +ellps=WGS84 +datum=WGS84")

source(paste0(wd, '/QA_list2.R'))

parcels_manual_wh <- parcels |> 
  mutate(class = stringr::str_to_lower(CLASS_CODE)) |>
  filter(APN %in% add_as_warehouse) |>
  st_transform("+proj=longlat +ellps=WGS84 +datum=WGS84")

parcels_lightIndustry <- parcels |>
  mutate(class = stringr::str_to_lower(CLASS_CODE)) |>
  filter(str_detect(class, 'light industrial')) |>
  filter(SHAPE_Area > sq_ft_threshold_maybeWH) |>
  st_transform("+proj=longlat +ellps=WGS84 +datum=WGS84")

##Bind two Riv.co. datasets together
##Create a type category for the warehouse and industrial designation parcels

parcels_join_yr <- bind_rows(parcels_warehouse, parcels_lightIndustry, parcels_manual_wh) |>
  left_join(crest_property_tidy, by =c('APN' = 'PIN')) |>
  unique() |>
  mutate(YEAR_BUILT = ifelse(is.na(YEAR_BUILT), 1776, YEAR_BUILT)) |>
  mutate(type = as.factor(ifelse(str_detect(class, 'warehouse'), 'warehouse', 'other')))

##parse SBD data codes
setwd(warehouse_dir)
SBD_codes <- read_excel('Assessor Use Codes 05-21-2012.xls') |>
  clean_names() |>
  mutate(description = str_to_lower(description),
         use_code = as.numeric(use_code)) |>
  mutate(type = case_when(
    str_detect(description, 'warehouse') ~ 'warehouse',
    str_detect(description, 'light industrial') ~'other',
    str_detect(description, 'flex') ~ 'other',
    str_detect(description, 'storage') ~ 'other',
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

##Import OC data - current parcels are useless
#sf::st_layers(dsn = OC_dir)
##FIXME
#lu_codes <- c('1231', '1323', '1340', '1310')
OC_parcels <- sf::st_read(dsn=paste0(warehouse_dir, '/OC_wh2018.geojson'), quiet = TRUE, type = 3) |>
  clean_names() |>
  mutate(class = 'warehouse',
         type = 'warehouse')


## Need to convert OC parcel data from XYZ polygon to XY polygon
narrow_OC_parcels <- OC_parcels |>
 # left_join(code_desc, (by = c('lu16' = 'lu_codes'))) |>
  mutate(year_built = 1910) |>
  #select(apn, shape_area, class, type, geometry, year_built, county) |>
  st_transform("+proj=longlat +ellps=WGS84 +datum=WGS84") |>
  mutate(type = as.factor(type)) |>
  #st_zm() |>
  mutate(threshold = ifelse(shape_area > sq_ft_threshold_maybeWH, 1, 0)) |>
  mutate(exclude = ifelse(type == 'warehouse', 0,
                          ifelse(threshold == 1, 0, 1))) |>
  filter(exclude == 0) |>
  rename(apn = address) |> 
  select(apn, shape_area, class, type, geometry, year_built, county) #|>

##combine spatial data frames for display
##Select and rename columns to make everything match
##Note that we can always add other columns if they are useful for display 
narrow_RivCo_parcels <- parcels_join_yr |>
  dplyr::select(APN, SHAPE_Area, class, type, SHAPE, YEAR_BUILT) |>
  clean_names() |>
  st_cast(to = 'POLYGON') #|>

##Function required to rename sf column because sf package is dumb about this
rename_geometry <- function(g, name){
  current = attr(g, "sf_column")
  names(g)[names(g)==current] = name
  st_geometry(g)=name
  g
}

narrow_RivCo_parcels <- rename_geometry(narrow_RivCo_parcels, 'geometry') |>
  mutate(county = 'Riverside')
names(narrow_RivCo_parcels)
  
narrow_SBDCo_parcels <- SBD_warehouse_ltInd |>
  mutate(year_built = BASE_YEAR) |>
  dplyr::select(APN, SHAPE_AREA, class, type, geometry, year_built) |>
  clean_names() |>
  mutate(county = 'San Bernardino')


# Import DataTree Year_built info
DataTree <- readxl::read_excel('SBDCo_warehouse_list2_Output.xlsx') |> 
  janitor::clean_names() |> 
  select(apn_formatted, apn_unformatted, year_built, year_built_effective)

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

narrow_SBDCo_parcels2 <- compare |> 
  mutate(year_built2 = ifelse(is.na(year_built), year_base, year_built)) |> 
  dplyr::select(apn, shape_area, class, type, geometry, year_built2, county) |> 
  rename(year_built = year_built2)

## Remove big raw files and save .RData file to app directory

str(narrow_RivCo_parcels)
str(narrow_SBDCo_parcels2)
str(LA_warehouse_parcels)
str(narrow_OC_parcels)

narrow_LA_parcels <- rename_geometry(LA_warehouse_parcels, 'geometry') |>
  mutate(type = as.factor(type), county = 'Los Angeles')

rm(ls = parcels, crest_property, crest_property_slim, SBD_parcels, crest_property_solo, 
   crest_property_dups, crest_property_dups2, crest_property_tidy, OC_parcels) #|>

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
setwd(wd) 
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

combo_final <- bind_rows(combo1, combo2)
setwd(geojson_dir)
unlink('finalParcels.geojson')
unlink('plannedParcels.geojson')
unlink('comboFinal.geojson')
st_write(final_parcels, 'finalParcels.geojson', append = FALSE)
st_write(planned_final, 'plannedParcels.geojson', append = FALSE)
st_write(combo_final, 'comboFinal.geojson', append = FALSE)
setwd(wd)

rm(ls = combo1, combo2, IEcounties, planned_final, final_parcels)
##FIXME put stats here
rm(ls = joined_parcels2, sub1acre_warehouses)


setwd(app_dir)
save.image('.RData')
setwd(warehouse_dir)
save.image('.RData')
setwd(shapefile_dir)
unlink('finalParcels.shp')
st_write(combo_final, 'finalParcels.shp', append = FALSE)
#st_write(planned_final, 'plannedParcels.shp', append = FALSE)

setwd(wd)


