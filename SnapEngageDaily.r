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