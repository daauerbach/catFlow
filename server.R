## catflow server, D.Auerbach spring 2016
if (!require("colorRamps")) { install.packages("colorRamps", dependencies = TRUE); library(colorRamps)}
if (!require("ggplot2")) { install.packages("ggplot2", dependencies = TRUE); library(ggplot2)}
if (!require("shiny")) { install.packages("shiny", dependencies = TRUE); library(shiny)}
if (!require("leaflet")) { install.packages("leaflet", dependencies = TRUE); library(leaflet)}
if (!require("DT")) { install.packages("DT", dependencies = TRUE); library(DT)}
if (!require("dplyr")) { install.packages("dplyr", dependencies = TRUE); library(dplyr)}
if (!require("cluster")) { install.packages("cluster", dependencies = TRUE); library(cluster)}
#shinyBS Has bsTooltip functions for adding hover/click fixed text: if (!require("shinyBS")) { install.packages("shinyBS", dependencies = TRUE); library(shinyBS)}

gm = readRDS("gmsc_ffws.rds") %>% #11025
   filter(!is.na(GRIDCODE)) %>% #11021 with a valid GRIDCODE as above
      filter(!is.na(COMID)) %>% #11007 with GRIDCODE actually in natcatlookup
         filter(!is.na(CatAreaSqKm)) #10999, so apparently 8 bad cats? 
#can further select out features pre-emptively...
#can add 0.000001 as crude fix for log...

shinyServer(function(input, output, session) {

  gms = reactive({
      select(gm, one_of(c("station_nm",input$ws, input$fm)))
      #could add log'd cols here, esp. for control to base 10, but perhaps unnecessarily inefficient?
      })#end gms reactive
   
  cex.vec = eventReactive(input$cex
      ,switch(input$cex
              ,none = rep(0.7,nrow(gm))
              ,nobs = 0.2 + gm$nobs/max(gm$nobs)
              ,WsAreaSqKm = 0.1*log(gm$WsAreaSqKm+1)
              )
      ) #end cex.vec

  ranges = reactiveValues(x = NULL, y = NULL)

  #below are chunks for a non-zooming base version and a starter ggplot2 version
  output$scatter = renderPlot({
     d = gms()
     par(bty="l", las=1, mar=c(5,5,0.5,0.5))
     plot(data.matrix(gms()[,-1])
          ,xlim = ranges$x , ylim = ranges$y
          ,main="",xlab="",ylab=""
          ,log = paste0(input$log, collapse = "")
          ,pch=21 ,col=1 ,bg=rgb(30/255,144/255,255/255,100/255)  #via col2rgb("dodgerblue", T)
          ,cex = cex.vec())
     title(xlab = input$ws, cex.lab=2, col.lab="#009900")
     title(ylab = input$fm, cex.lab=2, col.lab="#66CCFF")
  })#end scatter
  
  observeEvent(input$dblscatter, {
     brush = input$brushscatter
     if (!is.null(brush)) {
        ranges$x <- c(brush$xmin, brush$xmax)
        ranges$y <- c(brush$ymin, brush$ymax)     
     } else {
        ranges$x <- NULL
        ranges$y <- NULL
     }
  })#end plotzooming
   
  #build the starting map 
  output$gageMap = renderLeaflet({
     leaflet(gm) %>% setView(-93.65, 39.0285, zoom = 4) %>% addTiles(group = "OSM") %>% 
        addCircles(lng = ~dec_long_va, lat = ~dec_lat_va #use CircleMarkers for fixed radii
                   ,layerId = ~station_nm, stroke = F
                   ,radius = ~nobs/max(nobs) * 5000
                   ,fillOpacity = 0.7, fillColor = ~colorRamps::blue2red(10)[findInterval(pctnoflow,seq(0,1,length.out = 10))]
                   ,popup = htmltools::htmlEscape(~station_nm)
                   )
    })#end gageMap
  
  #click on the scatter to pan & zoom to the gage
  observeEvent(input$clickscatter, {
     d = gms()
     #crude for now: just taking closest/top
     clickedgage = as.character(nearPoints(d, coordinfo = input$clickscatter, xvar = names(d)[2] , yvar = names(d)[3])$station_nm[1])
     if(!is.na(clickedgage)){
        output$gagename = renderText({ paste("Selected gage is:   ", clickedgage) })
        cgm = filter(gm, station_nm == clickedgage)
        leafletProxy("gageMap") %>%
           setView(cgm$dec_long_va, cgm$dec_lat_va, zoom=9) %>%
           addCircles(cgm$dec_long_va, cgm$dec_lat_va
                      ,popup = htmltools::htmlEscape(cgm$station_nm), layerId="junk"
                      ,radius = cgm$nobs/max(gm$nobs) * 12000
                      ,stroke = T, color = "black", weight = 8
                      ,fillOpacity = 0.9, fillColor = "red"#"#ADFF2F"
           )
        }
     })#end scatter clicks
     
  ### Cluster tab work
  #keeping a small sample for prototyping
  #note reactive returned value is cached and the function is NOT actually called again here according to event scheduling article
  observe({
     flowvars = c("nobs", "pctnoflow","pcntl0.01","pcntl0.5","pcntl0.99")
     d = select(gm, one_of(input$clusfeat))
     cla = clara(d, k = as.integer(input$k)
                 ,stand = T, rngR = T
                 ,samples = 5, sampsize = 100
                 )
     output$clus = renderPlot({
        par(bty="l", las=1)
        clusplot(cla, color=T, col.p = cla$clustering
                 ,main="Gages ordinated by first two axes of PCA on selected features")
        legend("topright", horiz=F, bty="n"
               , col=1:max(cla$clustering), pch=1:max(cla$clustering), legend = 1:max(cla$clustering))
        })
     output$clusmed = renderDataTable({
        if(!is.null(cla)){
           dt = select(gm, one_of(flowvars)) %>%  #nobs:pctnoflow
              group_by(clus = cla$clustering) %>%
               summarize_each(funs(median(.,na.rm=T)))
           } else {dt = select(gm, one_of(flowvars)) %>% sample_n(size=0)}
        datatable(dt, options = list(dom = "t")) %>% formatRound(columns=flowvars, digits=c(0,5,5,3,2))
        })
  })#end observe
   

})#end server



