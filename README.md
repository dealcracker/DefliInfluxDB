# Defli Installation and Update Scripts
These shell scripts help to install the Defli ground station. One script installs the base Defli ground station on a new device. Another script installs the new Defli Influx Connector on new or existing ground stations. These scripts are compatible with the 64-bit version of Ubuntu 20.04, 22.04, and 23.04 as well as Rasberry Pi OS.

## Influx Connector Installation Script
Use this script to install the new MongoDB connector on your new or existing Defli Ground station.

### Usage
```
sudo bash -c "$(wget -O - https://raw.githubusercontent.com/dealcracker/DefliMongoDB/master/installMongo.sh)"
```
	
## Defli Ground Station Installation Script
Use this script to install the base Defli ground station on a new device. This script also installs the graphs package. You will be prompted to enter the latitude and longitude of your ground station. Note that this script will reboot your device at the end of the installation. 

After rebooting (at the end of the installation), please run 'sudo autogain1090' and then run the MongoDB Connector install script.

### Usage
```
sudo bash -c "$(wget -O - https://raw.githubusercontent.com/dealcracker/DefliMongoDB/master/installDefli.sh)"
```
