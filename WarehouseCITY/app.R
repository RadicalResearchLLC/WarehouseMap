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
#library(automap)
#library(gstat)

# Define UI for application that displays warehouses
ui <- fluidPage(title = 'Warehouse CITY',
  tags$style(type="text/css", "div.info.legend.leaflet-control br {clear: both;}"),
    titlePanel(
      fluidRow(column(4),
               column(width =6,
               div(style = 'height:60px; font-size: 60px;',
               'Warehouse CITY')),
               column(2, shiny::img(height = 30, src = 'Logo.png')))
      ),

    # Display map and bar chart
    fluidRow(
        column(10, align = 'center', leafletOutput("map", height = 800))
        )
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
      addPolygons(color = ~palette(type), 
        group = 'Warehouses',
        label = ~htmlEscape(paste('Parcel', apn, ';', round(shape_area,0), 'sq.ft.', class))
        ) %>%
      addLegend(pal = palette, 
        values = c('warehouse', 'light industrial'),
        title = 'Parcel class') 
    
    map1
    })
  
}
# Run the application 
shinyApp(ui = ui, server = server)
