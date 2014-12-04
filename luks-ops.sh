#!/bin/bash

# Bash script for quickly managing LUKS volumes:
# You can create a virtual volume from a file block and set a LUKS partition.
# Helps you mount and unmount LUKS partitions.
# Author: John (troon) Ombagi 
# Twitter: @johntroony | Email: jayombagi <at> gmail <dot> com


################################################################################
# Variables
constant="luks_"
cryptdev=$(cat < /dev/urandom | tr -dc "[:lower:]"  | head -c 8)
logs=$(cat < /dev/urandom | tr -dc "[:lower:]"  | head -c 4)
loopdev=$(losetup -f)
temp_name="$constant$logs"

####### Some Color variables for "secsyness"
# colors for errors and statuses
red=$(tput setab 0; tput setaf 1)
yellow=$(tput setab 0; tput setaf 3)
none=$(tput sgr0)

# colors for messages
green="\033[32m"
blue="\033[34m"
normal="\033[0m"

################################################################################
## PREPS

# Print out intro banner
function intro(){
echo -e "$yellow ================================================= $none"
echo -e "$green \tLUKS-OPs for basic LUKS operations. $normal"
echo -e "$green \t\tJohn Troony $normal"
echo -e "$green \tjayombagi (at) gmail.com $normal"
echo -e "$yellow ================================================= $none"
}

# Check if required applications are installed
type -P dmsetup &>/dev/null || { echo -e "$red dmestup is not installed. Damn! $none" >&2; exit 1; }
type -P cryptsetup &>/dev/null || { echo -e "$red cryptsetup is not installed. Damn! $none" >&2; exit 1; }

# Confirm if user has root privileges
if [ $UID -ne 0 ]; then
	echo -e "$red User not root! Please run as root. $none" 
	exit 1;
fi

clear

##### FUNCTIONS 

############################################################################## 1
## Function that tries to clean up LUKS setup that did"t mount (failed)
function Clean(){
Close_luks=$(dmsetup ls | cut -d$"\t" -f 1 | xargs -I % cryptsetup luksClose %)
lo_detach=$(losetup -a | grep loop | cut -d ":" -f 1 | xargs -I % losetup -d %)
$Close_luks
$lo_detach
exit 1;
}

############################################################################## 2
# Function to Setup a new virtual volume with LUKS
function New_volume(){

#Function"s Variables
Mapper="/dev/mapper/"$cryptdev 
node="/media/"$temp_name 

# Get Size of the disk to create . If not 512 MB is used
read -p "Enter size (MB) of virtual disk to create [default 512]  " size
while [[ -z  $size  ]]; do
        size=512
done
echo -e "$green $size MB is set as your default virtual disk capacity.\n $normal"

# Get Disk Name from user. If not, a random one is used.
read -p "Enter name of virtual disk to create (default LUKS_randomString) " name
while [[ -z  $name  ]]; do
	name="$temp_name"
done

# Sanitize input (Remove special chars from filename)
name=$(echo  "$name"  | tr -dc a-zA-Z)

# Obviously, keeping the user patient :)
echo -e "$green $name is set as your default virtual disk name. (No special chars)\n $normal"
echo -e "$yellow Keep calm.. Creating File block. This might take time depending on the File size and your machine!\n $none"

# Create a block-file (virtual-disk)
base="/usr/$name"
dd if=/dev/zero of="$base" bs=1M count="$size"
echo -e  "$green \nDone creating the block file $name in /usr/ directory\n $normal"

# Create a block device from the file.
losetup "$loopdev" "/usr/$name" 2> "/tmp/$logs.log"

# variables for testing losetup	
confirm_lo=$(losetup -a | grep "$loopdev" | cut -d":" -f3 | grep \( | cut -d"(" -f2 | tr -dc a-zA-Z\/ | cut -d"/" -f3)
match="$name"

# Test if losetup is fine before we continue execution
if [[ "$confirm_lo" != "$match" ]]; then
	rm "/usr/$name"
	echo -e "$red There was a problem setting up LUKS.. Try $0 new device-name device-size\n $none"
	# For Debugs Only
	#echo "confirm LoopBack is "$confirm_lo 
	#echo "confirm Match is $match"
	Clean
	exit 1;
fi

# Select a full cipher/mode/iv specification to use. Default is aes-xts-plain64
echo -e "$green ################################################ $normal"
echo -e "$blue Select a full cipher/mode/iv specification to use $normal"
echo -e "$yellow 1) aes-cbc-essiv:sha256 2) aes-xts-plain64 3) twofish-ecb 4) serpent-cbc-plain 5) Custom $none"
read full_spec 
while [[ -z "$full_spec" ]]; do
	full_spec=2
done

# Use the selected cipher to luksformat the created Loop-device
case $full_spec in
	1) cryptsetup luksFormat -c aes-cbc-essiv:sha256 "$loopdev" 2> "/tmp/$logs.log"
	;;
	2) cryptsetup luksFormat -c aes-xts-plain64 "$loopdev" 2> "/tmp/$logs.log"
	;;
	3) cryptsetup luksFormat -c serpent-cbc-plain "$loopdev" 2>"/tmp/$logs.log"
	;;
	4) cryptsetup luksFormat -c twofish-ecb "$loopdev" 2> "/tmp/$logs.log"
	;;
	5) read -p "Specify full cipher/mode/iv to use:  " custom 
	while [[ -z "$custom " ]]; do
		echo -e "$red \nNothing entered.. Using default cipher..\n $none"
		cryptsetup luksFormat -c aes-xts-plain64 "$loopdev" 2> "/tmp/$logs.log"
	done
	cryptsetup luksFormat -c "$custom" "$loopdev" 2> "/tmp/$logs.log"
	;;
	*) echo -e "$red Bad option! I am getting a tattoo of your name! \n $none"
	exit 1;
	;;
