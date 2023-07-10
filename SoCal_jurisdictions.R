## Extract SoCal Places for data Warehouse CITY
library(sf)
library(tidyverse)


Cal_places <- sf::st_read(dsn = 'C:/Dev/US_spatial_data/tl_2022_06_place') |> 
  st_transform(crs = 4326)

Cal_places_centroids <- st_centroid(Cal_places)

SoCalCounties <- sf::st_read(dsn =  'C:/Dev/WarehouseMap/community_geojson/California_County_Boundaries.geojson') |>
  filter(COUNTY_NAME %in% c('Los Angeles', 'Orange', 'Riverside', 'San Bernardino')) |> 
  filter(is.na(ISLAND)) |> 
  st_transform(crs = 4326)

SoCal_places <- SoCalCounties |> 
  st_join(Cal_places_centroids, join = st_contains) |> 
  st_set_geometry(value = NULL) |> 
  left_join(Cal_places) |> 
  st_as_sf() |> 
  st_transform(crs = 4326)

OC_and_LA_jurisdictions <- SoCalCounties |> 
  filter(COUNTY_NAME %in% c('Los Angeles', 'Orange')) |> 
  st_join(Cal_places, join = st_intersects) |> 
  st_set_geometry(value=NULL) |> 
  left_join(Cal_places) |> 
  st_as_sf() |> 
  st_transform(crs = 4326)

LAOC <- c('Malibu', 'Santa Monica', 'Manhattan Beach', 'Hermosa Beach', 'Redondo Beach', 'Palos Verde Estates',
          'Rancho Palos Verde', 'Newport Beach', 'El Segundo')

beach_towns <- OC_and_LA_jurisdictions |> 
  filter(NAME %in% LAOC)

SoCal_places2 <- rbind(SoCal_places, beach_towns) |> 
  select(COUNTY_NAME, NAME, NAMELSAD, ALAND, geometry)


setwd('C:/Dev/WarehouseMap/community_geojson')
unlink('SoCal_jurisdictions.geojson')
sf::st_write(SoCal_places2, 'SoCal_jurisdictions.geojson')

