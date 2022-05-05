## This is an alpha version of Warehouse CITY, a community mapping tool for warehouse impacts
## Authored by Mike McCarthy, Radical Research LLC
## Thanks to Sean Raffuse at UC Davis AQRC for help with the nearby intersection code for great circles 
## First created May, 2022
## Last modified May, 2022
#

library(shiny)
library(leaflet)
library(htmltools)
#library(gghighlight)
#library(spatstat)
library(sf)
#library(gstat)
#library(spdep)
#library(raster)
#library(rgdal)
library(tidyverse)
library(DT)
#library(automap)
#library(gstat)

# Define UI for application that displays warehouses
ui <- fluidPage(title = 'Warehouse CITY',
  tags$style(type="text/css", "div.info.legend.leaflet-control br {clear: both;}"),
    titlePanel(
      fluidRow(column(4),
               column(width =6,
               div(style = 'height:60px; font-size: 50px;',
               'Warehouse CITY')),
               column(2, shiny::img(height = 30, src = 'Logo.png')))
      ),

    # Display map and bar chart
    fluidRow(column(1),
             column(4, sliderInput('year_slider', 'Year built', min(final_parcels$year_built), max(final_parcels$year_built), 
             value = range(final_parcels$year_built), step = 1, sep =''), animate = TRUE),
             column(7)
             ),
    fluidRow(column(12, textOutput('test'))),
    fluidRow(column(4, textOutput('text2'))),
    fluidRow(
        column(8, align = 'center', leafletOutput("map", height = 800)),
        column(4, align = 'center', dataTableOutput('warehouseDF'))
        ),
  
)

# Define server logic required to draw a histogram
server <- function(input, output) {

# Filter data to only include subset from input menus  

# color palettes and lists
  palette <- colorFactor( palette = c('Blue', 'Brown'),
                          levels = c('warehouse', 'light industrial'))
  
  #str(parcels_join_yr)
  #Create leaflet map with legend 
  
output$map <- renderLeaflet({
    map1 <- leaflet(data = final_parcels) %>%
      addTiles() %>%
      setView(lat = 34, lng = -117.30, zoom = 11) %>%
      addProviderTiles("Esri.WorldImagery", group = 'Imagery') %>%
      addLayersControl(baseGroups = c('Basemap', 'Imagery'),
        overlayGroups =c('Warehouses', 'Circle'),
        options = layersControlOptions(collapsed = FALSE)
        ) %>%
      #addPolygons(color = ~palette(type), 
      #  group = 'Warehouses',
      #  label = ~htmlEscape(paste('Parcel', apn, ';', round(shape_area,0), 'sq.ft.', class, year_built))
      #  ) %>%
      addLegend(pal = palette, 
        values = c('warehouse', 'light industrial'),
        title = 'Parcel class') 
    
    map1
    })

filteredParcels <- reactive({
     selectedYears <- final_parcels %>%
       filter(year_built >= input$year_slider[1] & year_built <= input$year_slider[2]) %>%
       mutate(shape_area = round(shape_area, 0))
       
})

parcelDF1 <- reactive({
  filteredParcels() %>%
    as.data.frame() %>%
    rename(parcel.number = apn, sq.ft = shape_area) %>%
    dplyr::select(-geometry, -type) %>%
    arrange(desc(sq.ft))
})

trip_length <- 50

SumStats <- reactive({
  parcelDF_circle() %>%
    summarize(count = n(), sum.Sq.Ft. = round(sum(sq.ft), 0)) %>%
    mutate(Truck.Trips = round(Truck_trips_1000sqft*sum.Sq.Ft./1000 ,0)) %>%
    mutate(PoundsDiesel = round(trip_length*Truck.Trips*DPM_VMT_2022_lbs,1))
})

output$test <- renderText({
   paste('Your selection has', SumStats()$count, 'warehouses, summing to', SumStats()$sum.Sq.Ft,
         'sq.ft. which resulted in an estimated', SumStats()$Truck.Trips, 'truck trips emitting', SumStats()$PoundsDiesel, 
         'pounds of Diesel PM every day')
         })

observe({
  leafletProxy("map", data = filteredParcels()) %>%
      clearShapes() %>%
      addPolygons(color = ~palette(type), 
        group = 'Warehouses',
        label = ~htmlEscape(paste('Parcel', apn, ';', round(shape_area,0), 'sq.ft.', class, year_built)) 
      )
})

observe({
  leafletProxy("map", data = circle()) %>%
    clearGroup(group = 'Circle') %>%
    addPolygons(color = 'grey50',
                group = 'Circle')
  })

## Generate a data table of warehouses in selected reactive data
output$warehouseDF <- renderDataTable(
  parcelDF_circle(), 
  caption  = 'Warehouse list by parcel number, square footage, and year built',
  rownames = FALSE, 
  options = list(dom = 'tp',
                 pageLength = 15) 
)

output$text2 <- renderText({
  req(input$map_click)
  paste('You clicked on', round(input$map_click$lat,5), round(input$map_click$lng,5))
})

##Calculate circle around a selected point
circle <- reactive({
  req(input$map_click)
  #FIXME - make this user defined
  distance <- 5000
  lat1 <- round(input$map_click$lat, 8)
  lng1 <- round(input$map_click$lng, 8)
  clickedCoords <- data.frame(lng1, lat1)
  
  dat_point <- st_as_sf(clickedCoords, coords = c('lng1', 'lat1'), crs = 4326) %>%
    st_transform(3857)
  circle_sf <- st_buffer(dat_point, distance) %>%
    st_transform("+proj=longlat +ellps=WGS84 +datum=WGS84")
  return(circle_sf)
})

##Code to select nearby warehouse polygons
nearby_warehouses <- reactive({
  req(circle())
  nearby <- st_intersects(circle(), filteredParcels())
  nearby2 <- filteredParcels()[nearby[[1]],] %>%
    as.data.frame() %>%
    rename(parcel.number = apn, sq.ft = shape_area) %>%
    dplyr::select(-geometry, -type) %>%
    arrange(desc(sq.ft))
    
  return(nearby2)
})

parcelDF_circle <- reactive({
  if (is.null(input$map_click)) {
  warehouse2 <- parcelDF1()
  }
  else {
    warehouse2 <- nearby_warehouses() %>%
      as.data.frame()# %>%
      #rename(parcel.number = apn, sq.ft = shape_area) %>%
     # dplyr::select(-geometry, -type) %>%
     # arrange(desc(sq.ft))
  }
  # warehouse2 <- filteredParcels() %>%
  #    st_intersect(circle()) %>%
  #   as.data.frame() %>%
  #    rename(parcel.number = apn, sq.ft = shape_area) %>%
  #   dplyr::select(-geometry, -type) %>%
  #    arrange(desc(sq.ft))
  #    warehouse2 <- parcelDF1()
  #  } 
  return(warehouse2)
})

}
# Run the application 
shinyApp(ui = ui, server = server)
