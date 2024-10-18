## This is an alpha version of Warehouse CITY, a community mapping tool for warehouse impacts
## Authored by Mike McCarthy, Radical Research LLC
## Thanks to Sean Raffuse at UC Davis AQRC for help with the nearby intersection code for great circles 
## First created May, 2022
## Last modified October, 2024
#

library(shiny)
library(leaflet)
library(htmltools)
library(sf)
library(tidyverse)
library(DT)
library(markdown)
library(shinycssloaders)
library(bslib)

deploy_date <- 'October 18, 2024'
version <- 'Warehouse CITY v1.21a, last updated'
sf_use_s2(FALSE)
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
  theme = bs_theme(
    bootswatch = 'united',
    font_scale = 0.7, 
    spacer = "0.2rem",
    primary = '#F7971D',
    "navbar-bg" = '#F7971D',
    bg = 'white',
    fg = '#333'),
  ##Create a tabset display to have a readme file and main warehouse page
  tabsetPanel(
    tabPanel('Dashboard', 
    #sidebarLayout
    # Display slider bar selections, checkbox, and summary text
    fluidRow(column(3, align = 'center', h3('Warehouse Selection Filters'),
                hr(),
             radioButtons(
                  inputId = 'Juris_District', 
                  label = 'Select by Jurisdiction or Legislative District',
                  choices = c('Jurisdiction', 'District'), 
                  selected = 'Jurisdiction', 
                  inline = TRUE), 
             conditionalPanel("input.Juris_District == 'Jurisdiction'",
               selectizeInput(inputId = 'City', label = 'Jurisdictions - Select up to 8',
                 choices = c('', sort(jurisdictions$name), 'unincorporated'), 
                 options = list(maxItems = 8))
             ),
             conditionalPanel("input.Juris_District == 'District'",
               selectizeInput(inputId = 'District', label = 'Legislative Districts - Select up to 8',
                 choices = c('', sort(districts$DistrictLabel)), 
                 options = list(maxItems = 8))
             ),
              numericInput('year_slider', 'Select warehouses built by', 
                min = 1980, 
                max = 2025, 
                value = 2025,
                width = '200px'),
             checkboxInput(inputId = 'UnknownYr', 
                label = 'Display parcels with unknown year built', value = TRUE),
             sliderInput('radius', 'Circle (radius in km)', min = 1, max = 20, value = 5, step =1),
             actionButton(inputId = 'Reset', label = 'Reset circle'),
            hr(),
            div(
              h3('Advanced User Input Options'),
              checkboxInput(inputId = 'Z', label = NULL, value = FALSE)
            ),
            conditionalPanel("input.Z == true",
                
                numericInput(inputId = 'FAR', label = 'Floor area ratio - (0.05 to 1)', value = 0.55,
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
                  min = 1, max = 5, step = 0.01, width = '200px'),
                numericInput(inputId = 'Jobs', label = 'Jobs per acre', value = 8,
                   min = 4, max = 20, step = 1, width = '200px'),
                numericInput(inputId = 'VacancyRate', label = 'Vacancy rate (%)', value = 7.5,
                  min = 0, max = 15, step = 0.1, width = '200px')
            ),
            hr(),
            downloadButton('ExportPoly',
                           'Download selected warehouse polygons - geojson',
                           icon = icon('download')
            ),
            hr(),
            # Display deploy date
            h3('Version and Deployment info'),
            hr(),
            paste(version, deploy_date),
            hr(),
            h3('Citation'),
            uiOutput('Cite')
            ),
             column(8, align = 'center', 
             shinycssloaders::withSpinner(DTOutput('Summary')),
             shinycssloaders::withSpinner(leafletOutput("map", height = 600)),
             shinycssloaders::withSpinner(DTOutput('warehouseDF'))
             ))
    ),
    tabPanel('Readme',
      div(style = 'width: 90%; margin: auto;',
      fluidRow(includeMarkdown("readme.md"))
      )
    )
  )
)

