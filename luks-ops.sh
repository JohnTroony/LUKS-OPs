#!/bin/bash

# Bash script for quickly managing LUKS volumes:
# You can create a virtual volume from a file block and set a LUKS partition.
# Helps you mount and unmount LUKS partitions.
# Author: John (Troon) Ombagi
# Twitter: @johntroony | Email: jayombagi <at> gmail <dot> com


################################################################################
# Variables
constant="luks_"
cryptdev=$(cat < /dev/urandom | tr -dc "[:lower:]"  | head -c 8)
logs=$(cat < /dev/urandom | tr -dc "[:lower:]"  | head -c 4)
temp_name="$constant$logs"
now=$(date +"-%b-%d-%y-%H%M%S")


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
type -P dmsetup &>/dev/null || { echo -e "$red dmestup is not installed. Damn! $none" >> "$LOGFILE" 2>&1; exit 1; }
type -P cryptsetup &>/dev/null || { echo -e "$red cryptsetup is not installed. Damn! $none" >> "$LOGFILE" 2>&1; exit 1; }

# Confirm if user has root privileges
if [ $UID -ne 0 ]; then
	echo -e "$red User not root! Please run as root. $none"
	exit 1;
fi

clear

# Variable that requires super-user to be set
loopdev=$(losetup -f)
##### FUNCTIONS 

############################### a
function choose_disk(){
# Get Disk Name from user. If not, a random one is used.
read -p "Enter USB/Removable Disk to Format (e.g. /dev/sdx) : " disk
while [[ -z  $disk  ]]; do
read -p "You must enter USB/Removable Disk to Format: " disk	
done
}



################################ c
function confirm_disk(){
#Confirm if the Disk is correctly SET
read -p "Are you sure you want to use $disk ? YES/NO : " confirm
while [[ -z  $confirm  ]]; do
read -p "Please confirm with 'YES' or deny with 'NO': " confirm	
done

if [ $confirm == 'YES' ]; then
echo -e "$red \n We are going to use $disk \n $normal"

elif [ $confirm == 'NO' ]; then
echo -e "$red \n Please select another DISK to use... \n $normal"
choose_disk

else
confirm_disk

fi

}


################################ b
function check_disk(){
# Check if file already exists.
while [ ! -e "$disk" ]; do
   	echo -e "$red Disk selected is not available! ($disk) $none"
   	echo -e "$yellow Please use another Disk $none"
   	choose_disk
   	confirm_disk
   	
done
}
############################################################################## 1
## Function that tries to clean up LUKS setup that did not't mount (failed)
function Clean(){
Close_luks=$(dmsetup ls | cut -d$'\t' -f 1 | xargs -I % cryptsetup luksClose %)
lo_detach=$(losetup -a | grep loop | cut -d':' -f 1 | xargs -I % losetup -d %)
$Close_luks >> "$LOGFILE" 2>&1
$lo_detach >> "$LOGFILE" 2>&1

echo -e "$yellow Log File : $LOGFILE $none"
exit 1;
}

