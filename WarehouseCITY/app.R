## This is an alpha version of Warehouse CITY, a community mapping tool for warehouse impacts
## Authored by Mike McCarthy, Radical Research LLC
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
    #fluidRow(column(2, textOutput('test'))),
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
        overlayGroups =c('Warehouses'),
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

parcelDF <- reactive({
  filteredParcels() %>%
    as.data.frame() %>%
    rename(parcel.number = apn, sq.ft = shape_area) %>%
    dplyr::select(-geometry, -type) %>%
    arrange(desc(sq.ft))
})

#output$test <- renderText({
#   paste('Minimum year is ', input$year_slider[1], 'and maximum year is ', input$year_slider[2])
#         })

observe({
  leafletProxy("map", 
      data = filteredParcels()) %>%
      clearShapes() %>%
      addPolygons(data = filteredParcels(),
                  color = ~palette(type), 
      group = 'Warehouses',
      label = ~htmlEscape(paste('Parcel', apn, ';', round(shape_area,0), 'sq.ft.', class, year_built))
      )
})

output$warehouseDF <- renderDataTable(
  parcelDF(), 
  caption  = 'Warehouse list by parcel number, square footage, and year built',
  rownames = FALSE, 
  options = list(dom = 'tp',
                 pageLength = 15) #%>%
)



  
}
# Run the application 
shinyApp(ui = ui, server = server)
