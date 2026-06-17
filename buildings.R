library(overturemapsr)
library(tigris)
library(dplyr)
library(sf)
library(pmtiles)
library(readr)
library(stringr)

wd <- getwd()
data_dir <- str_c(wd, '/Datasets')

### IE Processing separate from LA/OC due to size
WH.url <- 'https://raw.githubusercontent.com/RadicalResearchLLC/WarehouseMap/main/WarehouseCITY/geoJSON/comboFinal.geojson'
warehouses <- st_read(WH.url) |>  
  st_transform(crs = 4326) |> 
  filter(!is.na(category))

sf_use_s2(FALSE)

gc()

gc()
wh_unionIE <- warehouses |> 
  filter(county %in% c('Riverside County', 'San Bernardino County')) |> 
  group_by(category) |> 
  summarize()

#leaflet::leaflet() |> leaflet::addTiles() |> leaflet::addPolygons(data = wh_unionIE)
CA_bbox<-st_bbox(wh_unionIE)

sys.time()
## download buildings for CA - May 20, 2026 version
buildings <- record_batch_reader(
  schema_type = 'building',
  bbox = CA_bbox,
  release_date = '2026-05-20'
)
rm(ls = warehouses)
gc()
wh_buildings <- st_filter(buildings, wh_unionIE) 
wh_buildings2 <- wh_buildings |> 
  select(id, geometry)

gc()
sf_use_s2(FALSE)
st_write(wh_buildings2, 'buildingsIE.geojson')

rm(ls = wh_unionIE, wh_buildings, buildings, wh_buildings2)
gc()

warehouses <- st_read(WH.url) |>  
  st_transform(crs = 4326) |> 
  filter(!is.na(category))

sf_use_s2(FALSE)

gc()
wh_unionLA <- warehouses |> 
  filter(county %in% c('Orange County', 'Los Angeles County')) |> 
  group_by(category) |> 
  summarize()

#leaflet::leaflet() |> leaflet::addTiles() |> leaflet::addPolygons(data = wh_unionIE)
CA_bbox2<-st_bbox(wh_unionLA)

rm(ls = warehouses)
gc()
sys.time()
## download buildings for CA - May 20, 2026 version
buildingsLA <- record_batch_reader(
  schema_type = 'building',
  bbox = CA_bbox2,
  release_date = '2026-05-20'
)

gc()
wh_buildingsLA <- st_filter(buildingsLA, wh_unionLA) 
wh_buildingsLA2 <- wh_buildingsLA |> 
  select(id, geometry)

rm(ls = buildingsLA)


leaflet::leaflet() |> leaflet::addTiles() |> leaflet::addPolygons(data = wh_buildingsLA)

gc()
sf_use_s2(FALSE)
st_write(wh_buildingsLA2, 'buildingsLA.geojson')

### one off combo of data

buildingsIE <- sf::st_read(dsn = 'buildingsIE.geojson')
buildingsLA <- sf::st_read(dsn = 'buildingsLA.geojson')

buildingsAll <- bind_rows(buildingsIE, buildingsLA)

areaSF <- as.numeric(st_area(buildingsAll))*10.7639
buildingsAll$areaSF <- areaSF
       
smallBldgs <- buildingsAll |> 
  filter(areaSF < 22000)
whBldgs <- buildingsAll |> 
  filter(areaSF >= 22000)

leaflet::leaflet() |> leaflet::addProviderTiles("Esri.WorldImagery" 
                                                  ) |> leaflet::addPolygons(data = whBldgs)
            
st_write(smallBldgs, 'smallWH.geojson')
st_write(whBldgs, 'buildingsJune26.geojson')