############################################################################## 2
# Function to Setup a new virtual volume with LUKS
function New_volume(){

#Function's Variables
Mapper="/dev/mapper/$cryptdev"
node="/media/$temp_name"

# Get Size of the disk to create . If not 512 MB is used
read -p "Enter size (MB) of virtual disk to create [default 512]  " size
while [[ -z  $size  ]]; do
    size=512
done

if [[ ! "$size" =~ [0-9] ]]; then
	echo -e "$red invalid size number for Block file! $none"
	exit 1;
else
size=$(echo  "$size"  | tr -dc 0-9)
echo -e "$green $blue $size MB $normal is set as your default virtual disk capacity. (Numbers Only) \n $normal"
fi
	
# Get Disk Name from user. If not, a random one is used.
read -p "Enter name of virtual disk to create (default LUKS_randomString) " name
while [[ -z  $name  ]]; do
	name="$temp_name"
done

# Remove special chars from name
name=$(echo  "$name"  | tr -dc a-zA-Z)

# Check if file already exists.
if [ -f "/usr/$name" ]; then
   	echo -e "$red A Disk Named $name is already available! (/usr/$name) $none"
   	echo -e "$yellow Please use another Disk Name or delete the existing file$none"
   	exit 1;
else
	# sanitize input (Remove special chars from filename)
	echo -e "$green $blue $name $normal is set as your default virtual disk name. (No special chars). \n $normal"
fi

# Obviously, keeping the user patient :)
echo -e "$yellow Keep calm.. Creating File Block. This might take time depending on the File size and your machine! \n $none"

# Create a block-file (virtual-disk)
base="/usr/$name"
dd if=/dev/zero of="$base" bs=1M count="$size" >> "$LOGFILE" 2>&1
echo -e  "$green \nDone creating the block file $name in /usr/ directory. \n $normal"

# Create a block device from the file.
losetup "$loopdev" "/usr/$name" >> "$LOGFILE" 2>&1

# variables for testing losetup	(loop-device setup)
confirm_lo=$(losetup -a | grep "$loopdev" | grep -o -P '(?<=\().*(?=\))')
confirm_final=${confirm_lo##*/}
match="$name"

# Test if losetup is fine before we continue execution
if [[ "$confirm_final" != "$match" ]]; then
	echo -e "$red There was a problem setting up LUKS.. Try $0 new device-name device-size. \n $none"
	echo -e "$yellow Check Log file $LOGFILE $none"
	rm "$base" >> "$LOGFILE" 2>&1
	
	# For Debugs Only
	#echo "confirm Loop Back is $confirm_final"
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
	1) cryptsetup luksFormat -c aes-cbc-essiv:sha256 "$loopdev"
	;;
	2) cryptsetup luksFormat -c aes-xts-plain64 "$loopdev"
	;;
	3) cryptsetup luksFormat -c serpent-cbc-plain "$loopdev"
	;;
	4) cryptsetup luksFormat -c twofish-ecb "$loopdev"
	;;
	5) read -p "Specify full cipher/mode/iv to use:  " custom 
	while [[ -z "$custom" ]]; do
		echo -e "$red \nNothing entered.. Using default cipher..\n $none"
		cryptsetup luksFormat -c aes-xts-plain64 "$loopdev"
	done
	cryptsetup luksFormat -c "$custom" "$loopdev"
	;;
	*) echo -e "$red Bad option! I am getting a tattoo of your name! \n $none"
	exit 1;
	;;
esac

# Setup Loop-Device
cryptsetup luksOpen "$loopdev" "$cryptdev" >> "$LOGFILE" 2>&1

# variable used below in testing luksopen status
confirm_crypt=$(dmsetup ls | cut -d$'\t' -f 1 | grep "$cryptdev")

# test if luksopen was successful before proceeding
if [[ "$confirm_crypt" != "$cryptdev" ]]; then
	echo -e "$red There was a problem setting up LUKS.. Check Log file $LOGFILE . $none"
	echo -e "$yellow Password did not Match or If you entered lower-case yes use YES next time.\n $none"
	rm "$base" >> "$LOGFILE" 2>&1
	#For debugs only
	#echo "CryptDevice = "$cryptdev 
	#echo "Matching cryptdev = "$confirm_cryp 
	exit 1;
fi

