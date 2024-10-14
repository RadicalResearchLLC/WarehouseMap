# WAIRE imports and overlay checks

library(tidygeocoder)
library(leaflet)

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

NOV_PhaseI <- readxl::read_excel(str_c(output_dir, '/NOV_List_12_14_23.xlsx')) |>
  mutate(addr = str_c(Address, ', ', City, ' ', Zip)) |> 
  janitor::clean_names()

#Geocodio appears to do the best job
lat_longs_geocodio <- NOV_PhaseI |> 
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

rm(ls = warehouses_100k_estimate)
rm(ls = buffer_70m, NOV_PhaseI)

