## catflow UI, D.Auerbach spring 2016
if (!require("colorRamps")) { install.packages("colorRamps", dependencies = TRUE); library(colorRamps)}
if (!require("ggplot2")) { install.packages("ggplot2", dependencies = TRUE); library(ggplot2)}
if (!require("shiny")) { install.packages("shiny", dependencies = TRUE); library(shiny)}
if (!require("leaflet")) { install.packages("leaflet", dependencies = TRUE); library(leaflet)}
if (!require("DT")) { install.packages("DT", dependencies = TRUE); library(DT)}
if (!require("dplyr")) { install.packages("dplyr", dependencies = TRUE); library(dplyr)}
if (!require("cluster")) { install.packages("cluster", dependencies = TRUE); library(cluster)}

ffws = readRDS("ffwsList.rds")

shinyUI(navbarPage(title = "catFlow", collapsible = T
                   ##CSS called from url:
                   ,theme = "http://bootswatch.com/flatly/bootstrap.min.css"
                   ,tabPanel("flow v. feature"
                             ,fluidRow(
                               column(2,
                                      wellPanel(
                                         style = "background-color: #66CCFF; padding:5px;
                                                  overflow-y:scroll; min-height: 900px" #; max-height: 900px;" 
                                         ,radioButtons("fm", label = "Flow metric"
                                                              #hard coded for now
                                                              ,choices = list("No flow days"="noflow"
                                                                              ,"Percent no flow"="pctnoflow"
                                                                              ,"99.9% excdnc."="pcntl0.001"
                                                                              ,"99% excdnc."="pcntl0.01"
                                                                              ,"90% excdnc."="pcntl0.1"
                                                                              ,"75% excdnc."="pcntl0.25"
                                                                              ,"median"="pcntl0.5"
                                                                              ,"5% excdnc. (hi)"="pcntl0.95"
                                                                              ,"1% excdnc. (hi)"="pcntl0.99"
                                                              )
                                                              ,selected = "pctnoflow")
                                                   ,radioButtons("cex", inline = F, label = "Scale points:"
                                                                , choices = list("None"="none","Record length"="nobs", "Drainage area"="WsAreaSqKm"))
                                                   ,checkboxGroupInput("log", inline = T, label = "Log axes:", choices = list("X"="x","Y"="y"))
                                      ) )#end fm selector col
                               
                               ,column(8
                                       ,h5("Drag then double-click to zoom, double-click to reset, single click to identify gage")
                                       ,plotOutput("scatter", click="clickscatter", brush="brushscatter", dblclick = "dblscatter", height = "450px" ) #resetOnNew = TRUE?
                                       ,h4(textOutput("gagename")) #verbatimTextOutput("gagename")
                                       ,leafletOutput("gageMap", height = "450px")
                                      )#end plot & map col
                               
                               ,column(2
                                       ,wellPanel(
                                         style = "background-color: #009900; padding:5px;
                                                  overflow-y:scroll; min-height: 900px" #; max-height: 900px;"
                                         ,radioButtons("ws", inline = T, label = "Watershed Feature"
                                                       ,choices = as.list(c(ffws$topo,ffws$hydc
                                                                            ,ffws$soil,ffws$impv
                                                                            ,ffws$nlcd11))
                                                       #as.list(names(gm)[grep("WsAreaSqKm",names(gm)):ncol(gm)])
                                                       ,selected = "WsAreaSqKm")
                                         )
                                       )#end ws feature selector col
                             )#end fluidrow
                   )#end flow v. feature
                   
                   ,tabPanel("clustering"
                      ,sidebarLayout(
                         sidebarPanel(width=3
                                      ,sliderInput(inputId = "k", label = "k = ", min=2, max=10, value=3, step=1, ticks=F)
                                      ,checkboxGroupInput("clusfeat", inline = T
                                               ,label = h4("Features to include:") 
                                               ,choices = as.list(c(ffws$topo,ffws$hydc
                                                                    ,ffws$soil,ffws$impv
                                                                    ,ffws$nlcd11))
                                               ,selected = c("ElevWs","PrecipWs", "ClayWs"))
                            
                         )#end sidepanel
                         ,mainPanel(
                            plotOutput("clus")
                            ,br()
                            ,h4("Cluster medians of basic flow metrics (record percentiles in CMS)")
                            ,dataTableOutput("clusmed")
                         )
                      )
                   )#end clustab

))
