#!/bin/bash
# 
# Copyright 2019-2021 Shiyghan Navti. Email shiyghan@techequity.company
#
#################################################################################
#############            Explore Multiple VPC Networks            ###############
#################################################################################

function ask_yes_or_no() {
    read -p "$1 ([y]yes to preview, [n]o to create, [d]del to delete): "
    case $(echo $REPLY | tr '[A-Z]' '[a-z]') in
        n|no)  echo "no" ;;
        d|del) echo "del" ;;
        *)     echo "yes" ;;
    esac
}

function ask_yes_or_no_proj() {
    read -p "$1 ([y]es to change, or any key to skip): "
    case $(echo $REPLY | tr '[A-Z]' '[a-z]') in
        y|yes) echo "yes" ;;
        *)     echo "no" ;;
    esac
}

clear
MODE=1
export TRAINING_ORG_ID=$(gcloud organizations list --format 'value(ID)' --filter="displayName:techequity.training" 2>/dev/null)
export ORG_ID=$(gcloud projects get-ancestors $GCP_PROJECT --format 'value(ID)' 2>/dev/null | tail -1 )
export GCP_PROJECT=$(gcloud config list --format 'value(core.project)' 2>/dev/null)  

echo
echo
echo -e "                        👋  Welcome to Cloud Sandbox! 💻"
echo 
echo -e "              *** PLEASE WAIT WHILE LAB UTILITIES ARE INSTALLED ***"
sudo apt-get -qq install pv > /dev/null 2>&1
echo 
export SCRIPTPATH=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

mkdir -p `pwd`/gcp-ce-vpc
export PROJDIR=`pwd`/gcp-ce-vpc
export SCRIPTNAME=gcp-ce-vpc.sh

if [ -f "$PROJDIR/.env" ]; then
    source $PROJDIR/.env
else
cat <<EOF > $PROJDIR/.env
export GCP_PROJECT=$GCP_PROJECT
export GCP_REGION=us-west2
export GCP_ZONE=us-west2-a
EOF
source $PROJDIR/.env
fi

# Display menu options
while :
do
clear
cat<<EOF
=======================================================================
Configure Cloud VPC, Cloud IAP, Cloud NAT and Private Google Access
-----------------------------------------------------------------------
Please enter number to select your choice:
 (1) Enable APIs
 (2) Create VPC networks
 (3) Create VPC Nework firewall rules
 (4) Create VM instances 
 (5) Explore connectivity between VM instances
 (6) Explore a VM instance with multiple network interfaces
 (7) Configure Identity Aware Proxy
 (8) Configure Cloud NAT 
 (9) Update VM with private IP 
(10) Create Cloud Storage bucket 
(11) Configure Private Google Access
(12) Copy content of Cloud Storage bucket to VM with private IP
 (G) Launch user guide
 (Q) Quit
-----------------------------------------------------------------------------
EOF
echo "Steps performed${STEP}"
echo
echo "What additional step do you want to perform, e.g. enter 0 to select the execution mode?"
read
clear
case "${REPLY^^}" in

"0")
start=`date +%s`
source $PROJDIR/.env
echo
echo "Do you want to run script in preview mode?"
export ANSWER=$(ask_yes_or_no "Are you sure?")
cd $HOME
if [[ ! -z "$TRAINING_ORG_ID" ]]  &&  [[ $ORG_ID == "$TRAINING_ORG_ID" ]]; then
    export STEP="${STEP},0"
    MODE=1
    if [[ "yes" == $ANSWER ]]; then
        export STEP="${STEP},0i"
        MODE=1
        echo
        echo "*** Command preview mode is active ***" | pv -qL 100
    else 
        if [[ -f $PROJDIR/.${GCP_PROJECT}.json ]]; then
            echo 
            echo "*** Authenticating using service account key $PROJDIR/.${GCP_PROJECT}.json ***" | pv -qL 100
            echo "*** To use a different GCP project, delete the service account key ***" | pv -qL 100
        else
            while [[ -z "$PROJECT_ID" ]] || [[ "$GCP_PROJECT" != "$PROJECT_ID" ]]; do
                echo 
                echo "$ gcloud auth login --brief --quiet # to authenticate as project owner or editor" | pv -qL 100
                gcloud auth login  --brief --quiet
                export ACCOUNT=$(gcloud config list account --format "value(core.account)")
                if [[ $ACCOUNT != "" ]]; then
                    echo
                    echo "Copy and paste a valid Google Cloud project ID below to confirm your choice:" | pv -qL 100
                    read GCP_PROJECT
                    gcloud config set project $GCP_PROJECT --quiet 2>/dev/null
                    sleep 3
                    export PROJECT_ID=$(gcloud projects list --filter $GCP_PROJECT --format 'value(PROJECT_ID)' 2>/dev/null)
                fi
            done
            gcloud iam service-accounts delete ${GCP_PROJECT}@${GCP_PROJECT}.iam.gserviceaccount.com --quiet 2>/dev/null
            sleep 2
            gcloud --project $GCP_PROJECT iam service-accounts create ${GCP_PROJECT} 2>/dev/null
            gcloud projects add-iam-policy-binding $GCP_PROJECT --member serviceAccount:$GCP_PROJECT@$GCP_PROJECT.iam.gserviceaccount.com --role=roles/owner > /dev/null 2>&1
            gcloud --project $GCP_PROJECT iam service-accounts keys create $PROJDIR/.${GCP_PROJECT}.json --iam-account=${GCP_PROJECT}@${GCP_PROJECT}.iam.gserviceaccount.com 2>/dev/null
            gcloud --project $GCP_PROJECT storage buckets create gs://$GCP_PROJECT > /dev/null 2>&1
        fi
        export GOOGLE_APPLICATION_CREDENTIALS=$PROJDIR/.${GCP_PROJECT}.json
        cat <<EOF > $PROJDIR/.env