# Show possible setups in the system (if empty then it's an error! Should be at least one by now)
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
	1) mkfs.ext3 -L "$name"  "/dev/mapper/$cryptdev" >> "$LOGFILE" 2>&1
	;;
	2) mkfs.ext4 -L "$name"  "/dev/mapper/$cryptdev" >> "$LOGFILE" 2>&1
	;;
	3) mkfs.btrfs -L "$name"  "/dev/mapper/$cryptdev" >> "$LOGFILE" 2>&1
	;;
	4) mkfs.bfs -V "$name"  "/dev/mapper/$cryptdev" >> "$LOGFILE" 2>&1
	;;
	5) mkfs.ntfs -L "$name"  "/dev/mapper/$cryptdev" >> "$LOGFILE" 2>&1
	;;
	6) mkfs.vfat -n "$name"  "/dev/mapper/$cryptdev" >> "$LOGFILE" 2>&1
	;;
	7) read -p "Specify file system to use:  " fileSys
	   mkfs."$fileSys"  "/dev/mapper/$cryptdev" >> "$LOGFILE" 2>&1
	;;
	*) echo -e "$red No match found! Your option is magical? \n $none"
	Clean
	exit 1;
	;;
esac

# Print Stats/Details
echo -e "$yellow Disk-Name:\t $name\n Path:\t\t /usr/$name\n Loop-Device:\t $loopdev\n Mapper:\t $Mapper\n Mount point:\t $node\n $none"

# mount volume
mkdir "$node" >> "$LOGFILE" 2>&1
mount  "/dev/mapper/$cryptdev" "$node" >> "$LOGFILE" 2>&1
chown -HR "$SUDO_USER" "$node" >> "$LOGFILE" 2>&1
echo -e "$yellow You can delete $node after use. Logs at $LOGFILE \n $none"

echo -e "$yellow Log File : $LOGFILE $none"
exit 1;
}


############################################################################## 3
# Function to Setup a new USB/Removable volume with LUKS

function USB_volume(){

#Function's Variables
Mapper="/dev/mapper/$cryptdev"
node="/media/$temp_name"


# Get list of all available disks to create.
echo -e "$green Probing for all the Disks available in the System: \n $normal"
lshw -class disk | grep "logical name"

echo -e "$red \n WARNING!: Please CHOOSE the correct disk, using a wrong disk drive WILL destroy your data! \n $normal"

# Call function to select Disk to use
choose_disk

# Call function to check if Disk Exist
check_disk

# Call function to confirm the selectes Disk to use
confirm_disk


echo -e "$red \n WARNING!: Make sure you've a backup of the data in the volume : $disk \n $normal"

for n in "$disk""*" ; do umount $n ; done

# TO-DO: Prepare the Removable device 
#base="/usr/$name"
#dd if=/dev/zero of="$base" bs=1M count="$size" >> "$LOGFILE" 2>&1
#echo -e  "$green \nDone creating the block file $name in /usr/ directory. \n $normal"

(echo o; echo n; echo p; echo 1; echo ; echo; echo w) | fdisk $disk

disk2="$disk""1"
if [ -z $disk2 ]; then
   	echo -e "$red I can't confirm if the Removable Storage device was partitioned $none"
   	echo -e "$yellow Please confirm if $disk2 exist $none"
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
	1) cryptsetup --verify-passphrase luksFormat -c aes-cbc-essiv:sha256 "$disk2"
	;;
	2) cryptsetup --verify-passphrase luksFormat -c aes-xts-plain64 "$disk2"
	;;
	3) cryptsetup --verify-passphrase luksFormat -c serpent-cbc-plain "$disk2"
	;;
	4) cryptsetup --verify-passphrase luksFormat -c twofish-ecb "$disk2"
	;;
	5) read -p "Specify full cipher/mode/iv to use:  " custom 
	while [[ -z "$custom" ]]; do
		echo -e "$red \nNothing entered.. Using default cipher..\n $none"
		cryptsetup --verify-passphrase luksFormat -c aes-xts-plain64 "$disk2"
	done
	cryptsetup --verify-passphrase luksFormat -c "$custom" "$disk2"
	;;
	*) echo -e "$red Bad option! I am getting a tattoo of your name! \n $none"
	exit 1;
	;;
esac

# Setup Loop-Device
cryptsetup luksOpen "$disk2" "$cryptdev" >> "$LOGFILE" 2>&1

