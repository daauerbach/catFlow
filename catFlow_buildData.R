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
# nwis2nhdp = readRDS(gzcon(url("https://github.com/daauerbach/streamcatUtils/raw/master/NWIStoNHDplusV2.rds")))

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

#### Join the GAGESII data
#### GAGESII data built from "GAGES/basinchar_and_report_sept_2011/spreadsheets-in-csv-format"
# http://water.usgs.gov/GIS/dsdl/basinchar_and_report_sept_2011.zip
# and with spatial: http://water.usgs.gov/GIS/dsdl/gagesII_9322_point_shapefile.zip

nwis2cat = readRDS(gzcon(url("https://github.com/daauerbach/streamcatUtils/raw/master/NWIS_Sc_all.rds")))

g2 = readRDS(gzcon(url("https://github.com/daauerbach/streamcatUtils/raw/master/GAGESII_9322_sept30_2011_tbldf.rds"))) %>%
   mutate(GAGEID = STAID) #9067 by 335, col name added instead of rename to confirm match
# #Disagreements: 9067 with text attributes
# nrow(readRDS("GAGESII/spdf_gagesII_9322_sept30_2011.rds")) #9322 in the spatial points
# sum(table(nwis2cat$GagesII)) #9203 in the NHDplus lookup, of which 7217 nonref, 1986 ref
# sum(nwis2cat$GAGEID %in% g2$STAID) #9040...so 282 or 3% of 9322 are missing



#rename g2cat as cfd: catFlowData

g2cat = left_join(g2, nwis2cat, by="GAGEID") #TRUE, just for confirmation: identical(g2cat$STAID, g2cat$GAGEID)
# #now 7094 nonref, 1944 ref, 29 NA ??
# table(g2cat$GagesII, useNA = "always")
# #80 gages with no StreamCat data (due to the absences in the noted above the NHDplus lookup)
# filter(g2cat, is.na(CatAreaSqKm)) %>% select(one_of(c("STANAME","LAT_GAGE","LNG_GAGE","HCDN-2009","STATION_NM"
#                                                      ,"DASqKm","GagesII", "CatAreaSqKm", "WsAreaSqKm","PctAg2006Slp10Cat")))
#drop rows/gages: with no StreamCat data
#drop features: the local "Cat", a few duplicated names, yearly temp and precip before 1980
#8987 by 401, note some NA scattered through individual features
#drops to 7047 nonref, 1938 ref, 2 NA
g2cat = filter(g2cat, !is.na(CatAreaSqKm)) %>%
   select(-contains("Cat")) %>%
   select(-grep(".y$", names(g2cat))) %>%
   select(-grep(paste0("TMP",1950:1979, collapse = "|"), names(g2cat))) %>%
   select(-grep(paste0("PPT",1950:1979, collapse = "|"), names(g2cat)))
#keep it clean...
rm(g2, nwis2cat)

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

# ## Quick look across types of features at numeric scales and summary similarity
# ## precip appears to be different scale; temp, runoff, and BFI the same
# sapply(
#   select(g2cat, one_of(c(cf$hydc_g, cf$hydc_sc))) %>% mutate(PPTAVG_BASIN = PPTAVG_BASIN*10)
#   , summary)
# ## different scale but still comparable: ROCKDEP/RckDep, WT/WtDep, Perm
# sapply(
#   select(g2cat, one_of(c(cf$soil_g, cf$soil_sc))) %>% na.omit()
#   , summary)
# plot(PermWs ~ PERMAVE, data=g2cat)
# plot(RckDepWs ~ ROCKDEPAVE, data=g2cat)
# plot(WtDepWs ~ WTDEPAVE, data=g2cat)
# ## nlcd looks good, already 0-100
# sapply(select(g2cat, one_of(c(cf$nlcd06_g, cf$nlcd06_sc))), summary)
# ## streamcat storage/dams is *1000, RdDens is good, RD_STR/RdCrs okay
# sapply(select(g2cat, one_of(c(cf$devel_g, cf$devel_sc))), summary)
# #interesting...perhaps best as scatter...
# sapply(select(g2cat, one_of(c(cf$pop_g, cf$pop_sc))), summary)

## join on raw feature differences
## not looped due to feature name idiosyncrasies
## straight subtraction returns a df, microbenchmark has base [,] ~2x faster than dplyr::select
g2cat = mutate(g2cat, PPTAVG_BASIN = 10*PPTAVG_BASIN
               ,STOR_NOR_2009 = 1000*STOR_NOR_2009
               ,STOR_NID_2009 = 1000*STOR_NID_2009
)
g2cat = cbind(g2cat, g2cat[,cf$hydc_g] - g2cat[,cf$hydc_sc])
names(g2cat)[(ncol(g2cat)-length(cf$hydc_g)+1):ncol(g2cat)] = c("dif_ppt","dif_tmin","dif_tmean","dif_tmax","dif_runoff","dif_bfi")  
g2cat = cbind(g2cat, g2cat[,cf$soil_g] - g2cat[,cf$soil_sc])
names(g2cat)[(ncol(g2cat)-length(cf$soil_g)+1):ncol(g2cat)] = paste0("dif_",tolower(sub("AVE","",cf$soil_g)))
g2cat = cbind(g2cat, g2cat[,cf$nlcd06_g] - g2cat[,cf$nlcd06_sc])
names(g2cat)[(ncol(g2cat)-length(cf$nlcd06_g)+1):ncol(g2cat)] = paste0("dif_",tolower(sub("NLCD06","",cf$nlcd06_g)))
g2cat = cbind(g2cat, g2cat[,cf$devel_g] - g2cat[,cf$devel_sc])
names(g2cat)[(ncol(g2cat)-length(cf$devel_g)+1):ncol(g2cat)] = paste0("dif_",tolower(cf$devel_g))
g2cat = cbind(g2cat, g2cat[,cf$pop_g] - g2cat[,cf$pop_sc])
names(g2cat)[(ncol(g2cat)-length(cf$pop_g)+1):ncol(g2cat)] = paste0("dif_",tolower(cf$pop_g))

g2cat = tbl_df(g2cat)



## probably want to clean various "non-ST" gages (canals, diversions, etc.): table(gm$site_tp_cd)
## though some are plausibly interesting...
## should join a state abbreviation column to final object, currently missing requiring extra lookup to subset by state

