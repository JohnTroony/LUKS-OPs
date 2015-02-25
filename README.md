LUKS-OPs
========

#####What is Luks-Ops? 
A bash script to automate the most basic usage of LUKS and Cryptsetup in Linux.

Like:

* Creating a virtual disk volume with LUKS format.
* Mounting an existing LUKS volume
* Unmounting a Single LUKS volume or all LUKS volume in the system.

#####What Luks-Ops is not?
* A replacement for LUKS or Cryptsetup.



### Basic Usage 

There is an option for a menu:
```bash
luks-ops.sh menu
```

Other options include:
```bash
1) luks-ops.sh new DISKNAME 512
2) luks-ops.sh mount /path/to/device MOuntPoint
3) luks-ops.sh unmount-all 
4) luks-ops.sh clean
5) luks-ops.sh usage
```
1. Will create a virtual-disk named DISKNAME with size 512 MB
2. Will mount device at MountPoint 
3. Will unmount all luks volume mounted
4. Will clean all unfinished setups incase of errors (But I recommend using 4)
5. Will print help message


### Default Options:

* Virtual-disk size = 512 MB and it's created on /usr/ directory
* Default filesystem used =  ext4
* **Cipher options:**
  * Creating LUKS1: aes-xts-plain64, Key: 256 bits, LUKS header hashing: sha1, RNG: /dev/urandom
  * plain: aes-cbc-essiv:sha256, Key: 256 bits, Password hashing: ripemd160 (about-time :smile:)
* Mounting point = /media/luks_* where * is random-string.
* Others.. 
**NB.** You can change /dev/urandom to /dev/zero (speed?)

### Dependencies (Install applications:)
1. **dmsetup** -- low level logical volume management
2. **cryptsetup** -- manage plain dm-crypt and LUKS encrypted volumes

**NB: Run as root.**

#### But make sure you read the man pages and other online Doc about LUKS
* man cryptsetup (or cryptsetup --help)
* man dmsetup

#### TODO
1. Support for KEYs
2. Remote VPS setup (booting option) 
3. ZSH completion 
4. [ Include other user requests here ]

###Docs..

The LUKS website at http://code.google.com/p/cryptsetup/

The cryptsetup FAQ, contained in the distribution package and online at http://code.google.com/p/cryptsetup/wiki/FrequentlyAskedQuestions

The cryptsetup mailing list and list archive, see FAQ entry 1.6.

The LUKS on-disk format specification available at http://code.google.com/p/cryptsetup/wiki/Specification

#### Edit the script to fit your use... Share!/Merge.. :blue_heart:


