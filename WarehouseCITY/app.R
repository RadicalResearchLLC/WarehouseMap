## This is an alpha version of Warehouse CITY, a community mapping tool for warehouse impacts
## Authored by Mike McCarthy, Radical Research LLC
## Thanks to Sean Raffuse at UC Davis AQRC for help with the nearby intersection code for great circles 
## First created May, 2022
## Last modified June, 2022
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
             column(2, sliderInput('year_slider', 'Year built', min = min(final_parcels$year_built), max(final_parcels$year_built), 
             value = range(final_parcels$year_built), step = 1, sep ='')),
             column(1, checkboxInput(inputId = 'UnknownYr', label = 'Display parcels with unknown year built information',
                                     value = TRUE)),
             column(2, sliderInput('radius', 'Selection radius (km)', min = 1, max = 10, value = 5, step =1)),
             column(2, align = 'center', selectizeInput(inputId = 'City', label = 'Select a city',
                choices = c('', city_names$city), options = list(maxItems = 1))
             )
             #column(2, textOutput('text2'))
             ),
    fluidRow(column(1),
             column(8, align = 'center', dataTableOutput('Summary'))
             ),
        # Display map and table
    fluidRow(
        column(1),
        column(8, align = 'center', leafletOutput("map", height = 600))
        ),
    fluidRow(column(2),
             column(6, align = 'center', dataTableOutput('warehouseDF'))),
    fluidRow(column(9),
             column(3, 'Warehouse CITY v1.07, July 25, 2022'))
    ),
    tabPanel('Readme',
      div(style = 'width: 90%; margin: auto;',
      fluidRow(includeMarkdown("readme.md")),
      )
    )
  )
  
)