export GCP_PROJECT=$GCP_PROJECT
export GCP_REGION=$GCP_REGION
export GCP_ZONE=$GCP_ZONE
EOF
        gsutil cp $PROJDIR/.env gs://${GCP_PROJECT}/${SCRIPTNAME}.env > /dev/null 2>&1
        echo
        echo "*** Google Cloud project is $GCP_PROJECT ***" | pv -qL 100
        echo "*** Google Cloud region is $GCP_REGION ***" | pv -qL 100
        echo "*** Google Cloud zone is $GCP_ZONE ***" | pv -qL 100
        echo
        echo "*** Update environment variables by modifying values in the file: ***" | pv -qL 100
        echo "*** $PROJDIR/.env ***" | pv -qL 100
        if [[ "no" == $ANSWER ]]; then
            MODE=2
            echo
            echo "*** Create mode is active ***" | pv -qL 100
        elif [[ "del" == $ANSWER ]]; then
            export STEP="${STEP},0"
            MODE=3
            echo
            echo "*** Resource delete mode is active ***" | pv -qL 100
        fi
    fi
else 
    if [[ "no" == $ANSWER ]] || [[ "del" == $ANSWER ]] ; then
        export STEP="${STEP},0"
        if [[ -f $SCRIPTPATH/.${SCRIPTNAME}.secret ]]; then
            echo
            unset password
            unset pass_var
            echo -n "Enter access code: " | pv -qL 100
            while IFS= read -p "$pass_var" -r -s -n 1 letter
            do
                if [[ $letter == $'\0' ]]
                then
                    break
                fi
                password=$password"$letter"
                pass_var="*"
            done
            while [[ -z "${password// }" ]]; do
                unset password
                unset pass_var
                echo
                echo -n "You must enter an access code to proceed: " | pv -qL 100
                while IFS= read -p "$pass_var" -r -s -n 1 letter
                do
                    if [[ $letter == $'\0' ]]
                    then
                        break
                    fi
                    password=$password"$letter"
                    pass_var="*"
                done
            done
            export PASSCODE=$(cat $SCRIPTPATH/.${SCRIPTNAME}.secret | openssl enc -aes-256-cbc -md sha512 -a -d -pbkdf2 -iter 100000 -salt -pass pass:$password 2> /dev/null)
            if [[ $PASSCODE == 'AccessVerified' ]]; then
                MODE=2
                echo && echo
                echo "*** Access code is valid ***" | pv -qL 100
                if [[ -f $PROJDIR/.${GCP_PROJECT}.json ]]; then
                    echo 
                    echo "*** Authenticating using service account key $PROJDIR/.${GCP_PROJECT}.json ***" | pv -qL 100
                    echo "*** To use a different GCP project, delete the service account key ***" | pv -qL 100
                else
                    while [[ -z "$PROJECT_ID" ]] || [[ "$GCP_PROJECT" != "$PROJECT_ID" ]]; do
                        echo 
                        echo "$ gcloud auth login --brief --quiet # to authenticate as project owner or editor" | pv -qL 100
                        gcloud auth login  --brief --quiet
                        export ACCOUNT=$(gcloud config list account --format "value(core.account)")
                        if [[ $ACCOUNT != "" ]]; then
                            echo
                            echo "Copy and paste a valid Google Cloud project ID below to confirm your choice:" | pv -qL 100
                            read GCP_PROJECT
                            gcloud config set project $GCP_PROJECT --quiet 2>/dev/null
                            sleep 3
                            export PROJECT_ID=$(gcloud projects list --filter $GCP_PROJECT --format 'value(PROJECT_ID)' 2>/dev/null)
                        fi
                    done
                    gcloud iam service-accounts delete ${GCP_PROJECT}@${GCP_PROJECT}.iam.gserviceaccount.com --quiet 2>/dev/null
                    sleep 2
                    gcloud --project $GCP_PROJECT iam service-accounts create ${GCP_PROJECT} 2>/dev/null
                    gcloud projects add-iam-policy-binding $GCP_PROJECT --member serviceAccount:$GCP_PROJECT@$GCP_PROJECT.iam.gserviceaccount.com --role=roles/owner > /dev/null 2>&1
                    gcloud --project $GCP_PROJECT iam service-accounts keys create $PROJDIR/.${GCP_PROJECT}.json --iam-account=${GCP_PROJECT}@${GCP_PROJECT}.iam.gserviceaccount.com 2>/dev/null
                    gcloud --project $GCP_PROJECT storage buckets create gs://$GCP_PROJECT > /dev/null 2>&1
                fi
                export GOOGLE_APPLICATION_CREDENTIALS=$PROJDIR/.${GCP_PROJECT}.json
                cat <<EOF > $PROJDIR/.env
