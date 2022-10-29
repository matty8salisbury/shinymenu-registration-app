#APP TO ALLOW AUTOMATED SET UP OF SHINYMENU APP SUITE inc orderApp and PubEnd

#1. Set up: Install libraries and set working drive ----

#install libraries for Shiny
library("shiny")
library("shinyWidgets")

#3. Shiny UI function

shinyUI <- fluidPage(
  
  #theme = "bootstrap.css",
  setBackgroundColor(
    color = "GhostWhite"
  ),
  
  titlePanel("ShinyMenu Ordering App - Registration"),
  
  tabsetPanel(id = "inTabset",
              
    tabPanel(title = "Register", value = "panel1",
             #Provide Display Name, Postcode, Password
             
             #Zone
             uiOutput(outputId = "SelectedZone"),
             
             #Display Name
             textInput(inputId = "displayName", label = HTML("Business Name <br> <i>(as you would like it displayed in the app - 40 characters or less)")),
             
             #Postcode
             textInput(inputId = "postcode", label = "Business Postcode"),
             
             #Password
             textInput(inputId = "password", label = "Business Password"),
             
             #data file
             fileInput(inputId = "priceListfile", label = "Upload Pricelist (csv file)", accept = ".csv"),

             #Select time used
             uiOutput(outputId = "selectedShift"),
             
             #Submit button
             actionButton(inputId = "registerButton", label = "Submit Registration")
             
    ),
    tabPanel(title = "Review & Confirm", value = "panel2",
             
             helpText("Nearly finished, just one more thing to do."),
             helpText("Please review the below information, scroll to the bottom of the page and hit the Confirm & Proceed button if all the information is correct"),
             
             textOutput(outputId = "displayNameCheck"),
             textOutput(outputId = "postcodeCheck"),
             textOutput(outputId = "shiftCheck"),
             #textOutput(outputId = "password"),
             tableOutput(outputId = "priceList"),
             
             #Confirm Submission button
             actionButton(inputId = "backButton", label = "Back"),
             
             #Confirm Submission button
             actionButton(inputId = "confirmButton", label = "Confirm & Proceed"),
             
             helpText("After clicking 'Confirm & Proceed', please wait.  This can take around 5 minutes and you MUST remain connected to the internet for all of that time."),
             helpText("You will be redirected to a completion screen once the process is complete."),
    ),
    tabPanel(title = "Registration Complete", value = "panel3",
             
             helpText("Thank you for registering with shiny menu!"),
             helpText("Your site should now be available at the address below.  Please be sure to click the first link (Venue End Link) and LOG IN before clciking the Customer App (the second won't work otherwise)."),
             helpText("It is strongly recommended that you read the user guide and carefully consider how to use the app suite in your business."),
             #helpText(textOutput(outputId = "pubEndAddress")),
             #helpText(textOutput(outputId = "orderAppAddress"))
             helpText(textOutput(outputId = "userName")),
             uiOutput("pubEndLink"),
             uiOutput("orderAppLink")

    )
  )
)



#2. Shiny Server function to record information for a single order ----

