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
             
             #Display Name
             textInput(inputId = "displayName", label = HTML("Business Name <br> (as you would like it displayed in the app - 40 characters or less)")),
             
             #Postcode
             textInput(inputId = "postcode", label = "Business Postcode"),
             
             #Password
             textInput(inputId = "password", label = "Business Password"),
             
             #data file
             fileInput(inputId = "priceListfile", label = "Upload Pricelist (csv file)", accept = ".csv"),

             #Submit button
             actionButton(inputId = "registerButton", label = "Submit Registration")
             
    ),
    tabPanel(title = "Review & Confirm", value = "panel2",
             
             helpText("Nearly finished, just one more thing to do."),
             helpText("Please review the below information, scroll to the bottom of the page and hit the Confirm & Proceed button if all the information is correct"),
             
             textOutput(outputId = "displayNameCheck"),
             textOutput(outputId = "postcodeCheck"),
             #textOutput(outputId = "password"),
             tableOutput(outputId = "priceList"),
             
             
             #Confirm Submission button
             actionButton(inputId = "backButton", label = "Back"),
             
             #Confirm Submission button
             actionButton(inputId = "confirmButton", label = "Confirm & Proceed")
    ),
    tabPanel(title = "Registration Complete", value = "panel3",
             
             helpText("Thank you for registering with shiny menu!"),
             helpText("Your site will be available shortly at the address below.  In some cases, it can take up to 24 hours due to internet propagation."),
             helpText(textOutput(outputId = "venueName"))

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
  
  output$priceList <- renderTable({
    file <- input$priceListfile
    ext <- tools::file_ext(file$datapath)

    req(file)
    validate(need(ext == "csv", "Please upload a csv file"))
    
    priceList <- read.csv(file$datapath, header = T)
    validate(need(names(priceList) == c("Item",	"Price",	"Section",	"Description"), "Please upload a csv file in the format request (i.e. set out with headings of: Item, Price, Section, Description)"))
    
    priceList
  })

  
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
    
    venueName <- gsub("'", "1", gsub(" ", "_", paste0(trimws(input$displayName), " ", trimws(input$postcode))))
    venueDisplayName <- trimws(input$displayName)
    if(nchar(venueDisplayName) > 40) {venueDisplayName <- substring(venueDisplayName, 1, 40)}
    venuePostcode <- trimws(input$postcode)
    venuePassword <- trimws(input$password)
    
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
    
    tx  <- readLines("/home/shiny/OrderApp/venueinfo.R")
    tx  <- gsub(pattern = "Bananaman1s_Bar_PE27_6TN", replace = venueName, x = tx)
    tx  <- gsub(pattern = "Bananaman's Bar", replace = venueDisplayName, x = tx)
    tx  <- gsub(pattern = "mypassword", replace = venuePassword, x = tx)
    tx  <- gsub(pattern = "replaceThisUsername", replace = venueName, x = tx)
    tx  <- gsub(pattern = "replaceThisPassword", replace = replacementMySqlPassword, x = tx)
    writeLines(tx, con=paste("/home/shiny/OrderApp/venueinfo-", gsub("_", "-", tolower(venueName)), ".R", sep=""))
    
    #REPLACE venuename IN SHELL SCRIPT TO CREATE GCP RESOURCES
    
    tx2  <- readLines("/home/shiny/OrderApp/shinymenu-startup.sh")
    tx2  <- gsub(pattern = "venuename", replace = gsub("_", "-", tolower(venueName)), x = tx2)
    writeLines(tx2, con=paste("/home/shiny/OrderApp/shinymenu-startup.sh"))
    
    #SAVE PRICE LIST TO CORRECT LOCATION
    
    output$priceList <- renderTable({
      file <- input$priceListfile
      priceList <- read.csv(file$datapath, header = T)
      write.csv(x=priceList, file=paste("/home/shiny/OrderApp/priceList-", gsub("_", "-", tolower(venueName)), ".csv", sep=""))
    })
    
    #PREPARE CONFIRMATION OUTPUT TO USER
    
    output$venueName = renderText(
      paste0("https://" 
             ,gsub("'", "1"
                   , gsub(" ", "_", paste0(trimws(input$displayName), " ", trimws(input$postcode)))
                   )
             , ".shinymenu.online"
             )
      )
    
  })
  
}


shinyApp(ui = shinyUI, server = shinyServer)