export GCP_PROJECT=$GCP_PROJECT
export GCP_REGION=$GCP_REGION
export GCP_ZONE=$GCP_ZONE
EOF
                gsutil cp $PROJDIR/.env gs://${GCP_PROJECT}/${SCRIPTNAME}.env > /dev/null 2>&1
                echo
                echo "*** Google Cloud project is $GCP_PROJECT ***" | pv -qL 100
                echo "*** Google Cloud region is $GCP_REGION ***" | pv -qL 100
                echo "*** Google Cloud zone is $GCP_ZONE ***" | pv -qL 100
                echo
                echo "*** Update environment variables by modifying values in the file: ***" | pv -qL 100
                echo "*** $PROJDIR/.env ***" | pv -qL 100
                if [[ "no" == $ANSWER ]]; then
                    MODE=2
                    echo
                    echo "*** Create mode is active ***" | pv -qL 100
                elif [[ "del" == $ANSWER ]]; then
                    export STEP="${STEP},0"
                    MODE=3
                    echo
                    echo "*** Resource delete mode is active ***" | pv -qL 100
                fi
            else
                echo && echo
                echo "*** Access code is invalid ***" | pv -qL 100
                echo "*** You can use this script in our Google Cloud Sandbox without an access code ***" | pv -qL 100
                echo "*** Contact support@techequity.cloud for assistance ***" | pv -qL 100
                echo
                echo "*** Command preview mode is active ***" | pv -qL 100
            fi
        else
            echo
            echo "*** You can use this script in our Google Cloud Sandbox without an access code ***" | pv -qL 100
            echo "*** Contact support@techequity.cloud for assistance ***" | pv -qL 100
            echo
            echo "*** Command preview mode is active ***" | pv -qL 100
        fi
    else
        export STEP="${STEP},0i"
        MODE=1
        echo
        echo "*** Command preview mode is active ***" | pv -qL 100
    fi
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"1")
start=`date +%s`
source $PROJDIR/.env
if [ $MODE -eq 1 ]; then
    export STEP="${STEP},1i"
    echo
    echo "$ gcloud services enable compute.googleapis.com iap.googleapis.com # to enable compute APIs" | pv -qL 100
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},1"
    echo
    echo "$ gcloud services enable compute.googleapis.com iap.googleapis.com # to enable compute APIs" | pv -qL 100
    gcloud services enable compute.googleapis.com iap.googleapis.com
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},1x"
    echo
    echo "*** Nothing to delete ***" | pv -qL 100
else
    export STEP="${STEP},1i"
    echo
    echo "1. Enable APIs" | pv -qL 100
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"2")
start=`date +%s`
source $PROJDIR/.env
if [ $MODE -eq 1 ]; then
    export STEP="${STEP},2i"
    echo
    echo "$ gcloud compute networks create management --subnet-mode custom # to create custom network" | pv -qL 100
    echo
    echo "$ gcloud compute networks subnets create managementsubnet-us --network management --region europe-west4 --range 10.130.0.0/20 # to create subnet" | pv -qL 100
    echo
    echo "$ gcloud compute networks create mynetwork --subnet-mode custom # to create custom network" | pv -qL 100
    echo
    echo "$ gcloud compute networks subnets create mynetworksubnet-us --network=mynetwork --region=europe-west4 --range=10.128.0.0/20" | pv -qL 100
    echo
    echo "$ gcloud compute networks subnets create mynetworksubnet-eu --network=mynetwork --region=europe-west1 --range=10.132.0.0/20" | pv -qL 100
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},2"
    echo
    echo "$ gcloud compute networks create management --subnet-mode custom # to create custom network" | pv -qL 100
    gcloud compute networks create management --subnet-mode custom
    echo
    echo "$ gcloud compute networks subnets create managementsubnet-us --network management --region europe-west4 --range 10.130.0.0/20 # to create subnet" | pv -qL 100
    gcloud compute networks subnets create managementsubnet-us --network management --region europe-west4 --range 10.130.0.0/20
    echo
    echo "$ gcloud compute networks create mynetwork --subnet-mode custom # to create custom network" | pv -qL 100
    gcloud compute networks create mynetwork --subnet-mode custom
    echo
    echo "$ gcloud compute networks subnets create mynetworksubnet-us --network=mynetwork --region=europe-west4 --range=10.128.0.0/20" | pv -qL 100
    gcloud compute networks subnets create mynetworksubnet-us --network=mynetwork --region=europe-west4 --range=10.128.0.0/20
    echo
    echo "$ gcloud compute networks subnets create mynetworksubnet-eu --network=mynetwork --region=europe-west1 --range=10.132.0.0/20" | pv -qL 100
    gcloud compute networks subnets create mynetworksubnet-eu --network=mynetwork --region=europe-west1 --range=10.132.0.0/20
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},2x"
    echo
    echo "$ gcloud compute networks subnets delete mynetworksubnet-eu --region=europe-west1 # to delete subnet" | pv -qL 100
    gcloud compute networks subnets delete mynetworksubnet-eu --region=europe-west1
    echo
    echo "$ gcloud compute networks subnets delete mynetworksubnet-us --region=europe-west4 # to delete subnet" | pv -qL 100
    gcloud compute networks subnets delete mynetworksubnet-us --region=europe-west4
    echo
    echo "$ gcloud compute networks delete mynetwork # to delete network" | pv -qL 100
    gcloud compute networks delete mynetwork
    echo
    echo "$ gcloud compute networks subnets delete managementsubnet-us --region europe-west4 # to delete subnet" | pv -qL 100
    gcloud compute networks subnets delete managementsubnet-us --region europe-west4
    echo
    echo "$ gcloud compute networks delete management # to delete network" | pv -qL 100
    gcloud compute networks delete management