shinyServer <- function(input, output, session) {
  
  showTab(inputId = "inTabset", target = "panel1")
  hideTab(inputId = "inTabset", target = "panel2")
  hideTab(inputId = "inTabset", target = "panel3")
  
  output$displayNameCheck = renderText(paste0("Business Name: ",input$displayName))
  output$postcodeCheck = renderText(paste0("Postcode: ",input$postcode))
  output$passwordCheck = renderText(paste0("Password: ",input$password))
  output$shiftCheck = renderText(paste0("Time On / Cost per month: ",input$shift))
  output$userName = renderText(paste0("User Name: ", gsub("'", "1", gsub(" ", "_", paste0(trimws(input$displayName), " ", trimws(input$postcode))))))
  
  zoneListNames <- read.csv(file = "gcp_zones.csv", header = T)
  zoneList <- as.list(zoneListNames$gcp_zone_name)
  
  output$SelectedZone <- renderUI({selectInput(inputId = 'zoneName',
                                              label = div(HTML("International Zone <br> <i>for UK select Europe/London"), style="margin-top:10px"),
                                              choices = zoneList)})
  
  
  output$priceList <- renderTable({
    file <- input$priceListfile
    ext <- tools::file_ext(file$datapath)

    req(file)
    validate(need(ext == "csv", "Please upload a csv file"))
    
    priceList <- read.csv(file$datapath, header = T)
    validate(need(names(priceList) == c("Item",	"Price",	"Section",	"Description"), "Please upload a csv file in the format request (i.e. set out with headings of: Item, Price, Section, Description)"))
    
    priceList
  })
  
  output$selectedShift <- renderUI({selectInput(inputId = 'shift',
                                               label = HTML("Time On: <br> 
                                               <i>Early (6am-6pm) <br>
                                               <i>Late (12pm-12am) <br> 
                                               <i>Always"),
                                               choices = c("Early (£10 per month)", "Late (£10 per month)", "Always (£18 per month)"))})

  
  observeEvent(input$registerButton, {
    
    hideTab(inputId = "inTabset", target = "panel1")
    showTab(inputId = "inTabset", target = "panel2")
    
  })
  
  observeEvent(input$backButton, {
    
    showTab(inputId = "inTabset", target = "panel1")
    hideTab(inputId = "inTabset", target = "panel2")
  })
  
  observeEvent(input$confirmButton, {
    
    hideTab(inputId = "inTabset", target = "panel1")
    hideTab(inputId = "inTabset", target = "panel2")
    showTab(inputId = "inTabset", target = "panel3")
    
    #CREATE INFORMATION TO REPLACE IN TEMPLATE FILES
    
    zoneName <- input$zoneName
    zone <- paste0(zoneListNames$gcp_zone[zoneListNames$gcp_zone_name == zoneName], "-a")
    shift <- input$shift
    venueName <- gsub("'", "1", gsub(" ", "_", paste0(trimws(input$displayName), " ", trimws(input$postcode))))
    venueDisplayName <- trimws(input$displayName)
    if(nchar(venueDisplayName) > 40) {venueDisplayName <- substring(venueDisplayName, 1, 40)}
    venuePostcode <- trimws(input$postcode)
    venuePassword <- trimws(input$password)
    sqlVenuePassword <- paste0("p",sprintf("%08d", round(runif(1)*1e8,0)))
    
    passwords <- function(nl = 10, npw = 1, help = FALSE) {
      if (help) return("gives npw passwords with nl characters each")
      if (nl < 8) nl <- 8
      spch <- c("!", "#", "$", "%", "&", "(", ")", "*", "+", "-", ".", "/", ":", ";", "<", "=", ">", "?", "@", "[", "]", "^", "_", "{", "|", "}", "~")
      out <- c()
      for(i in 1:npw) {
        pw <- c(sample(letters, 2), sample(LETTERS, 2), sample(0:9, 2), sample(spch, 2))
        pw <- c(pw, sample(c(letters, LETTERS, 0:9, spch), nl-8, replace = TRUE))
        pw <- sample(pw)
        for(k in 1:nl) {out[i] <- paste(out[i], pw[k], sep = "")}
      }
      out
    }
    replacementMySqlPassword <- passwords()[1]

    #CREATE ORDERAPP DIRECTORY SPECIFIC TO THE VENUE
    #dir.create(paste("~//OrderApp_", venueName, sep = ""))
    
    #REPLACE INFORMATION IN VENUE TEMPLATE
    
    system2(command="cp", args = c("/home/shiny/OrderApp/venueinfo.R", paste0("/home/shiny/OrderApp/venueinfo-",gsub("_", "-", tolower(venueName)),".R")), stdout = TRUE)
    system2(command="sed", args = c("-i", "-e", paste0("s/Bananaman1s_Bar_PE27_6TN/", venueName, "/g"), paste0("/home/shiny/OrderApp/venueinfo-", gsub("_", "-", tolower(venueName)), ".R")), stdout = TRUE)
    system2(command="sed", args = c("-i", "-e", paste0("s/",'"Bananaman',"'s ",'Bar"/','"', venueDisplayName, '"/g'), paste0("/home/shiny/OrderApp/venueinfo-", gsub("_", "-", tolower(venueName)), ".R")), stdout = TRUE)
    #system2(command="sed", args = c("-i", "-e", paste0("s/mypassword/", venuePassword, "/g"), paste0("/home/shiny/OrderApp/venueinfo-", gsub("_", "-", tolower(venueName)), ".R")), stdout = TRUE)
    system2(command="sed", args = c("-i", "-e", paste0("s/replaceThisUsername/", venueName, "/g"), paste0("/home/shiny/OrderApp/venueinfo-", gsub("_", "-", tolower(venueName)), ".R")), stdout = TRUE)
    system2(command="sed", args = c("-i", "-e", paste0("s/replaceThisPassword/", sqlVenuePassword, "/g"), paste0("/home/shiny/OrderApp/venueinfo-", gsub("_", "-", tolower(venueName)), ".R")), stdout = TRUE)

    #REPLACE venuename IN SHELL SCRIPT TO CREATE GCP RESOURCES
    
    system2(command="cp", args = c("/home/shiny/shinymenu-registration-app/GCP-shinymenu-startup.sh", paste0("/home/shiny/shinymenu-registration-app/GCP-shinymenu-startup-",gsub("_", "-", tolower(venueName)),".sh")), stdout = TRUE)
    system2(command="cp", args = c("/home/shiny/shinymenu-registration-app/http-venuename-shiny.conf", paste0("/home/shiny/shinymenu-registration-app/http-",gsub("_", "-", tolower(venueName)),"-shiny.conf")), stdout = TRUE)
    system2(command="cp", args = c("/home/shiny/shinymenu-registration-app/https-venuename-shiny.conf", paste0("/home/shiny/shinymenu-registration-app/https-",gsub("_", "-", tolower(venueName)),"-shiny.conf")), stdout = TRUE)
    
    system2(
      command="sed", 
      args = c(
      "-i",
      "-e", 
      paste0("s/venuename/", gsub("_", "-", tolower(venueName)), "/g"),
      paste0("/home/shiny/shinymenu-registration-app/GCP-shinymenu-startup-",gsub("_", "-", tolower(venueName)),".sh")
      ), 
      stdout = TRUE
      )
    
    system2(
      command="sed", 
      args = c(
        "-i",
        "-e", 
        paste0("s/Venue_Name/", venueName, "/g"),
        paste0("/home/shiny/shinymenu-registration-app/GCP-shinymenu-startup-",gsub("_", "-", tolower(venueName)),".sh")
      ), 
      stdout = TRUE
    )
    
    system2(
      command="sed", 
      args = c(
        "-i",
        "-e", 
        paste0("s/sqlusername/", venueName, "/g"),
        paste0("/home/shiny/shinymenu-registration-app/GCP-shinymenu-startup-",gsub("_", "-", tolower(venueName)),".sh")
      ), 
      stdout = TRUE
    )
    
    system2(
      command="sed", 
      args = c(
        "-i",
        "-e", 
        paste0("s/sqlpassword/", sqlVenuePassword, "/g"),
        paste0("/home/shiny/shinymenu-registration-app/GCP-shinymenu-startup-",gsub("_", "-", tolower(venueName)),".sh")
      ), 
      stdout = TRUE
    )
    
    system2(
      command="sed", 
      args = c(
        "-i",
        "-e", 
        paste0("s/venuepassword/", venuePassword, "/g"),
        paste0("/home/shiny/shinymenu-registration-app/GCP-shinymenu-startup-",gsub("_", "-", tolower(venueName)),".sh")
      ), 
      stdout = TRUE
    )
    
    system2(
      command="sed", 
      args = c(
        "-i",
        "-e", 
        paste0("s/venuename/", gsub("_", "-", tolower(venueName)), "/g"),
        paste0("/home/shiny/shinymenu-registration-app/http-",gsub("_", "-", tolower(venueName)),"-shiny.conf")
      ), 
      stdout = TRUE
    )
    
    system2(
      command="sed", 
      args = c(
        "-i",
        "-e", 
        paste0("s/venuename/", gsub("_", "-", tolower(venueName)), "/g"),
        paste0("/home/shiny/shinymenu-registration-app/https-",gsub("_", "-", tolower(venueName)),"-shiny.conf")
      ), 
      stdout = TRUE
    )
    
    #REPLACE INFORMATION IN START AND STOP FILES USED BY SYSTEMD TIMER
    
    if(shift == "Early (£10 per month)"){
      scheduleStartFile <- "/home/shiny/startUps6.sh"
      scheduleStopFile <- "/home/shiny/shutDowns6.sh"
    }
      
    if(shift == "Late (£10 per month)") {
      scheduleStartFile <- "/home/shiny/startUps12.sh"
      scheduleStopFile <- "/home/shiny/shutDowns12.sh"
    }
    
    if(shift != "Always (£18 per month") {
      #start file
      txShift <- readLines(con = scheduleStartFile)
      if(length(grep(paste0("#/snap/bin/gcloud compute instances start --zone=",zone), txShift))==1){
        txShift2 <- gsub(paste0("#/snap/bin/gcloud compute instances start --zone=",zone), paste0("/snap/bin/gcloud compute instances start", "\\\\", "\n", tolower(venueName), " \\\\", "\n--zone=", zone), x=txShift)  
      } else{
        txShift2 <- gsub(paste0("--zone=",zone), paste0(tolower(venueName), " \\\\", "\n--zone=", zone), x=txShift)
      }
      #stop file
      txShift <- readLines(con = scheduleStopFile)
      if(length(grep(paste0("#/snap/bin/gcloud compute instances stop --zone=",zone), txShift))==1){
        txShift2 <- gsub(paste0("#/snap/bin/gcloud compute instances stop --zone=",zone), paste0("/snap/bin/gcloud compute instances stop", "\\\\", "\n", tolower(venueName), " \\\\", "\n--zone=", zone), x=txShift)  
      } else{
        txShift2 <- gsub(paste0("--zone=",zone), paste0(tolower(venueName), " \\\\", "\n--zone=", zone), x=txShift)
      }
      writeLines(txShift2, con = scheduleStopFile)
    }

    #PASS SQL REQUIRED VARS
    tx <- readLines(con = paste0("/home/shiny/shinymenu-registration-app/GCP-shinymenu-startup-",gsub("_", "-", tolower(venueName)),".sh"))
    tx2 <- gsub("sqluid", venueName, x=tx)
    tx2 <- gsub("sqlpwd", sqlVenuePassword, x=tx2)
    writeLines(tx2, con = paste0("/home/shiny/shinymenu-registration-app/GCP-shinymenu-startup-",gsub("_", "-", tolower(venueName)),".sh"))

    #SAVE PRICE LIST TO CORRECT LOCATION
    
    output$priceList <- renderTable({
      file <- input$priceListfile
      priceList <- read.csv(file$datapath, header = T)
      write.csv(x=priceList, file=paste("/home/shiny/OrderApp/price_list-", gsub("_", "-", tolower(venueName)), ".csv", sep=""))
    })
    
    #PREPARE CONFIRMATION OUTPUT TO USER
    
    #output$pubEndAddress = renderText(
    #  paste0("https://" 
    #         ,gsub("_", "-", tolower(venueName))
    #         , ".shinymenu.online/PubEnd"
    #         )
    #  )
    
    pubEndUrl <- a("Venue End App", href=paste0("https://" 
                                            ,gsub("_", "-", tolower(venueName))
                                            , ".shinymenu.online/PubEnd")
                   , target="_blank"
                   )
    
    output$pubEndLink <- renderUI({
      tagList("Venue End link. Please Follow this first and Login before clicking the second link:", pubEndUrl)
    })
    
    #output$orderAppAddress = renderText(
    #  paste0("https://" 
    #         ,gsub("_", "-", tolower(venueName))
    #         , ".shinymenu.online/OrderApp"
    #  )
    #)
    
    orderAppUrl <- a("Customer App", href=paste0("https://" 
                                                 ,gsub("_", "-", tolower(venueName))
                                                 , ".shinymenu.online/OrderApp")
                     ,target="_blank"
                     )
    
    output$orderAppLink <- renderUI({
      tagList("Customer App link:", orderAppUrl)
    })
    
    #RUN BASH SHELL SCRIPT TO PROVISION GCP RESOURCES
    
    system2(command = "chmod", args=c("+x", paste0("/home/shiny/shinymenu-registration-app/GCP-shinymenu-startup-",gsub("_", "-", tolower(venueName)),".sh")))
    system2(command = "bash", args=c(paste0("/home/shiny/shinymenu-registration-app/GCP-shinymenu-startup-",gsub("_", "-", tolower(venueName)),".sh")))
    
  })
  
}

shinyApp(ui = shinyUI, server = shinyServer)