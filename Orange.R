##Warehouse Map App V1
##Created by Mike McCarthy, Radical Research LLC
##Riverside County Data Import and Processing Steps
##First created July, 2023
##Last modified July, 2023

library(tidyverse)
library(sf)
library(pdftools)
library(tesseract)
library(tidygeocoder)

# Data processing for Orange County requires reading PDF addresses from Rule 2305 CoStar dataset
Orange_dir <- paste0(wd, '/Orange')


txt2 <- pdf_ocr_text(paste0(Orange_dir, '/BoardPackage 05072021_PR 2305_AppendixC.pdf'))
#rcmp_report <- pdf_text('RCMP_External_Review_Committee_AR_2018.pdf')

#CoStar1_spl <- strsplit(CoStar1, "\n")

#CoStarVec <- data.frame(CoStar1_spl) |> 
#  slice(6:66) |> 
#  rename(unsplit = c....second.Draft.Final.Staff.Report.Appendix.C....Property.Address.City.State.Zip.Property.Address.City.State.Zip...) |> 
#  mutate(split = str_split_fixed(unsplit, ' ', n = 10)) |> 
#  select(unsplit) |> 
#  as.data.frame()


addresses <- data.frame()
zips <- readxl::read_xls(path = paste0(Orange_dir, '/zip_code_database.xls')) |> 
  janitor::clean_names() |> 
  filter(state == 'CA') |> 
  filter(county %in% c('San Bernardino County', 'Los Angeles County', 'Riverside County', 'Orange County')) |> 
  select(zip, county)


pages <- c(17, 18, 22, 25, 26, 27, 28, 29, 30)
unparsedList <- data.frame()

for (ii in 1:length(pages)) {
  pages[ii]
  CoStar1 <- txt2[pages[ii]]
  CoStar1_spl <- strsplit(CoStar1, "\n")
  CoStar1_spl[[1]]
  CoStarVec <- data.frame(CoStar1_spl) |> 
    slice(6:66) |> 
    rename(unsplit = c....second.Draft.Final.Staff.Report.Appendix.C....Property.Address.City.State.Zip.Property.Address.City.State.Zip...) |> 
    mutate(split = str_split_fixed(unsplit, ' ', n = 10)) |> 
    select(unsplit) |> 
    as.data.frame()
  unparsedList <- rbind(unparsedList, CoStarVec)
}

unparsedList2 <- unparsedList |> 
  mutate(end = str_locate(unsplit, ' CA ')[,'end']) |> 
  mutate(list1 = str_sub(unsplit, 0, end + 5),
         list2 = str_sub(unsplit, end + 6, str_length(unsplit)))

addresses <- unparsedList2 |> 
  pivot_longer(names_to = 'address', values_to = 'list', cols = 3:4) |> 
  select(list) |> 
  mutate(list2 = str_squish(list)) |> 
  mutate(list3 = str_replace(list2, '— ', '')) |> 
  mutate(list3 = str_replace(list3, '~~ ', '')) |> 
  mutate(list3 = str_replace(list3, '~ ', '')) |> 
  mutate(list3 = str_replace(list3, '~', '')) |> 
  mutate(list3 = str_replace(list3, '= ', '')) |> 
  filter(!is.na(list3)) |> 
  select(list3) |> 
  mutate(zip = as.numeric(str_sub(list3, str_length(list3) - 5, str_length(list3)))) |> 
  left_join(zips)

OC_addresses_4_geocoding <- addresses |> 
  filter(county == 'Orange County') |> 
  mutate(lat = NA, long = NA) |> 
  mutate(address = str_replace(list3, ' CA', ', CA')) |> 
  select(6, 2:3)

nrow(OC_addresses_4_geocoding)


#Geocodio appears to do the best job
lat_longs_geocodio <- OC_addresses_4_geocoding |> 
  geocode(address = address, method = 'geocodio',
          full_results = TRUE)

rm(ls = addresses, addresses2, CoStar1_spl)

rm(ls = OC_parcelsOver300, OCFixed, OCnull, OCaddress_check,
   unparsedList, unparsedList2)
rm(ls = lat_longs, lat_long2, OC_addresses_4_geocoding, OC_addresses_last27)
rm(ls = txt2)
gc()
rm(ls = OC_parcels_narrow, OC_parcelsOver150, OC_parcels_all)

##Import parcel data
#wd <- getwd()
OC_data <- '/Landbase_Public_Data/'
OC_parcels_all <- sf::st_read(dsn = paste0(Orange_dir, OC_data)) |> 
  select(created, last_edit, LegalStart, geometry, OID_JOIN) |> 
  st_set_crs(2230) #|> 
#st_transform(4326)

OC_size <- st_area(OC_parcels_all)

OC_parcels_narrow <- OC_parcels_all |> 
  st_set_geometry(value = NULL)

OC_parcels_narrow$size <- as.numeric(OC_size)

