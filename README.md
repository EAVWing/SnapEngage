---
title: "SnapEngage Data in R"
author: "Stephen Ewing"
date: "November 15, 2018"
output:
  pdf_document: 
    highlight: zenburn
    toc: yes
    toc_depth: 4
    df_print: tibble
    fig_caption: false
  html_document:
    df_print: tibble
    theme: lumen
    highlight: zenburn
---

```{r setup, include=FALSE}
knitr::opts_chunk$set(echo = TRUE, cache = TRUE, warning = FALSE, message = FALSE, fig.align = "center")
library(jsonlite)  
library(tidyverse) 
library(anytime)   
library(lubridate)
```

## Get the Data

Snap Engage is a enterprise chat platform we use to reach out to customers while they are visiting our website.  I'd like to use the data generated from the service to attribute sales to our CSRs and to analyze the transcripts with NLP techniques.  

Snap Engage offers a Logs API accessible via bash command.  This write up will show the code used to get the logs data into R.

The [developer page](https://developer.snapengage.com/?json#logs-api) gives us the staring point.

They tell us we need to get our API token, organization ID and widget ID from the website's admin page.

With that information we're to construct the following bash command:

`curl "https://www.snapengage.com/api/v2/{orgId}/logs?widgetId={widgetId}&start=2017-04-20&end=2017-04-28" -H "Authorization: api_token"`

I've saved my orgID, widgetID and api_token as system variables using:

`Sys.setenv(seOrg = "code")`

`Sys.setenv(seWidget = "code")`

`Sys.setenv(seAuth = "code")`

Here's how to construct the URL in R.  This call will pull all the chat logs from 01/01/2014 through yesterday.

```{r eval=FALSE}

library(jsonlite)  # To read .json files
library(tidyverse) # <3
library(anytime)   # To convert time stamps to dates
library(lubridate) # To work with dates

# The URL arg broken into pieces
urlPart1  <- '"https://www.snapengage.com/api/v2/'
orgCode   <- Sys.getenv("seOrg") # get this from SE admin
urlPart2  <- "/logs?widgetId="
widgetID  <- Sys.getenv("seWidget") # get this from SE admin
urlPart3  <- "&start="
startDate <- "2014-01-01" # can be any date in this format
urlPart4  <- "&end="
endDate   <- date(now()) - 1 # can be any date (20xx-2DigitMonth-2DigitDay)
urlPart5  <- '" -H "Authorization: '
authCode  <- Sys.getenv("seAuth") # get this from SE admin
urlPart6  <- '"'

# Paste the call together
urlArg <- paste0(urlPart1,
                 orgCode,
                 urlPart2,
                 widgetID,
                 urlPart3,
                 startDate,
                 urlPart4,
                 endDate,
                 urlPart5,
                 authCode,
                 urlPart6)

# Make the first output name
outputFileName <- paste0("ChatLogs-File", 1, ".json")

# Download the first .json file
system2(command = "curl",
        args = urlArg,
        stdout = outputFileName,
        stderr = 'deleteme.json')

# Load the first .json file into R
data <- fromJSON(outputFileName)

# If the request returns more than 100 records they will provide a link to
# the next set of records.  Here I'll loop through gathering the files until
# the isn't another file listed to get.

i <- 2

while(str_length(data[["linkToNextSetOfResults"]]) > 1){
    outputFileName <- paste0("ChatLogs-File",
                             i,
                             ".json")
    urlArg = paste0('"',
                    data[["linkToNextSetOfResults"]],
                    urlPart5,
                    authCode,
                    urlPart6)
    system2(command = "curl",
            args = urlArg,
            stdout = outputFileName,
            stderr = 'deleteme.json')
    data <- fromJSON(outputFileName)
    i <- i + 1
}
```

## Merge the Data

With all the files downloaded it's time to put them together into a usable data set.  Each file is saved as a list of two elements, the cases and the link to the next set of records.  We want to collect all the cases into one big data frame.

I've collected 1,746 files of records.  I'll loop through them appending to a new data frame.

### Transcripts

This list will have all the transcripts.  I'm more interested in the meta data first which I can eaisly push up into Domo.  These I'll save for a NLP project.

```{r, eval=FALSE}
transcripts <- compact(fromJSON("ChatLogs-File1.json")[["cases"]][["transcripts"]])

i <- 2

for(i in 2:1746){
    dataNew <- compact(fromJSON(paste0("ChatLogs-File", i, ".json"))[["cases"]][["transcripts"]])
    transcripts <- append(transcripts, dataNew)
    i = i + 1
}
```

### Metadata

I'll drop the columns that have the nested lists and aggrigate the metadata.  The first time I tried to aggrigate the metadata I got to file 82 and got an error.  Apparently some of the logs are for chats recieved when nobody was available to take them.  Those log files are missing the chat_agent_id and chat_agent_alias fields. Before I run the loop to consolidate the metadata I'll make a loop to figure out how many variables each file has.

```{r}
data <- fromJSON("ChatLogs-File1.json")[[1]]

numberOfVariables <- length(names(data))

i <- 2

for(i in 2:1746){
    numberOfVariables <- append(numberOfVariables,
                          length(names(fromJSON(paste0("ChatLogs-File",
                                                i,
                                                ".json"))[[1]])))
    i <- i + 1
}

table(numberOfVariables)
```

We can see that the number of variables varries by file from a low of 29 to a high of 34.  It looks like file 600 is the first file with 34 variables.  I'm droping the 3 list fields, the new one is javascript_variables.

```{r}
data600 <- fromJSON("ChatLogs-File600.json")[[1]] %>%
    select(-transcripts, -requester_details, -javascript_variables) 

names600 <- names(data600)

names600
```

Since mutating all the files that don't have 34 variables sounds like a lot of work and because I don't want to manipulate the original files I'll make a data frame with the 31 variables we want.  I'll make the fields all have a length of the number of files x 100 records per file, so, `1746*100=174,600`.

```{r, eval=FALSE}
bigDF <- data.frame(id = character(length = 174600),
                    url = character(length = 174600),
                    type = character(length = 174600),
                    requested_by = character(length = 174600),
                    description = character(length = 174600),
                    created_at_date = numeric(length = 174600),
                    created_at_seconds = integer(length = 174600),
                    created_at_milliseconds = integer(length = 174600),
                    proactive_chat = logical(length = 174600),
                    page_url = character(length = 174600),
                    referrer_url = character(length = 174600),
                    entry_url = character(length = 174600),
                    ip_address = character(length = 174600),
                    user_agent = character(length = 174600),
                    browser = character(length = 174600),
                    os = character(length = 174600),
                    country_code = character(length = 174600),
                    country = character(length = 174600),
                    region = character(length = 174600),
                    city = character(length = 174600),
                    latitude = numeric(length = 174600),
                    longitude = numeric(length = 174600),
                    source_id = integer(length = 174600),
                    chat_waittime = integer(length = 174600),
                    chat_duration = integer(length = 174600),
                    chat_agent_id = character(length = 174600),
                    chat_agent_alias = character(length = 174600),
                    language_code = character(length = 174600),
                    destination_url = character(length = 174600),
                    survey_score = integer(length = 174600),
                    survey_comments = character(length = 174600),
                    stringsAsFactors = FALSE)
```

```{r, eval=FALSE}
i <- 1
for(i in 1:1746){ 
    dataNew <- fromJSON(paste0("ChatLogs-File", i, ".json"))[[1]] 
    try(bigDF$id[(((i-1)*100)+1):(((i-1)*100)+dim(dataNew)[1])] <- dataNew$id)
    try(bigDF$url[(((i-1)*100)+1):(((i-1)*100)+dim(dataNew)[1])] <- dataNew$url)
    try(bigDF$type[(((i-1)*100)+1):(((i-1)*100)+dim(dataNew)[1])] <- dataNew$type)
    try(bigDF$requested_by[(((i-1)*100)+1):(((i-1)*100)+dim(dataNew)[1])] <- dataNew$requested_by)
    try(bigDF$description[(((i-1)*100)+1):(((i-1)*100)+dim(dataNew)[1])] <- dataNew$description)
    try(bigDF$created_at_date[(((i-1)*100)+1):(((i-1)*100)+dim(dataNew)[1])] <- dataNew$created_at_date)
    try(bigDF$created_at_seconds[(((i-1)*100)+1):(((i-1)*100)+dim(dataNew)[1])] <- dataNew$created_at_seconds)
    try(bigDF$created_at_milliseconds[(((i-1)*100)+1):(((i-1)*100)+dim(dataNew)[1])] <- dataNew$created_at_milliseconds)
    try(bigDF$proactive_chat[(((i-1)*100)+1):(((i-1)*100)+dim(dataNew)[1])] <- dataNew$proactive_chat)
    try(bigDF$page_url[(((i-1)*100)+1):(((i-1)*100)+dim(dataNew)[1])] <- dataNew$page_url)
    try(bigDF$referrer_url[(((i-1)*100)+1):(((i-1)*100)+dim(dataNew)[1])] <- dataNew$referrer_url)
    try(bigDF$entry_url[(((i-1)*100)+1):(((i-1)*100)+dim(dataNew)[1])] <- dataNew$entry_url)
    try(bigDF$ip_address[(((i-1)*100)+1):(((i-1)*100)+dim(dataNew)[1])] <- dataNew$ip_address)
    try(bigDF$user_agent[(((i-1)*100)+1):(((i-1)*100)+dim(dataNew)[1])] <- dataNew$user_agent)
    try(bigDF$browser[(((i-1)*100)+1):(((i-1)*100)+dim(dataNew)[1])] <- dataNew$browser)
    try(bigDF$os[(((i-1)*100)+1):(((i-1)*100)+dim(dataNew)[1])] <- dataNew$os)
    try(bigDF$country_code[(((i-1)*100)+1):(((i-1)*100)+dim(dataNew)[1])] <- dataNew$country_code)
    try(bigDF$country[(((i-1)*100)+1):(((i-1)*100)+dim(dataNew)[1])] <- dataNew$country)
    try(bigDF$region[(((i-1)*100)+1):(((i-1)*100)+dim(dataNew)[1])] <- dataNew$region)
    try(bigDF$city[(((i-1)*100)+1):(((i-1)*100)+dim(dataNew)[1])] <- dataNew$city)
    try(bigDF$latitude[(((i-1)*100)+1):(((i-1)*100)+dim(dataNew)[1])] <- dataNew$latitude)
    try(bigDF$longitude[(((i-1)*100)+1):(((i-1)*100)+dim(dataNew)[1])] <- dataNew$longitude)
    try(bigDF$source_id[(((i-1)*100)+1):(((i-1)*100)+dim(dataNew)[1])] <- dataNew$source_id)
    try(bigDF$chat_waittime[(((i-1)*100)+1):(((i-1)*100)+dim(dataNew)[1])] <- dataNew$chat_waittime)
    try(bigDF$chat_duration[(((i-1)*100)+1):(((i-1)*100)+dim(dataNew)[1])] <- dataNew$chat_duration)
    try(bigDF$chat_agent_id[(((i-1)*100)+1):(((i-1)*100)+dim(dataNew)[1])] <- dataNew$chat_agent_id)
    try(bigDF$chat_agent_alias[(((i-1)*100)+1):(((i-1)*100)+dim(dataNew)[1])] <- dataNew$chat_agent_alias)
    try(bigDF$language_code[(((i-1)*100)+1):(((i-1)*100)+dim(dataNew)[1])] <- dataNew$language_code)
    try(bigDF$destination_url[(((i-1)*100)+1):(((i-1)*100)+dim(dataNew)[1])] <- dataNew$destination_url)
    try(bigDF$survey_score[(((i-1)*100)+1):(((i-1)*100)+dim(dataNew)[1])] <- dataNew$survey_score)
    try(bigDF$survey_comments[(((i-1)*100)+1):(((i-1)*100)+dim(dataNew)[1])] <- dataNew$survey_comments)
    i = i + 1
}

bigDF <- filter(bigDF, created_at_date != 0) %>%
    mutate(created_at_seconds = anytime(bigDF$created_at_seconds)) %>%
    mutate(created_at_date = date(anytime(bigDF$created_at_seconds)))
```

## Push Up to Domo

```{r, eval=FALSE}
DomoR::init(Sys.getenv("domoCustomer"), Sys.getenv("domoToken"))
#DomoR::create(bigDF, "Chat Metadata")
DomoR::replace_ds("8608c2f1-eab3-478b-90df-4571d8c38700", bigDF)
```

## Daily Script

Now that I have all the historical chat metadata pushed up to the cloud server I can write a script to automatically gather and push up the previous day's chat metadata.

```{r, eval=FALSE}
library(jsonlite)  # To read .json files
library(tidyverse) # <3
library(anytime)   # To convert time stamps to dates
library(lubridate) # To work with dates
library(DomoR)     # To push to the cloud

# The URL arg broken into pieces
urlPart1  <- '"https://www.snapengage.com/api/v2/'
orgCode   <- Sys.getenv("seOrg") # get this from SE admin
urlPart2  <- "/logs?widgetId="
widgetID  <- Sys.getenv("seWidget") # get this from SE admin
urlPart3  <- "&start="
startDate <- date(now()) - 1 # yesterday
urlPart4  <- "&end="
endDate   <- date(now()) - 1 # yesterday
urlPart5  <- '" -H "Authorization: '
authCode  <- Sys.getenv("seAuth") # get this from SE admin
urlPart6  <- '"'

# Paste the call together
urlArg <- paste0(urlPart1,
                 orgCode,
                 urlPart2,
                 widgetID,
                 urlPart3,
                 startDate,
                 urlPart4,
                 endDate,
                 urlPart5,
                 authCode,
                 urlPart6)

# Make the first output name
outputFileName <- paste0("ChatLogs-", date(now()) - 1, "-File", 1, ".json")

# Download the first .json file
system2(command = "curl",
        args = urlArg,
        stdout = outputFileName,
        stderr = 'deleteme.json')

# Load the first .json file into R
data <- fromJSON(outputFileName)

# If the request returns more than 100 records they will provide a link to
# the next set of records.  Here I'll loop through gathering the files until
# the isn't another file listed to get.

i <- 2

while(str_length(data[["linkToNextSetOfResults"]]) > 1){
    outputFileName <- paste0("ChatLogs-",
                             date(now()) - 1,
                             "-File",
                             i,
                             ".json")
    urlArg = paste0('"',
                    data[["linkToNextSetOfResults"]],
                    urlPart5,
                    authCode,
                    urlPart6)
    system2(command = "curl",
            args = urlArg,
            stdout = outputFileName,
            stderr = 'deleteme.json')
    data <- fromJSON(outputFileName)
    i <- i + 1
}

bigDF <- data.frame(id = character(length = length(grep(date(now())-1, dir(), value=TRUE)) * 100),
                    url = character(length = length(grep(date(now())-1, dir(), value=TRUE)) * 100),
                    type = character(length = length(grep(date(now())-1, dir(), value=TRUE)) * 100),
                    requested_by = character(length = length(grep(date(now())-1, dir(), value=TRUE)) * 100),
                    description = character(length = length(grep(date(now())-1, dir(), value=TRUE)) * 100),
                    created_at_date = numeric(length = length(grep(date(now())-1, dir(), value=TRUE)) * 100),
                    created_at_seconds = integer(length = length(grep(date(now())-1, dir(), value=TRUE)) * 100),
                    created_at_milliseconds = integer(length = length(grep(date(now())-1, dir(), value=TRUE)) * 100),
                    proactive_chat = logical(length = length(grep(date(now())-1, dir(), value=TRUE)) * 100),
                    page_url = character(length = length(grep(date(now())-1, dir(), value=TRUE)) * 100),
                    referrer_url = character(length = length(grep(date(now())-1, dir(), value=TRUE)) * 100),
                    entry_url = character(length = length(grep(date(now())-1, dir(), value=TRUE)) * 100),
                    ip_address = character(length = length(grep(date(now())-1, dir(), value=TRUE)) * 100),
                    user_agent = character(length = length(grep(date(now())-1, dir(), value=TRUE)) * 100),
                    browser = character(length = length(grep(date(now())-1, dir(), value=TRUE)) * 100),
                    os = character(length = length(grep(date(now())-1, dir(), value=TRUE)) * 100),
                    country_code = character(length = length(grep(date(now())-1, dir(), value=TRUE)) * 100),
                    country = character(length = length(grep(date(now())-1, dir(), value=TRUE)) * 100),
                    region = character(length = length(grep(date(now())-1, dir(), value=TRUE)) * 100),
                    city = character(length = length(grep(date(now())-1, dir(), value=TRUE)) * 100),
                    latitude = numeric(length = length(grep(date(now())-1, dir(), value=TRUE)) * 100),
                    longitude = numeric(length = length(grep(date(now())-1, dir(), value=TRUE)) * 100),
                    source_id = integer(length = length(grep(date(now())-1, dir(), value=TRUE)) * 100),
                    chat_waittime = integer(length = length(grep(date(now())-1, dir(), value=TRUE)) * 100),
                    chat_duration = integer(length = length(grep(date(now())-1, dir(), value=TRUE)) * 100),
                    chat_agent_id = character(length = length(grep(date(now())-1, dir(), value=TRUE)) * 100),
                    chat_agent_alias = character(length = length(grep(date(now())-1, dir(), value=TRUE)) * 100),
                    language_code = character(length = length(grep(date(now())-1, dir(), value=TRUE)) * 100),
                    destination_url = character(length = length(grep(date(now())-1, dir(), value=TRUE)) * 100),
                    survey_score = integer(length = length(grep(date(now())-1, dir(), value=TRUE)) * 100),
                    survey_comments = character(length = length(grep(date(now())-1, dir(), value=TRUE)) * 100),
                    stringsAsFactors = FALSE)

i <- 1
for(i in 1:length(grep(date(now())-1, dir(), value=TRUE))){ 
    dataNew <- fromJSON(paste0("ChatLogs-",
                             date(now()) - 1,
                             "-File",
                             i,
                             ".json"))[[1]] 
    try(bigDF$id[(((i-1)*100)+1):(((i-1)*100)+dim(dataNew)[1])] <- dataNew$id)
    try(bigDF$url[(((i-1)*100)+1):(((i-1)*100)+dim(dataNew)[1])] <- dataNew$url)
    try(bigDF$type[(((i-1)*100)+1):(((i-1)*100)+dim(dataNew)[1])] <- dataNew$type)
    try(bigDF$requested_by[(((i-1)*100)+1):(((i-1)*100)+dim(dataNew)[1])] <- dataNew$requested_by)
    try(bigDF$description[(((i-1)*100)+1):(((i-1)*100)+dim(dataNew)[1])] <- dataNew$description)
    try(bigDF$created_at_date[(((i-1)*100)+1):(((i-1)*100)+dim(dataNew)[1])] <- dataNew$created_at_date)
    try(bigDF$created_at_seconds[(((i-1)*100)+1):(((i-1)*100)+dim(dataNew)[1])] <- dataNew$created_at_seconds)
    try(bigDF$created_at_milliseconds[(((i-1)*100)+1):(((i-1)*100)+dim(dataNew)[1])] <- dataNew$created_at_milliseconds)
    try(bigDF$proactive_chat[(((i-1)*100)+1):(((i-1)*100)+dim(dataNew)[1])] <- dataNew$proactive_chat)
    try(bigDF$page_url[(((i-1)*100)+1):(((i-1)*100)+dim(dataNew)[1])] <- dataNew$page_url)
    try(bigDF$referrer_url[(((i-1)*100)+1):(((i-1)*100)+dim(dataNew)[1])] <- dataNew$referrer_url)
    try(bigDF$entry_url[(((i-1)*100)+1):(((i-1)*100)+dim(dataNew)[1])] <- dataNew$entry_url)
    try(bigDF$ip_address[(((i-1)*100)+1):(((i-1)*100)+dim(dataNew)[1])] <- dataNew$ip_address)
    try(bigDF$user_agent[(((i-1)*100)+1):(((i-1)*100)+dim(dataNew)[1])] <- dataNew$user_agent)
    try(bigDF$browser[(((i-1)*100)+1):(((i-1)*100)+dim(dataNew)[1])] <- dataNew$browser)
    try(bigDF$os[(((i-1)*100)+1):(((i-1)*100)+dim(dataNew)[1])] <- dataNew$os)
    try(bigDF$country_code[(((i-1)*100)+1):(((i-1)*100)+dim(dataNew)[1])] <- dataNew$country_code)
    try(bigDF$country[(((i-1)*100)+1):(((i-1)*100)+dim(dataNew)[1])] <- dataNew$country)
    try(bigDF$region[(((i-1)*100)+1):(((i-1)*100)+dim(dataNew)[1])] <- dataNew$region)
    try(bigDF$city[(((i-1)*100)+1):(((i-1)*100)+dim(dataNew)[1])] <- dataNew$city)
    try(bigDF$latitude[(((i-1)*100)+1):(((i-1)*100)+dim(dataNew)[1])] <- dataNew$latitude)
    try(bigDF$longitude[(((i-1)*100)+1):(((i-1)*100)+dim(dataNew)[1])] <- dataNew$longitude)
    try(bigDF$source_id[(((i-1)*100)+1):(((i-1)*100)+dim(dataNew)[1])] <- dataNew$source_id)
    try(bigDF$chat_waittime[(((i-1)*100)+1):(((i-1)*100)+dim(dataNew)[1])] <- dataNew$chat_waittime)
    try(bigDF$chat_duration[(((i-1)*100)+1):(((i-1)*100)+dim(dataNew)[1])] <- dataNew$chat_duration)
    try(bigDF$chat_agent_id[(((i-1)*100)+1):(((i-1)*100)+dim(dataNew)[1])] <- dataNew$chat_agent_id)
    try(bigDF$chat_agent_alias[(((i-1)*100)+1):(((i-1)*100)+dim(dataNew)[1])] <- dataNew$chat_agent_alias)
    try(bigDF$language_code[(((i-1)*100)+1):(((i-1)*100)+dim(dataNew)[1])] <- dataNew$language_code)
    try(bigDF$destination_url[(((i-1)*100)+1):(((i-1)*100)+dim(dataNew)[1])] <- dataNew$destination_url)
    try(bigDF$survey_score[(((i-1)*100)+1):(((i-1)*100)+dim(dataNew)[1])] <- dataNew$survey_score)
    try(bigDF$survey_comments[(((i-1)*100)+1):(((i-1)*100)+dim(dataNew)[1])] <- dataNew$survey_comments)
    i = i + 1
}

bigDF <- filter(bigDF, created_at_date != 0) 

bigDF <- bigDF %>%
    mutate(created_at_seconds = anytime(bigDF$created_at_seconds)) %>%
    mutate(created_at_date = date(anytime(bigDF$created_at_seconds)))

DomoR::init(Sys.getenv("domoCustomer"), Sys.getenv("domoToken"))
DomoR::replace_ds("8608c2f1-eab3-478b-90df-4571d8c38700", bigDF)
```

