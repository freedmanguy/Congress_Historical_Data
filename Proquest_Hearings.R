# scrape congressional hearings data from Proquest
# review requirements for selenium server and chromedriver in git page

# fill in authentication credentials below.
# DO NOTE SHARE script with others once filled in
# alternatively store credentials in a file and import into R environment
myuser <- # fill in with UT user
mypassword <- # fill in with UT password  

# in terminal: cmd+alt+enter (requires selenium driver in the folder)
cd ~/downloads/selenium
java -jar selenium-server-standalone-3.9.1.jar -port 4447 # choose an open port

# in r: cmd+enter
xfun::pkg_attach2("RSelenium","httr","dplyr")
remDr <- remoteDriver(
  remoteServerAddr = "localhost",
  port = 4447L, # match to the port above
  browserName = "safari" # change to chrome if prefer (requires chromedriver in the same folder)
)

# declare functions for extracting separate pieces of information

# full description
extractitems <- function(){
  x <- remDr$findElements(using = "class", value = "itemTitle")
  temp <- c()
  for(i in 1:length(x)){
    temp[i] <- x[[i]]$getElementText()
  }
  
  cat1 <- unlist(temp)
  return(cat1)
}

# hearing type
extracttype <- function(){
  x <- remDr$findElements(using = "class", value = "docType")
  temp <- c()
  for(i in 1:length(x)){
    temp[i] <- x[[i]]$getElementText()
  }
  
  cat1 <- unlist(temp)
  return(cat1)
}

# date
extractdate <- function(){
  x <- remDr$findElements(using = "class", value = "col-md-3")
  temp <- c()
  for(i in 1:length(x)){
    temp[i] <- x[[i]]$getElementText()
  }
  
  cat1 <- unlist(temp)
  return(cat1)
}

# committee
extractcomm <- function(){
  x <- remDr$findElements(using = "class", value = "col-md-7")
  temp <- c()
  for(i in 1:length(x)){
    temp[i] <- x[[i]]$getElementText()
  }
  
  cat1 <- unlist(temp)
  return(cat1)
}

# open browser and naviage to proquest
mystart <- Sys.time()
try(remDr$quit())
remDr$open()
remDr$navigate("https://congressional-proquest-com.ezproxy.lib.utexas.edu/congressional/search/advanced/advanced?")
rm(webElemu,webElemp,webElems)
webElemu <- remDr$findElement(using = "name", value = "j_username")
webElemu$sendKeysToElement(list(myuser))
webElemp <- remDr$findElement(using = "name", value = "j_password")
webElemp$sendKeysToElement(list(mypassword))
webElems <- remDr$findElement(using = "name", value = "_eventId_proceed")
webElems$clickElement()

# approve two-factor authentication in Duo before continuing

mydata <- list()
for(mycongress in 41:80){# choose congresses for query
  remDr$navigate("https://congressional-proquest-com.ezproxy.lib.utexas.edu/congressional/search/advanced/advanced?")
  Sys.sleep(15)
  remDr$setWindowSize(height = 10000, width = 1280) #3000
  selall <- remDr$findElement(using = "name" , value = "selectAll")
  selall$mouseMoveToLocation(webElement = selall)
  selall$click()
  selhearings <- remDr$findElement(using = "id" , value = "hrg")
  selhearings$mouseMoveToLocation(webElement = selhearings)
  selhearings$click()
  selcongress <- remDr$findElement(using = "id" , value = "congress")
  selcongress$executeScript("document.getElementById('congress').click()")
  selcongressS <- remDr$findElement(using = "id" , value = "selectedCongress")
  selcongressS$sendKeysToElement(list(as.character(mycongress)))
  mysearch.run <- remDr$findElement(using = "link text", value = "Search")
  mysearch.run$mouseMoveToLocation(webElement = mysearch.run)
  mysearch.run$clickElement()
  Sys.sleep(15)
  
  myres <- remDr$findElement(using = "class", value = "resultCount")
  myres <- myres$getElementText()
  myres <- gsub(" |[a-z]|,","",myres[[1]],ignore.case = T) %>% 
    as.character() %>% 
    as.numeric()
  mynext <- floor((myres-1)/20)
  
  cat1 <- extractitems()
  cat2 <- extracttype()
  cat3 <- extractdate()
  dates <- cat3[grepl("^Date:",cat3)]
  citation <- cat3[grepl("^Citation:",cat3)]
  cat4 <- extractcomm()
  committee <- cat4[grepl("^Committee:",cat4)]
  collation <- cat4[grepl("^Collation:",cat4)]
  
  i <- 1
  while(i <=mynext){
    remDr$setWindowSize(height = 10000, width = 1280)
    nextpage <- remDr$findElement(using = "id", value = "btnNext")
    nextpage$mouseMoveToLocation(webElement = nextpage)
    nextpage$clickElement()
    Sys.sleep(5)
    cat1 <- c(cat1,extractitems())
    cat2 <- c(cat2,extracttype())
    cat3 <- c(cat3, extractdate())
    cat4 <- c(cat4, extractcomm())
    print(i)
    i <- i+1
  }
  
  dates <- cat3[grepl("^Date:",cat3)]
  citation <- cat3[grepl("^Citation:",cat3)]
  committee <- cat4[grepl("^Committee:",cat4)]
  collation <- cat4[grepl("^Collation:",cat4)]
  
  mydata[[mycongress]] <- data.frame(congress = rep(mycongress, length(cat1)),
                                     title = cat1,
                                     type = cat2,
                                     date = dates,
                                     committee = committee,
                                     citation = citation,
                                     collation = collation)
  print(i)
}
myend <- Sys.time()

finaldata <- plyr::ldply(mydata)

writexl::write_xlsx(finaldata, "HearingsProquest.xlsx")