OC_parcelsOver100 <- OC_parcels_narrow |> 
  filter(size > 100000) |> 
  mutate(ID = row_number()) |> 
  #st_set_geometry(value = NULL) #|> 
  left_join(OC_parcels_all) |> 
  st_as_sf() |> 
  st_transform("+proj=longlat +ellps=WGS84 +datum=WGS84") #|> 


rm(OC_parcels_all, OC_parcels_narrow)

lat_lngs_sf <- lat_longs_geocodio |> 
  st_as_sf(coords = c('long', 'lat'), crs = 4326) |> 
  filter(accuracy_type == 'rooftop')  

sf_use_s2(FALSE)
OC_warehouse_polygons1 <- lat_lngs_sf |>
  st_join(OC_parcelsOver100) |> 
  st_set_geometry(value = NULL) |> 
  left_join(OC_parcelsOver100) |> 
  st_as_sf() |> 
  filter(address != '1051S East St Anaheim, CA 92805')

OC_wh <- OC_warehouse_polygons1 |> 
  select(address, zip, county, size, geometry)


lu_codes <- c('1231', '1323', '1340', '1310')
OC_SCAG <- sf::st_read(dsn = paste0(wd, '/Warehouse_data/OC_parcels')) |> 
  janitor::clean_names() |>
  select(apn, shape_are, year_adopt, county, scag_gp_co, lu16) |>
  filter(lu16 %in% lu_codes)

class <- c('commercial storage', 'open storage', 'wholesaling and warehousing',
           'light industrial')
type <- c('other', 'other', 'warehouse', 'other')
code_desc <- data.frame(lu_codes, class, type)

## Need to convert OC parcel data from XYZ polygon to XY polygon
narrow_OC_parcels <- OC_SCAG |>
  left_join(code_desc, (by = c('lu16' = 'lu_codes'))) |>
  mutate(shape_area = as.numeric(shape_are),
         year_built = as.numeric(lubridate::year(year_adopt))) |>
  #select(apn, shape_area, class, type, geometry, year_built, county) |>
  st_transform("+proj=longlat +ellps=WGS84 +datum=WGS84") |>
  mutate(type = as.factor(type)) |>
  st_zm() |>
  mutate(threshold = ifelse(shape_area > 150000, 1, 0)) |>
  mutate(exclude = ifelse(type == 'warehouse', 0,
                          ifelse(threshold == 1, 0, 1))) |>
  filter(exclude == 0) |>
  select(apn, shape_area, class, type, geometry, year_built, county) #|>

#rm(ls = OC_parcelsOver100)

narrow_OC_parcels2 <- narrow_OC_parcels |> 
  select(apn, shape_area, county, geometry) |> 
  st_transform(crs = 4326) 
names(narrow_OC_parcels2)
narrow_OC_CoStar <- OC_warehouse_polygons1 |> 
  select(address, size, geometry) |> 
  st_transform(crs = 4326)

#st_precision(narrow_OC_parcels2) <- 0.00001
#st_precision(narrow_OC_CoStar) <- 0.00001

equalsOC <- narrow_OC_CoStar |> 
  st_filter(narrow_OC_parcels2) |> 
  dplyr::distinct() |> 
  rename(shape_area = size)
unequalsOC <- narrow_OC_CoStar |> 
  st_filter(st_union(narrow_OC_parcels2),
            .predicate = st_disjoint) |> 
  rename(shape_area = size)
unequalsOC2 <- narrow_OC_parcels2 |> 
  st_filter(st_union(narrow_OC_CoStar),
            .predicate = st_disjoint) |> 
  rename(address = apn) |> 
  select(-county)

OC_warehouses <- bind_rows(equalsOC,
                           unequalsOC,
                           unequalsOC2) |> 
  mutate(county = 'Orange',
         class = 'warehouse',
         type = 'warehouse')

narrow_OC_parcels <- OC_warehouses |>
  # left_join(code_desc, (by = c('lu16' = 'lu_codes'))) |>
  mutate(year_built = 1910) |>
  #select(apn, shape_area, class, type, geometry, year_built, county) |>
  st_transform("+proj=longlat +ellps=WGS84 +datum=WGS84") |>
  mutate(type = as.factor(type)) |>
  #st_zm() |>
  mutate(threshold = ifelse(shape_area > sq_ft_threshold_maybeWH, 1, 0)) |>
  mutate(exclude = ifelse(type == 'warehouse', 0,
                          ifelse(threshold == 1, 0, 1))) |>
  filter(exclude == 0) |>
  rename(apn = address) |> 
  select(apn, shape_area, class, type, geometry, year_built, county) #|>

unlink('OC_wh2018.geojson')
st_write(OC_warehouses, 'OC_wh2018.geojson') 

rm(ls = lat_longs_geocodio, narrow_OC_parcels2, OC_parcelsOver100, OC_SCAG,
   OC_warehouse_polygons1, OC_warehouses, OC_wh, OCzips, unequalsOC, unequalsOC2,
   zips, narrow_OC_CoStar)

rm(ls = code_desc, equalsOC, lat_lngs_sf, CoStarVec)

