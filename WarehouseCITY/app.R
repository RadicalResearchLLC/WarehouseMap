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
      fluidRow(column(1),
               column(3,
               div(style = 'height:60px; font-size: 30px;',
               'Warehouse CITY')),
               column(2, shiny::img(height = 60, src = 'Logo_Redford.jpg')),
               column(2, shiny::img(height = 38, src = 'Logo.png')))
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
                value = TRUE)),
             column(4, textOutput('text2'))),
    fluidRow(column(1),
             column(5, align = 'center', dataTableOutput('Summary'))
             ),
    # Display map and table
    fluidRow(
        column(1),
        column(8, align = 'center', leafletOutput("map", height = 600))
        ),
    fluidRow(column(2),
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
      setView(lat = 34, lng = -117.60, zoom = 9) %>%
      addProviderTiles("Esri.WorldImagery", group = 'Imagery') %>%
      addLayersControl(baseGroups = c('Basemap', 'Imagery'),
        overlayGroups = c('Warehouses', 'Size bins', 'Circle', 
                          'SCAQMD boundary', 'light industry'),
        options = layersControlOptions(collapsed = FALSE)
        ) 
    
    map1 %>% hideGroup(c('light industry', 'Size bins', 'SCAQMD boundary'))#, 'Warehouse Size')
    })

#Observe leaflet proxy for layers that refresh (warehouses, circle)
observe({
  leafletProxy("map", data = filteredParcels()) %>%
      clearGroup(group = 'Warehouses') %>%
      addPolygons(color = '#8D3312', 
        group = 'Warehouses',
        weight = 3,
        fillOpacity = 0.5,
        label = ~htmlEscape(paste('Parcel', apn, ';', round(shape_area,0), 'sq.ft.', class, year.built)) 
      )
})

OrBr <- c('beige' = '#EEE1B1',
          'gold' = '#CF7820',
          'carrot' = '#A94915',
          'rust' = '#8D3312',
          'brown' = '#5F1003')

paletteSize <- colorFactor(OrBr,
                 levels = c('Less than 100,000',  
                            '100,000 to 250,000',
                            '250,000 to 500,000',
                            '500,000 to 1,000,000',
                            '1,000,000+'), 
                  reverse = FALSE)

observe({
  leafletProxy("map", data = final_parcels) %>%
    clearGroup(group = 'Size bins') %>%
    addPolygons(color = ~paletteSize(size_bin),
                weight = 3,
                fillOpacity = 0.8,
                group = 'Size bins') %>%
    addLegend(pal = paletteSize, 
              values = c('Less than 100,000',  
                         '100,000 to 250,000',
                         '250,000 to 500,000',
                         '500,000 to 1,000,000',
                         '1,000,000+'),
              title = 'Size bins (Sq.ft.)')
})

observe({
  leafletProxy("map", data = circle()) %>%
    clearGroup(group = 'Circle') %>%
    addPolygons(color = 'grey50',
                group = 'Circle')
  })

observe({
  leafletProxy("map", data = AQMD_boundary) %>%
    clearGroup(group = 'SCAQMD boundary') %>%
    addPolygons(color = 'black', 
                fillOpacity = 0.02, 
                weight = 3,
                group = 'SCAQMD boundary')
})

observe({
  leafletProxy("map", data = filter(final_parcels, type == 'light industrial')) %>%
    clearGroup(group = 'light industry') %>%
    addPolygons(color = 'orange', 
                     fillOpacity = 0.02, 
                     weight = 3,
                     group = 'light industry')
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
    rename(parcel.number = apn) %>%
    mutate(Sq.ft. = round(floorSpace.sq.ft, 0),
           acreage = round(shape_area/43560, 0)) %>%
    dplyr::select(parcel.number, class, year.built, acreage, Sq.ft.) %>%
    arrange(desc(Sq.ft.))
  
  return(nearby2)
})

##Select between data without selection radius or with
parcelDF_circle <- reactive({
  if (is.null(input$map_click)) {
    warehouse2 <- filteredParcels() %>%
      as.data.frame() %>%
      rename(parcel.number = apn) %>%
      mutate(Sq.ft. = round(floorSpace.sq.ft, 0),
             acreage = round(shape_area/43560, 0)) %>%
      dplyr::select(parcel.number, class, year.built, acreage, Sq.ft.) %>%
      arrange(desc(Sq.ft.)) 
      
  }
  else {
    warehouse2 <- nearby_warehouses() %>%
      as.data.frame()
  }
  return(warehouse2)
})

##Add variables for Heavy-duty diesel truck calculations

#Truck trips = WAIRE 100k sq.ft. number
Truck_trips_1000sqft <- 0.67
DPM_VMT_2022_lbs <- 0.00037807
NOX_VMT_2022_lbs <- 0.01098794
CO2_VMT_2022_lbs <- 4.21520828
trip_length <- 50

## calculate summary stats

SumStats <- reactive({
  parcelDF_circle() %>%
    summarize(Warehouses = n(), Warehouse.Acreage = round(sum(acreage), 0), 
              Total.Bldg.Sq.ft. = round(sum(Sq.ft.), 0)) %>%
    mutate(Truck.Trips = round(Truck_trips_1000sqft*0.001*Total.Bldg.Sq.ft. ,0)) %>%
    mutate(PoundsDieselPM.perDay = round(trip_length*Truck.Trips*DPM_VMT_2022_lbs,1),
           PoundsNOx.perDay = round(trip_length*Truck.Trips*NOX_VMT_2022_lbs, 0),
           PoundsCO2.perDay = round(trip_length*Truck.Trips*CO2_VMT_2022_lbs, 0)) 
})

##Display summary table
output$Summary <- renderDataTable(
  SumStats(), 
  caption  = 'This interactive map shows the logistics industry footprint in Los Angeles, Orange, Riverside, and San Bernadino Counties.  Zoom in and/or click an area to see specific community impacts. Summary statistics are estimates based on publicly available datasets. Please see Readme tab for more information on methods and data sources.',
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
