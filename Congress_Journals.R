# scrape congressional journal data in congress by opening a browser window
# review requirements for selenium server and chromedriver in git page

# house ----
xfun::pkg_attach2(c("RSelenium","dplyr","writexl"))

# in terminal: cmd+alt+enter (requires selenium driver in the folder)
cd ~/downloads/kbills
java -jar selenium-server-standalone-3.9.1.jar -port 4446 # choose an open port

# in r: cmd+enter
remDr <- remoteDriver(
  remoteServerAddr = "localhost",
  port = 4446L, # match to the port above
  browserName = "safari" # change to chrome if prefer (requires chromedriver in the same folder)
)

# open a browser window and navigate to the relevant page
remDr$open()
remDr$navigate("http://memory.loc.gov/ammem/amlaw/lwhjlink.html")

remDr$setWindowSize(width = 1200, height = 10000)

# identify congressional sessions
test <- remDr$findElements(using = "partial link", value = "Session")
test[[1]]$getElementAttribute(attrName = "href")

sessions <- data.frame(session = rep(NA, length(test)))
sessions$url <- NA
for(i in 1:length(test)){
  sessions[i,1] <- test[[i]]$getElementText()
  sessions[i,2] <- test[[i]]$getElementAttribute(attrName = "href")
  print(i)
}
sessions$congress <- 0
sessions$congress[grepl("^First",sessions$session)] <- 1
sessions$congress <- cumsum(sessions$congress)
sessions$journal.url <- NA

for(i in 1:nrow(sessions)){
  rm(x)
  remDr$navigate(sessions$url[i])
  remDr$setTimeout(type = "page load",milliseconds = 20000)
  x <- remDr$findElement(using = "link", value = "NAVIGATOR")
  x <- x$getElementAttribute(attrName = "href")
  sessions$journal.url[i] <- x[[1]]
  print(i)
}

# identify journal links
jlinks <- unique(sessions$journal.url)

journals <- list()
for(i in 1:length(jlinks)){
  rm(x,temp)
  remDr$navigate(jlinks[i])
  remDr$setTimeout(type = "page load",milliseconds = 20000)
  x <- remDr$findElements(using = "partial link", value = "DAY")
  temp <- data.frame(day = rep(NA, length(x)), url = rep(NA, length(x)))
  for(j in 1:length(x)){
    temp[j,1] <- x[[j]]$getElementText()
    temp[j,2] <- x[[j]]$getElementAttribute(attrName = "href")
    print(paste(i,":",j))
  }
  journals[[i]] <- temp
  print("==================")
  print(i)
  print("==================")
}

journals.df <- plyr::ldply(journals)
journals.df$id <- c(1:nrow(journals.df))
saveRDS(journals.df, "journals.RDS")

# download texts
journal.texts <- list()
for(i in 1:nrow(journals.df)){
  x <- read_html(journals.df$url[i])
  y <- html_nodes(x, "p") %>% 
    html_text()
  y <- grep("^A Century of Lawmaking|^House Journal|^Page [0-9]|previous section|next section|navigator",y,value = T, invert = T,ignore.case = T)
  y <- y[y !=""]
  journal.texts[[i]] <- data.frame(id = rep(journals.df$id[i],length(y)),
                                   text = y)
  print(i)
  Sys.sleep(.5)
}
saveRDS(journal.texts, "journaltexts.RDS")
journal.texts.df <- plyr::ldply(journal.texts)
journal.texts.df <- journal.texts.df %>% 
  group_by(id) %>% 
  mutate(paragraph = 1) %>% 
  mutate(paragraph = cumsum(paragraph))
journal.texts.df$committee <- 0
journal.texts.df$committee[grepl("committee",journal.texts.df$text,ignore.case = T)] <- 1

journals.df$day <- gsub("Februry","February",journals.df$day)
journals.df$date <- NA
journals.df$date <- gsub("^[a-z]*,?\\.? |^[a-z]*,|^[a-z]*; ?","",journals.df$day, ignore.case = T)
journals.df$date <- gsub("\\.","",journals.df$date)
journals.df$date <- gsub("\\.","",journals.df$date)
journals.df$date <- gsub(",","",journals.df$date)
journals.df$date <- gsub("^ +| +$","",journals.df$date)
journals.df$date <- as.Date(journals.df$date, "%B %d %Y")
temp <- filter(journals.df, is.na(date))
temp$date <- as.Date(c("1789-04-06","1789-04-08","1789-07-21","1789-07-29",
                       "1789-09-08","1789-09-09","1790-02-26","1790-04-06",
                       "1790-04-08","1792-11-26","1794-12-24","1811-01-10",
                       "1816-01-02","1817-01-08","1824-05-24","1830-05-29",
                       "1834-12-31","1838-07-04"))
