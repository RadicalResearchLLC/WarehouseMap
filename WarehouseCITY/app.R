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
library(markdown)
#library(automap)
#library(gstat)

## Define UI for application that displays warehouses
# Show app name and logos
ui <- fluidPage(title = 'Warehouse CITY',
  tags$style(type="text/css", "div.info.legend.leaflet-control br {clear: both;}"),
    titlePanel(
      fluidRow(column(3),
               column(6,
               div(style = 'height:60px; font-size: 45px;',
               'Warehouse CITY')),
               column(1.5, shiny::img(height = 50, src = 'Logo_Redford.jpg')),
               column(1.5, shiny::img(height = 30, src = 'Logo.png')))
      ),
  ##Create a tabset display to have a readme file and main warehouse page
  tabsetPanel(
    tabPanel('Dashboard',
    # Display slider bar selections, checkbox, and summary text
    fluidRow(column(1), 
             column(3, sliderInput('year_slider', 'Year built', min = min(final_parcels$year_built), max(final_parcels$year_built), 
             value = range(final_parcels$year_built), step = 1, sep ='')),
             column(3, sliderInput('radius', 'Selection radius (km)', min = 1, max = 10, value = 5, step =1))#,
             #column(3, checkboxInput('inputId' = 'DetailTable', label = 'Display detailed table of selected warehouses',
              #  value = FALSE))
             ),
    fluidRow(column(1),
             column(4, checkboxInput(inputId = 'UnknownYr', label = 'Display parcels with unknown year built information',
                value = TRUE))),
    #fluidRow(column(12, textOutput('test'))),
    fluidRow(column(3),
             column(5, align = 'center', dataTableOutput('Summary'))
             #column(3, textOutput('text2')),
             ),
    # Display map and table
    fluidRow(
        column(1),
        column(10, align = 'center', leafletOutput("map", height = 600))
        ),
    fluidRow(column(3),
             column(6, align = 'center', dataTableOutput('warehouseDF'))),
    ),
    tabPanel('Readme',
      fluidRow(includeMarkdown("readme.md"))
    )
  )
  
)


server <- function(input, output) {

# color palettes 
  palette <- colorFactor( palette = c('Blue', 'Brown'),
                          levels = c('warehouse', 'light industrial'))
  

#Create leaflet map with legend and layers control
  
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

#Observe leaflet proxy for layers that refresh (warehouses, circle)
observe({
  leafletProxy("map", data = filteredParcels()) %>%
      clearGroup(group = 'Warehouses') %>%
      addPolygons(color = ~palette(type), 
        group = 'Warehouses',
        label = ~htmlEscape(paste('Parcel', apn, ';', round(shape_area,0), 'sq.ft.', class, year.built)) 
      )
})
observe({
  leafletProxy("map", data = circle()) %>%
    clearGroup(group = 'Circle') %>%
    addPolygons(color = 'grey50',
                group = 'Circle')
  })

## Generate a data table of warehouses in selected reactive data
output$warehouseDF <- DT::renderDataTable(
  parcelDF_circle(), 
  server = FALSE,
  caption  = 'Warehouse list by parcel number, square footage, and year built',
  rownames = FALSE, 
  options = list(dom = 'Btp',
    pageLength = 15,
    buttons = c('csv','excel')),
  extensions = c('Buttons')
)

## Reactive data selection logic

# First select parcels based on checkbox and year range input

filteredParcels <- reactive({
  if(input$UnknownYr == TRUE) {
    selectedYears <- final_parcels %>%
      filter(year_built >= input$year_slider[1] & year_built <= input$year_slider[2]) %>%
      mutate(shape_area = round(shape_area, 0))
  } else {
    selectedYears <- final_parcels %>%
      filter(year.built != 'unknown') %>%
      filter(year_built >= input$year_slider[1] & year_built <= input$year_slider[2]) %>%
      mutate(shape_area = round(shape_area, 0))
  }
  return(selectedYears)
})

##Calculate circle around a selected point
circle <- reactive({
  req(input$map_click)
  #FIXME - make this user defined
  distance <- input$radius*1000
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
    dplyr::select(-geometry, -type, -year_built) %>%
    arrange(desc(sq.ft))
  
  return(nearby2)
})

##Select between data without selection radius or with
parcelDF_circle <- reactive({
  if (is.null(input$map_click)) {
    warehouse2 <- filteredParcels() %>%
      as.data.frame() %>%
      rename(parcel.number = apn, sq.ft = shape_area) %>%
      dplyr::select(-geometry, -type, -year_built) %>%
      arrange(desc(sq.ft))
  }
  else {
    warehouse2 <- nearby_warehouses() %>%
      as.data.frame()
  }
  return(warehouse2)
})

##Add variables for Heavy-duty diesel truck calculations
Truck_trips_1000sqft <- 0.64
DPM_VMT_2022_lbs <- 0.00037807
trip_length <- 50

## calculate summary stats and render text outputs

SumStats <- reactive({
  parcelDF_circle() %>%
    summarize(Warehouses = n(), Total.Sq.Ft. = round(sum(sq.ft), 0)) %>%
    mutate(Truck.Trips = round(0.65*Truck_trips_1000sqft*Total.Sq.Ft./1000 ,0)) %>%
    mutate(PoundsDieselPM.perDay = round(trip_length*Truck.Trips*DPM_VMT_2022_lbs,1))
})

##Display summary table
output$Summary <- renderDataTable(
  SumStats(), 
  caption  = 'Summary of selected warehouse statistics',
  rownames = FALSE, 
  options = list(dom = '') 
)

output$text2 <- renderText({
  req(input$map_click)
  paste('You clicked on', round(input$map_click$lat,5), round(input$map_click$lng,5))
})

}
# Run the application 
shinyApp(ui = ui, server = server)