else
    export STEP="${STEP},2i"
    echo
    echo "1. Create custom network" | pv -qL 100
    echo "2. Create subnet" | pv -qL 100
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"3")
start=`date +%s`
source $PROJDIR/.env
if [ $MODE -eq 1 ]; then
    export STEP="${STEP},3i"
    echo
    echo "$ gcloud compute firewall-rules create managementnet-allow-icmp-ssh-rdp --network management --source-ranges 0.0.0.0/0 --action=ALLOW --rules=tcp:22,tcp:3389,icmp # to allow http" | pv -qL 100
    echo
    echo "$ gcloud compute firewall-rules create mynetwork-allow-icmp-ssh-rdp --direction=INGRESS --priority=1000 --network=mynetwork --action=ALLOW --rules=icmp,tcp:22,tcp:3389 --source-ranges=0.0.0.0/0 # to allow ping, ssh and rdp" | pv -qL 100
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},3"
    echo
    echo "$ gcloud compute firewall-rules create managementnet-allow-icmp-ssh-rdp --network management --source-ranges 0.0.0.0/0 --action=ALLOW --rules=tcp:22,tcp:3389,icmp # to allow http" | pv -qL 100
    gcloud compute firewall-rules create managementnet-allow-icmp-ssh-rdp --network management --source-ranges 0.0.0.0/0 --action=ALLOW --rules=tcp:22,tcp:3389,icmp
    echo
    echo "$ gcloud compute firewall-rules create mynetwork-allow-icmp-ssh-rdp --direction=INGRESS --priority=1000 --network=mynetwork --action=ALLOW --rules=icmp,tcp:22,tcp:3389 --source-ranges=0.0.0.0/0 # to allow ping, ssh and rdp" | pv -qL 100
    gcloud compute firewall-rules create mynetwork-allow-icmp-ssh-rdp --direction=INGRESS --priority=1000 --network=mynetwork --action=ALLOW --rules=icmp,tcp:22,tcp:3389 --source-ranges=0.0.0.0/0
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},3x"
    echo
    echo "$ gcloud compute firewall-rules delete managementnet-allow-icmp-ssh-rdp # to delete firewall rules" | pv -qL 100
    gcloud compute firewall-rules delete managementnet-allow-icmp-ssh-rdp
    echo
    echo "$ gcloud compute firewall-rules delete mynetwork-allow-icmp-ssh-rdp # to delete firewall rules" | pv -qL 100
    gcloud compute firewall-rules delete mynetwork-allow-icmp-ssh-rdp
else
    export STEP="${STEP},3i"
    echo
    echo "1. Configure firewall rule to allow http" | pv -qL 100
    echo "2. Configure firewall rule to allow ping, ssh and rdp" | pv -qL 100
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"4")
start=`date +%s`
source $PROJDIR/.env
if [ $MODE -eq 1 ]; then
    export STEP="${STEP},4i"
    echo
    echo "$ gcloud compute instances create managementnet-us-vm --zone europe-west4-c --machine-type=n1-standard-1 --subnet=managementsubnet-us --preemptible # to create instance" | pv -qL 100
    echo
    echo "$ gcloud compute instances create mynet-eu-vm --zone=europe-west1-c --machine-type=n1-standard-1 --subnet=mynetworksubnet-eu --preemptible --no-address # to create instance" | pv -qL 100
    echo
    echo "$ gcloud compute instances create mynet-us-vm --zone=europe-west4-c --machine-type=n1-standard-1 --subnet=mynetworksubnet-us --preemptible # to create instance" | pv -qL 100
    echo
    echo "$ gcloud compute instances create vm-appliance --machine-type=n1-standard-4 --zone=europe-west4-c --network-interface subnet=managementsubnet-us --network-interface subnet=mynetworksubnet-us # to create instance with multiple NIC" | pv -qL 100
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},4"
    echo
    echo "$ gcloud compute instances create managementnet-us-vm --zone europe-west4-c --machine-type=n1-standard-1 --subnet=managementsubnet-us --preemptible # to create instance" | pv -qL 100
    gcloud compute instances create managementnet-us-vm --zone europe-west4-c --machine-type=n1-standard-1 --subnet=managementsubnet-us --preemptible
    echo
    echo "$ gcloud compute instances create mynet-eu-vm --zone=europe-west1-c --machine-type=n1-standard-1 --subnet=mynetworksubnet-eu --preemptible --no-address # to create instance" | pv -qL 100
    gcloud compute instances create mynet-eu-vm --zone=europe-west1-c --machine-type=n1-standard-1 --subnet=mynetworksubnet-eu --preemptible --no-address
    echo
    echo "$ gcloud compute instances create mynet-us-vm --zone=europe-west4-c --machine-type=n1-standard-1 --subnet=mynetworksubnet-us --preemptible # to create instance" | pv -qL 100
    gcloud compute instances create mynet-us-vm --zone=europe-west4-c --machine-type=n1-standard-1 --subnet=mynetworksubnet-us --preemptible
    echo
    echo "$ gcloud compute instances create vm-appliance --machine-type=n1-standard-4 --zone=europe-west4-c --network-interface subnet=managementsubnet-us --network-interface subnet=mynetworksubnet-us # to create instance with multiple NIC" | pv -qL 100
    gcloud compute instances create vm-appliance --machine-type=n1-standard-4 --zone=europe-west4-c --network-interface subnet=managementsubnet-us --network-interface subnet=mynetworksubnet-us
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},4x"
    echo
    echo "$ gcloud compute instances delete vm-appliance --zone=europe-west4-c # to delete instance" | pv -qL 100
    gcloud compute instances delete vm-appliance --zone=europe-west4-c
    echo
    echo "$ gcloud compute instances delete mynet-us-vm --zone=europe-west4-c # to delete instance" | pv -qL 100
    gcloud compute instances delete mynet-us-vm --zone=europe-west4-c
    echo
    echo "$ gcloud compute instances delete mynet-eu-vm --zone=europe-west1-c # to delete instance" | pv -qL 100
    gcloud compute instances delete mynet-eu-vm --zone=europe-west1-c
    echo
    echo "$ gcloud compute instances delete managementnet-us-vm --zone europe-west4-c # to delete instance" | pv -qL 100
    gcloud compute instances delete managementnet-us-vm --zone europe-west4-c