##First pass at a ggplot version, working...
#   output$scatter = renderPlot({
#      d = gms()
#      ggplot(d, aes_string(names(d)[2], names(d)[3])) + 
#         geom_point() +
#         coord_cartesian(xlim = ranges$x, ylim = ranges$y)
#   })#end scatter

# # Static render working with base plot, but probably worth more learning ggvis...
# output$scatter = renderPlot({
#    par(bty="l", las=1, mar=c(5,5,0.5,0.5))
#    plot(data.matrix(gms()[,-1])
#         ,main="",xlab="",ylab=""
#         ,log = paste0(input$log, collapse = "")
#         ,pch=21 ,col=1 ,bg=rgb(30/255,144/255,255/255,100/255)  #via col2rgb("dodgerblue", T)
#         ,cex = cex.vec())
#    title(xlab = input$ws, cex.lab=2, col.lab="#009900")
#    title(ylab = input$fm, cex.lab=2, col.lab="#66CCFF")
# })#end scatter

# #the leaflet popup already indicates the gage name
# #and did not get far having map clicks redraw the whole scatter for 11K points...slow and fairly complicated observers?
# observeEvent(input$gageMap_shape_click, {
#    if(!is.null(input$gageMap_shape_click$id)){
#       gg = filter(gm, station_nm == as.character(input$gageMap_shape_click$id))
#       leafletProxy("gageMap") %>%
#          addCircles(input$gageMap_shape_click$lng, input$gageMap_shape_click$lat
#                     ,layerId="junk"
#                     ,radius = gg$nobs/max(gm$nobs) * 15000
#                     ,stroke = T, color = "black", weight = 6
#                     ,fillOpacity = 0.2, fillColor = "purple"
#          )
#    }
# })#end gagemap clicks

#### Started playing with ggvis for plot - some nice advantages but too much learning curve for now 
# if (!require("ggvis")) { install.packages("ggvis", dependencies = TRUE); library(ggvis)}
# reactive({
#    gms %>% ggvis(x = as.symbol(input$ws), y = as.symbol(input$fm) ) %>% 
#       set_options(height = 500) %>%
#       layer_points(size := 50, size.hover := 200
#                    ,fillOpacity := 0.2, fillOpacity.hover := 0.5
#       ) #%>%
#    #             add_tooltip( , "hover")
# }) %>% bind_shiny("scatter")

