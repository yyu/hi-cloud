#!/usr/bin/env bash

if [ -z "$KISSBASH_PATH" ]; then echo -e '\033[31mERROR\033[0m : KISSBASH_PATH is not set'; exit 1; fi
. "$KISSBASH_PATH/term/colors"
. "$KISSBASH_PATH/exec/explicitly"
. "$KISSBASH_PATH/console/lines"
. "$KISSBASH_PATH/cloud/aws/ec2"

FROM_DEV=/dev/xvdg
TO_DEV=/dev/xvdo

clone_volume() {
    local volume_id=`get_ebs_volume_id_from_stdin`
    if [ $? -eq 0 ]; then
        echo -e "volume ${COLOR[cyn]}$volume_id${COLOR[ylw]} will be cloned" | serr_with_color ylw
    else
        echo -e "Bad EBS volume id" | serr_with_color ylw
    fi
    get_ebs_volumes $volume_id | serr_with_color ylw

    local instance_id=`get_ec2_instance_id_for_volume $volume_id`
    if [ "$instance_id" != "None" ]; then
        local instance_state=`explicitly \
            aws ec2 describe-instances \
                --instance-id $instance_id \
                --query "Reservations[*].Instances[0].State.Name" \
                --output text`
        echo -e "volume $volume_id is attached to" `color red $instance_state` `color ylw instance` `color blu $instance_id` | color ylw >&2

        #list_ec2_instances_web_style | grep --color $instance_id >&2

        #if [ "$instance_state" != "stopped" ]; then
        #    echo "Press any key to stop instance `color red $instance_id`. Ctrl-C to quit." | serr_with_color mgt
        #    read
        #    explicitly aws ec2 stop-instances --instance-ids $instance_id
        #fi

        echo "Ctrl-C to quit or press any key to detach `color blu $instance_id`" | serr_with_color mgt
        read
        explicitly aws ec2 detach-volume --volume-id $volume_id
        wait_until_volume_is available $volume_id

        get_ebs_volumes $volume_id | serr_with_color ylw
    fi
    #echo -n i-0302e732c9e5c247d | pbcopy

    instance_id=`get_ec2_instance_id_from_stdin`
    if [ $? -eq 0 ]; then
        echo -e "EC2 instance ${COLOR[cyn]}$instance_id${COLOR[ylw]} will be used to clone the EBS volume" | serr_with_color ylw
    else
        echo -e "Bad EC2 instance id" | serr_with_color ylw
    fi

    explicitly aws ec2 attach-volume --volume-id $volume_id --instance-id $instance_id --device $FROM_DEV

    local az=`explicitly aws ec2 describe-volumes --volume-ids $volume_id --query "Volumes[*].{InstanceId:AvailabilityZone}" --output text`
    #local sz=`explicitly aws ec2 describe-volumes --volume-ids $volume_id --query "Volumes[*].{InstanceId:Size}" --output text`
    local sz=16

    local create_volume_output=`explicitly aws ec2 create-volume --volume-type gp2 --availability-zone $az --size $sz | tee_serr_with_color blu`
    local new_volume_id=`echo $create_volume_output | sed -E 's/.*VolumeId\": \"(vol-[a-z0-9]*).*/\1/g'`
    color GRN $new_volume_id

    wait_until_volume_is "available" $new_volume_id
    explicitly aws ec2 attach-volume --volume-id $new_volume_id --instance-id $instance_id --device $TO_DEV
    wait_until_volume_is "in-use" $new_volume_id

    #sudo sfdisk -d $FROM_DEV > from.sfdisk

    local public_ip=`get_ec2_instance_public_ip $instance_id`
    local pemkey=`explicitly aws ec2 describe-instances --instance-ids $instance_id --query "Reservations[*].Instances[0].KeyName" --output text`
    serr_with_color ylw "Path to pem file for" `color MGT $pemkey` `color ylw please`
    read pemfile
    serr_with_color ylw "Username for" `color MGT $instance_id` `color ylw please`
    read username

    explicitly ssh -i $pemfile $username@$public_ip "
                                                     echo '--------------------------------------------------------------------------------'
                                                     rm -rf /tmp/.kissbash
                                                     git clone https://github.com/yyu/kissbash.git /tmp/.kissbash
                                                     export KISSBASH_PATH=/tmp/.kissbash/kissbash
                                                     . \$KISSBASH_PATH/console/lines
                                                     . \$KISSBASH_PATH/exec/explicitly
                                                     serr_with_color YLW '--------------------------------------------------------------------------------'
                                                     explicitly sudo mkfs.ext4 $TO_DEV | serr_with_color YLW
                                                    "
    local partitions=`explicitly ssh -i $pemfile $username@$public_ip "sudo fdisk -l $FROM_DEV | grep '83 Linux' | cut -d' ' -f1"`
    for part in $partitions; do
        local partbase=`basename $part`
        explicitly ssh -i $pemfile $username@$public_ip "
                                                     export KISSBASH_PATH=/tmp/.kissbash/kissbash
                                                     . \$KISSBASH_PATH/console/lines
                                                     . \$KISSBASH_PATH/exec/explicitly
                                                     serr_with_color YLW '--------------------------------------------------------------------------------'
                                                     explicitly sudo mkdir -vp /mnt/dev0
                                                     explicitly sudo mount $part /mnt/dev0
                                                     explicitly sudo mount $TO_DEV /mnt/dev1
                                                     serr_with_color YLW '--------------------------------------------------------------------------------'
                                                     explicitly sudo mkdir -p /mnt/dev1/$partbase
                                                     explicitly sudo cp -r /mnt/dev0/* /mnt/dev1/$partbase/
                                                     serr_with_color YLW '--------------------------------------------------------------------------------'
                                                     explicitly sudo umount $TO_DEV
                                                     explicitly sudo umount $part
                                                    "
    done

    explicitly ssh -i $pemfile $username@$public_ip "
                                                     export KISSBASH_PATH=/tmp/.kissbash/kissbash
                                                     . \$KISSBASH_PATH/exec/explicitly
                                                     serr_with_color YLW '--------------------------------------------------------------------------------'
                                                     explicitly sudo dd bs=512 if=$TO_DEV of=/tmp/dd.out
                                                     explicitly ls -lh /tmp/dd.out
                                                     explicitly sudo chmod 777 /tmp/dd.out
                                                     explicitly sudo rm /tmp/dd.out.gz
                                                     explicitly gzip /tmp/dd.out
                                                     explicitly ls -lh /tmp/dd.out
                                                     explicitly ls -lh /tmp/dd.out.gz
                                                     explicitly echo '--------------------------------------------------------------------------------'
                                                    "

    echo "aws ec2 detach-volume --volume-id $new_volume_id && sleep 5 && aws ec2 delete-volume --volume-id $new_volume_id" | tee_serr_with_color RED | pbcopy
}

clone_disk() {
    local FROM_DEV=$1
    local TO_DEV=$2

    explicitly ssh -i $pemfile $username@$public_ip "
                                                     export KISSBASH_PATH=/tmp/.kissbash/kissbash
                                                     . \$KISSBASH_PATH/exec/explicitly
                                                     explicitly echo '--------------------------------------------------------------------------------'
                                                     explicitly sudo sfdisk -d $FROM_DEV > info.sfdisk
                                                     explicitly echo '--------------------------------------------------------------------------------'
                                                     explicitly cat info.sfdisk
                                                     explicitly echo '--------------------------------------------------------------------------------'
                                                     explicitly sudo sfdisk $TO_DEV < info.sfdisk
                                                     explicitly echo '--------------------------------------------------------------------------------'
                                                     explicitly sudo fdisk -l $TO_DEV
                                                     explicitly echo '--------------------------------------------------------------------------------'
                                                     explicitly sudo mkfs.ext4 ${TO_DEV}1
                                                     explicitly sudo mkfs.ext4 ${TO_DEV}2
                                                     explicitly echo '--------------------------------------------------------------------------------'
                                                     explicitly sudo mkdir -vp /mnt/dev0
                                                     explicitly sudo mkdir -vp /mnt/dev1
                                                     explicitly echo '--------------------------------------------------------------------------------'
                                                    "
    local partitions=`explicitly ssh -i $pemfile $username@$public_ip "sudo fdisk -l $FROM_DEV | grep '83 Linux' | cut -d' ' -f1 | grep -o -E '[0-9]*\$'"`

    for part in $partitions; do
        explicitly ssh -i $pemfile $username@$public_ip "
                                                     export KISSBASH_PATH=/tmp/.kissbash/kissbash
                                                     . \$KISSBASH_PATH/exec/explicitly
                                                     explicitly echo '--------------------------------------------------------------------------------'
                                                     explicitly sudo mount $FROM_DEV$part /mnt/dev0
                                                     explicitly sudo mount $TO_DEV$part /mnt/dev1
                                                     explicitly echo '--------------------------------------------------------------------------------'
                                                     explicitly mount | grep xvd
                                                     explicitly echo '--------------------------------------------------------------------------------'
                                                     explicitly sudo cp -r /mnt/dev0/* /mnt/dev1/
                                                     explicitly echo '--------------------------------------------------------------------------------'
                                                     explicitly sudo df -h
                                                     explicitly echo '--------------------------------------------------------------------------------'
                                                     explicitly sudo du -h --max-depth=1 /mnt/dev0
                                                     explicitly echo '--------------------------------------------------------------------------------'
                                                     explicitly sudo du -h --max-depth=1 /mnt/dev1
                                                     explicitly echo '--------------------------------------------------------------------------------'
                                                     explicitly sudo umount $FROM_DEV$part
                                                     explicitly sudo umount $TO_DEV$part
                                                     explicitly echo '--------------------------------------------------------------------------------'
                                                     explicitly mount | grep xvd
                                                     explicitly echo '--------------------------------------------------------------------------------'
                                                    "
    done
}

if [ $# -lt 1 ]; then
    clone_volume
fi
