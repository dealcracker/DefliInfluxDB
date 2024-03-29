#!/bin/bash
# install the Defli InfluxDB connector
# Copyright (c) 2024 dealcracker
#

#enforce sudo
if ! [[ $EUID = 0 ]]; then
    echo "Please run this script with 'sudo'..."
    exit 1
fi

#Check for readsb
if [ ! -e "/etc/default/readsb" ]; then
  echo "Warning: Readsb is not found."
  echo "Assuming Readsb is in a Docker and continuing..."
  echo ""
  echo "Enter the geogrphical coordinates of your Defli ground station (decimal)"
  read -p "Latitude:  " latitude
  read -p "Longitude: " longitude
else
  latitude=$(grep -oP -- "--lat \K[^ ]+" /etc/default/readsb)
  longitude=$(grep -oP -- "--lon \K[^ ]+" /etc/default/readsb)
fi

#change to user's home dir
user_dir=$(getent passwd ${SUDO_USER:-$USER} | cut -d: -f6)
cd $user_dir

#get the user name
user_name=sudo who am i | awk '{print $1}'
current_dir=$(pwd)

#Check for node-red
if [ -e "/root/.node-red/settings.js" ]; then
  read -p  "Node-Red is already installed. This script will delete any existing installation and all flows. Do you want to continue? (y/n) " response
  if [ $response != "y" ]; then
    echo "Aborting installation"
    exit 1
  fi
else 
  if [ -e "$current_dir/.node-red/settings.js" ]; then
    read -p  "Node-Red is already installed. This script will delete any existing installation and all flows. Do you want to continue? (y/n) " response
    if [ $response != "y" ]; then
      echo "Aborting installation"
      exit 1
    fi
  fi
fi
#stop and remove any running node-res service
systemctl stop nodered > /dev/null 2>&1
systemctl disable nodered > /dev/null 2>&1
rm -f /lib/systemd/system/nodered.service > /dev/null 2>&1

#remove any existing node-red installation directories
rm -fr /root/.node-red > /dev/null 2>&1
rm -fr $current_dir/.node-red > /dev/null 2>&1


#Prompt user for the Ground Station information
echo "Go to defli-wallet.com to find your unique Ground Station information:"
read -p "Enter Your Ground Station Bucket ID: " bucket
read -p "Enter Your Ground Station API Key  : " token

#Make bucket lowercase
bucket="$(tr [A-Z] [a-z] <<< "$bucket")"

#check GS ID length
if [ "${#bucket}" -lt 3 ]; then
  echo "Error: Ground Station Bucket ID is too short."
  echo "Aborting installation"
  exit 1
fi

#check Token length
if [ "${#token}" -lt 5 ]; then
  echo "Error: Ground Station API Key is too short."
  echo "Aborting installation"
  exit 1
fi

echo "============ Influx Connector ==============="
echo "Installing the Influx connector for Defli" 

#Determine IP address to use in flow
#test if localhost is reachable
  echo "Determining local IP address..."
  ping -c 3 localhost > /dev/null 2>&1
  if [ $? -eq 0 ]; then
    ip_address="localhost"
    echo "Using localhost instead of fixed IP address"
  else
    # get the eth0 ip address
    ip_address=$(ip addr show eth0 | awk '/inet / {print $2}' | cut -d'/' -f1)
    #Check if eth0 is up and has an IP address
    if [ -n "$ip_address" ]; then
      echo "Using wired ethernet IP address: $ip_address"
    else
      # Get the IP address of the Wi-Fi interface using ip command
      ip_address=$(ip addr show wlan0 | awk '/inet / {print $2}' | cut -d'/' -f1)
      if [ -n "$ip_address" ]; then
        echo "Using wifi IP address: $ip_address"
      else
        echo "Unable to determine your device IP address"
        echo "No IP address. Installation Failed."
        exit 1
      fi
    fi
  fi

# Update the package list
echo ""
echo "Updating package list..."
apt-get -qq update -y

#remove MongoDB Connector
echo ""
echo "Removing MongoDB..."
mongo_service_file_path="/lib/systemd/system/adsb_collector.service"
if [ -e "$mongo_service_file_path" ]; then
	echo "Removing MongoDB Connector ..."
  systemctl disable --now adsb_collector 
	rm -f /lib/systemd/system/adsb_collector.service
	rm -fr adsb-data-collector-mongodb