else
    export STEP="${STEP},4i"
    echo
    echo "1. Create instance" | pv -qL 100
    echo "2. Create instance with multiple NIC" | pv -qL 100
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"5")
start=`date +%s`
source $PROJDIR/.env
if [ $MODE -eq 1 ]; then
    export STEP="${STEP},5i"
    echo
    echo "$ gcloud compute ssh --quiet --zone europe-west4-c mynet-us-vm --command=\"ping -c 3 \$IPV4\" # to ping managementnet-us-vm public IP from mynet-us-vm" | pv -qL 100
    echo
    echo "$ gcloud compute ssh --quiet --zone europe-west4-c mynet-us-vm --command=\"ping -c 3 \$IPV4\" # to ping managementnet-us-vm private IP from mynet-us-vm" | pv -qL 100
    echo
    echo "$ gcloud compute ssh --quiet --zone europe-west4-c mynet-us-vm --command=\"ping -c 3 \$IPV4\" # to ping mynet-eu-vm private IP from mynet-us-vm" | pv -qL 100
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},5"
    echo
    export IPV4=$(gcloud compute instances describe managementnet-us-vm --zone europe-west4-c --format=text  | grep '^networkInterfaces\[[0-9]\+\]\.accessConfigs\[[0-9]\+\]\.natIP:' | sed 's/^.* //g' 2>&1) # to set IP
    echo "$ gcloud compute ssh --quiet --zone europe-west4-c mynet-us-vm --command=\"ping -c 3 $IPV4\" # to ping managementnet-us-vm public IP from mynet-us-vm" | pv -qL 100
    gcloud compute ssh --quiet --zone europe-west4-c mynet-us-vm --command="ping -c 3 $IPV4"
    echo
    read -n 1 -s -r -p $'*** Press the Enter key to continue ***'
    echo && echo
    export IPV4=$(gcloud compute instances describe managementnet-us-vm --zone europe-west4-c --format=text  | grep '^networkInterfaces\[[0-9]\+\]\.networkIP:' | sed 's/^.* //g' 2>&1) # to set IP
    echo "$ gcloud compute ssh --quiet --zone europe-west4-c mynet-us-vm --command=\"ping -c 3 $IPV4\" # to ping managementnet-us-vm private IP from mynet-us-vm" | pv -qL 100
    gcloud compute ssh --quiet --zone europe-west4-c mynet-us-vm --command="ping -c 3 $IPV4"
    echo
    read -n 1 -s -r -p $'*** Press the Enter key to continue ***'
    echo && echo
    export IPV4=$(gcloud compute instances describe mynet-eu-vm --zone europe-west1-c --format=text  | grep '^networkInterfaces\[[0-9]\+\]\.networkIP:' | sed 's/^.* //g' 2>&1) # to set IP
    echo "$ gcloud compute ssh --quiet --zone europe-west4-c mynet-us-vm --command=\"ping -c 3 $IPV4\" # to ping mynet-eu-vm private IP from mynet-us-vm" | pv -qL 100
    gcloud compute ssh --quiet --zone europe-west4-c mynet-us-vm --command="ping -c 3 $IPV4"
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},5x"
    echo
    echo "*** Nothing to delete ***" | pv -qL 100
