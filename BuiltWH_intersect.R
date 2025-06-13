'%ni%' <- Negate('%in%') ## not in operator
library(leaflet)


recently_builtWH <- final_parcels |> 
  filter(year_built > 2016)

earlier_projects <- plannedWarehouses |> 
  filter(recvd_date <= mdy('1/1/2023')) |> 
  st_centroid()

earlier_projects2 <- plannedWarehouses |> 
  filter(recvd_date <= mdy('1/1/2023')) 

check_wh_list <- st_intersection(recently_builtWH, earlier_projects) #|> 
  #st_set_geometry(value = NULL) 

check_wh_list2 <- st_intersection(recently_builtWH, earlier_projects2)

check_wh_list3 <- check_wh_list2 |> 
  st_set_geometry(value = NULL) |> 
  select(sch_number)

difference <- check_wh_list3 |> 
  select(sch_number) |> 
  anti_join(check_wh_list) |> 
  left_join(check_wh_list2) |> 
  st_as_sf()

#recently_builtIntersect <- recently_builtWH |> 
#  st_filter(check_wh_list) 

#check_wh_list2 <- st_intersection(plannedWarehouses, recently_builtIntersect) 

leaflet() |> 
  setView(lat = 34, lng = -117.60, zoom = 9) |> 
  addProviderTiles(providers$CartoDB.Positron, group = 'Basemap')  |>
  addProviderTiles(providers$Esri.WorldImagery, group = 'Imagery') |> 
  addLayersControl(baseGroups = c('Basemap', 'Imagery')) |> 
  addPolygons(data = recently_builtWH,
              color = 'blue',
              weight = 2,
              fillOpacity = 0.2,
              label = ~year_built
  ) |> 
  addPolygons(data = earlier_projects2,
              color = 'orange',
              fillOpacity = 0.2,
              label = ~sch_number) |> 
  addPolygons(data = check_wh_list2,
              color = 'red',
              weight = 1,
              fillOpacity = 0.2,
              label = ~sch_number) |> 
  addMarkers(data = check_wh_list)

## check for non-centroid parcels
leaflet() |> 
  setView(lat = 34, lng = -117.60, zoom = 9) |> 
  addProviderTiles(providers$CartoDB.Positron, group = 'Basemap')  |>
  addProviderTiles(providers$Esri.WorldImagery, group = 'Imagery') |> 
  addLayersControl(baseGroups = c('Basemap', 'Imagery')) |> 
  addPolygons(data = earlier_projects2,
              color = 'orange',
              fillOpacity = 0.2,
              label = ~sch_number) |> 
  addPolygons(data = difference,
              color = 'red',
              weight = 1,
              fillOpacity = 0.2,
              label = ~sch_number) |> 
  addMarkers(data = st_centroid(difference))

OddCentroidsBuilt <- check_wh_list2 |> 
  filter(sch_number == '2020079023') |> 
  select(project, apn, sch_number, ceqa_url) |> 
  st_set_geometry(value = NULL)

approved_built_since2022 <- check_wh_list |> 
  st_set_geometry(value = NULL) |> 
  filter(sch_number %ni% c('2020059028', '2022020461')) |> 
  select(project, apn, sch_number, ceqa_url) |> # less than 50% buildout projects
  bind_rows(OddCentroidsBuilt)

## Anti-join the built warehouses

planned_notBuilt <- plannedWarehouses |> 
  anti_join(approved_built_since2022) 

## Add filter list for specific projects that are built out more than 50%
## FIXME

planned_tidy <- planned_notBuilt |> 
  mutate(shape_area =  round(parcel_area, -3),
         class = stage_pending_approved,
         year_chr = 'future',
         year_built = 2025,
         type = 'warehouse',
         row = row_number()) |> 
  select(-parcel_area, -stage_pending_approved) |> 
  mutate(county = str_c(county, ' County'))

leaflet() |> 
  setView(lat = 34, lng = -117.60, zoom = 9) |> 
  addProviderTiles(providers$CartoDB.Positron, group = 'Basemap')  |>
  addProviderTiles(providers$Esri.WorldImagery, group = 'Imagery') |> 
  addLayersControl(baseGroups = c('Basemap', 'Imagery')) |> 
  addPolygons(data = recently_builtWH,
              color = 'darkred',
              fillOpacity = 0.2,
              weight = 1) |> 
  addPolygons(data = planned_tidy,
              color = 'orange',
              weight = 1,
              fillOpacity = 0.2,
              label = ~sch_number) 

rm(ls = planned_notBuilt, approved_built_since2022,
   check_wh_list, check_wh_list2, earlier_projects,
   recently_builtWH, recently_builtIntersect,
   earlier_projects2, difference, check_wh_list3)



#leaflet() |> 
  #addPolygons(data = planned_tidy,
    #          weight = 2, 
   #           color = 'red') |> 
  #addPolygons(data = recently_builtWH,
 #             weight = 2, color = 'blue') |> 
#  addTiles()

