#!/bin/bash

#To autoselect the partition scheme based on available storage options.
FREE=$(( 512 * 1024 * 1024 ))

#Declare associate arrays
declare -A DISK_NAME
declare -A DISK_MIN
declare -A DISK_MAX
declare -A DISK_PRIORITY
declare -A USE_DISK_SIZE
#Declare general array
declare -a DISK_LIST

#LV name for each partition.
# DISK_NAME["/"]="root"
# DISK_NAME["''"]="swap"
# DISK_NAME["/home"]="home"
DISK_NAME["/opt/safesquid"]="opt+safesquid"
DISK_NAME["/usr/local/safesquid"]="usr+local+safesquid"
DISK_NAME["/var/lib/safesquid"]="var+lib+safesquid"
DISK_NAME["/var/cache/safesquid"]="var+cache+safesquid"
DISK_NAME["/var/www/safesquid"]="var+www+safesquid"
DISK_NAME["/var/db/safesquid"]="var+db+safesquid"
DISK_NAME["/var/log/safesquid"]="var+log+safesquid"
#Minimum alloted disk size for each partition.
# DISK_MIN["/"]=5120
# DISK_MIN["/boot"]=512
# DISK_MIN["''"]=2048
# DISK_MIN["/home"]=5120
DISK_MIN["/opt/safesquid"]=512
DISK_MIN["/usr/local/safesquid"]=1024
DISK_MIN["/var/lib/safesquid"]=512
DISK_MIN["/var/cache/safesquid"]=1024
DISK_MIN["/var/www/safesquid"]=5120
DISK_MIN["/var/db/safesquid"]=2048
DISK_MIN["/var/log/safesquid"]=1024
#Maximum alloted disk size for each partition.
# DISK_MAX["/"]=-1
# DISK_MAX["/boot"]=2048
# DISK_MAX["''"]=8192
# DISK_MAX["/home"]=20480
DISK_MAX["/opt/safesquid"]=4096
DISK_MAX["/usr/local/safesquid"]=4096
DISK_MAX["/var/lib/safesquid"]=4096
DISK_MAX["/var/cache/safesquid"]=5120
DISK_MAX["/var/www/safesquid"]=15360
DISK_MAX["/var/db/safesquid"]=10240
DISK_MAX["/var/log/safesquid"]=-1
#Disk priority
# DISK_PRIORITY["/"]=2
# DISK_PRIORITY["/boot"]=2
# DISK_PRIORITY["''"]=2
# DISK_PRIORITY["/home"]=2
DISK_PRIORITY["/opt/safesquid"]=1
DISK_PRIORITY["/usr/local/safesquid"]=1
DISK_PRIORITY["/var/lib/safesquid"]=2
DISK_PRIORITY["/var/cache/safesquid"]=2
DISK_PRIORITY["/var/www/safesquid"]=2
DISK_PRIORITY["/var/db/safesquid"]=2
DISK_PRIORITY["/var/log/safesquid"]=9

INSTALL_DEPENDENCIES()
{
	declare -a PACKS
	PACKS+=("lvm2")

	
	D=${DEBIAN_FRONTEND}	
	export DEBIAN_FRONTEND=noninteractive
	apt-get update && apt-get upgrade 
	apt-get install -y ${PACKS[*]}
	export DEBIAN_FRONTEND=${D}
}

# Get list of unused paritions
GET_DISK_LIST () { 

    DISKS=$(lsblk -p -l -n -o NAME,TYPE | awk '$2 =="disk" {print $1}')
    PARTITIONS=$(lsblk -p -l -n -o NAME,TYPE | awk '$2 =="part" {print $1}')

    # Flag to track if any disk is being used in a partition
    DISK_USED=0

    # Loop through each disk
    for DEV in $DISKS; do
        # Loop through each partition
        for PART in $PARTITIONS; do
            # Check if partition name contains disk name
            if [[ "${PART}" == "${DEV}"* ]]; then
                DISK_USED=1
            fi
        done
        # Check if disk is unused
        if [ "$DISK_USED" = 0 ]; then
            DISK_LIST+=("${DEV}")
        fi
        DISK_USED=0
    done
}

#Get total disk size for available storage device
GET_TOTAL_DISK_SIZE () {

    DISK_TOTAL=$(echo "${DISK_LIST[*]}" | xargs -n 1 lsblk -b -n | awk '/disk/ {total += $4} END {printf "%.0f", total}')
    TOTAL_DISK_SIZE=$(( DISK_TOTAL - FREE ))
}

