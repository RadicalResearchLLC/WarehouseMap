##EMFAC emissions calculations for Warehouse CITY
##Created by Mike McCarthy
##Initially written July 2022
##Last modified October 2022

library(tidyverse)
library(janitor)

wd <- getwd()
output_dir <- paste0(wd, '/exports_other')

setwd(output_dir)

##Original analysis 
##Only included diesel HHDV - no MHDV or LHDV

EMFAC_HDDV <- read.csv('EMFAC2021-EI-202xClass-SouthCoastAQMD-2022-Annual-20220621144942.csv', skip = 8) %>%
  clean_names()

ggplot(EMFAC_HDDV, aes(x = trips, y = total_vmt)) +
  geom_label(aes(label = vehicle_category), size = 2) +
  theme_bw() + 
  geom_smooth(method = 'lm')

EMFAC_tidy <- EMFAC_HDDV %>%
  select(vehicle_category, total_vmt, n_ox_totex, pm2_5_totex, pm2_5_total, co2_totex) %>%
  pivot_longer(cols = 3:6, names_to = 'emissions_type', values_to = 'tons_day') %>%
  mutate(tons_mile = tons_day/total_vmt) %>%
  mutate(pounds_mile = 2000*tons_mile) %>%
  mutate(SWCV = str_detect(vehicle_category, 'SWCV')) %>%
  filter(SWCV == FALSE)

EMFAC_tidy %>% 
  ggplot(aes(x = total_vmt, y = pounds_mile)) +
  geom_text(aes(label = vehicle_category), size = 2) +
    theme_bw() +
    geom_smooth() +
  scale_y_log10() +
  facet_wrap( ~emissions_type) 

EMFAC_summary <- EMFAC_tidy %>%
  select(emissions_type, total_vmt, tons_day) %>%
  group_by(emissions_type) %>%
  summarize(sum_VMT = sum(total_vmt), sum_tons = sum(tons_day)) %>%
  mutate(tons_mile = sum_tons/sum_VMT) %>%
  mutate(pounds_mile = 2000*tons_mile)

EMFAC_allTrucks <- read.csv('EMFAC2021-EI-202xClass-SouthCoast-2022-Annual-20221023202818.csv', skip = 8) %>%
  clean_names()

EMFAC_tidy2 <- EMFAC_allTrucks %>%
  filter(vehicle_category != 'MDV') %>% 
  select(vehicle_category, calendar_year, fuel, trips, total_vmt, n_ox_totex, pm2_5_totex, pm2_5_total, co2_totex) %>%
  pivot_longer(cols = 6:9, names_to = 'emissions_type', values_to = 'tons_day') %>%
  mutate(tons_mile = tons_day/total_vmt) %>%
  mutate(pounds_mile = 2000*tons_mile) %>%
  mutate(SWCV = str_detect(vehicle_category, 'SWCV')) %>%
  filter(SWCV == FALSE)

EMFAC_tidy2 %>% 
  ggplot(aes(x = total_vmt, y = pounds_mile, color = fuel)) +
  geom_text(aes(label = vehicle_category), size = 2) +
  theme_bw() +
  #geom_smooth() +
  scale_y_log10() +
  facet_wrap( ~emissions_type) 

EMFAC_summary2 <- EMFAC_tidy2 %>%
  select(emissions_type, total_vmt, tons_day) %>%
  group_by(emissions_type) %>%
  summarize(sum_VMT = sum(total_vmt), sum_tons = sum(tons_day)) %>%
  mutate(tons_mile = sum_tons/sum_VMT) %>%
  mutate(pounds_mile = 2000*tons_mile)
