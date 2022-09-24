#!/bin/bash

##########################################################################
#DEPLOYMENT SCRIPT FOR SHINY MENU APPS ON GCP                            #
#CREATES VM BASED ON MACHINE IMAGE AND LOADS SPECIFIC INFO FOR VENUE     #
#VERSION 1                                                               #
#CREATED 20220918                                                        #
#AUTHOR M V SALISBURY                                                    #
##########################################################################

#CREATE A VM FROM THE SHINY MENU BASE IMAGE

gcloud beta compute instances create venuename-shinymenu-machine \
--project=shinymenu-test-01 --zone=europe-west1-b --machine-type=e2-micro \
--network-interface=network-tier=PREMIUM,subnet=default \
--metadata=^,@^ssh-keys=matt:ecdsa-sha2-nistp256\ AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBI5rfDe\+gqhHpmqfqxb2nDEHafnE4BPuNNxZqiG5dQZBix1/Wmh/WvaIqh\+4JmYHw1wLZA9UodjOWi0rxngtq0I=\ google-ssh\ \{\"userName\":\"matt@shinymenu.online\",\"expireOn\":\"2022-09-17T18:35:54\+0000\"\}$'\n'matt:ssh-rsa\ AAAAB3NzaC1yc2EAAAADAQABAAABAQCAt3HcxqlbCpVJcpj9v9AZZMBjrEHjEpfCN3nGOS9UcAfAkh0EVqGtwyz9WE0zYout8JY9SrlOYnBNlEa9o5VMnbaTsasEnr7D4L9HVl5gmU80FQF3f/fvc5vDkjSekIpXlTiNycDPhzeVpG1Zar5HPOLNJDwEeGuFXt9YswEsnDvN7coNB5KRW\+t\+s01pNSjvBxzqcmKB0rIw0kDWMkrszh\+PnGkMDk4aC0dnzdvloYdCbh9g7dH\+G7n8Sc\+yy/7XNWL\+PjJt3w7QTFN3odxmoa/W6ytuCjVqcRBKsg9nSn1btm2idurq0AOti8xFSFqa\+b6XijeNpymxXb1Hc2zl\ google-ssh\ \{\"userName\":\"matt@shinymenu.online\",\"expireOn\":\"2022-09-17T18:36:11\+0000\"\} \
--maintenance-policy=MIGRATE \
--provisioning-model=STANDARD \
--service-account=vm1-sa-001@shinymenu-test-01.iam.gserviceaccount.com \
--scopes=https://www.googleapis.com/auth/cloud-platform \
--min-cpu-platform=Automatic \
--tags=shiny-server,http-server,https-server \
--no-shielded-secure-boot \
--shielded-vtpm \
--shielded-integrity-monitoring \
--reservation-affinity=any \
--source-machine-image=shinymenu-base-machine-image-001 \
--quiet

wait
sleep 60

#COPY ACROSS THE venueinfo.R FILE

gcloud compute scp /home/shiny/OrderApp/venueinfo-venuename.R serviceAccount@venuename-shinymenu-machine:~/venueinfo.R --zone=europe-west1-b --quiet
gcloud compute ssh serviceAccount@venuename-shinymenu-machine --zone=europe-west1-b --quiet --command "sudo mv -f ~/venueinfo.R /home/shiny/OrderApp/"

#COPY ACROSS THE priceList FILE

gcloud compute scp /home/shiny/OrderApp/price_list-venuename.csv serviceAccount@venuename-shinymenu-machine:~/price_list.csv --zone=europe-west1-b --quiet
gcloud compute ssh serviceAccount@venuename-shinymenu-machine --zone=europe-west1-b --quiet --command "sudo mv -f ~/price_list.csv /home/shiny/OrderApp/"