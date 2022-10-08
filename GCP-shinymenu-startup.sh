#!/bin/bash

##########################################################################
#DEPLOYMENT SCRIPT FOR SHINY MENU APPS ON GCP                            #
#CREATES VM BASED ON MACHINE IMAGE AND LOADS SPECIFIC INFO FOR VENUE     #
#VERSION 1                                                               #
#CREATED 20220918                                                        #
#AUTHOR M V SALISBURY                                                    #
##########################################################################

#CREATE A STATIC IP ADDRESS

gcloud compute addresses create venuename-ip \
    --region=europe-west1

statip=$(gcloud compute addresses describe venuename-ip --region=europe-west1 --format="get(address)")

#CREATE A VM FROM THE SHINY MENU BASE IMAGE

gcloud beta compute instances create venuename-shinymenu-machine \
--project=shinymenu-test-01 \
--zone=europe-west1-b \
--machine-type=e2-micro \
--address=$statip \
--metadata=^,@^startup-script=sudo\ R\ -e\ \"library\(shinymanager\)\;\ credentials\ \<-\ data.frame\(user\ =\ c\(\'venuename\',\ \'matt\'\),\ password\ =\ c\(\'venuepassword\',\ \'stokeHaveWonIt31\?\'\),\ admin\ =\ c\(FALSE,\ TRUE\),\ stringsAsFactors\ =\ FALSE\)\;create_db\(credentials_data\ =\ credentials,\ sqlite_path\ =\ \'c:/shinymenu/database.sqlite\',\ passphrase\ =\ \'bananaVacuum291\?\'\)\"$'\n'sudo\ mysql\ -e\ \"CREATE\ USER\ \'sqluid\'@\'localhost\'\ IDENTIFIED\ BY\ \'sqlpwd\'\;GRANT\ ALL\ PRIVILEGES\ ON\ \*.\*\ TO\ \'sqluid\'@\'localhost\'\ WITH\ GRANT\ OPTION\;FLUSH\\\ PRIVILEGES\;\"
#--metadata=startup-script=sudo\ R\ -e\ \"library\(shinymanager\)\;\ credentials\ \<-\ data.frame\(user\ =\ c\(\'venuename\',\ \'matt\'\),\ password\ =\ c\(\'venuepassword\',\ \'stokeHaveWonIt31\?\'\),\ admin\ =\ c\(FALSE,\ TRUE\),\ stringsAsFactors\ =\ FALSE\)\;create_db\(credentials_data\ =\ credentials,\ sqlite_path\ =\ \'home/shiny/database.sqlite\',\ passphrase\ =\ \'bananaVacuum291\?\'\)\"$'\n'sudo\ mysql\ -e\ \"CREATE\ USER\ \'sqluid\'@\'localhost\'\ IDENTIFIED\ BY\ \'sqlpwd\'\;GRANT\ ALL\ PRIVILEGES\ ON\ \*.\*\ TO\ \'sqluid\'@\'localhost\'\ WITH\ GRANT\ OPTION\;FLUSH\\\ PRIVILEGES\;\" \
--maintenance-policy=MIGRATE \
--provisioning-model=STANDARD \
--service-account=shinymenu-user-sa-001@shinymenu-test-01.iam.gserviceaccount.com \
--scopes=https://www.googleapis.com/auth/cloud-platform \
--min-cpu-platform=Automatic \
--tags=http-server,https-server \
--no-shielded-secure-boot \
--shielded-vtpm \
--shielded-integrity-monitoring \
--reservation-affinity=any \
--source-machine-image=shinymenu-base-machine-image-001

wait
sleep 60

#COPY ACROSS THE venueinfo.R FILE

gcloud compute scp /home/shiny/OrderApp/venueinfo-venuename.R serviceAccount@venuename-shinymenu-machine:~/venueinfo.R --zone=europe-west1-b --quiet
gcloud compute ssh serviceAccount@venuename-shinymenu-machine --zone=europe-west1-b --quiet --command "sudo mv -f ~/venueinfo.R /home/shiny/OrderApp/"

#COPY ACROSS THE priceList FILE

gcloud compute scp /home/shiny/OrderApp/price_list-venuename.csv serviceAccount@venuename-shinymenu-machine:~/price_list.csv --zone=europe-west1-b --quiet
gcloud compute ssh serviceAccount@venuename-shinymenu-machine --zone=europe-west1-b --quiet --command "sudo cp ~/price_list.csv /home/shiny/PubEnd/"
gcloud compute ssh serviceAccount@venuename-shinymenu-machine --zone=europe-west1-b --quiet --command "sudo mv -f ~/price_list.csv /home/shiny/OrderApp/"

#CREATE DNS

gcloud dns --project=shinymenu-test-01 record-sets remove venuename.shinymenu.online. \
 --type="A" \
 --zone="shinymenu-zone" \
 --rrdatas=$statip \
 --ttl="300"

gcloud dns --project=shinymenu-test-01 record-sets create venuename.shinymenu.online. \
 --type="A" \
 --zone="shinymenu-zone" \
 --rrdatas=$statip \
 --ttl="300"
 
# #COPY ACROSS HTTP CONFIG FILE
 
gcloud compute scp /home/shiny/shinymenu-registration-app/http-venuename-shiny.conf serviceAccount@venuename-shinymenu-machine:~/shiny.conf --zone=europe-west1-b --quiet
gcloud compute ssh serviceAccount@venuename-shinymenu-machine --zone=europe-west1-b --quiet --command "sudo mv -f ~/shiny.conf /etc/nginx/sites-available/shiny.conf"
gcloud compute ssh serviceAccount@venuename-shinymenu-machine --zone=europe-west1-b --quiet --command "cd /etc/nginx/sites-enabled && sudo ln -s ../sites-available/shiny.conf"
gcloud compute ssh serviceAccount@venuename-shinymenu-machine --zone=europe-west1-b --quiet --command "sudo systemctl restart nginx"
 
# #RUN CERTBOT
 
gcloud compute ssh serviceAccount@venuename-shinymenu-machine --zone=europe-west1-b --quiet --command "sudo certbot certonly --nginx -d venuename.shinymenu.online --non-interactive --agree-tos --email matty8salisbury@gmail.com"
 
# #COPY ACROSS HTTPS CONFIG FILE
 
gcloud compute scp /home/shiny/shinymenu-registration-app/https-venuename-shiny.conf serviceAccount@venuename-shinymenu-machine:~/shiny.conf --zone=europe-west1-b --quiet
gcloud compute ssh serviceAccount@venuename-shinymenu-machine --zone=europe-west1-b --quiet --command "sudo mv -f ~/shiny.conf /etc/nginx/sites-available/shiny.conf"
gcloud compute ssh serviceAccount@venuename-shinymenu-machine --zone=europe-west1-b --quiet --command "sudo systemctl restart nginx"


# Init DB using credentials data
#sudo R -e "library(shinymanager); credentials <- data.frame(user = c('venuename', 'matt'), password = c('venuepassword', 'stokeHaveWonIt31?'), admin = c(FALSE, TRUE), stringsAsFactors = FALSE);create_db(credentials_data = credentials, sqlite_path = 'c:/shinymenu/database.sqlite', passphrase = 'bananaVacuum291?')"
#sudo mysql -e "CREATE USER 'sqluid'@'localhost' IDENTIFIED BY 'sqlpwd';GRANT ALL PRIVILEGES ON *.* TO 'sqluid'@'localhost' WITH GRANT OPTION;FLUSH\ PRIVILEGES;"

