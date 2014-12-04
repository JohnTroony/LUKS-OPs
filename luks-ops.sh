#!/bin/bash

# Bash script for quickly managing LUKS volumes:
# You can create a virtual volume from a file block and set a LUKS partition.
# Helps you mount and unmount LUKS partitions.
# Author: John (troon) Ombagi 
# Twitter: @johntroony | Email: jayombagi <at> gmail <dot> com


################################################################################
# Variables
constant="luks_"
disk_name=$(cat /dev/urandom | tr -dc 'a-z'| head -c 6)
cyptDev=$(cat /dev/urandom | tr -dc 'a-z'| head -c 8)
logs=$(cat /dev/urandom | tr -dc 'a-z'| head -c 4)
loopDev=$(losetup -f)
temp_name=$constant$logs

#Some Color variables for "secsyness"
red=$(tput setab 0; tput setaf 1)
yellow=$(tput setab 0; tput setaf 3)
none=$(tput sgr0)

green="\033[32m"
blue="\033[34m"
normal="\033[0m"

################################################################################
# Print out intro banner
function intro(){
echo -e $yellow"================================================="$none
echo -e $green"\tLUKS-OPs for basic LUKS operations."$normal
echo -e $green"\t\tJohn Troony"$normal
echo -e $green"\tjayombagi (at) gmail.com"$normal
echo -e $yellow"================================================="$none
}

# Check if required applications are installed
type -P dmsetup &>/dev/null || { echo -e $red"dmestup is not installed. Damn!"$none >&2; exit 1; }
type -P cryptsetup &>/dev/null || { echo -e $red"cryptsetup is not installed. Damn!"$none >&2; exit 1; }

# Confirm if user has root privileges
if [ $UID -ne 0 ]; then
	echo -e $red"User not root! Please run as root."$none 
	exit 1;
fi

clear

##### FUNCTIONS 

############################################################################## 1
## Function that tries to clean up LUKS setup that didn't mount (failed)
function Clean(){
Close_luks=$(dmsetup ls | cut -d$'\t' -f 1 | xargs -I % cryptsetup luksClose %)
lo_detach=$(losetup -a | grep loop | cut -d ":" -f 1 | xargs -I % losetup -d %)
$Close_luks
$lo_detach
exit 1;
}

############################################################################## 2
# Function to Setup a new virtual volume with LUKS
function New_volume(){
#Function Variables


# Get Size of the disk to create . If not 512 MB is used
read -p "Enter size (MB) of virtual disk to create [default 512]  " size
while [[ -z "$size" ]]; do
        size=512
done
echo -e $green"$size MB is set as your default virtual disk capcity.\n"$normal

# Get Disk Name from user. If not, a random one is used.
read -p "Enter name of virtual disk to create (default LUKS_random.disk)  " name
while [[ -z "$name" ]]; do
	name=$temp_name
done
echo -e $green"$name is set as your default virtual disk name.\n"$normal

echo -e $yellow"Keep calm.. Creating File block. This might take time depending on the File size and your machine!\n"$none
# Create a block-file (virtual-disk)
dd if=/dev/zero of=/usr/$name bs=1M count=$size
echo -e  $green"\nDone creating the block file $name in /usr/ directory\n"$normal

# Create a block device from the file.

losetup $loopDev /usr/$name 2>/tmp/$logs.log
confirm_lo=$(losetup -a | grep /dev/loop0 | cut -d':' -f3 | grep \( | cut -d'(' -f2 | tr -dc a-zA-Z\/ | cut -d'/' -f3)
match="luks"$logs
echo "confirm LoopBack is $confirm_lo"
echo "confirm Match is $match"
if [[ $confirm_lo != $match ]]; then
	rm /usr/$name
	echo -e $red"There was a problem setting up LUKS.. Try '$0 new device-name device-size'\n"$none
	Clean
	exit 1;
fi

# Select a full cipher/mode/iv specification to use. Default is aes-xts-plain64
echo -e $green"################################################"$normal
echo -e $blue"Select a full cipher/mode/iv specification to use"$normal
echo -e $yellow"1) aes-cbc-essiv:sha256 2) aes-xts-plain64 3) twofish-ecb 4) serpent-cbc-plain 5) Custom"$none
read full_spec 
while [[ -z "$full_spec" ]]; do
	full_spec=2
done

# Use the selected cipher to luksformat the created Loop-device
case $full_spec in
	1) cryptsetup luksFormat -c aes-cbc-essiv:sha256 $loopDev 2>/tmp/$logs.log
	;;
	2) cryptsetup luksFormat -c aes-xts-plain64 $loopDev 2>/tmp/$logs.log
	;;
	3) cryptsetup luksFormat -c serpent-cbc-plain $loopDev 2>/$logs.log
	;;
	4) cryptsetup luksFormat -c twofish-ecb $loopDev 2>/tmp/$logs.log
	;;
	5) read -p "Specify full cipher/mode/iv to use:  " custom 
	while [[ -z "$custom " ]]; do
		echo -e $red"\nNothing entered.. Using default cipher..\n"$none
		cryptsetup luksFormat -c aes-xts-plain64 $loopDev 2>/tmp/$logs.log
	done
	cryptsetup luksFormat -c $custom $loopDev 2>/tmp/$logs.log
	;;
	*) echo -e $red"Bad option! I'm getting a tatoo of your name! \n"$none
	exit 1;
	;;
