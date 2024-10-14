'%ni%' <- Negate('%in%') ## not in operator

recently_builtWH <- combo_final |> 
  filter(category == 'Existing') |> 
  filter(year_built > 2021)

approved <- combo_final |> 
  filter(category == 'Approved')

check_wh_list <- st_intersection(recently_builtWH, approved) |> 
  st_set_geometry(value = NULL) 

recently_builtIntersect <- recently_builtWH |> 
  right_join(check_wh_list) 

check_wh_list2 <- st_intersection(approved, recently_builtWH) |> 
  st_set_geometry(value = NULL) 

approved_intersect <- approved |> 
  right_join(check_wh_list2)

sf_use_s2(FALSE)
leaflet() |> 
  setView(lat = 34, lng = -117.60, zoom = 9) |> 
  addProviderTiles(providers$CartoDB.Positron, group = 'Basemap')  |>
  addProviderTiles(providers$Esri.WorldImagery, group = 'Imagery') |> 
  addLayersControl(baseGroups = c('Basemap', 'Imagery')) |> 
  addPolygons(data = approved_builtJune2024,
              color = 'red',
              weight = 1,
              fillOpacity = 0.2,
              label = ~apn) |> 
  addPolygons(data = recently_builtIntersect,
              color = 'blue',
              weight = 2,
              fillOpacity = 0.2,
              #label = ~year_built
              ) 

# export data that is mostly built for removal
# remove parcels not yet 66% built out

approved_builtJune2024 <- approved_intersect |> 
  filter(apn %ni% c('Merril Commerce Center Specific Plan area',
                    'Beech Avenue Logistics Center',
                    'Old 215 Industrial Business Park',
                    'Ramona Indian Warehouse project',
                    'Core5 Rider Project',
                    'South campus'))