# variable used below in testing luksopen status
confirm_crypt=$(dmsetup ls | cut -d$'\t' -f 1 | grep "$cryptdev")

# test if luksopen was successful before proceeding
if [[ "$confirm_crypt" != "$cryptdev" ]]; then
	echo -e "$red There was a problem setting up LUKS.. Check Log file $LOGFILE . $none"
	echo -e "$yellow Password did not Match or If you entered lower-case yes use YES next time.\n $none"
	rm "$base" >> "$LOGFILE" 2>&1
	#For debugs only
	#echo "CryptDevice = "$cryptdev 
	#echo "Matching cryptdev = "$confirm_cryp 
	exit 1;
fi

# Show possible setups in the system (if empty then it's an error! Should be at least one by now)
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
	option=6
done

# Use option selected to make file-system (default is ext4, option 2)
case "$option" in
	1) mkfs.ext3 -L "$name"  "/dev/mapper/$cryptdev" >> "$LOGFILE" 2>&1
	;;
	2) mkfs.ext4 -L "$name"  "/dev/mapper/$cryptdev" >> "$LOGFILE" 2>&1
	;;
	3) mkfs.btrfs -L "$name"  "/dev/mapper/$cryptdev" >> "$LOGFILE" 2>&1
	;;
	4) mkfs.bfs -V "$name"  "/dev/mapper/$cryptdev" >> "$LOGFILE" 2>&1
	;;
	5) mkfs.ntfs -L "$name"  "/dev/mapper/$cryptdev" >> "$LOGFILE" 2>&1
	;;
	6) mkfs.vfat -n "$name"  "/dev/mapper/$cryptdev" >> "$LOGFILE" 2>&1
	;;
	7) read -p "Specify file system to use:  " fileSys
	   mkfs."$fileSys"  "/dev/mapper/$cryptdev" >> "$LOGFILE" 2>&1
	;;
	*) echo -e "$red No match found! Your option is magical? \n $none"
	Clean
	exit 1;
	;;
esac

ryptsetup luksDump $disk2

# Print Stats/Details
echo -e "$yellow Disk-Name:\t $disk\n Partition:\t $disk2\n	 Mapper:\t $Mapper\n Mount point:\t $node\n $none"

# mount volume
mkdir "$node" >> "$LOGFILE" 2>&1
mount  "/dev/mapper/$cryptdev" "$node" >> "$LOGFILE" 2>&1
chown -HR "$SUDO_USER" "$node" >> "$LOGFILE" 2>&1
echo -e "$yellow You can delete $node after use. Logs at $LOGFILE \n $none"

echo -e "$yellow Log File : $LOGFILE $none"
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

# Check if Path to LUKS volume exist
if [ ! -f "$volume" ]; then
   	echo -e "$red LUKS Volume:$volume entered is not available! $none"
    exit 1;
else
    echo -e "$blue $volume was selected as the Path to LUKS volume. \n $normal"
fi

Disk_Path=$(losetup -a | grep $volume | grep -o -P '(?<=\().*(?=\))')

if [[ $volume == $Disk_Path ]]; then
	echo -e "$red Disk $volume is already mounted!.. If you are not using any LUKS device do either:$none"
	echo -e "$green 1. $0 unmount-all$normal $blue (After using disks or fatal/unknown error) $normal" 
	echo -e "$green 2. $0 clean $normal $blue (after a failed setup) $normal"
	exit 1;
fi

# Get mount-point to use or make a temporary one to use
read -p "Enter a mount point [default /media/random_name] " mount_point
while [[ -z  "$mount_point"  ]]; do
		mkdir "$node" >> "$LOGFILE" 2>&1
        mount_point="$node"
done

# Check if Mount-point for the LUKS volume exist
if [ ! -d "$mount_point" ]; then
   	echo -e "$red Mount Point:$mount_point entered is not available! $none"
    exit 1;
else
    echo -e "$blue $mount_point is selected as the Mount Point. \n $normal"
fi


# setup Loop-Device and Open LUKS with random name
losetup "$loopdev" "$volume" >> "$LOGFILE" 2>&1
cryptsetup luksOpen "$loopdev" "$cryptdev" >> "$LOGFILE" 2>&1

# Mount volume with rw permission    
mount  "/dev/mapper/$cryptdev" -rw  "$node" >> "$LOGFILE" 2>&1
chown -HR "$SUDO_USER" "$node" >> "$LOGFILE" 2>&1
echo -e "$yellow \nYou can delete $node after use. \n $none"
echo -e "$yellow Log File : $LOGFILE $none"

exit 1;
}

############################################################################## 4
# Function to Unmount a luks volume

function Unmount_LUKSVolume(){

#List of possible mounted LUKS devices 
echo -e "\n $blue List of mount points of current mounted LUKS devices $normal"
mount | grep /dev/mapper | cut -d" " -f 3

# Print present mounted devices
echo -e "\n $blue List of mounted LUKS devices $normal"
Disk_Path=$(losetup -a |grep -o -P '(?<=\().*(?=\))')
echo -e "$green  Disk Path:\t Disk Name. $normal"
for i in $Disk_Path; do 
	echo -e "  $i\t ${i##*/}"
done
echo

# Get mount point
read -p "Enter volumes full mount point : e.g. /media/luks_disk: " path
while [[ -z  "$path"  ]]; do
	read -p "The full mount-point of the volume to unmount is required!: " path
done

# Check if Mount-point for the LUKS volume exist
if [ ! -d "$path" ]; then
   	echo -e "$red Mount Point:$mount_point entered is not available! $none"
    exit 1;
else
    echo -e "$blue $path is selected as the Mount Point. \n $normal"
fi

# Get the exact name of the virtual volume to be unmounted
read -p "Enter the Disk Name to unmount: " diskName
while [[ -z  "$diskName"  ]]; do
	read -p " Disk Name of the LUKS is needed to unmount! : " diskName
done

# Check if there is any mounted file as "disk name" supplied by user

if losetup -a | grep -q $diskName ; then
   	echo -e "$blue $diskName was selected as the LUKS to unmount. \n $normal"
else
    echo -e "$red No such disk ($diskName) is Mounted! Check again! $none"
    exit 1;
fi

# Create variables that identify parameters needed by cryptsetup & losetup
map_crypt=$(mount | grep "$path" | cut -d" " -f1 | cut -d"/" -f 4)
loop_dev=$(losetup -a | grep "$diskName" | cut -d ":" -f 1)

# Unmount procedure
umount "$path" >> "$LOGFILE" 2>&1
cryptsetup luksClose "$map_crypt" >> "$LOGFILE" 2>&1  # Close mapper
losetup -d "$loop_dev" >> "$LOGFILE" 2>&1
echo -e "$green Volume unmounted! $normal" # Detach loop-device
echo -e "$yellow Log File : $LOGFILE $none"

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
$umount_all >> "$LOGFILE" 2>&1
$Close_luks >> "$LOGFILE" 2>&1
$lo_detach >> "$LOGFILE" 2>&1

# Remove all temporary created mount-points at /media/ dir
rm -r /media/luks_* >> "$LOGFILE" 2>&1

# Make the user feel good :)
echo -e "$red All LUKS volumes Safely unmounted! \n $none"
echo -e "$yellow Log File : $LOGFILE $none"
exit 1;
}

############################################################################## 6
### Function for the options menu
function Main_menu(){
intro
echo -e "$green Select one of the option \n $normal"

a="Create a Virtual Volume"
b="Encrypt a Removable Volume"
c="Mount an Encrypted volume"
d="Unmount a volume"
e="Unmount all"
f="Clean after setup fail" 
g="quit"
 

select option in  "$a" "$b" "$c" "$d" "$e" "$f" "$g" 
do
	case "$option" in 
		"$a") New_volume
		;;
        	"$b") USB_volume
        	;;
		"$c") Mount_LUKSVolume
		;;
		"$d") Unmount_LUKSVolume
		;;
		"$e") unmount_all_LUKS
		;;
		"$f") Clean
		;;
		"$g") exit 1;
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
echo -e "$blue $0 usage $normal \n"
exit 1;
}
#### End of FUNCTIONS