esac

# Setup Loop-Device
cryptsetup luksOpen "$loopdev" "$cryptdev"

# variable used below in testing luksopen status
confirm_crypt=$(dmsetup ls | cut -d$'\t' -f 1 | grep "$cryptdev")

# test if luksopen was successful before proceeding
if [[ "$confirm_crypt" != "$cryptdev" ]]; then
	echo -e "$red There was a problem setting up LUKS.. Check if is  /tmp/$logs.log has anything. $none"
	echo -e "$yellow Password did notMatch or If you entered lower-case yes use YES next time.\n $none"
	#For debugs only
	#echo "CryptDevice = "$cryptdev 
	#echo "Matching cryptdev = "$confirm_cryp 
	exit 1;
fi

# Show possible setups in the system (if empty then it"s an error! Should be at least one by now)
echo -e "$green \nList of dmsetup current on your system... $normal"
dmsetup ls

# Section: Create a file system
echo

# File-System menu
echo -e "$green Select File system to use e.g 2 :\n $normal"
echo -e "$yellow 1. ext3   2. ext4   3. btrfs  4. bfs  $none"
echo -e "$yellow 5. ntfs   6. vfat   7. Other $none"
read option
while [[ -z  "$option"  ]]; do
	option=2
done

# Use option selected to make file-system (default is ext4, option 2)
case "$option" in
	1) mkfs.ext3 -L "$name"  "/dev/mapper/$cryptdev"
	;;
	2) mkfs.ext4 -L "$name"  "/dev/mapper/$cryptdev"
	;;
	3) mkfs.btrfs -L "$name"  "/dev/mapper/$cryptdev"
	;;
	4) mkfs.bfs -V "$name"  "/dev/mapper/$cryptdev"
	;;
	5) mkfs.ntfs -L "$name"  "/dev/mapper/$cryptdev"
	;;
	6) mkfs.vfat -n "$name"  "/dev/mapper/$cryptdev"
	;;
	7) read -p "Specify filesystem to use:  " fileSys
	   mkfs."$fileSys"  "/dev/mapper/$cryptdev"
	;;
	*) echo -e "$red No match found! Your option is magical?\n $none"
	Clean
	exit 1;
	;;
esac

# Print Stats/Details
echo -e "$yellow  Disk-Name:\t $name\n Path:\t\t /usr/$name\n Loop-Device:\t $loopdev\n Mapper:\t $Mapper\n Mount point:\t $node\n $none"

# mount volume
mkdir "$node"
mount  "/dev/mapper/$cryptdev" "$node"
chown -HR "$SUDO_USER" "$node"
echo -e "$yellow You can delete $node after use.\n $none"
exit 1;
}

############################################################################## 3
#Function to mount an Existing LUKS volume

function Mount_LUKSVolume(){

# Temporary mount point
node="/media/$temp_name"

# Get access to the LUKS volume
read -p "Enter Full Path to the LUKS Volume:  " volume
while [[ -z "$volume" ]]; do
	read -p "Please Enter Full Path to the LUKS Volume: " volume
done
echo -e "$blue $volume was selected.\n $normal"

# Get mount-point to use or make a temporary one to use
read -p "Enter a mount point [default /media/random_name] " mount_point
while [[ -z  "$mount_point"  ]]; do
		mkdir "$node"
        mount_point="$node"
done

# setup Loop-Device and Open LUKS with random name
losetup "$loopdev" "$volume"
cryptsetup luksOpen "$loopdev" "$cryptdev"

# Mount volume with rw permission    
mount  "/dev/mapper/$cryptdev" -rw  "$node"
chown -HR "$SUDO_USER" "$node"
echo -e "$yellow \nYou can delete $node after use.\n $none"

exit 1;
}

