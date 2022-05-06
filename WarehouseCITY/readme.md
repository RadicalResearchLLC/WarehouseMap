Warehouse City Documentation (alpha)
===================================

# Introduction

The Warehouse CITY (communitY Cumulative Impact Tool) dashboard is a tool developed to help visualize and quantify the development of warehouses in Southern California. This dashboard is a result of a collaboration between the Redford Conservancy at Pitzer College and Radical Research LLC. The goal of this tool is to help community organizations understand and quantify the cumulative impacts of existing and planned warehouses.   

# Navigating the tool

### Year range slider and unknown year checkbox

The slider with the year ranges from 1910 to 2021 allows a user to select parcels with identified build years within that range. Displayed years are included.  For example, if the user selects 2021 to 2021 all warehouses with a build year of 2021 are selected and displayed on the map and data table. Note that approximately 10% of parcels had unknown build years; those can be removed or added to any analysis with a checkbox button and are set as 1910 for selection purposes in the slider tool.  

### Selection Radius (km) slider 

This slider allows the user to alter the default radius of a great circle for selecting nearby warehouses. Radius distance values are in kilometers. The selection works when the user left-clicks in the map.  This will make a gray circle appear.  Any warehouses in the map intersecting that circle are selected for the calculation.  Any warehouses outside the gray area are still displayed on the map.  The data table updates to only show the warehouses included in the selection (both circle and year range).  

### Summary stats statement

Directly above the map is a text statement that says, "Your selection has X warehouses, summing to Y sq.ft. which resulted in an estimated Z truck trips emitting N pounds of diesel PM every day."  This statement reflects the currently selected data and updates if you change the clicked area in the map or the year range.  

### Map

The map navigates like a normal map. Blue and brown polygons indicate parcels classified by the county assessor's as a "warehouse" or 'light industrial' use, respectively.  At the top right of the map, the imagery can be switched between a basemap imagery and satellite imagery. Polygon overlays can be turned on or off by selecting the check boxes for warehouses and/or circle.  Clicking within the map draws a gray circle of radius (selection radius (km)).  This circle is used to identify nearby warehouses and light industry that are cumulatively affecting the selected area's air quality and truck traffic volumes.

### Data table

The table indicates the assessor parcel number, sq.ft. area of the parcel, the class indicating the type of building use, and the year the building was constructed. These columns are by default sorted from largest sq.ft. descending.  Clicking on the arrows next to each column header allows the data to be resorted. The table updates every time the slider inputs for year range or the circle selection is updated.    

## Data

Parcel data was obtained from publicly available data warehouses maintained by the counties of Riverside and San Bernadino.
* https://gis2.rivco.org/
* ftp://gis1.sbcounty.gov/

Parcel shapefiles were obtained in May, 2022. Data from the County websites are provides 'as is' and have multiple limitations in their use for this application. Parcels were filtered based on parcel use codes including the words 'warehouse' and 'light industrial'. Including only warehouse use codes excluded hundreds of known warehouses that are classified as light industrial or other use codes.  Both are shown and color-coded for ease of comparison and the Table allows a user to identify the use code of any individual selected parcel.  

## Methods

Parcel areas are currently used as reported in the assessor database. Warehouse footprints are unlikely to use the full parcel and often require space for parking lots, loading bays, and setbacks that will result in an over-estimate of warehouse square footage.

Truck trip estimates are based on the Institute of Transportation Engineers 2016 Report, "High-Cube Warehouse Vehicle Trip Generation Analysis" available here http://www.aqmd.gov/home/rules-compliance/ceqa/air-quality-analysis-handbook/high-cube-warehouse. The alpha version of the dashboard uses the average estimate of 0.64 heavy duty truck trips per thousand sq.ft of building space. The assessor database sq.ft. for the parcel. We have applied a 0.65 multiplier to the parcel area to estimate the building area. 

Diesel particulate matter emissions are based on year 2022 EMFAC2007 (version 2.3) emission factors. Diesel PM2.5 emissions are 0.00037807 pounds per mile. Vehicle trips were multiplied by an average truck trip distance of 50 miles. The trip distance is purely arbitrary but is like an underestimate of trip distances to and from the Ports of Los Angeles/Long Beach.  

The final code for calculating the selected warehouses square footage, truck trips, and diesel PM emissions is reproduced exactly below.

```{r}
##Add variables for Heavy-duty diesel truck calculations
Truck_trips_1000sqft <- 0.64
DPM_VMT_2022_lbs <- 0.00037807
trip_length <- 50

## calculate summary stats and render text outputs
SumStats <- reactive({
  parcelDF_circle() %>%
    summarize(count = n(), sum.Sq.Ft. = round(sum(sq.ft), 0)) %>%
    mutate(Truck.Trips = round(0.65*Truck_trips_1000sqft*sum.Sq.Ft./1000 ,0)) %>%
    mutate(PoundsDiesel = round(trip_length*Truck.Trips*DPM_VMT_2022_lbs,1))
})

output$test <- renderText({
  paste('Your selection has', SumStats()$count, 'warehouses, summing to', SumStats()$sum.Sq.Ft,
        'sq.ft. which resulted in an estimated', SumStats()$Truck.Trips, 'truck trips emitting', SumStats()$PoundsDiesel, 
        'pounds of Diesel PM every day')
})
```

## Limitations

While the dataset is awesome, it does have a number of limitations.  Two key issues are actively being investigates.
* Classification - warehouses and light industrial are large classes of parcels that include many different types of buildings.  This analyis tool is meant to specifically characterize warehouses.  However, in Riverside County, a very large fraction of all warehouses are classified as light industrial in the database.  While we faithfully represent what is in the assessor dataset, some of the parcels may be misclassified. We are actively working to improve the dataset to better represent the use of the building.
* Duplicate records - some parcel numbers have multiple records which can lead to double-counting area, truck trips, and emissions.  We are working to clean up this issue and only use the earliest year-built record for any parcels which are otherwise identical for square footage and parcel number.  



