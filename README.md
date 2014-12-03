LUKS-OPs
========

A bash script to automate the most basic usage of LUKS volumes in Linux.
Like:

* Creating a virtual disk volume with LUKS format.
* Mounting an existing LUKS volume
* Unmounting a Single LUKS volume or all LUKS volume in the system.

### Basic Usage 

There is an option for a menu:
```bash
./luks-ops.sh menu or ./luks-ops.sh
```
Other options include:
```bash
./luks-ops.sh menu
./luks-ops.sh new disk_Name Size_in_numbers
./luks-ops.sh mount /path/to/device (mountpoint) 
./luks-ops.sh unmount-all
./luks-ops.sh clean
./luks-ops.sh usage
```

### Default Options:

* Virtual-disk size = 512 MB and it's created on /usr/ directory
* Default filesystem used =  ext4
* ##### Cipher options:
  * LUKS1: aes-xts-plain64, Key: 256 bits, LUKS header hashing: sha1, RNG: /dev/urandom
  * plain: aes-cbc-essiv:sha256, Key: 256 bits, Password hashing: ripemd160
* Mounting point = /media/luks_* where * is random-string.
* Others.. 

### Dependencies
1. dmsetup ---  dmsetup - low level logical volume management
2. cryptsetup --- cryptsetup - manage plain dm-crypt and LUKS encrypted volumes

**NB: Run as root.**

#### But make sure you read the man pages and other onlie Doc about LUKS
* man cryptsetup (or cryptsetup --help)
* man dmsetup

The LUKS website at http://code.google.com/p/cryptsetup/
The cryptsetup FAQ, contained in the distribution package and online at http://code.google.com/p/cryptsetup/wiki/FrequentlyAskedQuestions
The cryptsetup mailing list and list archive, see FAQ entry 1.6.
The LUKS on-disk format specification available at http://code.google.com/p/cryptsetup/wiki/Specification

#### Edit the script to fit your use... Share!/Merge.. :blue_heart:


