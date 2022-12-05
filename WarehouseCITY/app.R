## This is an alpha version of Warehouse CITY, a community mapping tool for warehouse impacts
## Authored by Mike McCarthy, Radical Research LLC
## Thanks to Sean Raffuse at UC Davis AQRC for help with the nearby intersection code for great circles 
## First created May, 2022
## Last modified October, 2022
#

library(shiny)
library(leaflet)
library(htmltools)
library(sf)
library(tidyverse)
library(DT)
library(markdown)

deploy_date <- 'December 4, 2022'
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
               column(2, shiny::img(height = 38, src = 'Logo.png')),
               column(2, shiny::img(height = 60, src = 'RNOW.png'))
               )
      ),
  ##Create a tabset display to have a readme file and main warehouse page
  tabsetPanel(
    tabPanel('Dashboard', 
    #sidebarLayout
    # Display slider bar selections, checkbox, and summary text
    fluidRow(column(3, align = 'center', h3('Warehouse Selection Filters'),
                    hr(),
              selectizeInput(inputId = 'City', label = 'Jurisdictions - Select up to 5',
                 choices = c('', sort(jurisdictions$name)), options = list(maxItems = 5)),
              sliderInput('year_slider', 'Year built', 
               min = min(final_parcels$year_built), max(final_parcels$year_built), 
            #How does this break if I make the min year 1972?
               value = range(final_parcels$year_built), step = 1, sep =''),
             checkboxInput(inputId = 'UnknownYr', 
                label = 'Display parcels with unknown year built', value = TRUE),
             sliderInput('radius', 'Circle (radius in km)', min = 1, max = 10, value = 5, step =1),
             actionButton(inputId = 'Reset', label = 'Reset circle'),
            hr(),
            div(
              h3('Advanced User Input Options'),
              checkboxInput(inputId = 'Z', label = NULL, value = FALSE)
            ),
            conditionalPanel("input.Z == true",
                
                numericInput(inputId = 'FAR', label = 'Floor area ratio - (0.05 to 1)', value = 0.65,
                         min = 0.05, max = 1.0, step = 0.05, width = '200px'),
                numericInput(inputId = 'TruckPerTSF', label = 'Truck Trips per 1,000 sq.ft. (0.1 to 1.5)', value = 0.67,
                         min = 0.1, max = 1.5, step = 0.01, width = '200px'),
                numericInput(inputId = 'avgVMT', label = 'Truck trip length (miles - 5 to 60)', value = 38,
                         min = 5, max = 60, step = 1, width = '200px'),
                numericInput(inputId = 'DPMperMile', label = 'Diesel PM (lbs/mile)', value = 0.0000364,
                         min = 0.0000100, max = 0.0001, step = 0.000001, width = '200px'),
                numericInput(inputId = 'NOxperMile', label = 'NOx (lbs/mile)', value = 0.00410,
                         min = 0.0004, max = 0.04, step = 0.0001, width = '200px'),
                numericInput(inputId = 'CO2perMile', label = 'CO2 (lbs/mile)', value = 2.44,
                         min = 1, max = 5, step = 0.01, width = '200px')
                
            ),
            hr(),
            h3('Version and Deployment info'),
            hr(),
            paste('Warehouse CITY v1.10, last updated', deploy_date)
            ),
             column(8, align = 'center', 
             dataTableOutput('Summary'),
             leafletOutput("map", height = 600),
             dataTableOutput('warehouseDF')
             )),
        # Display deploy date
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
     # addTiles() %>%
      setView(lat = 34, lng = -117.60, zoom = 10) %>%
      addProviderTiles(providers$Esri.WorldImagery, group = 'Imagery') %>%
      addProviderTiles(providers$OpenRailwayMap, group = 'Rail') %>%
      addProviderTiles(providers$CartoDB.Positron, group = 'Basemap') %>% 
      addLayersControl(baseGroups = c('Basemap', 'Imagery'),
        overlayGroups = c('Warehouses', 'Jurisdictions', 'Circle', 'Size bins', 
                           'Rail', 'CalEnviroScreen', 'Diesel PM'), # 'SCAQMD boundary',
        options = layersControlOptions(collapsed = FALSE)
        )  %>%
      addLegend(pal = paletteSize, 
                values = c('28,000 to 100,000',  
                           '100,000 to 250,000',
                           '250,000 to 500,000',
                           '500,000 to 1,000,000',
                           '1,000,000+'),
                title = 'Size bins (Sq.ft.)',
                group = 'Size bins') %>% 
      addLegend(data = CalEJ4,
                pal = palDPM, 
                title = 'Diesel PM (%)', 
                values = ~DieselPM_P,
                group = 'Diesel PM') %>% 
      addLegend(data = CalEJ4,
                group = 'CalEnviroScreen',
                title = 'CalEnviroScreen Score',
                values = ~CIscoreP,
                pal = qpal) %>% 
      addMapPane('Jurisdictions', zIndex = 390) %>% 
      addMapPane('Circle', zIndex = 395) %>% 
      addMapPane('Warehouses', zIndex = 410) %>% 
      addMapPane('Size bins', zIndex = 420) %>% 
      addMapPane('CalEnviroScreen', zIndex = 400) %>% 
      addMapPane('Diesel PM', zIndex = 405)
    
    map1 %>% hideGroup(c('Rail', 'CalEnviroScreen', 'Diesel PM', 'Size bins'))
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
  req(circle_click$mapClick)
  
  leafletProxy("map", data = circle()) %>%
  #  clearShapes(group = 'Circle') %>% 
    clearGroup(group = 'Circle') %>%
    addPolygons(color = 'grey50',
                group = 'Circle')
  })
#Remove circle
observeEvent(input$Reset,   
  {leafletProxy("map", data = circle()) %>%
    clearGroup(group = 'Circle')
  }
)

#City boundaries
observe({
  req(selected_cities_all())
  leafletProxy("map", data = selected_cities_all()) %>%
    clearGroup(group = 'Jurisdictions') %>%
    addPolygons(color = 'black',
                fillOpacity = 0.05,
                weight = 2,
                group = 'Jurisdictions')
})
#CalEnviroScreen4.0 census tracts
CalEJ4_75 <- CalEJ4 %>% 
  filter(CIscoreP >= 0.0)

qpal <- colorQuantile('magma', CalEJ4_75$CIscoreP, n = 5, reverse = TRUE)

observe({
  leafletProxy("map", data = CalEJ4_75) %>%
    clearGroup(group = 'CalEnviroScreen') %>%
    addPolygons(color = ~qpal(CIscoreP), 
                weight = 0.8, 
                opacity = 0.8,
                fillColor = ~qpal(CIscoreP),
                label = ~htmlEscape(paste('Tract', Tract, ';', ' Score', 
                  round(CIscoreP, 0), '; population ', TotPop19)),
                group = 'CalEnviroScreen')
})
#Diesel PM census tracts
palDPM <- colorQuantile(palette = 'Greys', domain = CalEJ4$DieselPM_P, n = 5)

observe({
  leafletProxy("map", data = CalEJ4) %>%
    clearGroup(group = 'Diesel PM') %>%
    addPolygons(color = ~palDPM(DieselPM_P), 
                stroke = FALSE,
                fillOpacity = 0.5,
                fillColor = ~palDPM(DieselPM_P),
                group = 'Diesel PM')
})

# Warehouses base
observe({
  leafletProxy("map", data = filteredParcels()) %>%
    clearGroup(group = 'Warehouses') %>%
    addPolygons(color = 'gray', #'#8D3312',
                fillColor = 'red', #'#A94915',
                weight = 1.5,
                fillOpacity = 0.8,
                group = 'Warehouses',
                label = ~htmlEscape(paste('Parcel', apn, ';', round(shape_area,0), 'sq.ft.', class, year_chr)))
})

#Warehouse size bins
observe({
  leafletProxy("map", data = filteredParcels()) %>%
    clearGroup(group = 'Size bins') %>%
    addPolygons(color = '#8D3312',
                fillColor = ~paletteSize(size_bin),
                weight = 1,
                fillOpacity = 0.8,
                group = 'Size bins',
                label = ~htmlEscape(paste('Parcel', apn, ';', round(shape_area,0), 'sq.ft.', class, year_chr)))
})

