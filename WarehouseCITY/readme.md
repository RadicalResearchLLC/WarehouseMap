# Warehouse CITY Documentation (alpha v1.09 - released October 1, 2022)

# Introduction

The Warehouse CITY (communitY Cumulative Impact Tool) dashboard is a tool developed to help visualize and quantify the development of warehouses in Southern California. This dashboard is a result of a collaboration between the Redford Conservancy at Pitzer College and Radical Research LLC. The goal of this tool is to help community organizations understand and quantify the cumulative impacts of existing and planned warehouses. It builds off work done at the Redford Conservancy and published in the [Los Angeles Times](https://www.latimes.com/opinion/story/2022-05-01/inland-empire-warehouse-growth-map-environment).

# Navigating the tool

### Year range slider and unknown year checkbox

The slider with the year ranges from 1910 to 2022 allows a user to select parcels with identified build years within that range. Displayed years are included. For example, if the user selects 2011 to 2021 all warehouses with build years in that range are selected and displayed on the map and data table. Note that approximately 450 parcels had unknown build years; those can be removed or added to any analysis with a check box button and are set as 1910 for selection purposes in the slider tool.

### Selection Radius (km) slider

This slider allows the user to alter the default radius of a great circle for selecting nearby warehouses (and light industrial) parcels. Radius distance values are in kilometers. The selection works when the user left-clicks in the map. This will make a gray circle appear. Any warehouses in the map intersecting that circle are selected for the calculation. Any warehouses outside the gray area are still displayed on the map. The data tables update to only show the warehouses included in the selection (circle, year range, and city selection).

### Select a City Dropdown menu

This dropdown menu allows the user to select and display the city boundary of any incorporated city in the four county region. City names are alphabetical and can be manually selected via dropdown or typed into the box. Once selected, the city selection will filter the summary stats table and selection radius to only include warehouses within the selected city boundaries. Cities can be "unselected" by deleting the city selection without pressing enter or by refreshing the app. Unincorporated areas in each of the four counties can also be selected.

### Summary stats table

Directly above the map is a table that provides summary statistics for the selected warehouses. The summary table includes the number of warehouses, the acreage of the warehouse footprints, the total building floor space in units of square feet, the number of estimated truck trips, and an estimate of the daily diesel PM<sub>2.5</sub>, NO<sub>x</sub>, and CO<sub>2</sub> emissions from those truck trips. The table updates as the user selects different year ranges, clicks on different sections of the map, and/or chooses a city. Note that this estimate does not include car trips to and from warehouses in the emissions calculation, nor does it include truck idling emissions. The details on these calculations are discussed in the Methods section.

### Map

The map can be navigated using point, click, and drag features or by clicking on the zoom plus and minus buttons on the top left corner of the map. Polygon colors indicate estimated building square footage ranges calculated based on our methods described below from parcel sizes. At the top right of the map, the imagery can be switched between a street level **Basemap** and satellite **Imagery**. Polygon overlays can be turned on or off by selecting the check boxes for **Warehouses**, **City boundaries**, **Circle**, **Rail**, **CalEnviroScreen scores**, **Diesel PM**, and **Other parcel types**. Clicking within the map draws a gray circle with a radius from 1 to 10 km as the user selects, defaulting to 5 km (\~3.1 miles). This circle is used to identify nearby warehouses that are cumulatively affecting the selected area's air quality and truck traffic volumes. Size bins colors the warehouse polygons into five size bins based on building floor space square footage (Sq.ft.). The **Rail** layer indicates rail lines and railyards through the open source OpenRailwayMap providerTiles.

The check box for **Other parcel type** places a orange border overlay on all parcels that were classified as parcel types in county assessors land use categories that are likely warehouses but may be some non-warehouse land-use. We assume that these are mostly warehouses based on visual inspection of these parcels, but some parcels are likely misclassified as warehouses. This overlay is off by default.

The **CalEnviroScreen** overlay provides a color-coded overlay of census tracts that are in the top 25% of disproportionately impacted communities in the state. These scores are based on the [CalEnviroScreen4.0 methodology](https://oehha.ca.gov/calenviroscreen/report/calenviroscreen-40). Darker colors indicate higher impact of pollution and/or socioeconomic disadvantage. Mousing over census tracts displays the census tract number, population, and score (75-100).

The **Diesel PM** overlay provides a gray-scale overlay of census tract specific Diesel PM percentiles. The **Diesel PM** overlay was created by [California Air Resources Board](https://ww2.arb.ca.gov/) and is part of the CalEnviroScreen tool. Diesel PM emissions are based on the 2012 Southern California Association of Governments [SCAG](https://gisdata-scag.opendata.arcgis.com/) MPO data (v7) for vehicle activity/traffic flow; this does not capture the explosive growth in warehouse-induced truck traffic in the Inland counties in the last decade. Distributions of diesel PM in this layer are the most recent available as part of CARB gridded inventories. Full details on this layer are in the [CalEnviroScreen4.0 methodology](https://oehha.ca.gov/calenviroscreen/report/calenviroscreen-40).

### Detailed warehouse table

This table below the map provides individual parcel information on selected warehouses from the map. The table columns indicate the assessor parcel number, class which describes the building land-use, the land-use type as classified for display in the "other parcel type" overlay, the year the building was constructed, the building footprint in acres, and an estimate of the indoor floor space area in units of square feet. These columns are by default sorted from largest area descending. Clicking on the arrows next to each column header allows the data to be resorted. The table updates as user selections are changed. Typing into the boxes above the table allows one to filter the selection for different classifications; these table filter options do not update the map.

# Data

Parcel data was obtained from publicly available data warehouses maintained by the counties of Riverside, San Bernardino, and Los Angeles. Orange County data assessor data is not publicly available and was obtained through personal communication with OC public works and a specialized query of the SCAG dataset provided in May 2022.

-   <https://gis2.rivco.org/>
-   <ftp://gis1.sbcounty.gov/>
-   <https://egis-lacounty.hub.arcgis.com/datasets/lacounty>::la-county-parcel-map-service/about
-   Personal communications with staff at OC Public Works; <https://www.ocpublicworks.com/>

Parcel shapefiles were obtained September 26, 2022 for Riverside, San Bernardino County; August 12, 2022 for LA County, and May 18, 2022 for Orange County. Data from the County websites are provides 'as is' and have multiple limitations in their use for this application. For Riverside County, parcels were filtered based on parcel use codes including the words 'warehouse' and 'light industrial'. For San Bernardino County, the following land-use types were selected: warehouse, flex, light industry, and storage; we then excluded the following categories: 'retail warehouse', 'lumber storage', 'mini storage (public)', 'storage yard', 'auto storage yard', 'boat storage yard', 'grain storage', 'potato storage', 'bulk fertilizer storage', and 'mini-storage warehouse'. Los Angeles County parcels were filtered for only the land-use categorie of 'Warehousing, Distribution, and Storage'. 'Open Storage' was not included, even though many shipping containers around the ports are being stored in this class of parcel.

Emissions factor for diesel vehicles were generated from a VMT weighted calculation of EMFAC2021 based on fleet specific data for 2022 downloaded from <https://arb.ca.gov/emfac/>

# Methods

Warehouses were selected for display if their total parcel size was over 1 acre, which our method estimates to be at least 28,000 square feet of floor space (see next paragraph). The **Other parcel types** classified parcels were selected for display if their total parcel size was greater than 150,000 sq.ft. Different cutoffs were applied to avoid including large numbers of small parces that may potentially be misclassified.

Parcel areas as reported in the assessor databases include total square footage of the parcel footprint. Warehouse building space footprints are unlikely to use the full parcel and often require space for parking lots, loading bays, and setbacks that will result in an over-estimate of warehouse square footage. We estimate the indoor floor space using a floor-area ratio (**FAR**) of *0.65*, which is consistent with current guidance for industrial zoning in some jurisdictions in Riverside County.

Truck trip estimates are based on South Coast Air Quality Management District indirect warehouse source rule requirements for warehouses greater than 100,000 sq.ft. without truck trip counts [Rule 2305](http://www.aqmd.gov/docs/default-source/rule-book/reg-xxiii/r2305.pdf?sfvrsn=15). The alpha version of the dashboard uses the default weighted truck trip rate of 0.67 heavy duty truck trips per thousand sq.ft of building space from Rule 2305. As noted earlier, the assessor database sq.ft. for the parcel has a 0.65 multiplier to the parcel area to estimate the indoor building area. Thus, the calculation for truck trips is shown below.

```{r}
Parcel.Area * 0.65 * 0.67 / 1000 = Truck.trips.per.day
```

We note that we do not include any estimates of vehicle idling, which is particularly important for local exposures near warehouses. Thus, these estimates are likely underestimates of total emissions in close proximity to warehouses.

Diesel PM (exhaust), NO<sub>x</sub>, and CO<sub>2</sub> emissions are based on year 2022 EMFAC2021 (version 1.0.2) annual emission factors for the 2022 Heavy-duty fleet year for South Coast AQMD region. Diesel PM<sub>2.5</sub> emissions are \~0.00005415 pounds per mile. NO<sub>x</sub> emissions are \~0.006288 pounds per mile. CO<sub>2</sub> emissions are \~3.381 pounds per mile. Vehicle trips were multiplied by an average truck trip distance of 25 miles. The trip distance is purely arbitrary but is likely an overestimate of trip distances. Later versions of this tool may use SCAG trip length estimates.

The final code for calculating the selected warehouses square footage, truck trips, and pollutant emissions is reproduced exactly below.

```{r}

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

```

# Limitations

While the dataset is awesome, it does have a number of limitations. Multiples issues are being investigated or quality assured as we work to improve the utility of this tool.

-   **Classification** - warehouses are a large class of parcels that include many different types of buildings. This analysis tool is meant to specifically characterize warehouses. However, in Riverside and San Bernardino County, a very large fraction of all warehouses are not classified using the words 'warehouse', 'distribution', or 'storage' in the assessor descriptions. Instead, many are classified as *light industrial*, *flex*, and other terms in the assessor databases. While we faithfully represent the description in the assessor dataset, some of the parcels may be misclassified to warehouse. We are actively working to improve the dataset to better represent the use of the building as we visually inspect the dataset and gain local on-the-ground knowledge on individual facilities.

-   **Duplicate records** - some parcel numbers have multiple records for build year which can lead to double-counting area, truck trips, and emissions. When duplicates occur, we are using the earliest build year from the parcel database which may not account for parcel modifications or expansions.\

-   **Emissions calculations** - emissions are based on a set of emissions factors that do not account for the heterogeneity of truck trips by warehouse type (cold storage, dry storage, distribution facilities, etc.), nor the variability in truck trip distances based on location of the facility. This information is not readily available at the time but could be incorporated in later versions if and when reliable datasets become available.

-   **Orange County data** - Assessor parcel data is not directly from the assessor's office and is likely less reliable than the other three counties as a result.\

-   **Idling at warehouses** - No emissions estimate is made for idling of diesel vehicles at warehouses. This may be the largest local impact of warehouses for people living, working, attending school, or exercising adjacent to warehouses. Most jurisdictions have anti-idling rules prohibiting idling for more than 5 minutes, but enforcement is often complaint-based.

-   **Errata**

    -   We are working to improve the parcel information for this entire dataset. If you have any information on individual parcels that you believe are currently misclassified, please contact us at the email below and we'll work to improve our classification.\
    -   A large number (8,644) of sub 1-acre warehouses are excluded from this analysis as the application slows down significantly when displaying these micro-warehouses. The total area of the warehouses with less than 1-acre parcels is 1.7x10<sup>8</sup> sq.ft.\
    -   No estimate is made for light-duty vehicle trips of workers commuting to and from warehouses.\
    -   San Bernardino "build year" values are based on assessor base year, which is the "last year of appraisal" which likely biases the dataset for this county to look younger than it may truly be for parcels that changed ownership. Build year information is not directly available for this county at this time.

## Contact and Support

-   If you have questions or suggestions, please email [mikem\@radicalresearch.llc](mailto:mikem@radicalresearch.llc){.email}

-   If you are interested in supporting local organizations working on land-use issues, please visit the [Redford Conservancy](https://www.pitzer.edu/redfordconservancy/) and/or [Riverside Neighbors Opposing Warehouses](https://tinyurl.com/RIVNOW).