esac

### DEBUGS
#confirm_crypt=$(dmsetup ls | cut -d$'\t' -f 1 | grep $cyptDev)
#echo "CryptDevice = $cyptDev"
#echo "Matching CyptDev = $confirm_cryp"
#if [[ $confirm_crypt != $cyptDev ]]; then
#	echo -e $red"There was a problem setting up LUKS.. check /tmp/$logs.log\n"$none
#	exit 1;
#fi

cryptsetup luksOpen $loopDev $cyptDev

echo -e $green"\nList of dmsetup current on your system..."$normal
dmsetup ls

# Create a file system
echo
echo -e $green"Select File system to use e.g 2 :\n"$normal
echo -e $yellow"1. ext3   2. ext4   3. btrfs  4. bfs "$none
echo -e $yellow"5. ntfs   6. vfat   7. Other"$none
read option
while [[ -z "$option " ]]; do
	$option=2
done

case $option in
	1) mkfs.ext3 -L $name /dev/mapper/$cyptDev
	;;
	2) mkfs.ext4 -L $name /dev/mapper/$cyptDev
	;;
	3) mkfs.btrfs -L $name /dev/mapper/$cyptDev
	;;
	4) mkfs.bfs -V $name /dev/mapper/$cyptDev
	;;
	5) mkfs.ntfs -L $name /dev/mapper/$cyptDev
	;;
	6) mkfs.vfat -n $name /dev/mapper/$cyptDev
	;;
	7) read -p "Specify filesystem to use:  " fileSys
	   mkfs.$fileSys /dev/mapper/$cyptDev
	;;
	*) echo -e $red"No match found! Your option is magical?\n"$none
	exit 1;
	;;
esac

#mount
node="/media/$temp_name"
mkdir $node
mount /dev/mapper/$cyptDev $node
chown -HR $SUDO_USER $node
echo -e $yellow"You can delete $node after use.\n"$none
exit 1;
}

############################################################################## 3
#Function to mount an Existing LUKS volume

function Mount_LUKSVolume(){

node="/media/$temp_name"
read -p "Enter Full Path to the LUKS Volume:  " volume
while [[ -z "$volume" ]]; do
	read -p "Please Enter Full Path to the LUKS Volume: " volume
done
echo -e $blue"$volume was selected.\n"$normal

read -p "Enter a mount point [default /media/random_name] " mount_point
while [[ -z "$mount_point" ]]; do
		mkdir $node
        mount_point=$node
done

losetup $loopDev $volume
cryptsetup luksOpen $loopDev $cyptDev
    
mount /dev/mapper/$cyptDev -rw  $node
chown -HR $SUDO_USER $node
echo -e $yellow"\nYou can delete $node after use.\n"$none

exit 1;
}

############################################################################## 4
# Function to Unmount a luks volume

function Unmount_LUKSVolume(){

# Get full path of the virtual volume to unmount
#List of possible mounted LUKS devices 
echo -e $yellow"List of possible mounted LUKS devices"$none
mount | grep /dev/mapper

echo
read -p "Enter volume's full mount point : e.g. /media/luks_disk: " path
while [[ -z "$path" ]]; do
	read -p "The full mount-point of the volume to unmount is required!: " path
done
	
echo -e $green"$path is your mount-point."$normal

# Get the exact name of the virtual volume to be unmounted
read -p "Enter the name of the virtual disk: " diskName
while [[ -z "$diskName" ]]; do
	read -p "Name of the virtual disk is needed to unmount! : " diskName
done
echo -e $green"$diskName is your Vitual disk/volume Name.\n"$normal

# Create varibles that identify parameters needed by cryptsetup & losetup
map_crypt=$(mount | grep $path | cut -d" " -f1 | cut -d"/" -f 4)
loop_dev=$(losetup -a | grep $diskName | cut -d ":" -f 1)

# Unmounting procedure
umount $path
cryptsetup luksClose $map_crypt    # Close mapper
losetup -d $loop_dev 2>/tmp/luks_detach.log 
echo -e $green"Volume unmounted..\n"$normal # Detach loop-device
exit 1;

}

############################################################################## 5 
### Function to unmount all LUKS vol
function unmount_all_LUKS(){

#Some variables
umount_all=$(mount | grep mapper | cut -d " " -f 3 | xargs -I % umount %)
Close_luks=$(dmsetup ls | cut -d$'\t' -f 1 | xargs -I % cryptsetup luksClose %)
lo_detach=$(losetup -a | grep loop | cut -d ":" -f 1 | xargs -I % losetup -d %)

intro
# Run commands in variables
$umount_all
$Close_luks
$lo_detach

rm -r /media/luks_* 2> /dev/null

echo -e $red"All LUKS volume(s) Safely unmounted\n"$none
exit 1;
}

