#Extra code bits

#Display 'other' parcel type outlines
observe({
  leafletProxy("map", data = filter(filteredParcels(), type == 'other')) %>%
    clearGroup(group = 'Other parcel types') %>%
    addPolygons(color = 'orange', 
                fillOpacity = 0, 
                weight = 2,
                group = 'Other parcel types',
                label = ~htmlEscape(paste('Parcel', apn, ';', round(shape_area,0), 'sq.ft.', class, year_chr)))
})