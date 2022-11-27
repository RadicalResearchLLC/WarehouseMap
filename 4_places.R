##Warehouse Map App V1
##Created by Mike McCarthy, Radical Research LLC
##Inspired by Graham Brady and Susan Phillips at Pitzer College and their code
##located here: https://docs.google.com/document/d/16Op4GgmK0A_0mUHAf9qqXzT_aekbdLb_ZFtBaZKfj6w/edit
##First created November, 2022
##Last modified November, 2022
##This script acquires and tidies places - county, city, land-use authorities

library(sf)
library(tidyverse)
library(janitor)
library(leaflet)
library(htmltools)

'%ni%' <- Negate('%in%')

wd <- getwd()
city_dir <- paste0(wd, '/places/cities')
county_dir <- paste0(wd, '/places/CA_Counties')
MJPA_dir <- paste0(wd, '/places/MJPA/')

##Import city boundary data - https://data.ca.gov/dataset/ca-geographic-boundaries
setwd(city_dir)
#sf::st_layers(dsn = city_dir)
city_boundary <- sf::st_read(dsn = city_dir, quiet = TRUE, type = 3) %>%
  clean_names() %>% 
  st_transform("+proj=longlat +ellps=WGS84 +datum=WGS84")
##Import county boundary data - https://data.ca.gov/dataset/ca-geographic-boundaries
setwd(county_dir)
counties <- c('Los Angeles', 'Orange', 'Riverside', 'San Bernardino')

county_boundary <- sf::st_read(dsn = county_dir, quiet = TRUE, type = 3) %>% 
  clean_names() %>% 
  filter(name %in% counties) %>% 
  st_transform("+proj=longlat +ellps=WGS84 +datum=WGS84") %>% 
  select(name, lsad, geometry)

##Keep cities in four county region
##Keep places in four county region
city_list <- county_boundary %>% 
  select(geometry) %>% 
  #rename(county = name) %>% 
  st_join(city_boundary, left = TRUE) %>% 
  st_set_geometry(value = NULL) %>% 
  left_join(city_boundary) %>% 
  st_as_sf() %>% 
  st_transform("+proj=longlat +ellps=WGS84 +datum=WGS84") %>% 
  select(name, lsad, geometry) %>% 
  filter(lsad == 25)

##Remove dups
u <- st_equals(city_list, retain_unique = TRUE)
unique <- city_list[-unlist(u),] %>% 
  st_set_geometry(value = NULL)
final_cities <- unique %>% 
  left_join(city_list) %>% 
  distinct() %>% 
  st_as_sf() %>% 
  st_transform("+proj=longlat +ellps=WGS84 +datum=WGS84") #%>% 

##Import SCAG city boundary list - https://gisdata-scag.opendata.arcgis.com/datasets/27b134459761486991f0b72f8a9a67c5_0
SCAGList <- sf::st_read(dsn = 'C:/Dev/WarehouseMap/places/City_Boundaries_–_SCAG_Region.geojson') %>% 
  clean_names() %>% 
  filter(city == 'Unincorporated') %>% 
  filter(county %ni% c('Imperial', 'Ventura')) %>% 
  mutate(name = str_c(city, ' ', county),
         lsad = '26') %>% 
  select(name, geometry, lsad)

##Import MJPA boundary
setwd(MJPA_dir)
MJPA <- read_sf(dsn = MJPA_dir ) %>% 
  st_transform("+proj=longlat +ellps=WGS84 +datum=WGS84")

MJPA2 <- st_union(MJPA) %>% 
  st_transform("+proj=longlat +ellps=WGS84 +datum=WGS84")

areaValue <- st_area(MJPA2)

MJPA3 <- st_as_sf(MJPA2) %>% 
  mutate(name = 'MarchJPA',
         #convert m^2 to ft^2
         #area = as.numeric(areaValue*10.7639),
         lsad = 'JPA') %>% 
  rename(geometry = x)  

rm(ls = MJPA, MJPA2, u, unique, city_boundary, city_list)

## Remove MJPA from unincorporated Rivco

Unincorp_RivCo1 <- SCAGList %>% 
  filter(name == 'Unincorporated Riverside') %>% 
  st_union() %>% 
  st_as_sf() %>% 
  st_transform("+proj=longlat +ellps=WGS84 +datum=WGS84") %>% 
  rename(geometry = x) 

Unincorp_RivCo2 <- Unincorp_RivCo1 %>% 
  st_difference(MJPA3) %>% 
  mutate(name = 'Unincorporated RivCo')

rm(ls = Unincorp_RivCo1)

## Remove RivCo from SCAGList
SCAGList2 <- SCAGList %>% 
  filter(name != 'Unincorporated Riverside')

## Bind places together

jurisdictions <- bind_rows(final_cities, MJPA3, SCAGList2, Unincorp_RivCo2)

leaflet() %>% 
  addTiles() %>% 
  addPolygons(data = jurisdictions,
              label = ~htmlEscape(name),
              weight = 1,
              fillOpacity = 0.2)

rm(ls = final_cities, MJPA3, SCAGList, SCAGList2, Unincorp_RivCo2)
