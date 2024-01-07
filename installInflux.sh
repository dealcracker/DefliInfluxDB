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
  echo "Error: Readsb is not installed. Please run the Defli Ground Station Installation Script first."
  echo "Aborting installation"
  exit 1
fi

#Prompt user for the Ground Station ID
read -p "Enter Your Ground Station ID:  " gsid
read -p "Enter Your Ground Station Token:  " token

#check GS ID length
if [ "${#gsid}" -lt 5 ]; then
  echo "Error: Ground Station ID is too short."
  echo "Aborting installation"
  exit 1
fi

#check Token length
if [ "${#token}" -lt 5 ]; then
  echo "Error: Ground Token is too short."
  echo "Aborting installation"
  exit 1
fi

#change to user's home dir
user_dir=$(getent passwd ${SUDO_USER:-$USER} | cut -d: -f6)
cd $user_dir

#get the user name
user_name=sudo who am i | awk '{print $1}'

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

#Update Readsb config
readsb_original_line1="\"--net-only --net-connector localhost,30006,json_out\""
readsb_new_line1="\"--net-only --net-connector localhost,30006,json_out --net-sbs-port 30003 --net-sbs-reduce --net-beast-reduce-interval 2\""
readsb_original_line2="\"--net --net-heartbeat 60 --net-ro-size 1250 --net-ro-interval 0.05 --net-ri-port 30001 --net-ro-port 30002 --net-sbs-port 30003 --net-bi-port 30004,30104 --net-bo-port 30005\""
readsb_new_line1="\"--net --net-heartbeat 60 --net-ro-size 1250 --net-ro-interval 0.05 --net-ri-port 30001 --net-ro-port 30002 --net-sbs-port 30003 --net-bi-port 30004,30104 --net-bo-port 30005 --net-sbs-reduce --net-beast-reduce-interval 2\""
sed -i "s|$readsb_original_line1|$readsb_new_line1|g" "/etc/default/readsb"
sed -i "s|$readsb_original_line2|$readsb_new_line2|g" "/etc/default/readsb"
sudo systemctl restart readsb

#remove MongoDB Connector
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
./update-nodejs-and-nodered --confirm-root --confirm-install --skip-pi --no-init 
rm update-nodejs-and-nodered 

#install the Worldmap and InfluxDB nodes
echo ""
echo "Installing Required Nodes..."
npm install node-red-contrib-web-worldmap
npm install node-red-contrib-influxdb

#install node red admin
#npm install -g node-red-admin

echo ""
echo "Preparing Connector..."

#get the default flow file
wget https://raw.githubusercontent.com/dealcracker/DefliInfluxDB/master/flows.json 

# updated the coordinates and IP in defaultFlows.json
original_line1="GS_LATITUDE"
new_line1=$(grep -oP -- "--lat \K[^ ]+" /etc/default/readsb)

original_line2="GS_LONGITUDE"
new_line2=$(grep -oP -- "--lon \K[^ ]+" /etc/default/readsb)

original_line3="GS_IP_ADDRESS"
new_line3=$ip_address

original_line4="GS_BUCKET"
new_line4=$gsid

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

#delete the any existing file
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

# #get the service status
service_name="nodered"
status=$(systemctl is-active "$service_name")

# # Check the status
echo ""
case "$status" in
  "active")
    echo "************************************"
    echo "Installation Completed Successfully!" 
    echo "$service_name is running properly."
    echo 
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
