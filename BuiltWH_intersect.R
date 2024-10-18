'%ni%' <- Negate('%in%') ## not in operator
library(leaflet)


recently_builtWH <- final_parcels |> 
  filter(year_built > 2020)

earlier_projects <- plannedWarehouses |> 
  filter(year_rcvd <= 2022) |> 
  st_centroid()

check_wh_list <- st_intersection(recently_builtWH, earlier_projects) #|> 
  #st_set_geometry(value = NULL) 

recently_builtIntersect <- recently_builtWH |> 
  st_filter(check_wh_list) 

check_wh_list2 <- st_intersection(plannedWarehouses, recently_builtIntersect) 

leaflet() |> 
  setView(lat = 34, lng = -117.60, zoom = 9) |> 
  addProviderTiles(providers$CartoDB.Positron, group = 'Basemap')  |>
  addProviderTiles(providers$Esri.WorldImagery, group = 'Imagery') |> 
  addLayersControl(baseGroups = c('Basemap', 'Imagery')) |> 
  addPolygons(data = recently_builtIntersect,
              color = 'blue',
              weight = 2,
              fillOpacity = 0.2,
              label = ~apn
  ) |> 
  addPolygons(data = check_wh_list2,
              color = 'red',
              weight = 1,
              fillOpacity = 0.2,
              label = ~apn) 

approved_built_since2022 <- check_wh_list2 |> 
  st_set_geometry(value = NULL) |> 
  select(project, sch_number, ceqa_url)

## Anti-join the built warehouses

planned_notBuilt <- plannedWarehouses |> 
  anti_join(approved_built_since2022) 

planned_tidy <- planned_notBuilt |> 
  mutate(shape_area =  round(parcel_area, -3),
         class = stage_pending_approved,
         year_chr = 'future',
         year_built = 2025,
         type = 'warehouse',
         row = row_number()) |> 
  select(-parcel_area, -stage_pending_approved) |> 
  mutate(county = str_c(county, ' County'))

rm(ls = planned_notBuilt, approved_built_since2022,
   check_wh_list, check_wh_list2, earlier_projects,
   recently_builtWH, recently_builtIntersect)

leaflet() |> 
  addPolygons(data = planned_tidy) |> 
  addTiles()