################################################################################
# Main : where script execution starts

LOGFILE="/tmp/luks$now.log"

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

	# Test if Disk Name is set in letters only
	if [[ ! "$2" =~ [a-zA-Z] ]]; then
		echo -e "$red $2 is an invalid File Name for Disk (Use letters only) $none"
		exit 1;
	fi

	# Test if Disk size is set in numbers only
	if [[ ! "$3" =~ [0-9] ]]; then
		echo -e "$red $3 is an invalid size number for Block file! (Use numbers only) $none"
		exit 1;
	fi

	# Select numbers only in size 
	size=$(echo  "$3"  | tr -dc 0-9)
	echo -e "$green $blue $size MB $normal is set as your default virtual disk capacity. (Numbers Only) \n $normal"

	# Remove special chars from filename
	name=$(echo "$2" | tr -dc a-zA-Z)

	# Check if file already exists.
	if [ -f "/usr/$name" ]; then
	   	echo -e "$red A Disk Named $name is already available! (/usr/$name) $none"
	   	echo -e "$yellow Please use another Disk Name or delete the existing file$none"
	   	exit 1;
	else
		echo -e "$green $blue $name $normal is set as your default virtual disk name. (No special chars). \n $normal"
	fi
	
	#Create the LUKS virtual volume 
	base="/usr/$name"
	echo -e "$yellow Keep calm.. Creating File block. This might take time depending on the File size and your machine! \n $none" 
	dd if=/dev/zero of="$base" bs=1M count="$3" >> "$LOGFILE" 2>&1
	echo -e "$green \nBlock file created - /usr/$name \n $normal"
	
	# Loop device setup
	loopdev=$(losetup -f)
	losetup "$loopdev" "/usr/$name"
	
	# Variable for losetup test
	confirm_lo=$(losetup -a | grep "$loopdev" | grep -o -P '(?<=\().*(?=\))')
	confirm_final=${confirm_lo##*/}

	# Test if losetup is fine before we continue execution
	if [[ "$confirm_final" != "$name" ]]; then
		echo -e "$red There was a problem setting up LUKS.. \n Try $0 menu and choose option 1. \n Check $LOGFILE $none"
		rm "$base" >> "$LOGFILE" 2>&1
		# For Debugs
		#echo -e "$yellow Confirm Loop-device is $confirm_final\n Confirm-Match is $name \n $none"
		#	echo -e "$green  If the Loop-device is not the same as Confirm-Match... $normal $red ERROR!! $none"
		
		Clean
		exit 1;
	fi
	
	# LUKS format with default cipher
	cryptsetup luksFormat -c aes-xts-plain64 "$loopdev"
	echo 
	
	# Open LUKS with a random name
	cryptdev=$(cat < /dev/urandom | tr -dc "[:lower:]" | head -c 8)
	cryptsetup luksOpen "$loopdev" "$cryptdev" >> "$LOGFILE" 2>&1
	echo
	
	# Variable to used below to test for luksopen command status
	confirm_crypt=$(dmsetup ls | cut -d$'\t' -f 1 | grep "$cryptdev")
	
	# Testing luksopen command worked fine before proceeding
	if [[ "$confirm_crypt" != "$cryptdev" ]]; then
		echo -e "$red There was a problem setting up LUKS.. Check $LOGFILE . $none"
		echo -e "$yellow Password did not Match or If you entered lower-case yes use YES next time.\n $none"
		rm "$base" >> "$LOGFILE" 2>&1
		#For debugs
		#echo -e "$yellow CryptDevice = $cryptdev \n Matching-cryptdev = $confirm_cryp \n $none"
		#echo -e "$red ERROR! $none $green If CryptDevice is not equal to Matching-cryptdev.. $normal"
		exit 1;
	fi
	
	# Create default File System (ext4)
	echo -e "$yellow Creating File-System...... $none"
	mkfs.ext4 -L "$name"  "/dev/mapper/$cryptdev" >> "$LOGFILE" 2>&1

	echo -e "$green \n MOUNT : yes/no \n  $normal"
	
	# Mount the volume if the user accepts	
	read -p "LUKS Virtual disk created, mount it? yes/no :" mount_new
	if [ "$mount_new" == "yes" ]; then
		mkdir  "/media/$temp_name" >> "$LOGFILE" 2>&1
		mount  "/dev/mapper/$cryptdev" "/media/$temp_name" >> "$LOGFILE" 2>&1
		chown -HR "$SUDO_USER" "/media/$temp_name" >> "$LOGFILE" 2>&1
		echo -e "$green You can delete /media/$temp_name after use. \n $normal"
	else
		echo -e "$red Closing... $none"
	fi
	
	#print stats and exit
	_Path="/usr/$name"
	_Mapper="/dev/mapper/$cryptdev"

	echo -e "$yellow  Disk-Name: \t $name \n Path: \t\t $_Path \n Loop-Device: \t $loopdev \n Mapper: \t $_Mapper \n $none"
	echo -e "$green Log file : $LOGFILE \n $normal"
	exit 1;
	;;
	mount) # Mounting a LUKS volume (args shouldn't be less than 2; mount and mount-point).
	if [ $# -lt 2 ]; then
		usage
	fi

	# Test if disk to be mounted is present
	if [ ! -f "$2" ]; then
   		echo -e "$red $2 - Disk to mount is not available! $none"	
    	exit 1;
  	fi

	# Check if custom mount-point is supplied by user.
	if [ $# -eq 3 ]; then  
		mount_point="$3"
		if [ ! -d "$3" ]; then
   			echo -e "$red Mount-point:$3 entered is not available! $none"
    		exit 1;
  		fi
	else
		mkdir "/media/$temp_name" >> "$LOGFILE" 2>&1  # If no custom mount-point use default one.
        mount_point="/media/$temp_name" 
	fi

	# Check if disk supplied is already mounted
	Disk_Path=$(losetup -a | grep $2 | grep -o -P '(?<=\().*(?=\))')
	if [[ $2 == $Disk_Path ]]; then
		echo -e "$red Disk $2 is already mounted!.. If you are not using any LUKS device do either:$none"
		echo -e "$green 1. $0 unmount-all$normal $blue (After using disks or fatal/unknown error) or $normal" 
		echo -e "$green 2. $0 clean $normal $blue (after a failed setup) $normal"
		exit 1;
	fi
	
	# Setup Loop-Device and open LUKS with random name
	losetup "$loopdev" "$2" >> "$LOGFILE" 2>&1
	cryptsetup luksOpen "$loopdev" "$cryptdev" >> "$LOGFILE" 2>&1
	
	# Mount the volume and enable rw for other sudo user
    mount  "/dev/mapper/$cryptdev" -rw  "$mount_point" >> "$LOGFILE" 2>&1 && echo -e "$yellow LUKS Virtual disk mounted $none"
	chown -HR "$SUDO_USER" "$mount_point" >> "$LOGFILE" 2>&1
	echo -e "$yellow Mounted at:\t $mount_point\n Disk-Path:\t $2\n Loop-Device:\t $loopdev\n Mapper:\t  /dev/mapper/$cryptdev\n $none"
	echo -e "$yellow NB: You can delete $mount_point after use.  $none"
	echo -e "$green Log file : $LOGFILE \n $normal"
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
	*) echo -e "$red Oops! I did not get what you did there..  $none" # (usage func) Print help message and exit
	usage
	;;
esac