else
    export STEP="${STEP},5i"
    echo
    echo "1. Ping virtual machines" | pv -qL 100
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"6")
start=`date +%s`
source $PROJDIR/.env
if [ $MODE -eq 1 ]; then
    export STEP="${STEP},6i"
    echo
    echo "$ gcloud compute ssh --quiet --zone europe-west4-c vm-appliance --command=\"sudo ifconfig\" # to check network configuration" | pv -qL 100
    echo
    echo "$ gcloud compute ssh --quiet --zone europe-west4-c vm-appliance --command=\"ip route\" # to check route" | pv -qL 100
    echo
    echo "$ gcloud compute ssh --quiet --zone europe-west4-c vm-appliance --command=\"ping -c 3 \$IPV4\" # to ping mynet-eu-vm private IP from vm-appliance" | pv -qL 100
    echo
    echo "$ gcloud compute ssh --quiet --zone europe-west4-c vm-appliance --command=\"ping -c 3 \$IPV4\" # to ping managementnet-us-vm private IP from vm-appliance" | pv -qL 100
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},6"
    echo
    echo "$ gcloud compute ssh --quiet --zone europe-west4-c vm-appliance --command=\"sudo ifconfig\" # to check network configuration" | pv -qL 100
    gcloud compute ssh --quiet --zone europe-west4-c vm-appliance --command="sudo ifconfig"
    echo
    read -n 1 -s -r -p $'*** Press the Enter key to continue ***'
    echo && echo
    echo "$ gcloud compute ssh --quiet --zone europe-west4-c vm-appliance --command=\"ip route\" # to check route" | pv -qL 100
    gcloud compute ssh --quiet --zone europe-west4-c vm-appliance --command="ip route"
    echo
    read -n 1 -s -r -p $'*** Press the Enter key to continue ***'
    echo && echo
    export IPV4=$(gcloud compute instances describe managementnet-us-vm --zone europe-west4-c --format=text  | grep '^networkInterfaces\[[0-9]\+\]\.networkIP:' | sed 's/^.* //g' 2>&1) # to set IP
    echo "$ gcloud compute ssh --quiet --zone europe-west4-c vm-appliance --command=\"ping -c 3 $IPV4\" # to ping managementnet-us-vm private IP from vm-appliance" | pv -qL 100
    gcloud compute ssh --quiet --zone europe-west4-c vm-appliance --command="ping -c 3 $IPV4"
    echo
    read -n 1 -s -r -p $'*** Press the Enter key to continue ***'
    echo && echo
    export IPV4=$(gcloud compute instances describe mynet-eu-vm --zone europe-west1-c --format=text  | grep '^networkInterfaces\[[0-9]\+\]\.networkIP:' | sed 's/^.* //g' 2>&1) # to set IP
    echo "$ gcloud compute ssh --quiet --zone europe-west4-c vm-appliance --command=\"ping -c 3 $IPV4\" # to ping mynet-eu-vm private IP from vm-appliance" | pv -qL 100
    gcloud compute ssh --quiet --zone europe-west4-c vm-appliance --command="ping -c 3 $IPV4"
    echo
    read -n 1 -s -r -p $'*** Press the Enter key to continue ***'
    echo && echo
    export IPV4=$(gcloud compute instances describe mynet-us-vm --zone europe-west4-c --format=text  | grep '^networkInterfaces\[[0-9]\+\]\.networkIP:' | sed 's/^.* //g' 2>&1) # to set IP
    echo "$ gcloud compute ssh --quiet --zone europe-west4-c vm-appliance --command=\"ping -c 3 $IPV4\" # to ping mynet-us-vm private IP from vm-appliance" | pv -qL 100
    gcloud compute ssh --quiet --zone europe-west4-c vm-appliance --command="ping -c 3 $IPV4"
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},6x"
    echo
    echo "*** Nothing to delete ***" | pv -qL 100
else
    export STEP="${STEP},6i"
    echo
    echo "1. Check network configuration" | pv -qL 100
    echo "2. Check route" | pv -qL 100
    echo "3. Ping virtual machines" | pv -qL 100
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"7")
start=`date +%s`
source $PROJDIR/.env
if [ $MODE -eq 1 ]; then
    export STEP="${STEP},7i"
    echo
    echo "$ gcloud compute firewall-rules create allow-ssh-ingress-from-iap --direction=INGRESS --action=allow --rules=tcp:22 --source-ranges=35.235.240.0/20 --quiet # to allow SSH access" | pv -qL 100
    echo
    echo "$ gcloud alpha iap oauth-brands create --application_title=my-internal-app --support_email=\$(gcloud config get-value core/account) # to create brand" | pv -qL 100
    echo
    echo "$ gcloud alpha iap oauth-clients create \$BRAND_ID --display_name=my-internal-app # to create a brand" | pv -qL 100
    echo
    echo "$ gcloud projects add-iam-policy-binding \$GCP_PROJECT --member=user:\$EMAIL --role=roles/iap.tunnelResourceAccessor  # to add a user to the access policy for IAP" | pv -qL 100
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},7"
    echo
    echo "$ gcloud compute firewall-rules create allow-ssh-ingress-from-iap --direction=INGRESS --action=allow --rules=tcp:22 --source-ranges=35.235.240.0/20 --quiet # to allow SSH access" | pv -qL 100
    gcloud compute firewall-rules create allow-ssh-ingress-from-iap --direction=INGRESS --action=allow --rules=tcp:22 --source-ranges=35.235.240.0/20 --quiet
    export BRAND_NAME=$(gcloud alpha iap oauth-brands list --format="value(name)") > /dev/null 2>&1
    if [ -z "$BRAND_NAME" ]
    then
        echo && echo
        echo "$ gcloud alpha iap oauth-brands create --application_title=my-internal-app --support_email=$(gcloud config get-value core/account) # to create brand" | pv -qL 100
        gcloud alpha iap oauth-brands create --application_title=my-internal-app --support_email=$(gcloud config get-value core/account)
        sleep 10
        export BRAND_ID=$(gcloud alpha iap oauth-brands list --format="value(name)") > /dev/null 2>&1 # to set brand ID
    else
        export BRAND_ID=$(gcloud alpha iap oauth-brands list --format="value(name)") > /dev/null 2>&1 # to set brand ID
    fi
    export CLIENT_LIST=$(gcloud alpha iap oauth-clients list $BRAND_ID) > /dev/null 2>&1

    if [ -z "$CLIENT_LIST" ]
    then
        echo
        echo "$ gcloud alpha iap oauth-clients create $BRAND_ID --display_name=my-internal-app # to create a brand" | pv -qL 100
        gcloud alpha iap oauth-clients create $BRAND_ID --display_name=my-internal-app # to create a brand
        sleep 10
        export CLIENT_ID=$(gcloud alpha iap oauth-clients list $BRAND_ID --format="value(name)" | awk -F/ '{print $NF}') # to set client ID
        export CLIENT_SECRET=$(gcloud alpha iap oauth-clients list $BRAND_ID --format="value(secret)") # to set secret
    else
        export CLIENT_ID=$(gcloud alpha iap oauth-clients list $BRAND_ID --format="value(name)" | awk -F/ '{print $NF}') # to set client ID
        export CLIENT_SECRET=$(gcloud alpha iap oauth-clients list $BRAND_ID --format="value(secret)") # to set secret
    fi
    export EMAIL=$(gcloud config get-value core/account)
    echo
    echo "$ gcloud projects add-iam-policy-binding $GCP_PROJECT --member=user:$EMAIL --role=roles/iap.tunnelResourceAccessor  # to add a user to the access policy for IAP" | pv -qL 100
    gcloud projects add-iam-policy-binding $GCP_PROJECT --member=user:$EMAIL --role=roles/iap.tunnelResourceAccessor
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},7x"
    echo
    echo "$ gcloud compute firewall-rules delete allow-ssh-ingress-from-iap # to delete firewall" | pv -qL 100
    gcloud compute firewall-rules delete allow-ssh-ingress-from-iap 
    echo
    echo "$ gcloud projects remove-iam-policy-binding $GCP_PROJECT --member=user:$EMAIL --role=roles/iap.tunnelResourceAccessor  # to add a user to the access policy for IAP" | pv -qL 100
    export EMAIL=$(gcloud config get-value core/account)
    gcloud projects remove-iam-policy-binding $GCP_PROJECT --member=user:$EMAIL --role=roles/iap.tunnelResourceAccessor
else
    export STEP="${STEP},7i"
    echo
    echo "1. Create Brand" | pv -qL 100
    echo "2. Create OAuth client" | pv -qL 100
    echo "3. Create Secret" | pv -qL 100
    echo "4. Add user to access policy for IAP" | pv -qL 100
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"8")
start=`date +%s`
source $PROJDIR/.env
if [ $MODE -eq 1 ]; then
    export STEP="${STEP},8i"   
    echo
    echo "$ gcloud compute routers create europe-west1-nat-router --network mynetwork --region europe-west1 # to create a Cloud Router" | pv -qL 100
    echo
    echo "$ gcloud compute routers nats create europe-west1-nat-config --router-region europe-west1 --router europe-west1-nat-router --nat-all-subnet-ip-ranges --auto-allocate-nat-external-ips # to add a configuration to the router" | pv -qL 100
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},8"   
    echo
    echo "$ gcloud compute routers create europe-west1-nat-router --network mynetwork --region europe-west1 # to create a Cloud Router" | pv -qL 100
    gcloud compute routers create europe-west1-nat-router --network mynetwork --region europe-west1
    echo
    echo "$ gcloud compute routers nats create europe-west1-nat-config --router-region europe-west1 --router europe-west1-nat-router --nat-all-subnet-ip-ranges --auto-allocate-nat-external-ips # to add a configuration to the router" | pv -qL 100
    gcloud compute routers nats create europe-west1-nat-config --router-region europe-west1 --router europe-west1-nat-router --nat-all-subnet-ip-ranges --auto-allocate-nat-external-ips
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},8x"   
    echo
    echo "$ gcloud compute routers create europe-west1-nat-router --region europe-west1 # to delete router" | pv -qL 100
    gcloud compute routers delete europe-west1-nat-router --region europe-west1
else
    export STEP="${STEP},8i"
    echo
    echo "1. Create Cloud Router" | pv -qL 100
    echo "2. Add a configuration to the router" | pv -qL 100
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"9")
start=`date +%s`
source $PROJDIR/.env
if [ $MODE -eq 1 ]; then
    export STEP="${STEP},9i"   
    echo
    echo "$ gcloud compute --project \$GCP_PROJECT ssh mynet-eu-vm --zone europe-west1-c --tunnel-through-iap --command=\"sudo apt-get update\" # to update VM" | pv -qL 100
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},9"   
    echo
    echo "$ gcloud compute --project $GCP_PROJECT ssh mynet-eu-vm --zone europe-west1-c --tunnel-through-iap --command=\"sudo apt-get update\" # to update VM" | pv -qL 100
    gcloud compute --project $GCP_PROJECT ssh mynet-eu-vm --zone europe-west1-c --tunnel-through-iap --command="sudo apt-get update"
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},9x"   
    echo
    echo "*** Nothing to delete ***"
