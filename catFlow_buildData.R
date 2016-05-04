##catFlow: relationships between StreamCat landscape attributes and streamflow
##script to build data object joining NWIS/NHDplus, streamCat, GAGESII and flows

if (!require("dataRetrieval")) { install.packages("dataRetrieval", dependencies = TRUE); library(dataRetrieval)}
if (!require("httr")) { install.packages("httr", dependencies = TRUE); library(httr)}
if (!require("dplyr")) { install.packages("dplyr", dependencies = TRUE); library(dplyr)}

#### Cross reference NWIS gage numbers to NHDPlus2 COMIDs
# #Lookup built from NHDplus National GageInfo and GageLoc .dbfs, dropping unused cols and renaming
# #  see /Users/Dan/Google Drive/NHDplus/NHDPlusNationalData/makeGageLookup.R 
# #  note 233 GAGEIDs/rows have COMIDs but not full info due to missing in original GageInfo table 
# #  28164 by 18, COMID (integer); limited metadata relative to dataRetrieval functions...
# nwis2nhdp = readRDS(gzcon(url("https://github.com/daauerbach/catFlow/raw/master/NWIStoNHDplusV2.rds")))

#### Join StreamCat features to USGS gages
#### NOTE THESE STEPS REQUIRE CONSIDERABLE STORAGE AND TIME
# #build a national library of state.rds objects
# devtools::source_url("https://raw.githubusercontent.com/daauerbach/streamcatUtils/master/scu_getStreamCatST.R")
# setwd("/Users/Dan/Google Drive/NHDplus") 
# for(s in state.abb[-grep("AK|HI", state.abb)]) getStreamCatST(s, dirOut = "catdata")
# #bind up all available units, removing duplicates
# devtools::source_url("https://raw.githubusercontent.com/daauerbach/streamcatUtils/master/scu_bindStreamCatST.R")
# usa = filter(bindStreamCatST(state.abb[-grep("AK|HI", state.abb)]
#                              ,dirCatdata = "/Users/Dan/Google Drive/NHDplus/catdata")
#              , !duplicated(COMID))
# #join to previous...28164 by 240
# nwis2cat = left_join(nwis2nhdp, usa, by="COMID")
# ### Note 3400 in NHDplus lookup are missing from streamCat...
# ### mostly Hawaii (1280) and PR (611), but substantial numbers from FL, CA and ID...
# sort(table(filter(nwis2cat, is.na(nwis2cat$CatAreaSqKm))$STATE))
# ### original run: saveRDS(nwis2cat, "catFlowOrig/NWIS_NHDp_StreamCat_all.rds") #about 26mb

nwis2cat = readRDS(gzcon(url("https://github.com/daauerbach/catFlow/raw/master/NWIS_Sc_all.rds")))

#### Join the GAGESII data
#### GAGESII data built from "GAGES/basinchar_and_report_sept_2011/spreadsheets-in-csv-format"
# http://water.usgs.gov/GIS/dsdl/basinchar_and_report_sept_2011.zip
# and with spatial: http://water.usgs.gov/GIS/dsdl/gagesII_9322_point_shapefile.zip
#9067 by 335, col name added instead of rename to confirm match
g2 = readRDS(gzcon(url("https://github.com/daauerbach/catFlow/raw/master/GAGESII_9322_sept30_2011_tbldf.rds"))) %>% mutate(GAGEID = STAID)
# #Disagreements: 9067 with text attributes
# nrow(readRDS("GAGESII/spdf_gagesII_9322_sept30_2011.rds")) #9322 in the spatial points
# sum(table(nwis2cat$GagesII)) #9203 in the NHDplus lookup, of which 7217 nonref, 1986 ref
# sum(nwis2cat$GAGEID %in% g2$STAID) #9040...so 282 or 3% of 9322 are missing

## ORIGINAL VERSION (SUPPORTING TECH NOTE MSCPT) in catFlowOrig/catFlowWork.R
g2cat = left_join(g2, nwis2cat, by="GAGEID") #TRUE, for confirmation: identical(g2cat$STAID, g2cat$GAGEID)
rm(g2, nwis2cat) #clean up...
# #initially includes 7094 nonref, 1944 ref, 29 NA ??
# table(g2cat$GagesII, useNA = "always")
# #80 gages with no StreamCat data (due to the absences noted above in the NHDplus lookup)
# filter(g2cat, is.na(CatAreaSqKm)) %>% select(one_of(c("STANAME","LAT_GAGE","LNG_GAGE","HCDN-2009","STATION_NM","DASqKm","GagesII", "CatAreaSqKm", "WsAreaSqKm","PctAg2006Slp10Cat")))
##drop rows/gages: with no StreamCat data
##drop features: the local "Cat", a few duplicated names, yearly temp and precip
##8987 by 340; now 7047 nonref, 1938 ref, 2 NA; note some NA scattered through individual features
g2cat = filter(g2cat, !is.na(CatAreaSqKm)) %>%
   select(-contains("Cat")) %>% 
   select(-GAGEID) %>% 
   select(-grep(".y$", names(g2cat))) %>%
   select(-one_of(paste0("TMP",1950:2009,"_AVG"))) %>%
   select(-one_of(paste0("PPT",1950:2009,"_AVG"))) %>%
   mutate(PPTAVG_BASIN = 10*PPTAVG_BASIN, STOR_NOR_2009 = 1000*STOR_NOR_2009, STOR_NID_2009 = 1000*STOR_NID_2009)