fi

#install Node-Red
echo ""
echo "Preparing to install Node.js and Node-RED..."
wget https://raw.githubusercontent.com/node-red/linux-installers/master/deb/update-nodejs-and-nodered 
chmod +x update-nodejs-and-nodered
./update-nodejs-and-nodered --confirm-root --confirm-install --skip-pi --no-init --node18 
rm update-nodejs-and-nodered 

echo ""
echo "Preparing Connector..."

#get the default flow file
wget https://raw.githubusercontent.com/dealcracker/DefliInfluxDB/master/flows.json 

# updated the coordinates and IP in defaultFlows.json
original_line1="GS_LATITUDE"
new_line1=$latitude

original_line2="GS_LONGITUDE"
new_line2=$longitude

original_line3="GS_IP_ADDRESS"
new_line3=$ip_address

original_line4="GS_BUCKET"
new_line4=$bucket

sed -i "s|$original_line1|$new_line1|g" "flows.json"
sed -i "s|$original_line2|$new_line2|g" "flows.json"
sed -i "s|$original_line3|$new_line3|g" "flows.json"
sed -i "s|$original_line4|$new_line4|g" "flows.json"

#get the default flow cred
wget https://raw.githubusercontent.com/dealcracker/DefliInfluxDB/master/flows_cred.json 

#update the token
original_line5="GS_TOKEN"
new_line5=$token

sed -i "s|$original_line5|$new_line5|g" "flows_cred.json"

#get the settings file
wget https://raw.githubusercontent.com/dealcracker/DefliInfluxDB/master/settings.js 

echo ""
echo "Installing Connector..."

#delete any existing file
rm -fr /root/.node-red/.config.runtime.json
rm -fr /root/.node-red/flows.json
rm -fr /root/.node-red/flows_cred.json
rm -fr /root/.node-red/settings.js 

#move updated file to .node_red folder
mv flows.json /root/.node-red/flows.json
mv flows_cred.json /root/.node-red/flows_cred.json
mv settings.js /root/.node-red/settings.js

#Enable and start Node-Red service
systemctl enable nodered.service
systemctl start nodered.service

echo "Waiting Node-Red for service to start..."
sleep 3

#install the Worldmap and InfluxDB nodes
echo ""
echo "Installing Required Nodes..."
npm update
npm install -g node-red-admin
npm install node-red-contrib-web-worldmap
npm install node-red-contrib-influxdb
node-red-admin target "http://127.0.0.1:1880"
node-red-admin install node-red-contrib-web-worldmap
node-red-admin install node-red-contrib-influxdb

#Restart Node-Red service
systemctl restart nodered.service

echo "Waiting Node-Red for service to restart..."
sleep 3

flowsSize=$(wc -c <"/root/.node-red/flows.json")
flowsCredSize=$(wc -c <"/root/.node-red/flows_cred.json")

normalSize=0
if [ $flowsSize -ge 21000 ]; then
  if [ $flowsCredSize -ge 350 ]; then
      $normalSize=1
  fi
fi

# #get the service status
service_name="nodered"
status=$(systemctl is-active "$service_name")

# Check the status
echo ""
case "$status" in
  "active")
    echo "************************************"
    echo "Rod-Red Installation Completed" 
    echo "$service_name is running."
    echo
    echo "Flows file length: " $flowsSize
    echo "Flows_cred file length: " $flowsCredSize
    ;;
  "inactive")
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    echo "Installation Finished with a warning." 
    echo "Warning: $service_name is not running."
    echo ""
    echo "Try entering 'sudo systemctl start nodered' to start the service."
    echo "Then enter 'sudo systemctl status nodered' to check the status."
    ;;
  "failed")
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    echo "Installation Finished but failed to start." 
    echo "Error: $service_name is in a failed state."
    echo ""
    echo "Try entering 'sudo systemctl start nodered' to start the service."
    echo "Then enter 'sudo systemctl status nodered' to check the status."
    ;;
  *)
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    echo "Installation Complete." 
    echo "Status of $service_name: $status"
    echo "You can enter 'sudo systemctl status nodered' to check the status."
    ;;
esac