############################################################################## 6
### Function for the options menu
function Main_menu(){
intro
echo -e $green"Select one of the option\n"$normal
select option in "New Volumes" "Mount an existing vol" "Unmount a vol" "Unmount all" "Clean after setup fail" "quit"
do
	case $option in
		"New Volumes") New_volume
		;;
		"Mount an existing vol") Mount_LUKSVolume
		;;
		"Unmount a vol") Unmount_LUKSVolume
		;;
		"Unmount all") unmount_all_LUKS
		;;
		"Clean after setup fail") Clean
		;;
		"quit") exit 1;
		;;
		*) echo -e $red" Option not found! What did you do there?"$none;;
	esac
done
}

############################################################################## 7 
### Help Fuction 

function usage(){
echo -e $yellow"\t++++++++++++++++++++++++++++++++++++++"$none
echo -e $green"\tHow to use LUKS-OPs. In () are optional"$normal
echo -e $yellow"\t++++++++++++++++++++++++++++++++++++++"$none
echo -e $blue"$0 menu"$normal
echo -e $blue"$0 new disk_Name Size_in_numbers"$normal
echo -e $blue"$0 mount /path/to/device (mountpoint) "$normal
echo -e $blue"$0 unmount-all"$normal
echo -e $blue"$0 clean"$normal
echo -e $blue"$0 usage"$normal
echo
exit 1;
}
#### End of FUNCTIONS

################################################################################
# Main : where script execution starts

# If running script with no argumets then get the option menu.
if [ $# -lt 1 ]; then
		Main_menu
fi

# If running script with expected arguments(s), get served, if not get help. 
case "$1" in 
	new) # Creating new LUKS volume
	if [ $# != 3 ]; then
		usage
	fi
	
	echo -e $red"Notice:"$none
	echo -e $yellow"Default Cipher = aes-cbc-essiv:sha256 "$none
	echo -e $yellow"Default FileSystem = ext4"$none
	echo -e $green"====================================="$normal
	
	if [[ ! $3 =~ [0-9] ]]; then
		echo -e $red"invalid size number for Block file!"$none
		usage
	else
	
	#Create the LUKS virtual volume 	
	echo -e $yellow"Keep calm.. Creating File block. This might take time depending on the File size and your machine!\n"$none 
	dd if=/dev/zero of=/usr/$2 bs=1M count=$3
	echo -e $green"\nBlock file created - /usr/$2 \n"$normal
	
	loopDev=$(losetup -f)
	losetup $loopDev /usr/$2
	cryptsetup luksFormat -c aes-cbc-essiv:sha256 $loopDev
	echo 
	
	cyptDev=$(cat /dev/urandom | tr -dc 'a-z'| head -c 8)
	cryptsetup luksOpen $loopDev $cyptDev
	echo
	
	echo -e $yellow"Creating filesystem......"$none
	mkfs.ext4 -L $2 /dev/mapper/$cyptDev
	echo
	fi
	echo -e $green"DONE!!!\n"$normal
	echo -e $yellow"Virtual-Disk:\t /usr/$2\n Loop-Device:\t $loopDev\n Mapper:\t /dev/mapper/$cyptDev\n"$none
	
	read -p "LUKS Virtual disk created, mount it? yes/no :" mount_new
	if [ $mount_new == "yes" ]; then
		mkdir  /media/$temp_name
		mount /dev/mapper/$cyptDev /media/$temp_name
		chown -HR $SUDO_USER /media/$temp_name
		echo -e $green"You can delete '/media/$temp_name' after use.\n"$normal
	else
		echo -e $red"Closing..."$none
		exit 1;
	fi
	;;
	mount) # Mounting a LUKS volume
	if [ $# -lt 2 ]; then
		usage
	fi
	
	if [ $# -eq 3 ]; then
		mount_point="$3"
	else
		mkdir /media/$temp_name
        mount_point="/media/$temp_name"
	fi
	
	losetup $loopDev $2
	cryptsetup luksOpen $loopDev $cyptDev
	
    mount /dev/mapper/$cyptDev -rw  $mount_point 2>/dev/null && echo -e $yellow"LUKS Virtual disk mounted"$none
	chown -HR $SUDO_USER $mount_point
	echo -e $yellow"You can delete $mount_point after use."$none
	exit 1;	
	
	;;
	
	unmount-all)  # Unmount all present LUKS volumes on the System
	if [ $# -eq 1 ]; then
		unmount_all_LUKS
	else
		usage
	fi 
	;;
	
	clean) # Clean setups after a fail before proceding.
	if [ $# -eq 1 ]; then
		Clean
	else
		usage
	fi
	;;
	
	menu) # Get option menu if arguments are not more than one.
	if [ $# -eq 1 ]; then
		Main_menu
	else
		usage
	fi
	;;
	
	help) 
	usage
	;;
	*) echo -e $red"Oops! I didn't get what you did there.. "$none
	usage
	;;
esac