ALLOT_MINIMUM_DISK () {
    
    TOTAL_MIN_DISK=0
    for LV in "${!DISK_MIN[@]}"
    do
        USE_DISK_SIZE[${LV}]=${DISK_MIN[${LV}]}
        (( TOTAL_MIN_DISK+=${DISK_MIN[${LV}]} ))
        #If available total disk is less than total minumum disk space then return function.
        [[ $(( TOTAL_DISK_SIZE / 1024 / 1024 )) -lt $TOTAL_MIN_DISK ]] && echo "Total Disk Size less than required Minimum" && exit
    done
}

DISK_AVAIL_TO_USE () {
    #check for available disk storage.
    DISK_SPACE_UTILIZED=0
    for TOTAL_USED_SPACE in "${USE_DISK_SIZE[@]}"
    do
        (( DISK_SPACE_UTILIZED+=TOTAL_USED_SPACE ))
    done
    #2560/2048 will be used for /boot depends upon boot type
    AVAILABLE_DISK="$(( $(( TOTAL_DISK_SIZE / 1024 / 1024 )) - DISK_SPACE_UTILIZED ))"
} 

#Get the disk size which is smaller than the disk maximum; else use disk maximum.
MIN () {
    [[ "${2}" == -1  ]] && echo "${1}" && return
    [[ "${1}" -le "${2}" ]] && echo "${1}" && return
    echo "${2}";
}

#Sort priority in ascending order
GET_DISK_PRIORITY () {
    for key in "${!DISK_PRIORITY[@]}"
    do 
        echo "${DISK_PRIORITY[${key}]}" "${key}"
    done | sort
}

# Calculate the total priority weight
GET_TOTAL_PRIORITY () {

    typeset -i TOTAL_PRIORITY=0
    for key in "${!DISK_PRIORITY[@]}"
    do 
        (( TOTAL_PRIORITY+=${DISK_PRIORITY[${key}]} ))        
    done
    echo "${TOTAL_PRIORITY}"
}

#Check if available disk is in negative set minimum disk for all storage.
ALLOT_DISK () {

    USE_TOTAL_PRIORITY=$(GET_TOTAL_PRIORITY)
    while read -r PRIORITY PARTITION 
    do 
        DISK_AVAIL_TO_USE
        [[ ${AVAILABLE_DISK} -le 512 ]] && return;
        ALLOT_REMAINIG_DISK=$(( AVAILABLE_DISK * PRIORITY / USE_TOTAL_PRIORITY ))
        (( USE_TOTAL_PRIORITY-=PRIORITY ))
        NEW_DISK_SIZE_OFFERED="$(( ALLOT_REMAINIG_DISK + ${USE_DISK_SIZE[${PARTITION}]} ))"
        X=$(MIN ${NEW_DISK_SIZE_OFFERED} "${DISK_MAX[${PARTITION}]}")
        USE_DISK_SIZE[${PARTITION}]=$X
    done < <(GET_DISK_PRIORITY)
}

#Create lvm code block for user data.
LV_CREATE () {
    [ -z "${DISK_LIST[*]}" ] && echo "ERROR: DISK NOT FOUND!" echo "ATTACH A NEW BLOCK DEVICE" && exit 1 
    
    #Check if volume group already exists, if exists then use the existing vg
    VG_CREATE="0"
    VG=$(vgs --noheadings | awk '{print $1}')
    #If vg is not present then create a new volume group.
    [ -z "${VG}" ] && VG_CREATE="1" && VG="vg$(hostname -s)" 
    
    #Create physical volumes to be used in lvm and then create volume group if not present else extend to existing vloume group
    for DISK_ADD in "${DISK_LIST[@]}"
    do
        pvcreate "${DISK_ADD}"
        [ "${VG_CREATE}" == "1" ] && vgcreate "${VG}" "${DISK_ADD}"
        [ "${VG_CREATE}" == "0" ] && vgextend "${VG}" "${DISK_ADD}"
    done
  
	for LV in "${!DISK_NAME[@]}"
	do 
        lvcreate --size "${USE_DISK_SIZE[${LV}]}" --name "/dev/${VG}/${DISK_NAME[${LV}]}" "${VG}"
        mkfs.ext4 "/dev/${VG}/${DISK_NAME[${LV}]}"
        printf "/dev/%s/%s       %s    ext4  defaults   0    0\n" "$VG" "${DISK_NAME[$LV]}" "${LV}" >> /etc/fstab
        mkdir --parents "${LV}"
        
	done 
    #Auto mount all partitions.
    mount -a
}

# MAIN
MAIN () {

	INSTALL_DEPENDENCIES
    GET_DISK_LIST
    GET_TOTAL_DISK_SIZE
    ALLOT_MINIMUM_DISK
    ALLOT_DISK
    LV_CREATE
}

MAIN