#note that Sc and NWIS do not agree on the state for 83 obs
filter(g2cat, STATE.x != stabb)

#### Join preliminary streamflow numbers
#### PENDING REVISION WITH RERUN stateGages/stateMetrics() WRAPPER FUNCTIONS in catFlowOrig/catFlowWork.R
#### HERE JUST USING PREVIOUSLY BUILD OBJECTS FROM ORIGINAL stateMetrics() RUN
# # ## 'cfd' is cATfLOWdATA
# # cfd = left_join(g2cat
# #                 ,inner_join(do.call(rbind, readRDS("/Users/Dan/Google Drive/NHDplus/catFlowOrig/gagesCONUS.rds"))
# #                             ,do.call(rbind, readRDS("/Users/Dan/Google Drive/NHDplus/catFlowOrig/gagesCONUSmetrics.rds"))
# #                             , by="site_no") %>% rename(STAID = site_no)
# #                 ,by="STAID"
# #                 )
# #8987 by 378, including several redundant metadata features...
# saveRDS(cfd, "NWIS_G2_Sc_prelimFlows.rds")


cfd = readRDS(gzcon(url("https://github.com/daauerbach/catFlow/raw/master/NWIS_G2_Sc_prelimFlows.rds")))


#Watershed focal [Sc] features
ffws = readRDS(gzcon(url("https://github.com/daauerbach/streamcatUtils/raw/master/focalfeatWsList.rds")))

##comparison features
#grep("NLCD06",names(g2cat), value = T); grep("2006Ws$",names(g2cat), value = T)
cf = list(
   ids = c("LNG_GAGE","LAT_GAGE", "dec_lon", "dec_lat", "LonSite","LatSite"
           ,"COMID","STATION_NM","STATE_CD","Active","GagesII","HCDN-2009","HYDRO_DISTURB_INDX","BASIN_BOUNDARY_CONFIDENCE","SCREENING_COMMENTS")
   ,das = c("PCT_DIFF_NWIS","NWIS_DRAIN_SQKM","DRAIN_SQKM.x","DASqKm","WsAreaSqKm")
   ,hydc_g = c("PPTAVG_BASIN","T_MIN_BASIN","T_AVG_BASIN","T_MAX_BASIN", "RUNAVE7100","BFI_AVE")
   ,hydc_sc = c("PrecipWs","TminWs","TmeanWs","TmaxWs", "RunoffWs","BFIWs")
   ,soil_g = c("CLAYAVE","SANDAVE","OMAVE","ROCKDEPAVE","WTDEPAVE","PERMAVE","KFACT_UP")
   ,soil_sc = c("ClayWs","SandWs","OmWs","RckDepWs","WtDepWs","PermWs","KffactWs")
   ,nlcd06_g = c("IMPNLCD06","WATERNLCD06", "DEVLOWNLCD06","DEVMEDNLCD06","DEVHINLCD06", "DECIDNLCD06","EVERGRNLCD06","MIXEDFORNLCD06"
                 ,"SHRUBNLCD06","GRASSNLCD06","PASTURENLCD06","CROPSNLCD06", "WOODYWETNLCD06","EMERGWETNLCD06")
   ,nlcd06_sc = c("PctImp2006Ws","PctOw2006Ws", "PctUrbLo2006Ws","PctUrbMd2006Ws","PctUrbHi2006Ws", "PctDecid2006Ws","PctConif2006Ws","PctMxFst2006Ws"
                  ,"PctShrb2006Ws","PctGrs2006Ws","PctHay2006Ws","PctCrop2006Ws", "PctWdWet2006Ws","PctHbWet2006Ws")
   ,devel_g = c("STOR_NOR_2009","STOR_NID_2009","DDENS_2009",  "CANALS_PCT","MINING92_PCT","NPDES_MAJ_DENS","ROADS_KM_SQ_KM","RD_STR_INTERS")
   ,devel_sc = c("DamNrmStorWs", "DamNIDStorWs", "DamDensWs",  "CanalDensWs","MineDensWs","NPDESDensWs","RdDensWs","RdCrsWs")
   ,pop_g = c("PDEN_2000_BLOCK","PDEN_DAY_LANDSCAN_2007","PDEN_NIGHT_LANDSCAN_2007")
   ,pop_sc = "PopDen2010Ws"
)

