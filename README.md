# catFlow

Work in progress relating [StreamCat](http://www2.epa.gov/national-aquatic-resource-surveys/streamcat) data to flow statistics calculated from USGS NWIS data via [dataRetrieval](https://github.com/USGS-R/dataRetrieval).

*catFlow_buildData.R* creates the data object *NWIS_G2_Sc_prelimFlows.rds* from the other included data plus functions in streamCatUtils

Access these data directly from a session via:
```R
x = readRDS(gzcon(url("https://github.com/daauerbach/catFlow/raw/master/NWIS_G2_Sc_prelimFlows.rds")))
```

Also includes a placeholder shiny app pending updates to the underlying .rds object 


## Disclaimer
This code is provided on an "as is" basis and the user assumes responsibility for its use.  Any reference to specific commercial products, processes, or services by service mark, trademark, manufacturer, or otherwise, does not constitute or imply their endorsement, recommendation or favoring.
