# WAIRE imports and overlay checks

library(tidygeocoder)
library(leaflet)
library(sf)
library(purrr)
library(tabulapdf)
library(tidyverse)

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

pdf_path <- 'C:/Policy/WAIRE/violations-list_Jan2026.pdf'
p1 <- extract_tables(pdf_path, pages = 2:7, col_names = FALSE)
p2 <- extract_tables(pdf_path, pages = 9:18, col_names = FALSE)
p3 <- extract_tables(pdf_path, pages = 20:22, col_names = FALSE)
p8 <- extract_tables(pdf_path, pages = 8, col_names= FALSE, method = 'stream')
p19 <- extract_tables(pdf_path, pages = 19, col_names= FALSE, method = 'stream')
pg1_2 <-  extract_tables(pdf_path, pages = 1, col_names= FALSE, method = 'stream')
pg1 <- pg1_2[[1]] |> 
  slice(-1) |> 
  mutate(X4 = as.numeric(X4)) #|> 
  
tblList <- bind_rows(pg1,  p1[[1]], p1[[2]], p1[[3]], p1[[4]], p1[[5]], p1[[6]],
                    p8,  p2[[1]], p2[[2]], p2[[3]], p2[[4]],
                     p2[[5]], p2[[6]], p2[[7]], p2[[8]], p2[[9]],
                     p2[[10]], p19,p3[[1]], p3[[2]], p3[[3]],
) |> 
  rename(company = X1,
         address = X2,
         city = X3,
         zip = X4) |> 
  mutate(rowNo = row_number())

#googlesheets4::write_sheet(tblList, 
#                           ss = 'https://docs.google.com/spreadsheets/d/1VuiIqpsqrW1Gr3UPL7oLSZDeGViQL2KpEghxVcwJ8W8/edit?gid=0#gid=0')

fixTbl <- googlesheets4::read_sheet(ss = 'https://docs.google.com/spreadsheets/d/1VuiIqpsqrW1Gr3UPL7oLSZDeGViQL2KpEghxVcwJ8W8/edit?gid=0#gid=0',
                                    sheet = 'fixTbl') |> 
  janitor::clean_names() |> 
  filter(zip > 0) 

fixTbl2 <- fixTbl |> 
  select(-row_no) |> 
 # mutate(company = str_to_lower(company)) |> 
  group_by(company, address, city, zip) |> 
  summarize(count = n(), .groups = 'drop') 

fixTbl3 <- fixTbl |> 
  filter(lat > 0) |> 
  st_as_sf(coords = c('lng', 'lat'), crs = 4326) |> 
  select(-row_no)

rm(ls = p1, p19, p2, p3, p8, pg8, fixTbl)
rm(ls = pg1, pg1_2)
#sheet1 <- pdf_ocr_text('C:/Policy/WAIRE/violations-list_Dec2024.pdf')

#path <- 'C:/Policy/WAIRE/NOV_List_12_14_24.xlsx' #|>

#nm = c('Name', 'Address', 'City', 'Zip')

#table <- path |> 
#  readxl::excel_sheets() |> 
#  map(readxl::read_excel, path = path)#|> 

#table2 <- path |> 
#  readxl::excel_sheets() |>
#  map_df(~ readxl::read_excel(path = path, sheet = .x), .id = 'sheet')

#colnames(table2) <- c('sheet', 'name', 'address', 'city', 'zip')
  

#  set
#  mutate(addr = str_c(Address, ', ', City, ' ', Zip)) |> 
#  janitor::clean_names()

#Geocodio appears to do the best job
lat_longs_geocodio <- fixTbl2 |> 
  mutate(addr = stringr::str_c(address, ', ', city, ' ', zip)) |> 
  ##FIXME
  anti_join(fixTbl3) |> 
  geocode(address = addr, method = 'geocodio',
          full_results = TRUE) 

NOV_buffer_70m <- lat_longs_geocodio |> 
  filter(accuracy > 0.8) |> 
  select(company, address, city, zip, lat, long) |> 
  st_as_sf(coords = c('long', 'lat'), crs = 4326) |>
  bind_rows(fixTbl3) |> 
  st_transform(crs = 2230) |> 
  st_buffer(dist = 70) |> 
  st_transform(crs = 4326) |> 
  left_join(fixTbl2) 

#poorAccuracy_buffer <- NOV_buffer_70m |> 
#  filter(accuracy <0.8)

leaflet() |> 
  addTiles() |> 
  addPolygons(data= poorAccuracy_buffer,
              fillOpacity = 0.1,
              label = ~company,
              color = 'red')

warehouses_NOV <- combo_final |>
  filter(category == 'Existing') |> 
  filter(shape_area > 80000) |> 
  st_filter(NOV_buffer_70m)

leaflet() |> 
  addProviderTiles(provider = providers$CartoDB.Positron, group = 'Basemap') |> 
  addProviderTiles(provider = providers$Esri.WorldImagery, group = 'Imagery') |> 
  addLayersControl(baseGroups = c('BaseMap', 'Imagery'), 
                   overlayGroups = c('Warehouses', 'NOV addresses'),
                   options = layersControlOptions(collapsed = FALSE)) |> 
  addPolygons(data = combo_final,
              color = 'darkblue',
              weight = 0.3,
              fillOpacity = 0.1,
              label = ~apn) |> 
  #addPolygons(data = warehouses_NOV,
  #            color = 'black',
  #            label = ~apn,
  #            weight = 2,
  #            fillOpacity = 0.5) |> 
  addPolygons(data = warehouses_NOV,
              # lng = ~long,
              # lat = ~lat,
              label = ~paste(apn),
              weight = 1,
              fillOpacity = 0.9,
              color = 'black') # |> 
 # addPolygons(data= poorAccuracy_buffer,
  #            fillOpacity = 1,
 #             label = ~str_c(company, ' ', address, ' ', city),
 #             color = 'red')

rm(ls = warehouses_100k_estimate)
rm(ls = buffer_70m, table, table2)
rm(ls = fixTbl, fixTbl2, fixTbl3)
rm(ls = poorAccuracy_buffer)
rm(ls = tblList, NOV_buffer_70m)