############################################################################## 4
# Function to Unmount a luks volume

function Unmount_LUKSVolume(){

#List of possible mounted LUKS devices 
echo -e "$yellow List of possible mounted LUKS devices $none"
mount | grep /dev/mapper

echo

# Get mount point
read -p "Enter volumes full mount point : e.g. /media/luks_disk: " path
while [[ -z  "$path"  ]]; do
	read -p "The full mount-point of the volume to unmount is required!: " path
done
echo -e "$green $path is your mount-point. $normal"

# Get the exact name of the virtual volume to be unmounted
read -p "Enter the name of the virtual disk: " diskName
while [[ -z  "$diskName"  ]]; do
	read -p "Name of the virtual disk is needed to unmount! : " diskName
done
echo -e "$green $diskName is your Vitual disk/volume Name.\n $normal"

# Create variables that identify parameters needed by cryptsetup & losetup
map_crypt=$(mount | grep "$path" | cut -d" " -f1 | cut -d"/" -f 4)
loop_dev=$(losetup -a | grep "$diskName" | cut -d ":" -f 1)

# Unmount procedure
umount "$path"
cryptsetup luksClose "$map_crypt"    # Close mapper
losetup -d "$loop_dev" 2>/tmp/luks_detach.log 
echo -e "$green Volume unmounted..\n $normal" # Detach loop-device

exit 1;
}

############################################################################## 5 
### Function to unmount all LUKS vol
function unmount_all_LUKS(){

#Some variables
umount_all=$(mount | grep mapper | cut -d " " -f 3 | xargs -I % umount %)
Close_luks=$(dmsetup ls | cut -d$'\t' -f 1 | xargs -I % cryptsetup luksClose %)
lo_detach=$(losetup -a | grep loop | cut -d":" -f 1 | xargs -I % losetup -d %)

# intro banner
intro

# Run commands in variables
$umount_all
$Close_luks
$lo_detach

# Remove all temporary created mount-points at /media/ dir
rm -r /media/luks_* 2> /dev/null

# Make the user feel good :)
echo -e "$red All LUKS volumes Safely unmounted\n $none"
exit 1;
}

############################################################################## 6
### Function for the options menu
function Main_menu(){
intro
echo -e "$green Select one of the option\n $normal"
select option in "New Volumes" "Mount an existing vol" "Unmount a vol" "Unmount all" "Clean after setup fail" "quit"
do
	case "$option" in
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
		*) echo -e "$red  Option not found! What did you do there? $none";;
	esac
done
}

############################################################################## 7 
### Help Function 

function usage(){
echo -e "$yellow \t++++++++++++++++++++++++++++++++++++++ $none"
echo -e "$green \tHow to use LUKS-OPs. In () are optional $normal"
echo -e "$yellow \t++++++++++++++++++++++++++++++++++++++ $none"
echo -e "$blue $0 menu $normal"
echo -e "$blue $0 new disk_Name Size_in_numbers $normal"
echo -e "$blue $0 mount /path/to/device (mount point)  $normal"
echo -e "$blue $0 unmount-all $normal"
echo -e "$blue $0 clean $normal"
echo -e "$blue $0 usage $normal"
echo
exit 1;
}
#### End of FUNCTIONS

################################################################################
# Main : where script execution starts