server <- function(input, output) {


#Create leaflet map with legend and layers control
  
output$map <- renderLeaflet({
    map1 <- leaflet() %>%
      addTiles() %>%
      setView(lat = 34, lng = -117.60, zoom = 10) %>%
      addProviderTiles(providers$Esri.WorldImagery, group = 'Imagery') %>%
      addProviderTiles(providers$OpenRailwayMap, group = 'Rail') %>%
      addLayersControl(baseGroups = c('Basemap', 'Imagery'),
        overlayGroups = c('Warehouses', 'City boundaries', 'Circle', 'Rail', 
                          'SCAQMD boundary', 'light industry'),
        options = layersControlOptions(collapsed = FALSE)
        )  %>%
      addLegend(pal = paletteSize, 
                values = c('28,000 to 100,000',  
                           '100,000 to 250,000',
                           '250,000 to 500,000',
                           '500,000 to 1,000,000',
                           '1,000,000+'),
                title = 'Size bins (Sq.ft.)')
    
    map1 %>% hideGroup(c('Rail', 'light industry', 'SCAQMD boundary'))#, 'Warehouse Size')
    })

OrBr <- c('beige' = '#EEE1B1',
          'gold' = '#CF7820',
          'carrot' = '#A94915',
          'rust' = '#8D3312',
          'brown' = '#5F1003')

paletteSize <- colorFactor(OrBr,
                 levels = c('28,000 to 100,000',  
                            '100,000 to 250,000',
                            '250,000 to 500,000',
                            '500,000 to 1,000,000',
                            '1,000,000+'), 
                  reverse = FALSE)

#Circle select
observe({
  leafletProxy("map", data = circle()) %>%
    clearGroup(group = 'Circle') %>%
    addPolygons(color = 'grey50',
                group = 'Circle')
  })
#AQMD boundary
observe({
  leafletProxy("map", data = AQMD_boundary) %>%
    clearGroup(group = 'SCAQMD boundary') %>%
    addPolygons(color = 'black', 
                fillOpacity = 0.02, 
                weight = 3,
                group = 'SCAQMD boundary')
})
#Light industry overlay
observe({
  leafletProxy("map", data = filter(filteredParcels(), type == 'light industrial')) %>%
    clearGroup(group = 'light industry') %>%
    addPolygons(color = 'orange', 
                     fillOpacity = 0.02, 
                     weight = 3,
                     group = 'light industry')
})
#City boundaries
observe({
  leafletProxy("map", data = selected_cities()) %>%
    clearGroup(group = 'City boundaries') %>%
    addPolygons(color = 'black',
                fillOpacity = 0.02,
                weight = 2,
                group = 'City boundaries')
})
#Warehouse size bins
observe({
  leafletProxy("map", data = filteredParcels()) %>%
    clearGroup(group = 'Warehouses') %>%
    addPolygons(color =  '#A94915',
                fillColor = ~paletteSize(size_bin),
                weight = 2,
                fillOpacity = 0.8,
                group = 'Warehouses',
                label = ~htmlEscape(paste('Parcel', apn, ';', round(shape_area,0), 'sq.ft.', class, year.built)))
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
  extensions = c('Buttons'),
  filter = list(position = 'top', clear = FALSE)
)
## Reactive data selection logic
# First select parcels based on checkbox and year range input
filteredParcels1 <- reactive({
  if(input$UnknownYr == TRUE) {
    selectedYears <- final_parcels %>%
      dplyr::filter(year_built >= input$year_slider[1] & year_built <= input$year_slider[2]) %>%
      mutate(shape_area = round(shape_area, 0))
  } else {
    selectedYears <- final_parcels %>%
      dplyr::filter(year.built != 'unknown') %>%
      dplyr::filter(year_built >= input$year_slider[1] & year_built <= input$year_slider[2]) %>%
      mutate(shape_area = round(shape_area, 0))
  }
  return(selectedYears)
})
#Select city boundaries 
selected_cities <- reactive({
  req(input$City)
  dplyr::filter(city_names, city %in% input$City) %>% 
    st_transform("+proj=longlat +ellps=WGS84 +datum=WGS84")
})
#Select warehouses within city
filteredParcels <- reactive({
  if(input$City == '') {
    cityParcels <- filteredParcels1() 
    }
  else {
    cityIntersect <- st_intersects(selected_cities(), filteredParcels1())
    cityParcels <- filteredParcels1()[cityIntersect[[1]],] 
  }
  return(cityParcels)
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
#emissions per mile calculated from EMFAC 2022 SCAQMD VMT weighted heavy duty fleet
Truck_trips_1000sqft <- 0.67
DPM_VMT_2022_lbs <- 0.00005415206
NOX_VMT_2022_lbs <- 0.006287505
CO2_VMT_2022_lbs <- 3.380869
trip_length <- 25

## calculate summary stats

SumStats <- reactive({
  parcelDF_circle() %>%
    summarize(Warehouses = n(), 'Warehouse Acreage' = round(sum(acreage), 0), 
              Total.Bldg.Sq.ft = round(sum(Sq.ft.), 0)) %>%
    mutate(Truck.Trips = round(Truck_trips_1000sqft*0.001*Total.Bldg.Sq.ft ,0)) %>%
    mutate('Daily Diesel PM (pounds)' = round(trip_length*Truck.Trips*DPM_VMT_2022_lbs,1),
           'Daily NOx (pounds)' = round(trip_length*Truck.Trips*NOX_VMT_2022_lbs, 0),
           'Daily CO2 (pounds)' = round(trip_length*Truck.Trips*CO2_VMT_2022_lbs, 0)) %>%
    rename('Warehouse floor space (Sq.Ft.)' = Total.Bldg.Sq.ft,  'Daily Truck trips' = Truck.Trips)
})

##Display summary table
output$Summary <- renderDataTable(
  SumStats(), 
  caption  = 'This interactive map shows the logistics industry footprint in Los Angeles, Orange, Riverside, and San Bernadino Counties.  Zoom in and/or click an area to see specific community impacts. Summary statistics are estimates based on publicly available datasets. Please see Readme tab for more information on methods and data sources.',
  rownames = FALSE, 
  options = list(dom = '') 
)

#output$text2 <- renderText({
#  req(input$map_click)
#  paste('You clicked on', round(input$map_click$lat,5), round(input$map_click$lng,5))
#})


}
# Run the application 
shinyApp(ui = ui, server = server)
