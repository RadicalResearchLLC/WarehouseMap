# WAIRE imports and overlay checks

library(tidygeocoder)
library(leaflet)
library(sf)
library(purrr)

#WH.url <- 'https://raw.githubusercontent.com/RadicalResearchLLC/WarehouseMap/main/WarehouseCITY/geoJSON/comboFinal.geojson'
#combo_final <- st_read(WH.url) |>  
#  st_transform(crs = 4326) 

warehouses_100k_estimate <- combo_final |>
  mutate(est_SQFT = 0.5*shape_area) |> 
  filter(est_SQFT > 100000) |> 
  filter(category == 'Existing') |> 
  mutate(ISR_category = 
           case_when(est_SQFT >= 250000 ~ 'PhaseI',
                     est_SQFT >= 150000 & est_SQFT < 250000 ~ 'PhaseII',
                     est_SQFT >= 100000 & est_SQFT < 150000 ~ 'PhaseIII')) |> 
  st_set_geometry(value = NULL) |> 
  group_by(ISR_category) |> 
  summarize(count = n(),
            avg_SQFT = mean(est_SQFT),
            median_SQFT = median(est_SQFT),
            total_area_SQFT = sum(est_SQFT))

#NOV_PhaseI <- readxl::read_excel(str_c(output_dir, '/NOV_List_12_14_23.xlsx')) |>
#  mutate(addr = str_c(Address, ', ', City, ' ', Zip)) |> 
#  janitor::clean_names()

path <- 'C:/Policy/WAIRE/NOV_List_12_14_24.xlsx' #|>

nm = c('Name', 'Address', 'City', 'Zip')

table <- path |> 
  readxl::excel_sheets() |> 
  map(readxl::read_excel, path = path)#|> 

table2 <- path |> 
  readxl::excel_sheets() |>
  map_df(~ readxl::read_excel(path = path, sheet = .x), .id = 'sheet')

colnames(table2) <- c('sheet', 'name', 'address', 'city', 'zip')
  

#  set
#  mutate(addr = str_c(Address, ', ', City, ' ', Zip)) |> 
#  janitor::clean_names()

#Geocodio appears to do the best job
lat_longs_geocodio <- table2 |> 
  mutate(addr = stringr::str_c(address, ', ', city, ' ', zip)) |> 
  geocode(address = addr, method = 'geocodio',
          full_results = TRUE) 

buffer_70m <- lat_longs_geocodio |> 
  st_as_sf(coords = c('long', 'lat'), crs = 4326) |>
  st_transform(crs = 2230) |> 
  st_buffer(dist = 70) |> 
  st_transform(crs = 4326)

leaflet() |> 
  addTiles() |> 
  addPolygons(data= buffer_70m,
              fillOpacity = 0.1)

warehouses_NOV <- combo_final |>
  filter(category == 'Existing') |> 
  filter(shape_area > 100000) |> 
  st_filter(buffer_70m)

leaflet() |> 
  addProviderTiles(provider = providers$CartoDB.Positron, group = 'Basemap') |> 
  addProviderTiles(provider = providers$Esri.WorldImagery, group = 'Imagery') |> 
  addLayersControl(baseGroups = c('BaseMap', 'Imagery'), 
                   overlayGroups = c('Warehouses', 'NOV addresses'),
                   options = layersControlOptions(collapsed = FALSE)) |> 
  addPolygons(data = combo_final,
              color = 'darkred',
              weight = 0.3,
              fillOpacity = 0.2,
              label = ~apn) |> 
  addPolygons(data = warehouses_NOV,
              color = 'black',
              label = ~apn,
              weight = 2,
              fillOpacity = 0.5) |> 
  addPolygons(data = buffer_70m,
              # lng = ~long,
              # lat = ~lat,
              label = ~paste(name, addr),
              weight = 1,
              fillOpacity = 0.9)  |> 
  addCircleMarkers(data = lat_longs_geocodio,
                   lat = ~lat,
                   lng = ~long,
                   label = ~paste(name, addr),
                   weight = 1, 
                   color = 'darkblue',
                   radius = 5)

rm(ls = warehouses_100k_estimate)
rm(ls = buffer_70m, table, table2)