## Generate a data table of warehouses in selected reactive data
output$warehouseDF <- DT::renderDataTable(
  parcelDF_circle() %>% 
    rename('Assessor parcel number' = parcel.number, 'Building classification' = class, Acres = acreage,
           'Year built' = year_chr, 'Building sq.ft.' = Sq.ft.) %>% 
    select(-type), 
  server = FALSE,
  caption  = 'Warehouse list by parcel number, square footage, and year built',
  rownames = FALSE, 
  options = list(dom = 'Btp',
    pageLength = 10,
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
      dplyr::filter(year_chr != 'unknown') %>%
      dplyr::filter(year_built >= input$year_slider[1] & year_built <= input$year_slider[2]) %>%
      mutate(shape_area = round(shape_area, 0))
  }
  return(selectedYears)
})
#Select city boundaries 
selected_cities_all <- reactive({
  req(input$City)
  #countCity <- length(input$City)
  if(is.null(input$City)) {}
  else
     {
    selectedJuris <- jurisdictions %>% 
      filter(name %in% input$City) %>% 
      st_transform("+proj=longlat +ellps=WGS84 +datum=WGS84")
  }
})
selected_cities_union <- reactive({
  req(selected_cities_all()) 
  
  st_union(selected_cities_all())
})

#Select warehouses within city
filteredParcels <- reactive({
  if(is.null(input$City)) {
    cityParcels <- filteredParcels1() 
    }
  else {
  #  cityIntersect <- st_intersects(selected_cities(), filteredParcels1())
  #  cityParcels <- filteredParcels1()[cityIntersect[[1]],] 
  cityParcels <- filteredParcels1() %>% 
    filter(st_intersects(., selected_cities_union(), sparse = FALSE))
    
    }
  return(cityParcels)
})

## reactive circle
circle_click <- reactiveValues(mapClick = NULL)

## pass in map click
observeEvent(input$map_click,
             {circle_click$mapClick <- input$map_click})
##Unclick circle
observeEvent(input$Reset, 
             {circle_click$mapClick <- NULL}
  )
#observe(input$Reset,
#    {leafletProxy(mapId = 'map', data = NULL, clearGroup(group = 'Circle'))}
#  )

##Calculate circle around a selected point
circle <- reactive({
  req(circle_click$mapClick)

  distance <- input$radius*1000
  lat1 <- round(circle_click$mapClick$lat, 8)
  lng1 <- round(circle_click$mapClick$lng, 8)
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
    dplyr::select(parcel.number, class, year_chr, acreage, Sq.ft.) %>%
    arrange(desc(Sq.ft.))
  
  return(nearby2)
})

##Select between data without selection radius or with
parcelDF_circle <- reactive({
  if (is.null(circle_click$mapClick)) {
    warehouse2 <- filteredParcels() %>%
      as.data.frame() %>%
      rename(parcel.number = apn) %>%
      mutate(Sq.ft. = round(floorSpace.sq.ft, 0),
             acreage = round(shape_area/43560, 0)) %>%
      dplyr::select(parcel.number, class, type, year_chr, acreage, Sq.ft.) %>%
      arrange(desc(Sq.ft.)) 
      
  }
  else {
    warehouse2 <- nearby_warehouses() %>%
      as.data.frame()
  }
  return(warehouse2)
})

##Add variables for Heavy-duty truck calculations

#Truck trips = WAIRE 100k sq.ft. number
#emissions per mile calculated from EMFAC 2022 SCAQMD VMT weighted heavy duty fleet

## calculate summary stats

SumStats <- reactive({
  parcelDF_circle() %>%
    summarize(Warehouses = n(), 'Warehouse Acreage' = round(sum(acreage), 0), 
              Total.Bldg.Sq.ft = round(sum(acreage*input$FAR*43560), 0)) %>%
    mutate(Truck.Trips = round(input$TruckPerTSF*0.001*Total.Bldg.Sq.ft ,0)) %>%
    mutate('Daily Diesel PM (pounds)' = round(input$avgVMT*Truck.Trips*input$DPMperMile,1),
           'Daily NOx (pounds)' = round(input$avgVMT*Truck.Trips*input$NOxperMile, 0),
           'Daily CO2 (pounds)' = round(input$avgVMT*Truck.Trips*input$CO2perMile, 0)) %>%
    rename('Warehouse floor space (Sq.Ft.)' = Total.Bldg.Sq.ft,  'Daily Truck trips' = Truck.Trips)
})

##Display summary table
output$Summary <- renderDataTable(
  SumStats(), 
  caption  = 'This interactive map shows the logistics industry footprint in Los Angeles, Riverside, and San Bernardino Counties.  Zoom in and/or click an area to see specific community impacts. Summary statistics are estimates based on best available information. Please see Readme tab for more information on methods and data sources.',
  rownames = FALSE, 
  options = list(dom = '') 
)

}
# Run the application 
shinyApp(ui = ui, server = server)