journals.df <- filter(journals.df, !is.na(date)) %>% 
  bind_rows(temp) %>% 
  arrange(id)

fullsessions <- sessions
fullsessions$start <- gsub("^.*: *|to .*$","",fullsessions$session, ignore.case = T)
fullsessions$start <- as.Date(fullsessions$start, "%B %d, %Y")
fullsessions$end <- gsub("^.*to ","",fullsessions$session, ignore.case = T)
fullsessions$end <- as.Date(fullsessions$end, "%B %d, %Y")
fullsessions <- fullsessions %>% 
  group_by(congress) %>% 
  mutate(Session = 1) %>% 
  mutate(Session = cumsum(Session))
fullsessions <- select(fullsessions, congress, Session, start, end) %>% 
  rename("session" = "Session")

fullsessions.l <- list()
for(i in 1:nrow(fullsessions)){
  fulldates <- seq(fullsessions$start[i],fullsessions$end[i],1)
  fullsessions.l[[i]] <- data.frame(congress = rep(fullsessions$congress[i], length(fulldates)),
                                    session = rep(fullsessions$session[i], length(fulldates)),
                                    date = fulldates)
  print(i)
}
fullsessions.df <- plyr::ldply(fullsessions.l)
journals.df$date[journals.df$date=="0000-05-11"] <- as.Date("1820-05-11")

journal.texts.df <- select(journal.texts.df, id, paragraph, text, committee)

journal.texts.full <- left_join(journals.df,fullsessions.df) %>% 
  select(-day) %>% 
  left_join(journal.texts.df) %>% 
  mutate(Major = NA, Minor = NA)

write_xlsx(journal.texts.full, "House_journals.xlsx")
saveRDS(journal.texts.full, "House_journals.RDS")

# senate ----
rm(list=ls())
xfun::pkg_attach2(c("RSelenium","dplyr","writexl"))

# in terminal: cmd+alt+enter (requires selenium driver in the folder)
cd ~/downloads/kbills
java -jar selenium-server-standalone-3.9.1.jar -port 4446 # choose an open port

# in r: cmd+enter
remDr <- remoteDriver(
  remoteServerAddr = "localhost",
  port = 4446L, # match to the port above
  browserName = "safari" # change to chrome if prefer (requires chromedriver in the same folder)
)

# open a browser window and navigate to the relevant page
remDr$open()
remDr$navigate("http://memory.loc.gov/ammem/amlaw/lwsjlink.html")

remDr$setWindowSize(width = 1200, height = 10000)

# identify congressional sessions
test <- remDr$findElements(using = "partial link", value = "Session")
test[[1]]$getElementAttribute(attrName = "href")

sessions <- data.frame(session = rep(NA, length(test)))
sessions$url <- NA
for(i in 1:length(test)){
  sessions[i,1] <- test[[i]]$getElementText()
  sessions[i,2] <- test[[i]]$getElementAttribute(attrName = "href")
  print(i)
}

mydates <- read_html("http://memory.loc.gov/ammem/amlaw/lwsjlink.html")
mydates <- html_nodes(mydates, "td")
mydates <- html_text(mydates)
mydates <- strsplit(mydates, "Session") %>% 
  unlist()
mydates <- data.frame(orig = mydates)
mydates$cong <- 0
mydates$cong[grepl("\n[0-9]",mydates$orig)] <- 1
mydates <- mydates[c(51:nrow(mydates)),]
mydates$cong <- cumsum(mydates$cong)
mydates$drop <- 0
mydates$drop[grepl("\n[0-9]",mydates$orig)] <- 1
mydates <- filter(mydates, drop==0)

sessions$congress <- mydates$cong
sessions$journal.url <- NA

for(i in 1:nrow(sessions)){
  rm(x)
  remDr$navigate(sessions$url[i])
  remDr$setTimeout(type = "page load",milliseconds = 20000)
  x <- remDr$findElement(using = "link", value = "NAVIGATOR")
  x <- x$getElementAttribute(attrName = "href")
  sessions$journal.url[i] <- x[[1]]
  print(i)
}

# identify journal links
jlinks <- unique(sessions$journal.url)

journals <- list()
for(i in 1:length(jlinks)){
  rm(x,temp)
  remDr$navigate(jlinks[i])
  remDr$setTimeout(type = "page load",milliseconds = 20000)
  x <- remDr$findElements(using = "partial link", value = "DAY")
  temp <- data.frame(day = rep(NA, length(x)), url = rep(NA, length(x)))
  for(j in 1:length(x)){
    temp[j,1] <- x[[j]]$getElementText()
    temp[j,2] <- x[[j]]$getElementAttribute(attrName = "href")
    print(paste(i,":",j))
  }
  journals[[i]] <- temp
  print("==================")
  print(i)
  print("==================")
}

