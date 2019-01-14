#!/usr/bin/env bash

if [ -z "$KISSBASH_PATH" ]; then echo -e '\033[31mERROR\033[0m : KISSBASH_PATH is not set'; exit 1; fi
. "$KISSBASH_PATH/term/colors"
. "$KISSBASH_PATH/exec/explicitly"
. "$KISSBASH_PATH/console/lines"
. "$KISSBASH_PATH/cloud/aws/ec2"

FROM_DEV=/dev/xvdg
TO_DEV=/dev/xvdo

_get_ebs_volume_id() {
    local volume_id=`get_ebs_volume_id_from_stdin`
    if [ $? -eq 0 ]; then
        echo -e "volume ${COLOR[cyn]}$volume_id${COLOR[ylw]} will be cloned" | serr_with_color ylw
    else
        echo -e "Bad EBS volume id" | serr_with_color ylw
    fi
    get_ebs_volumes $volume_id | serr_with_color ylw
    echo $volume_id
}

_detach_volume_if_attached() {
    local volume_id="$1"
    if [ -z $volume_id ]; then
        return
    fi
    local instance_id=`get_ec2_instance_id_for_volume $volume_id`
    if [ "$instance_id" != "None" ]; then
        local instance_state=`explicitly \
            aws ec2 describe-instances \
                --instance-id $instance_id \
                --query "Reservations[*].Instances[0].State.Name" \
                --output text`
        echo -e "volume $volume_id is attached to" `color red $instance_state` `color ylw instance` `color blu $instance_id` | color ylw >&2

        echo "Ctrl-C to quit or press any key to detach `color blu $instance_id`" | serr_with_color m_t
        read
        explicitly aws ec2 detach-volume --volume-id $volume_id
        explicitly wait_until_volume_is available $volume_id
        explicitly get_ebs_volumes $volume_id | serr_with_color ylw
    fi
}

_detach_volume_of_device() {
    local dev=$1
    local volume_id=`explicitly aws ec2 describe-volumes --filter "Name=attachment.device,Values=$dev" --query "Volumes[*].VolumeId" --output text | tee_serr_with_color red`
    if [ -n "$volume_id" ]; then
        explicitly aws ec2 detach-volume --volume-id $volume_id
        wait_until_volume_is available $volume_id
        get_ebs_volumes $volume_id | serr_with_color ylw
    fi
}

