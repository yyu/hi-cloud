#!/usr/bin/env bash

if [ -z "$KISSBASH_PATH" ]; then echo -e '\033[31mERROR\033[0m : KISSBASH_PATH is not set'; exit 1; fi
. "$KISSBASH_PATH/term/colors"
. "$KISSBASH_PATH/console/lines"
. "$KISSBASH_PATH/cloud/aws/ec2"

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

    explicitly aws ec2 attach-volume --volume-id $volume_id --instance-id $instance_id --device "/dev/xvdg"

    local az=`explicitly aws ec2 describe-volumes --volume-ids $volume_id --query "Volumes[*].{InstanceId:AvailabilityZone}" --output text`
    local sz=`explicitly aws ec2 describe-volumes --volume-ids $volume_id --query "Volumes[*].{InstanceId:Size}" --output text`

    local create_volume_output=`explicitly aws ec2 create-volume --availability-zone $az --size $sz | tee_serr_with_color blu`
    local new_volume_id=`echo $create_volume_output | sed -E 's/.*VolumeId\": \"(vol-[a-z0-9]*).*/\1/g'`
    color GRN $new_volume_id

    wait_until_volume_is "available" $new_volume_id
    explicitly aws ec2 attach-volume --volume-id $new_volume_id --instance-id $instance_id --device "/dev/xvdo"
    wait_until_volume_is "in-use" $new_volume_id

    echo "
        aws ec2 detach-volume --volume-id $new_volume_id
        sleep 5
        aws ec2 delete-volume --volume-id $new_volume_id
    " | tee_serr_with_color RED | pbcopy
}

if [ $# -lt 1 ]; then
    clone_volume
fi