journals.df <- plyr::ldply(journals)
journals.df$id <- c(1:nrow(journals.df))
saveRDS(journals.df, "journals_senate.RDS")

# download texts
journal.texts <- list()
for(i in 1:nrow(journals.df)){
  x <- read_html(journals.df$url[i])
  y <- html_nodes(x, "p") %>% 
    html_text()
  y <- grep("^A Century of Lawmaking|^Senate Journal|^Page [0-9]|previous section|next section|navigator",y,value = T, invert = T,ignore.case = T)
  y <- y[y !=""]
  journal.texts[[i]] <- data.frame(id = rep(journals.df$id[i],length(y)),
                                   text = y)
  print(i)
  Sys.sleep(.5)
}
saveRDS(journal.texts, "journaltexts_senate.RDS")
journal.texts.df <- plyr::ldply(journal.texts)
journal.texts.df <- journal.texts.df %>% 
  group_by(id) %>% 
  mutate(paragraph = 1) %>% 
  mutate(paragraph = cumsum(paragraph))
journal.texts.df$committee <- 0
journal.texts.df$committee[grepl("committee",journal.texts.df$text,ignore.case = T)] <- 1

#journals.df$day <- gsub("Februry","February",journals.df$day)
journals.df$day <- gsub(" ?evening ?","",journals.df$day, ignore.case = T)
journals.df$day <- gsub("^ *","",journals.df$day, ignore.case = T)
journals.df$date <- NA
journals.df$date <- gsub("^[a-z]*,|^[a-z]*,?\\.? |^[a-z]*,|^[a-z]*; ?","",journals.df$day, ignore.case = T)
journals.df$date <- gsub("\\.","",journals.df$date)
journals.df$date <- gsub("\\.","",journals.df$date)
journals.df$date <- gsub("d,|d\\.|th,|st,|th\\.|th;","",journals.df$date, ignore.case = T)
journals.df$date <- gsub("th "," ",journals.df$date, ignore.case = T)
journals.df$date <- gsub(",","",journals.df$date)
journals.df$date <- gsub("^ +| +$","",journals.df$date)
journals.df$date <- as.Date(journals.df$date, "%B %d %Y")
temp <- filter(journals.df, is.na(date))
temp$date <- as.Date(c("1792-05-08","1793-02-20","1793-03-02",
                       "1797-03-04","1801-03-04","1803-03-03",
                       "1804-11-30","1806-04-21","1809-03-04",
                       "1817-03-04","1819-01-13","1819-01-22",
                       "1829-03-04","1848-02-23","1850-01-16",
                       "1852-02-12","1855-03-03","1855-02-28",
                       "1855-02-28","1855-03-03","1855-03-03",
                       "1855-03-03","1868-06-05"))
journals.df <- filter(journals.df, !is.na(date)) %>% 
  bind_rows(temp) %>% 
  arrange(id)

fullsessions <- sessions
fullsessions$start <- gsub("^.*: *|to .*$","",fullsessions$session, ignore.case = T)
fullsessions$start <- as.Date(fullsessions$start, "%B %d, %Y")
fullsessions$end <- gsub("^.*to ","",fullsessions$session, ignore.case = T)
fullsessions$end <- as.Date(fullsessions$end, "%B %d, %Y")
fullsessions$end[is.na(fullsessions$end)] <- fullsessions$start[is.na(fullsessions$end)]
fullsessions <- fullsessions %>% 
  group_by(congress) %>% 
  mutate(Session = 1) %>% 
  mutate(Session = cumsum(Session))
fullsessions <- select(fullsessions, congress, Session, start, end) %>% 
  rename("session" = "Session")

fullsessions.l <- list()
for(i in 1:nrow(fullsessions)){
  fulldates <- seq(fullsessions$start[i],fullsessions$end[i],1)
  fullsessions.l[[i]] <- data.frame(congress = rep(fullsessions$congress[i], length(fulldates)),
                                    session = rep(fullsessions$session[i], length(fulldates)),
                                    date = fulldates)
  print(i)
}
fullsessions.df <- plyr::ldply(fullsessions.l)

journal.texts.df <- select(journal.texts.df, id, paragraph, text, committee)

journal.texts.full <- left_join(journals.df,fullsessions.df) %>% 
  select(-day) %>% 
  left_join(journal.texts.df) %>% 
  mutate(Major = NA, Minor = NA) %>% 
  unique()

write_xlsx(journal.texts.full, "Senate_journals.xlsx")
saveRDS(journal.texts.full, "Senate_journals.RDS")