copy_files_in_volume() {
    local volume_id=`_get_ebs_volume_id`

    explicitly _detach_volume_if_attached $volume_id
    explicitly _detach_volume_of_device $FROM_DEV
    explicitly _detach_volume_of_device $TO_DEV

    instance_id=`explicitly get_ec2_instance_id_from_stdin`
    if [ $? -eq 0 ]; then
        echo -e "EC2 instance ${COLOR[cyn]}$instance_id${COLOR[ylw]} will be used to clone the EBS volume" | serr_with_color ylw
    else
        echo -e "Bad EC2 instance id" | serr_with_color ylw
        exit 1
    fi

    explicitly aws ec2 attach-volume --volume-id $volume_id --instance-id $instance_id --device $FROM_DEV

    local public_ip=`get_ec2_instance_public_ip $instance_id`
    local pemkey=`explicitly aws ec2 describe-instances --instance-ids $instance_id --query "Reservations[*].Instances[0].KeyName" --output text`
    serr_with_color y_w "Path to pem file for" `color M_T $pemkey` `color y_w please`
    read pemfile
    serr_with_color y_w "Username for" `color M_T $instance_id` `color y_w please`
    read username

    explicitly wait_until_volume_is "in-use" $volume_id

    local partitions=`explicitly ssh -i $pemfile $username@$public_ip "sudo fdisk -l $FROM_DEV | grep '83 Linux' | cut -d' ' -f1"`
    if [ -n "$partitions" ]; then
        for part in $partitions; do
            local partbase=`basename $part`
            explicitly ssh -i $pemfile $username@$public_ip "
                                                     export KISSBASH_PATH=/tmp/.kissbash/kissbash
                                                     . \$KISSBASH_PATH/console/lines
                                                     . \$KISSBASH_PATH/exec/explicitly
                                                     serr_with_color YLW '--------------------------------------------------------------------------------'
                                                     explicitly sudo mkdir -vp /mnt/dev0/$partbase
                                                     explicitly sudo mount $part /mnt/dev0/$partbase
                                                     serr_with_color YLW '--------------------------------------------------------------------------------'
                                                    "
        done
    fi

    # source device is ready

    # prepare for the destination device below

    # the same AZ as source volume
    local az=`explicitly aws ec2 describe-volumes --volume-ids $volume_id --query "Volumes[*].{InstanceId:AvailabilityZone}" --output text`

    # decide the size of the destination volume
    explicitly ssh -i $pemfile $username@$public_ip "sudo df -h" |serr_with_color blu
    echo "Volume size in GB: " | serr_with_color m_t
    read sz
    if [ -z "$sz" ]; then
        sz=`explicitly aws ec2 describe-volumes --volume-ids $volume_id --query "Volumes[*].{InstanceId:Size}" --output text`
    fi
    echo "Volume size in GB: $sz" | serr_with_color mgt

    local volume_creation_output=`explicitly aws ec2 create-volume --volume-type gp2 --availability-zone $az --size $sz | tee_serr_with_color blu`
    local new_volume_id=`echo $volume_creation_output | sed -E 's/.*VolumeId\": \"(vol-[a-z0-9]*).*/\1/g'`
    color GRN $new_volume_id

    wait_until_volume_is "available" $new_volume_id
    explicitly aws ec2 attach-volume --volume-id $new_volume_id --instance-id $instance_id --device $TO_DEV
    wait_until_volume_is "in-use" $new_volume_id

    sed -E 's/ *(#.*)*//g' > /tmp/fdisk.input << "EOF"
        o # clear the in memory partition table
        n # new partition
        p # primary partition
        1 # partition number 1
          # default - start at beginning of disk 
        +512M # boot parttion
        n # new partition
        p # primary partition
        2 # partion number 2
          # default, start immediately after preceding partition
          # default, extend partition to end of disk
        a # make a partition bootable
        1 # bootable partition is partition 1 -- /dev/sda1
        p # print the in-memory partition table
        w # write the partition table
        q # and we're done
EOF

    explicitly scp -i $pemfile /tmp/fdisk.input $username@$public_ip:/tmp/

    explicitly ssh -i $pemfile $username@$public_ip "
                                                     echo '--------------------------------------------------------------------------------'
                                                     rm -rf /tmp/.kissbash
                                                     git clone https://github.com/yyu/kissbash.git /tmp/.kissbash
                                                     export KISSBASH_PATH=/tmp/.kissbash/kissbash
                                                     . \$KISSBASH_PATH/console/lines
                                                     . \$KISSBASH_PATH/exec/explicitly
                                                     serr_with_color YLW '--------------------------------------------------------------------------------'
                                                     explicitly sudo fdisk $TO_DEV < /tmp/fdisk.input
                                                     serr_with_color YLW '--------------------------------------------------------------------------------'
                                                     explicitly sudo fdisk -l $TO_DEV
                                                     serr_with_color YLW '--------------------------------------------------------------------------------'
                                                     explicitly sudo mkfs.ext4 $TO_DEV"1" | serr_with_color YLW
                                                     explicitly sudo mkfs.ext4 $TO_DEV"2" | serr_with_color YLW
                                                     serr_with_color YLW '--------------------------------------------------------------------------------'
                                                     explicitly sudo mkdir -p /mnt/dev1/1
                                                     explicitly sudo mkdir -p /mnt/dev1/2
                                                     explicitly sudo mount $TO_DEV"1" /mnt/dev1/1
                                                     explicitly sudo mount $TO_DEV"2" /mnt/dev1/2
                                                     serr_with_color YLW '--------------------------------------------------------------------------------'
                                                    "

    explicitly ssh -i $pemfile $username@$public_ip

    echo "aws ec2 detach-volume --volume-id $new_volume_id && sleep 5 && aws ec2 delete-volume --volume-id $new_volume_id" | tee_serr_with_color RED | pbcopy
}

if [ $# -lt 1 ]; then
    copy_files_in_volume
fi
