# Defli Installation and Update Scripts
These shell scripts help to install the Defli ground station. One script installs the base Defli ground station on a new device. Another script installs the new Defli Influx Connector on new or existing ground stations. These scripts are compatible with the 64-bit version of Ubuntu 20.04, 22.04, and 23.04 as well as Rasberry Pi OS Bullseye and Bookworm. These scripts have also been used to install Defli on a Rak v2 running Crankk firmware for dual mining. 

## Influx Connector Installation Script
Use this script to install the new Infux connector on your new or existing Defli Ground station. On a fresh installation of the OS, this would be the second script to run.

### Usage
```
sudo bash -c "$(wget -O - https://raw.githubusercontent.com/dealcracker/DefliInfluxDB/master/installInflux.sh)"
```
	
## Defli Ground Station Installation Script
Use this script to install the base Defli ground station on a new device. This script also installs the graphs package. You will be prompted to enter the latitude and longitude of your ground station. Note that this script will reboot your device at the end of the installation. On a fresh installation of the OS, this would be the first script to run.

After rebooting (at the end of the installation), please run 'sudo autogain1090' and then run the Influx Connector install script.

### Usage
```
sudo bash -c "$(wget -O - https://raw.githubusercontent.com/dealcracker/DefliInfluxDB/master/installDefli.sh)"
```
