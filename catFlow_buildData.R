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

pCodeToName[grep("Discharge", pCodeToName$description), 1:2]
## wrapper helpter to return tbl_df of gages/rows by site features
## single state allows easy aggregration back up to regions or other groupings
## only one state allowed at a time by webservice for whatNWISsites
## and limit on number of sites in one call to whatNWISdata (hence somewhat kludgy factor index in sites.data construction)
## played with metric calculation here (returning as additional cols)
## but keeping as separate function for modularity (and potential mclapply)
## setting statCd ensures only daily mean, which reduces duplicate rows from min/max/instant (http://help.waterdata.usgs.gov/stat_code)
stateGages = function(stabb
                      ,endafter = as.Date("1985-01-01")
                      ,nobs = 365*5
){
   sites.all = whatNWISsites(stateCd=stabb, parameterCd = "00060")
   sites.data = do.call(rbind,
                        lapply(split(x = sites.all$site_no, f = factor(rep(paste0(letters,rep(1:50,each=26)), each=50, length.out=nrow(sites.all))))
                               , function(sitevec) whatNWISdata(sitevec, service = "dv", parameterCd = "00060", statCd = "00003")
                        ))
   sites.data = tbl_df(filter(sites.data, end_date > endafter & count_nu > nobs))
   return(sites.data)
} #end stateGages

# #str(stateGages("RI"))
# system.time(
#    gages.st <- setNames(lapply(state.abb[-grep("AK|HI", state.abb)], function(st) stateGages(st))
#                         , state.abb[-grep("AK|HI", state.abb)])
# )
# # #after stat_cd enforcement, still a few non-unique site_no due to idiosyncrasies...
# # sapply(gages.st, nrow)
# # sapply(gages.st, function(s) nrow(distinct(s, site_no)))
# # lapply(gages.st, function(s) filter(s, duplicated(site_no))$site_no)
# # t(filter(gages.st[["OK"]], site_no == "07334200"))
# # #distinct() just chooses first, not largest obs count as desired: (distinct(gages.st[["OK"]], site_no) %>% filter(site_no == "07334200"))$count_nu
# ##So, can clean up by selecting the record with the largest count...
# ##but this may still blow up in the metrics?
# gages.st = lapply(gages.st, function(s) {
#    if(any(duplicated(s$site_no))) {
#       ds = s$site_no[duplicated(s$site_no)]
#        ## make a copy of the not-duplicated gages
#        ## this DOES catch the first occurrence of a duplicated site_no
#        ## since ds is character not logical...
#       s2 = filter(s, !(site_no %in% ds))
#       for(i in unique(ds)) {
#          s2 = rbind(s2, filter(s, site_no %in% i) %>% slice(which.max(count_nu)))
#       }
#       return(s2)
#    } else {return(s)}
# })
# saveRDS(gages.st, "gagesCONUS.rds")

## follow up wrapper to return tbl_df of gages/rows by gage flow metrics; preallocated for certainty
## for one or a few stats, doesn't seem to make sense to hold the full record
## keeps it lighter and more reproducible for now
## lots of other useful info returned in readNWISdv call, including the lat/lon
## but just holding number of observations, number of missings obs, number of no flow days and a few quantiles
## began with inner_join() to other metadata before return, but seems to be potential for some duplicated rows/gages
## so returning just metrics to allow subsequent filter and join/merge
stateMetrics = function(stg #tbl_df of gages, as returned by stateGages
                        ,endafter = "1985-01-01"
                        ,prb = c(0.001, 0.01,0.1,0.25,0.5,0.95,.99)
){
   fmet = matrix(numeric(), nrow = nrow(stg), ncol = 3+length(prb)
                 ,dimnames = list(as.character(stg$site_no), c("nobs","nna","noflow", paste0("pcntl",prb)))
   )
   for(s in stg$site_no){
      q = 0.0283168 * readNWISdv(s, parameterCd = "00060", startDate = endafter)$X_00060_00003
      fmet[s,] = c(length(q), sum(is.na(q)), sum(q <= 0, na.rm = T)
                   ,quantile(q, probs = prb, na.rm = T)
      )
   }
   fmet = tbl_df(data.frame(site_no=stg$site_no, data.matrix(fmet), stringsAsFactors = F))
   return(fmet)
} #end stateMetrics

#tester: gages.st.met <- setNames(lapply(gages.st[c("DE","RI")], stateMetrics), c("DE","RI"))
# #again, preallocated due to memory issues
# #loop fails periodically due to Windows not reclaiming memory
# #testing gc() shows no effect...so just babysitting
# setwd("catFlow")
# gages.st = readRDS("gagesCONUS.rds")
# #gages.st.met = setNames(lapply(names(gages.st), function(x) NULL), names(gages.st))
# gages.st.met = readRDS("gagesCONUSmetrics.rds")
# sapply(gages.st.met, dim)
# for(s in names(gages.st.met)[sapply(gages.st.met, is.null)]){
#    print(s)
#    print(nrow(gages.st[[s]]))
#    gages.st.met[[s]] = stateMetrics(gages.st[[s]])
#    saveRDS(gages.st.met, "gagesCONUSmetrics.rds")
# }



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