else
    export STEP="${STEP},9i"
    echo
    echo "1. Update the virtual machine" | pv -qL 100
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"10")
start=`date +%s`
source $PROJDIR/.env
if [ $MODE -eq 1 ]; then
    export STEP="${STEP},10i"
    echo
    echo "$ gsutil mb -l europe-west1 gs://\${GCP_PROJECT} # to create bucket" | pv -qL 100
    echo 
    echo "$ gsutil iam ch allUsers:objectViewer gs://\${GCP_PROJECT} # to make the bucket publicly accessible" | pv -qL 100
    echo
    echo "$ gsutil cp \$PROJDIR/20MB.zip gs://\${GCP_PROJECT} # to copy files" | pv -qL 100
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},10"        
    echo
    echo "$ gsutil mb -l europe-west1 gs://${GCP_PROJECT} # to create bucket" | pv -qL 100
    gsutil mb -l europe-west1 gs://${GCP_PROJECT}
    echo 
    echo "$ gsutil iam ch allUsers:objectViewer gs://${GCP_PROJECT} # to make the bucket publicly accessible" | pv -qL 100
    gsutil iam ch allUsers:objectViewer gs://${GCP_PROJECT}
    echo
    echo "$ curl http://ipv4.download.thinkbroadband.com/20MB.zip # to download large file"
    curl http://ipv4.download.thinkbroadband.com/20MB.zip -o $PROJDIR/20MB.zip
    echo
    echo "$ gsutil cp $PROJDIR/20MB.zip gs://${GCP_PROJECT} # to copy files" | pv -qL 100
    gsutil cp $PROJDIR/20MB.zip gs://${GCP_PROJECT}
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},10x"        
    echo
    echo "$ gcloud storage rm --recursive  gs://${GCP_PROJECT} # to delete bucket" | pv -qL 100
    gcloud storage rm --recursive  gs://${GCP_PROJECT}
else
    export STEP="${STEP},10i"
    echo
    echo "1. Create Cloud Storage bucket" | pv -qL 100
    echo "2. Make bucket accessible" | pv -qL 100
    echo "3. Copy files into bucket" | pv -qL 100
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"11")
start=`date +%s`
source $PROJDIR/.env
if [ $MODE -eq 1 ]; then
  export STEP="${STEP},11i"   
    echo
    echo "$ gcloud compute --project \$GCP_PROJECT ssh mynet-eu-vm --zone europe-west1-c --tunnel-through-iap --command=\"gsutil cp gs://\$GCP_PROJECT/*.zip .\" # to copy file to bucket" | pv -qL 100
    echo
    echo "$ gcloud compute networks subnets update mynetworksubnet-eu --region=europe-west1 --enable-private-ip-google-access # to enable private google access" | pv -qL 100
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},11"   
    echo
    echo "$ gcloud compute --project $GCP_PROJECT ssh mynet-eu-vm --zone europe-west1-c --tunnel-through-iap --command=\"gsutil cp gs://$GCP_PROJECT/*.zip .\" # to copy file to bucket" | pv -qL 100
    gcloud compute --project $GCP_PROJECT ssh mynet-eu-vm --zone europe-west1-c --tunnel-through-iap --command="gsutil cp gs://$GCP_PROJECT/*.zip ."
    echo
    echo "$ gcloud compute networks subnets update mynetworksubnet-eu --region=europe-west1 --enable-private-ip-google-access # to enable private google access" | pv -qL 100
    gcloud compute networks subnets update mynetworksubnet-eu --region=europe-west1 --enable-private-ip-google-access
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},11x"   
    echo
    echo "*** Nothing to delete ***" | pv -qL 100
else
    export STEP="${STEP},11i"
    echo
    echo "1. Copy files into bucket" | pv -qL 100
    echo "2. Enable private google access" | pv -qL 100
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"12")
start=`date +%s`
source $PROJDIR/.env
if [ $MODE -eq 1 ]; then
    export STEP="${STEP},12i"
    echo
    echo "$ gcloud compute --project \$GCP_PROJECT ssh mynet-eu-vm --zone europe-west1-c --tunnel-through-iap --command=\"gsutil cp gs://\$GCP_PROJECT/*.zip .\" # to copy file to bucket" | pv -qL 100
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},12"        
    echo
    echo "$ gcloud compute --project $GCP_PROJECT ssh mynet-eu-vm --zone europe-west1-c --tunnel-through-iap --command=\"gsutil cp gs://$GCP_PROJECT/*.zip .\" # to copy file to bucket" | pv -qL 100
    gcloud compute --project $GCP_PROJECT ssh mynet-eu-vm --zone europe-west1-c --tunnel-through-iap --command="gsutil cp gs://$GCP_PROJECT/*.zip ."
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},12x"   
    echo
    echo "*** Nothing to delete ***" | pv -qL 100
else
    export STEP="${STEP},12i"
    echo
    echo "1. Copy files into bucket" | pv -qL 100
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"R")
echo
echo "
  __                      __                              __                               
 /|            /         /              / /              /                 | /             
( |  ___  ___ (___      (___  ___        (___           (___  ___  ___  ___|(___  ___      
  | |___)|    |   )     |    |   )|   )| |    \   )         )|   )|   )|   )|   )|   )(_/_ 
  | |__  |__  |  /      |__  |__/||__/ | |__   \_/       __/ |__/||  / |__/ |__/ |__/  / / 
                                 |              /                                          
"
echo "
We are a group of information technology professionals committed to driving cloud 
adoption. We create cloud skills development assets during our client consulting 
engagements, and use these assets to build cloud skills independently or in partnership 
with training organizations.
 
You can access more resources from our iOS and Android mobile applications.

iOS App: https://apps.apple.com/us/app/tech-equity/id1627029775
Android App: https://play.google.com/store/apps/details?id=com.techequity.app

Email:support@techequity.cloud 
Web: https://techequity.cloud

Ⓒ Tech Equity 2022" | pv -qL 100
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"G")
cloudshell launch-tutorial $SCRIPTPATH/.tutorial.md
;;

"Q")
echo
exit
;;
"q")
echo
exit
;;
* )
echo
echo "Option not available"
;;
esac
sleep 1
done
