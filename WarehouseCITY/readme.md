Warehouse City Documentation (alpha v1.0 - released May 18, 2022)
===================================

# Introduction

The Warehouse CITY (communitY Cumulative Impact Tool) dashboard is a tool developed to help visualize and quantify the development of warehouses in Southern California. This dashboard is a result of a collaboration between the Redford Conservancy at Pitzer College and Radical Research LLC. The goal of this tool is to help community organizations understand and quantify the cumulative impacts of existing and planned warehouses.   

# Navigating the tool

### Year range slider and unknown year checkbox

The slider with the year ranges from 1910 to 2021 allows a user to select parcels with identified build years within that range. Displayed years are included.  For example, if the user selects 2021 to 2021 all warehouses with a build year of 2021 are selected and displayed on the map and data table. Note that approximately 10% of parcels had unknown build years; those can be removed or added to any analysis with a checkbox button and are set as 1910 for selection purposes in the slider tool.  

### Selection Radius (km) slider 

This slider allows the user to alter the default radius of a great circle for selecting nearby warehouses (and light industrial) parcels. Radius distance values are in kilometers. The selection works when the user left-clicks in the map.  This will make a gray circle appear.  Any warehouses in the map intersecting that circle are selected for the calculation.  Any warehouses outside the gray area are still displayed on the map.  The data table updates to only show the warehouses included in the selection (both circle and year range).  

### Summary stats table

Directly above the map is a table that provides summary statistics for the selected warehouses. The summary table includes the number of warehouses, the sum of floor space in units of thousand square feet, the number of estimated truck trips, and an estimate of the diesel PM2.5, NOx, and CO2 emissions from those truck trips. The table updates as the user selects different year ranges or clicks on different sections of the map.  The details on how these are calculated are discussed further in the methods section.

### Map

The map can be navigated using point, click, and drag features or by clicking on the zoom plus and minus buttons on the top left. Polygon colors indicate parcels year built ranges as listed in the assessor database. At the top right of the map, the imagery can be switched between a basemap imagery and satellite imagery. Polygon overlays can be turned on or off by selecting the check boxes for warehouses and/or circle.  Clicking within the map draws a gray circle of radius (selection radius (km)).  This circle is used to identify nearby warehouses and light industry that are cumulatively affecting the selected area's air quality and truck traffic volumes. Finally, the air district map is visible as a boundary overlay and is called SCAQMD Boundary.

Land use classifications that contain the word 'warehouse' do not include a large number of warehouses, especially for the Riverside County dataset.  The checkbox for 'light industry' places a red circle on all parcels that were classified as light industry in the assessors land use categories. We are assuming that these are mostly warehouses based on visual inspection, but some parcels are likely misclassified as warehouses with this assumption.  This red circle overlay is off by default but can be switched on in the upper right menu.  

### Detailed warehouse data table

The table indicates the assessor parcel number, class which describes the building land-use, the year the building was constructed, and an estimate of the indoor area in units of thousand square feet. These columns are by default sorted from largest area descending.  Clicking on the arrows next to each column header allows the data to be resorted. The table updates every time the slider inputs for year range or the circle selection is updated.    

## Data

Parcel data was obtained from publicly available data warehouses maintained by the counties of Riverside and San Bernadino.
* https://gis2.rivco.org/
* ftp://gis1.sbcounty.gov/
* https://egis-lacounty.hub.arcgis.com/datasets/lacounty::la-county-parcel-map-service/about

Parcel shapefiles were obtained in May, 2022. Data from the County websites are provides 'as is' and have multiple limitations in their use for this application. Parcels were filtered based on parcel use codes including the words 'warehouse' and 'light industrial'. Including only warehouse use codes excluded hundreds of known warehouses that are classified as light industrial in Riverside and San Bernadino Counties.  Both are shown and color-coded for ease of comparison and the Table allows a user to identify the use code of any individual selected parcel.

## Methods

Parcel areas are as reported in the assessor databases include total area indoors and outdoors. Warehouse building space footprints are unlikely to use the full parcel and often require space for parking lots, loading bays, and setbacks that will result in an over-estimate of warehouse square footage. We estimate the indoor floor space using a floor-area ratio of 0.65, which is consistent with current guidance for industrial zoning in some jurisdictions in Riverside County.

Truck trip estimates are based on South Coast Air Quality Management District indirect warehouse source rule requirements for warehouses greater than 100,000 sq.ft. without truck trip counts. Rule 2305 is here:
http://www.aqmd.gov/docs/default-source/rule-book/reg-xxiii/r2305.pdf?sfvrsn=15

The alpha version of the dashboard uses the default weighted truck tripe rate of 0.67 heavy duty truck trips per thousand sq.ft of building space from rule 2305.d.(C) As noted earlier, the assessor database sq.ft. for the parcel has a 0.65 multiplier to the parcel area to estimate the indoor building area. 

Diesel particulate matter, NOx, and CO2 emissions are based on year 2022 EMFAC2007 (version 2.3) emission factors for the 2022 Heavy-duty fleet year. Diesel PM2.5 emissions are 0.00037807 pounds per mile. NOx emissions are 0.01098794 pounds per mile. CO2 emissions are 4.21520828 pounds per mile. Vehicle trips were multiplied by an average truck trip distance of 50 miles. The trip distance is purely arbitrary but is likely an underestimate of trip distances to and from the Ports of Los Angeles/Long Beach for Inland Empire warehouses and an overestimate of trip distances for LA county warehouses.  

The final code for calculating the selected warehouses square footage, truck trips, and pollutant emissions is reproduced exactly below.

```{r}
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
    summarize(Warehouses = n(), Total.Thousand.Sq.Ft. = round(sum(Thousand.sq.ft), 0)) %>%
    mutate(Truck.Trips = round(Truck_trips_1000sqft*Total.Thousand.Sq.Ft. ,0)) %>%
    mutate(PoundsDieselPM.perDay = round(trip_length*Truck.Trips*DPM_VMT_2022_lbs,1),
           PoundsNOx.perDay = round(trip_length*Truck.Trips*NOX_VMT_2022_lbs, 0),
           PoundsCO2.perDay = round(trip_length*Truck.Trips*CO2_VMT_2022_lbs, 0)) 
})

```

## Limitations

While the dataset is awesome, it does have a number of limitations.  Two key issues are actively being investigated.
* Classification - warehouses and light industrial are large classes of parcels that include many different types of buildings.  This analysis tool is meant to specifically characterize warehouses.  However, in Riverside County, a very large fraction of all warehouses are classified as light industrial in the database.  While we faithfully represent what is in the assessor dataset, some of the parcels may be misclassified. We are actively working to improve the dataset to better represent the use of the building.
* Duplicate records - some parcel numbers have multiple records for build year which can lead to double-counting area, truck trips, and emissions.  When duplicates occur, we are using the earliest build year from the parcel database which may not account for parcel modifications or expansions.  
*Emissions calculations - emissions are based on a set of emissions factors that do not account for the heterogeneity of truck trips by warehouse type (cold storage, dry storage, distribution facilities, etc.), nor the variability in truck trip distances based on location of the facility. This information is not available at the time but could be incorporated in later versions if a reliable dataset becomes available.


## Contact 

If you have questions or suggestions, please email mikem@radicalresearch.llc