server <- function(input, output) {

# Cite
  url <- a("Warehouse CITY - open data product", href="https://journals.sagepub.com/doi/10.1177/23998083241262553")
  output$Cite <- renderUI({
    tagList("Journal Article", url)
  })
#Create leaflet map with legend and layers control
  
output$map <- renderLeaflet({
    map1 <- leaflet() |> 
     # addTiles()  |>
      setView(lat = 34.1, lng = -117.60, zoom = 9) |> 
      addProviderTiles(providers$Esri.WorldImagery, group = 'Imagery') |> 
      addProviderTiles(providers$OpenRailwayMap, group = 'Rail') |> 
      addProviderTiles(providers$CartoDB.Positron, group = 'Basemap')  |>
      addLayersControl(baseGroups = c('Basemap', 'Imagery'),
        overlayGroups = c('Warehouses', 'Jurisdictions',
                          'Circle', 'Rail', 'CalEnviroScreen',
                          'Rule 2305 Violators'), 
        options = layersControlOptions(collapsed = FALSE),
        position = 'topright'
        )   |>
      addLegend(data = CalEJ4,
                group = 'CalEnviroScreen',
                title = 'CalEnviroScreen Score',
                values = ~CIscoreP,
                pal = qpal)  |>
      addLegend(data = filteredParcels(),
                pal = WHPal,
                title = 'Status',
                values = ~category,
                group = 'Warehouses',
                position = 'bottomright')  |>
      addMapPane('Jurisdictions', zIndex = 405)  |>  
      addMapPane('Circle', zIndex = 400) |>  
      addMapPane('Warehouses', zIndex = 410)  |>
      addMapPane('CalEnviroScreen', zIndex = 402)  |>
      hideGroup(c('Rail', 'CalEnviroScreen', 'Size bins', 
                  'Rule 2305 Violators'))
    })

#OrBr <- c('beige' = '#EEE1B1',
#          'gold' = '#CF7820',
#          'carrot' = '#A94915',
#          'rust' = '#8D3312',
#          'brown' = '#5F1003')

#Circle select
observe({
  req(circle_click$mapClick)
  
  leafletProxy("map", data = circle())  |> 
  #  clearShapes(group = 'Circle')  |>
    clearGroup(group = 'Circle')  |>
    addPolygons(color = 'grey50',
                group = 'Circle')
  })
#Remove circle
observeEvent(input$Reset,   
  {leafletProxy("map", data = circle())  |>
    clearGroup(group = 'Circle')
  }
)

#City boundaries
observe({
  req(selected_cities_all())
  leafletProxy("map", data = selected_cities_all())  |>
    clearGroup(group = 'Jurisdictions')  |>
    addPolylines(color = 'black',
                #fillOpacity = 0.05,
                weight = 2,
                group = 'Jurisdictions')
})
#CalEnviroScreen4.0 census tracts
CalEJ4_75 <- CalEJ4  |>
  filter(CIscoreP >= 0.0)

qpal <- colorQuantile('magma', CalEJ4_75$CIscoreP, n = 5, reverse = TRUE)

observe({
  leafletProxy("map", data = CalEJ4_75)  |>
    clearGroup(group = 'CalEnviroScreen')  |>
    addPolygons(color = ~qpal(CIscoreP), 
                weight = 0.8, 
                opacity = 0.8,
                fillColor = ~qpal(CIscoreP),
                label = ~htmlEscape(paste('Tract', Tract, ';', ' Score', 
                  round(CIscoreP, 0), '; population ', TotPop19)),
                group = 'CalEnviroScreen')
})

WHPal <- colorFactor(palette = c('red', 'black', '#F7971D'), domain = combo_final$category)

observe({
  leafletProxy("map", data = filteredParcels())  |>
    clearGroup(group = 'Warehouses')  |>
    addPolygons(color = ~WHPal(category), 
                weight = 1,
                fillOpacity = 0.5,
                group = 'Warehouses',
                label = ~htmlEscape(paste(apn, class, round(shape_area,-3), ' sq.ft.',  year_built))) 
})

observe({
  leafletProxy("map")  |>
    clearGroup(group = 'Rule 2305 Violators')  |>
    addCircleMarkers(data = lat_longs_geocodio,
                color = 'cyan',
                label = ~paste(company_name, addr),
                weight = 1,
                group = 'Rule 2305 Violators')  |>
    addPolygons(data = warehouses_NOV,
                color = 'darkblue',
                weight = 1,
                fillOpacity = 0.9,
                group = 'Rule 2305 Violators')
})

## Generate a data table of warehouses in selected reactive data
output$warehouseDF <- DT::renderDT(
  parcelDF_circle()  |>
  rename(Category = category, 'Assessor parcel number' = parcel.number, 'Building classification' = class, Acres = acreage,
           'Year built' = year_built, 'Building sq.ft.' = Sq.ft.), 
  #select(-type), 
  server = FALSE,
  caption  = 'Warehouse list by parcel number, square footage, and year built',
  rownames = FALSE, 
  options = list(
    dom = 'Btp',
    pageLength = 10,
    buttons = list( 
      list(extend = 'csv', filename = paste('Warehouse_List', sep='-')),
      list(extend = 'excel', filename =  paste("Warehouse_List", sep = "-")))),
  extensions = c('Buttons'),
  filter = list(position = 'top', clear = FALSE)
)

## Reactive data selection logic
# First select parcels based on checkbox and year range input
filteredParcels1 <- reactive({
  if(input$UnknownYr == TRUE) {
    selectedYears <- combo_final  |>
      dplyr::filter(year_built <= input$year_slider)  |>
      mutate(shape_area = round(shape_area, 0))
  } else {
    selectedYears <- combo_final  |>
      dplyr::filter(unknown == FALSE)  |>
      dplyr::filter( year_built <= input$year_slider)  |>
      mutate(shape_area = round(shape_area, 0))
  }
  return(selectedYears)
})
#Select city boundaries 
#Add select legislative boundaries
selected_cities_all <- reactive({
  
  #countCity <- length(input$City)
  if(input$Juris_District == 'Jurisdiction') {
    req(input$City)
    if(is.null(input$City)) {}
    else {
    selectedJuris <- jurisdictions  |>
      filter(name %in% input$City)  #|>
  #    st_transform(crs = 432)
     }
  }
  else {
    req(input$District)
    if(is.null(input$District)) {}
    else
    {
      selectedJuris <- districts |> 
        filter(DistrictLabel %in% input$District )
    }
  }
})

#selected_cities_union <- reactive({
#  req(selected_cities_all()) 
  
#  st_union(selected_cities_all())
#})

#Select warehouses within city
filteredParcels <- reactive({
  if(input$Juris_District == 'Jurisdiction') {
    if(is.null(input$City)) {
      cityParcels <- filteredParcels1() 
      }
    else {
      cityParcels <- filteredParcels1() |>  
      filter(place_name %in% input$City | county %in% input$City) #|> 
    }
  }
  else {
    if(is.null(input$District)) {
      cityParcels <- filteredParcels1()
      }
    else {
      cityParcels <- filteredParcels1() |>
        ##FIXME - note that this is theoretically districts, not cities 
        st_filter(selected_cities_all())
      }
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
  
  dat_point <- st_as_sf(clickedCoords, coords = c('lng1', 'lat1'), crs = 4326)  |>
    st_transform(3857)
  circle_sf <- st_buffer(dat_point, distance)  |>
    st_transform("+proj=longlat +ellps=WGS84 +datum=WGS84")
  return(circle_sf)
})

##Code to select nearby warehouse polygons
nearby_warehouses <- reactive({
  req(circle())
  nearby <- st_join(circle(), filteredParcels(), join = st_contains)  |>
    st_set_geometry(value = NULL)  |>
    as.data.frame()  |>
    rename(parcel.number = apn)  |>
    mutate(Sq.ft. = round((shape_area*input$FAR), -3),
           acreage = round(shape_area/43560, 0))  |>
    dplyr::select(category, parcel.number, class, year_built, acreage, Sq.ft.)  |>
    arrange(desc(Sq.ft.))
  
  return(nearby)
})

##Select between data without selection radius or with
parcelDF_circle <- reactive({
  if (is.null(circle_click$mapClick)) {
    warehouse2 <- filteredParcels()  |>
      as.data.frame()  |>
      rename(parcel.number = apn)  |>
      mutate(Sq.ft. = round((shape_area*input$FAR), -3),
             acreage = round(shape_area/43560, 0))  |>
      dplyr::select(category, parcel.number, class, year_built, acreage, Sq.ft.)  |>
      arrange(desc(Sq.ft.)) 
  }
  else {
    warehouse2 <- nearby_warehouses()  |>
      as.data.frame()
  }
  return(warehouse2)
})

##Add variables for Heavy-duty truck calculations

#Truck trips = WAIRE 100k sq.ft. number
#emissions per mile calculated from EMFAC 2022 SCAQMD VMT weighted heavy duty fleet

## calculate summary stats

SumStats <- reactive({
  req(parcelDF_circle())
  
  step1 <- parcelDF_circle()  |>
    group_by(category)  |>
    summarize(Warehouses = n(), Acreage = round(sum(acreage), 0), 
              Total.Bldg.Sq.ft = round(sum(acreage*input$FAR*43560), -5), .groups = 'drop')  #|>
  
  stepVacant <- step1 |> 
    filter(category == 'Existing') |> 
    mutate(category = 'Vacant', 
           Warehouses = round(input$VacancyRate*Warehouses/100, 0),
           Acreage = round(input$VacancyRate*Acreage/100, 0),
           Total.Bldg.Sq.ft = round(input$VacancyRate*Total.Bldg.Sq.ft/100, 0)
    )
  
  stepExisting <- step1 |> 
    filter(category == 'Existing') |> 
    mutate( Warehouses = round((100-input$VacancyRate)*Warehouses/100, 0),
           Acreage = round((100-input$VacancyRate)*Acreage/100, 0),
           Total.Bldg.Sq.ft = round((100-input$VacancyRate)*Total.Bldg.Sq.ft/100, 0)
    )
    
   step2 <- step1 |> 
     filter(category != 'Existing') |> 
     bind_rows(stepExisting) |> 
    mutate(Truck.Trips = round(input$TruckPerTSF*0.001*Total.Bldg.Sq.ft ,-3))  |>
    mutate('Daily Diesel PM (pounds)' = round(input$avgVMT*Truck.Trips*input$DPMperMile,1),
           'Daily NOx (pounds)' = round(input$avgVMT*Truck.Trips*input$NOxperMile, 0),
           'Daily CO2 (metric tons)' = round(input$avgVMT*Truck.Trips*input$CO2perMile*0.000453592, 1),
           'Jobs' = round(input$Jobs*Acreage)
           )  |>
    bind_rows(stepVacant) |> 
    rename('Warehouse floor space (Sq.Ft.)' = Total.Bldg.Sq.ft,  'Daily Truck trips' = Truck.Trips,
           Category = category, 'Warehouse count' = Warehouses)
   return(step2)
})

##Display summary table
output$Summary <- renderDT(
  SumStats()  |> 
    datatable(
      caption  = 'This interactive map shows the logistics industry footprint in Los Angeles, Orange, Riverside, and San Bernardino Counties.  Zoom in and/or click an area to see specific community impacts. Summary statistics are estimates based on best available information. Please see Readme tab for more information on methods and data sources.',
      rownames = FALSE, 
      options = list(dom = 'Bt',
                 buttons = list( 
                   list(extend = 'csv', filename = paste('SummaryStats', sep='-')),
                   list(extend = 'excel', filename =  paste("SummaryStats", sep = "-")))),
      extensions = c('Buttons')
    )  |>
    formatRound(columns = c(2:5, 7, 9),
                interval = 3, mark = ',',
                digits = 0)
) 

##Jurisdictional Aggregation

data4trends <- reactive({
  
  if(input$CountyCity == 'County') {
  trendsData <- combo_final |> 
    st_set_geometry(value = NULL) |>
    mutate(decade = case_when(
        year_built == 1980 ~ '1980',
        year_built >= 1981 & year_built <= 1990 ~ '1990',
        year_built >= 1991 & year_built <= 2000 ~ '2000',
        year_built >= 2001 & year_built <= 2010 ~ '2010',
        year_built >= 2011 & year_built <= 2020 ~ '2020',
        year_built >= 2021 ~ '2030 - Planned'
      )) |> 
      group_by(decade, county) |> 
      summarize(sumFootprint = sum(shape_area),
                count = n(), .groups = 'drop')
  } else {
    req(input$City2)
    
    trendsData <- combo_final |> 
      st_set_geometry(value = NULL) |>
      mutate(decade = case_when(
        year_built == 1980 ~ '1980',
        year_built >= 1981 & year_built <= 1990 ~ '1990',
        year_built >= 1991 & year_built <= 2000 ~ '2000',
        year_built >= 2001 & year_built <= 2010 ~ '2010',
        year_built >= 2011 & year_built <= 2020 ~ '2020',
        year_built >= 2021 ~ '2030 - Planned'
      )) |> 
      filter(place_name %in% input$City2) |> 
      group_by(decade, place_name) |> 
      summarize(sumFootprint = sum(shape_area),
                count = n(), .groups = 'drop')
  }
  return(trendsData)
})

output$trends <- renderPlot({
  if(input$CountyCity == 'County') {
    plot1 <- ggplot(data = data4trends(),
        aes(x = county, y = sumFootprint, fill = decade)) +
      geom_col(position = position_dodge(preserve= 'single')) +
      theme_bw() +
      scale_y_continuous(label = scales::comma_format()) +
      labs(x = 'County', y = 'Warehouse footprint (sq.ft.)',
           fill = 'Year') +
      scale_fill_viridis_d(direction = -1,) +
      geom_vline(xintercept = 2.5, color = 'darkred', linetype = 'twodash')
  }
  else if(input$CountyCity == 'City') {
    req(input$City2)
    plot1 <- ggplot(data = data4trends(),
                    aes(x = place_name, y = sumFootprint, fill = decade)) +
      geom_col(position = position_dodge(preserve= 'single')) +
      theme_bw() +
      scale_y_continuous(label = scales::comma_format()) +
      labs(x = 'City', y = 'Warehouse footprint (sq.ft.)',
           fill = 'Year') +
      scale_fill_viridis_d(direction = -1,)#+
     #geom_vline(xintercept = 2.5, color = 'darkred', linetype = 'twodash')
  }
  return(plot1)
})

output$Numbers<- DT::renderDT(
  data4trends() |> 
    rename('Footprint (sq.ft.)' = sumFootprint,
           'Number of warehouses' = count) |> 
  datatable(
    caption  = 'Summary statistics for jurisdictions.',
    rownames = FALSE, 
    options = list(dom = 'Bt')
  )
)

output$ExportPoly <- downloadHandler(
  filename = function() {
    str_c('warehouses', '.geojson')
  },
  content = function(filename) {
    sf::st_write(filteredParcels(), filename)
  }
)

}
# Run the application 
shinyApp(ui = ui, server = server)