# If running script with no arguments then get the option menu.
if [ $# -lt 1 ]; then
		Main_menu
fi

# If running script with expected arguments(s), get served, if not get help. 
case "$1" in 
	new) # Creating new LUKS volume (args should be exactly 3; new Name Size)
	if [ $# != 3 ]; then
		usage
	fi
	
	# Print some basic default options
	echo -e "$red Notice: $none"
	echo -e "$yellow Default Cipher = aes-xts-plain64 $none"
	echo -e "$yellow Default File System = ext4 $none"
	echo -e "$green ===================================== $normal"
	
	if [[ ! "$3" =~ [0-9] ]]; then
		echo -e "$red invalid size number for Block file! $none"
		usage
	else
	
	# Remove special chars from filename
	name=$(echo "$2" | tr -dc a-zA-Z)
	
	#Create the LUKS virtual volume 	
	echo -e "$yellow Keep calm.. Creating File block. This might take time depending on the File size and your machine!\n $none" 
	dd if=/dev/zero of=/usr/"$name" bs=1M count="$3"
	echo -e "$green \nBlock file created - /usr/$name \n $normal"
	
	# Loop device setup
	loopdev=$(losetup -f)
	losetup "$loopdev" "/usr/$name"
	
	# Variable for losetup test
	confirm_lo=$(losetup -a | grep "$loopdev" | cut -d":" -f3 | grep \( | cut -d"(" -f2 | tr -dc a-zA-Z\/ | cut -d"/" -f3)

	# Test if losetup is fine before we continue execution
	if [[ "$confirm_lo" != "$name" ]]; then
		rm "/usr/$name"
		echo -e "$red There was a problem setting up LUKS.. Try $0 new Name Size\n $none"
		# For Debugs
		#echo -e "$yellow confirm Loop-device is "$confirm_lo"\n Confirm-Match is "$name"\n $none"
		#echo -e "$red If the Loop-device is not the same as Confirm-Match... ERROR $none"
		
		Clean
		exit 1;
	fi
	
	# LUKS format with default cipher
	cryptsetup luksFormat -c aes-xts-plain64 "$loopdev"
	echo 
	
	# Open LUKS with a random name
	cryptdev=$(cat < /dev/urandom | tr -dc "[:lower:]" | head -c 8)
	cryptsetup luksOpen "$loopdev" "$cryptdev"
	echo
	
	# Variable to used below to test for luksopen command status
	confirm_crypt=$(dmsetup ls | cut -d$'\t' -f 1 | grep "$cryptdev")
	
	# Testing luksopen command worked fine before proceeding
	if [[ "$confirm_crypt" != "$cryptdev" ]]; then
		echo -e "$red There was a problem setting up LUKS.. Check if is /tmp/$logs.log has anything. $none"
		echo -e "$yellow Password did notMatch or If you entered lower-case yes use YES next time.\n $none"
		#For debugs
		#echo -e "$yellow CryptDevice = "$cryptdev"\n Matching-cryptdev = $confirm_cryp $none"
		#echo -e "$red If CryptDevice is not equal to Matching-cryptdev.. ERROR! $none"
		exit 1;
	fi
	
	# Create default File System (ext4)
	echo -e "$yellow Creating filesystem...... $none"
	mkfs.ext4 -L "$name"  "/dev/mapper/$cryptdev"
	echo
	fi
	echo -e "$green MOUNT : yes/no\n  $normal"
	
	# Mount the volume if the user accepts	
	read -p "LUKS Virtual disk created, mount it? yes/no :" mount_new
	if [ "$mount_new" == "yes" ]; then
		mkdir  /media/"$temp_name"
		mount  "/dev/mapper/$cryptdev" "/media/$temp_name"
		chown -HR "$SUDO_USER" "/media/$temp_name"
		echo -e "$green You can delete /media/$temp_name after use.\n $normal"
	else
		echo -e "$red Closing... $none"
	fi
	
	#print stats and exit
	echo -e "$yellow  Disk-Name:\t $name\n Path:\t\t /usr/$name\n Loop-Device:\t $loopdev\n Mapper:\t /dev/mapper/$cryptdev\n $none"
	exit 1;
	;;
	mount) # Mounting a LUKS volume (args shouldn"t be less than 2; mount and mount-point).
	if [ $# -lt 2 ]; then
		usage
	fi
	
	if [ $# -eq 3 ]; then  # Check if custom mount-point is supplied by user.
		mount_point="$3"
	else
		mkdir "/media/$temp_name"   # If no custom mount-point use default one.
        mount_point="/media/$temp_name" 
	fi
	
	# Setup Loop-Device and open LUKS with random name
	losetup "$loopdev" "$2"
	cryptsetup luksOpen "$loopdev" "$cryptdev"
	
	# Mount the volume and enable rw for other sudo user
    mount  "/dev/mapper/$cryptdev" -rw  "$mount_point" 2>/dev/null && echo -e "$yellow LUKS Virtual disk mounted $none"
	chown -HR "$SUDO_USER" "$mount_point"
	echo -e "$yellow  Mounted at:\t $mount_point\n Path to disk:\t\t $2\n Loop-Device:\t $loopdev\n Mapper:\t  /dev/mapper/$cryptdev\n $none"
	echo -e "$yellow NB: You can delete $mount_point after use. $none"
	exit 1;	
	;;
	
	unmount-all)  # Unmount all present LUKS volumes on the System (only 1 arg accepted)
	if [ $# -eq 1 ]; then
		unmount_all_LUKS
	else
		usage
	fi 
	;;
	
	clean) # Clean setups after a fail before proceeding. (only 1 arg accepted)
	if [ $# -eq 1 ]; then
		Clean
	else
		usage
	fi
	;;
	
	menu) # Get option menu if arguments are not more than one. (only 1 arg accepted)
	if [ $# -eq 1 ]; then
		Main_menu
	else
		usage
	fi
	;;
	
	help) # (usage func) Print help message and exit
	usage
	;;
	*) echo -e "$red Oooops! I did notget what you did there..  $none" # (usage func) Print help message and exit
	usage
	;;
esac
