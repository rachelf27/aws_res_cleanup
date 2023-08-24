#!/bin/bash
# This script cleans up the AWS EC2 resources.

# Steps
# Stop Instances aws ec2 stop-instances
# Handle any dependencies - remove sgs, detach and delete EBS volumes attached to the instances
# Review other related resources, such as EBS snapshots, Network interfaces or elastic IPs, either clean up or relese these resources
# Verify before terminating
# Terminate Instances once the instances ahve been stopped aws ec2 terminate-instances

# # Verify AWS CLI Credentials are setup
# if ! (aws configure list); then
#     echo "AWS config is not setup or CLI not installed. Please run \"aws configure\"."
#     exit 1
# fi

# ANSI escape sequence for bold text
bold=$(tput bold)

# ANSI escape sequence to reset formatting
reset=$(tput sgr0)

# # Get the list of all EC2 Instances
# ec2_list_output=$(aws ec2 describe-instances --query "Reservations[].Instances[].InstanceId" --output text)

# # Check if the list is empty
# if [ -z "$ec2_list_output" ]; then
#     echo -e "\n No EC2 instances found.\n"
#     exit 0
# fi
echo "testing 123..."

echo "testing 456..."


# Load JSON data from the file
function loadMockData () {
    echo "Loading mock data from instances_mock.json..."
    cat mock_instances.json
    json_data=$(cat mock_instances.json | jq -c '.')
}

# Function to parse user-friendly date to seconds
function parseDateToSeconds() {
    local dateInput=$1
    local value=${dateInput%% *}
    local unit=${dateInput#* }
    local unitInSeconds=0

    case "$unit" in
        seconds|second)
            unitInSeconds=1
            ;;
        minutes|minute)
            unitInSeconds=60
            ;;
        hours|hour)
            unitInSeconds=3600
            ;;
        days|day)
            unitInSeconds=86400
            ;;
        weeks|week)
            unitInSeconds=604800
            ;;
        *)
            echo "Invalid time unit. Please use seconds, minutes, hours, days, or weeks."
            exit 1
            ;;
    esac

    echo "$((value * unitInSeconds))"
}

function costOptimization() {
    # Get the current date in ISO8601 format
    current_date=$(date -u +'%Y-%m-%dT%H:%M:%SZ')

    # Check if the Idle Period and Threshold are provided as an argument
    if [ $# -eq 2 ]; then
        idlePeriod=$1
        threshold=$2
    else
        idlePeriod="0 days"
        threshold=0
    fi

    # # Check if both idlePeriod and threshold are zero
    # if [ $idlePeriod -eq 0 ] && [ $threshold -eq 0 ]; then
    #     echo "You did not provide an Idle period or Threshold. Please provide a valid value."
    #     return 1
    # fi

    # if [ $idlePeriod -ne 0 ] && [ $threshold -ne 0 ]; then
    #     # Instances that are both idle and underutilized
    #     ec2_list_output=$(aws ec2 describe-instances \
    #         --query "Reservations[].Instances | 
    #                   [?LaunchTime <= \`$current_date\` - $idlePeriod || CPUUtilization < $threshold].InstanceId" \
    #         --output text)
    # elif [ $idlePeriod -ne 0 ]; then
    #     # Instances that are idle but not underutilized
    #     ec2_list_output=$(aws ec2 describe-instances \
    #         --query "Reservations[].Instances | 
    #                   [?LaunchTime <= \`$current_date\` - $idlePeriod].InstanceId" \
    #         --output text)
    # elif [ $threshold -ne 0 ]; then
    #     # Instances that are underutilized but not idle
    #     ec2_list_output=$(aws ec2 describe-instances \
    #         --query "Reservations[].Instances | 
    #                   [?CPUUtilization < $threshold].InstanceId" \
    #         --output text)
    # else
    #     # Instances that are not idle or underutilized (no action taken for this scenario)
    #     echo "No action taken for instances that are not idle or underutilized."
    #     return 0
    # fi
    #printf "Printing....$json_data \n"
    # Convert the idlePeriodInput to seconds
    # Convert the idlePeriodInput to seconds
    idlePeriodSeconds=$(parseDateToSeconds "$idlePeriodInput")

    ec2_list_output=$(echo "$json_data" | jq -r --arg threshold "$threshold" --argjson idlePeriodSeconds "$idlePeriodSeconds" '
        .Reservations[].Instances | map(select(
            (.LaunchTime | fromdateiso8601 | mktime) <= (now - $idlePeriodSeconds) and (.CPUUtilization | tonumber) <= ($threshold | tonumber)
        )) | map(.InstanceId) | join(" ")
    ')


    # # Convert the idlePeriod to seconds
    # idlePeriodSeconds=$(date -d "$idlePeriod" +%s)

    # ec2_list_output=$(echo "$json_data" | jq -r --argjson idlePeriodSeconds "$idlePeriodSeconds" --arg threshold "$threshold" '
    #     .Reservations[].Instances | map(select(
    #         (.LaunchTime | fromdateiso8601 | mktime) <= (now - $idlePeriodSeconds) and (.CPUUtilization | tonumber) <= ($threshold | tonumber)
    #     )) | map(.InstanceId) | join(" ")
    # ')
    # ec2_list_output=$(echo "$json_data" | jq -r --argjson idlePeriodSeconds $((idlePeriod*24*60*60)) --arg threshold $threshold '
    #     .Reservations[].Instances | map(select(
    #         (.LaunchTime | fromdateiso8601 | mktime) <= (now - $idlePeriodSeconds) and (.CPUUtilization | tonumber) <= ($threshold|tonumber)
    #     )) | map(.InstanceId) | join(" ")
    # ')




    if [ -z "$ec2_list_output" ]; then
        echo -e "\n No EC2 instances found for Cost Optimization.\n"
    else
        echo "EC2 instances for Cost Optimization: ${bold}${ec2_list_output}${reset}"
        # createSnapshots
        # stopInstances
        # detachAndDeleteEbsVolumes
        # removeSecurityGroupRules
        # releaseElasticIPs
        # detachAndDeleteNetworkInterfaces
        # terminateInstances
    fi
}

function resourceOptimization() {
    # Check if the Instance Type is provided as an argument
    if [ $# -eq 1 ]; then
        instanceType=$1
    else
        instanceType=0
    fi

    # Check if instanceType is zero
    if [ $instanceType -eq 0 ]; then
        echo "You did not provide an Instance Type. Please provide a valid value."
        return 1
    fi

    # Get the list of all EC2 Instances based on the provided scenarios
    ec2_list_output=$(echo "$json_data" | jq -r '
        .Reservations[].Instances | map(select(
            .InstanceType == "t2.micro" or
            .InstanceType == "m5.large" or
            .InstanceType == "r5.xlarge" or
            .InstanceType == "m1.small" or
            .InstanceType == "c3.large" or
            .InstanceType == "m3.medium"
        )) | map(.InstanceId) | join(" ")
    ')
    # Get the list of all EC2 Instances that are overprovisioned and old configurations (e.g., 't2.micro')
    # ec2_list_output=$(aws ec2 describe-instances --filters "Name=instance-type,Values=${instanceType}" --query "Reservations[].Instances[].InstanceId" --output text)
    if [ -z "$ec2_list_output" ]; then
        echo -e "\n No EC2 instances found for Resource Optimization.\n"
    else
        echo "EC2 instances for Resource Optimization: ${bold}${ec2_list_output}${reset}"
        # createSnapshots
        # stopInstances
        # detachAndDeleteEbsVolumes
        # removeSecurityGroupRules
        # releaseElasticIPs
        # detachAndDeleteNetworkInterfaces
        # terminateInstances
    fi
}

function devEnvironmentCleanup() {
    # Check if the Environment Tag is provided as an argument
    if [ $# -eq 1 ]; then
        envTag=$1
    else
        envTag=0
    fi

    # Check if envTag is zero
    if [ $envTag -eq 0 ]; then
        echo "You did not provide a specific Tag. Please provide a valid value."
        return 1
    fi
    # Get the list of all EC2 Instances based on the provided scenarios
    ec2_list_output=$(echo "$json_data" | jq -r '
        .Reservations[].Instances | map(select(
            (.LaunchTime | fromdate) <= (now - 2*24*60*60) and .CPUUtilization <= 60
            and (.Tags[] | select(.Key == "Environment" and .Value == "Development")).Value == "Development"
            and (.Tags[] | select(.Key == "do-not-terminate")).Value != "true"
        )) | map(.InstanceId) | join(" ")
    ')

    # Get the list of all EC2 Instances a specific tag (e.g., Key=Environment, Value=Development)
    # ec2_list_output=$(aws ec2 describe-instances --filters "Name=tag:Environment,Values=$envTag" --query "Reservations[].Instances[].InstanceId" --output text)
    if [ -z "$ec2_list_output" ]; then
        echo -e "\n No EC2 instances found for Development Environment Cleanup.\n"
    else
        echo "EC2 instances for Development Environment Cleanup: ${bold}${ec2_list_output}${reset}"
        # createSnapshots
        # stopInstances
        # detachAndDeleteEbsVolumes
        # removeSecurityGroupRules
        # releaseElasticIPs
        # detachAndDeleteNetworkInterfaces
        # terminateInstances
    fi
}

function complianceSecurityCleanup() {
    # Check if the Security Group Port and/or SSH Key are provided as an argument
    if [ $# -eq 2 ]; then
        sgPort=$1
        sshKey=$2
    else
        sgPort=0
        sshKey=0
    fi

    # Check if envTag is zero
    if [ $envTag -eq 0 ]; then
        echo "You did not provide a specific Tag. Please provide a valid value."
        return 1
    fi
    ec2_list_output=$(echo "$json_data" | jq -r '
        .Reservations[].Instances | map(select(
            (.LaunchTime | fromdate) <= (now - 1*24*60*60) and .CPUUtilization <= 50
            and (.Tags[] | select(.Key == "Port" and .Value == "22")).Value == "22"
            and (.Tags[] | select(.Key == "Key-name" and .Value == "PowerUser_Pair")).Value == "PowerUser_Pair"
        )) | map(.InstanceId) | join(" ")
    ')
    # # Get the list of all EC2 Instances and filter out instances with open ports (assuming the instances have a Security Group allowing incoming traffic on port 22)
    # ec2_list_output=$(aws ec2 describe-instances \
    #     --query "Reservations[].Instances | 
    #           [?State.Name=='running' && SecurityGroups[].IpPermissions[?ToPort==null || ToPort>= $sgPort]] | 
    #           [?KeyName=='$sshKey'].InstanceId" \
    #     --output text)

    if [ -z "$ec2_list_output" ]; then
        echo -e "\n No EC2 instances found for Compliance and Security Cleanup.\n"
    else
        echo "EC2 instances for Compliance and Security Cleanup: ${bold}${ec2_list_output}${reset}"
        # createSnapshots
        # stopInstances
        # detachAndDeleteEbsVolumes
        # removeSecurityGroupRules
        # releaseElasticIPs
        # detachAndDeleteNetworkInterfaces
        # terminateInstances
    fi
}

# Create snapshots for EBS volumes attached to instances
function createSnapshots() {
    for instance_id in $ec2_list_output; do
        # Get the list of EBS volumes attached to the instance
        ebs_volumes=$(aws ec2 describe-volumes --filters "Name=attachment.instance-id,Values=$instance_id" --query "Volumes[].VolumeId" --output text)

        # Loop through each EBS volume to create a snapshot
        for volume_id in $ebs_volumes; do
            echo "Creating snapshot for EBS volume: ${bold}$volume_id${reset}"
            aws ec2 create-snapshot --volume-id "$volume_id" --description "Backup snapshot for instance $instance_id"
        done
    done
}

# Stop Instances
function stopInstances() {
    for instance_id in $ec2_list_output; do
        # Ask for confirmation before proceeding with stopping instances
        read -p "Are you sure you want to stop the EC2 instance ${bold}$instance_id${reset}? (yes/no): " confirmation
        case $confirmation in
            [Yy][Ee][Ss]|[Yy])
                echo "Stopping EC2 instance: ${bold}$instance_id${reset}"
                # aws ec2 stop-instances --instance-ids "$instance_id"
                ;;
            *)
                echo "Stopping EC2 instance 'Canceled': ${bold}$instance_id${reset}"
                ;;
        esac
        sleep 10
    done
}

# Remove any attached EBS Volumes
function detachAndDeleteEbsVolumes() {
    # Loop through each instance to handle EBS volumes
    for instance_id in $ec2_list_output; do
        echo "Detaching and deleting EBS volumes for EC2 instance: ${bold}$instance_id${reset}"
        # Get the list of EBS volumes attached to the instance
        ebs_volumes=$(aws ec2 describe-volumes --filters "Name=attachment.instance-id,Values=$instance_id" --query "Volumes[].VolumeId" --output text)

        # Loop through each EBS volume to detach and delete
        for volume_id in $ebs_volumes; do
            echo "Detaching EBS volume: ${bold}$volume_id${reset}"
            #aws ec2 detach-volume --volume-id "$volume_id"

            # Adding a delay before deleting the volume to ensure it is detached
            sleep 5

            echo "Deleting EBS volume: ${bold}$volume_id${reset}"
            #aws ec2 delete-volume --volume-id "$volume_id"
        done
    done
}

# Remove any Custom Security Group Rules
function removeSecurityGroupRules() {
    # Loop through each instance to handle Security Groups Rules
    for instance_id in $ec2_list_output; do
        echo "Removing custom Security Group Rules for EC2 instance: ${bold}$instance_id${reset}"

        # Get the security group IDs associated with the instance
        security_group_ids=$(aws ec2 describe-instances --instance-ids "$instance_id" --query "Reservations[].Instances[].SecurityGroups[].GroupId" --output text)

        # Loop through each security group to remove the custom rules
        for sg_id in $security_group_ids; do
            echo "Removing custom rules from Security Group: ${bold}$sg_id${reset}"

            # Get the custom security group rules for the instance (assuming custom rules have a specific source IP or port range)
            custom_rules=$(aws ec2 describe-security-group-rules --group-id "$sg_id" --query "SecurityGroupRules[?UserIdGroupPairs[0].GroupId=='$sg_id'].RuleId" --output text)

            # Loop through each custom rule to revoke it
            for rule_id in $custom_rules; do
                aws ec2 revoke-security-group-ingress --group-id "$sg_id" --rule-id "$rule_id"
            done
        done
    done
}

# Release Elastic IPs associated with instances
function releaseElasticIPs() {
    for instance_id in $ec2_list_output; do
        # Get the Elastic IP allocation ID associated with the instance
        elastic_ips=$(aws ec2 describe-instances --instance-ids "$instance_id" --query "Reservations[].Instances[].NetworkInterfaces[].Association.PublicIp" --output text)

        # Loop through each Elastic IP to release it
        for elastic_ip in $elastic_ips; do
            echo "Releasing Elastic IP: ${bold}$elastic_ip${reset}"
            aws ec2 release-address --public-ip "$elastic_ip"
        done
    done
}

# Detach and delete Network Interfaces associated with instances
function detachAndDeleteNetworkInterfaces() {
    for instance_id in $ec2_list_output; do
        # Get the Network Interface IDs associated with the instance
        network_interfaces=$(aws ec2 describe-instances --instance-ids "$instance_id" --query "Reservations[].Instances[].NetworkInterfaces[].NetworkInterfaceId" --output text)

        # Loop through each Network Interface to detach and delete it
        for network_interface in $network_interfaces; do
            echo "Detaching and deleting Network Interface: ${bold}$network_interface${reset}"
            aws ec2 detach-network-interface --attachment-id "$network_interface"
            aws ec2 delete-network-interface --network-interface-id "$network_interface"
        done
    done
}


# Terminate Instances
function terminateInstances() {
    # Check for "do not terminate" tag before proceeding
    for instance_id in $ec2_list_output; do
        # Get the instance tags
        instance_tags=$(aws ec2 describe-instances --instance-ids "$instance_id" --query "Reservations[].Instances[].Tags" --output json)

        # Check if any tag indicates "do not terminate"
        should_terminate=true
        for tag in $(echo "$instance_tags" | jq -c '.[] | @base64'); do
            _jq() {
                echo "$tag" | base64 --decode | jq -r "$1"
            }
            tag_key=$(_jq '.Key')
            tag_value=$(_jq '.Value')
            if [ "$tag_value" = "do-not-terminate" ]; then
                should_terminate=false
                break
            fi
        done

        if $should_terminate; then
            # Ask for confirmation before proceeding with termination
            read -p "Are you sure you want to terminate EC2 instance ${bold}$instance_id${reset}? (yes/no): " confirmation
            case $confirmation in
                [Yy][Ee][Ss]|[Yy])
                    echo "Terminating EC2 instance: ${bold}$instance_id${reset}"
                    # Uncomment the actual termination command when ready
                    # aws ec2 terminate-instances --instance-ids "$instance_id"
                    ;;
                *)
                    echo "Termination canceled for instance: ${bold}$instance_id${reset}"
                    ;;
            esac
        fi
    done
}

# Load the JSON mock data
#loadMockData

# Menu for the EC2 Cleanup script
function ec2Menu() {
    while true; do
        clear
        echo -ne "=== Menu for EC2 Cleanup === \n"
        echo " 1) Cost Optimization - terminate idle/underutilized(e.g. > 2 weeks, < 30% Threshold) instances"
        echo " 2) Resource Optimization - terminate overprovisioned/outdated configuration instances"
        echo " 3) Development Enviornment Cleanup - terminate instances tagged with a specific environment"
        echo " 4) Complaince and Security - terminate instances with risky security group rules"
        echo " 5) Exit"
        read -p "Enter your choice (1, 2, 3, 4, or 5): " num
        case $num in
        1)
            loadMockData
            echo -n "Enter the idle period (e.g. \"2 weeks\" or \"15 days\"): "
            read idlePeriod
            echo -n "Enter the underutilized threshold ((e.g. \"30\" for 30%): "
            read threshold
            loadMockData
            costOptimization "$idlePeriod" "$threshold"
            ;;
        2)
            echo -n "Enter the Instance Type (e.g. \"c4.xlarge\"): "
            read instanceType
            resourceOptimization "$instanceType"
            ;;
        3)
            echo -n "Enter the Environment Tag (e.g. \"Development\"): "
            read envTag
            devEnvironmentCleanup "$envTag"
            ;;
        4)
            echo -n "Enter the Port number to identify risky Security Group rules (e.g. \"22\" for SSH): "
            read sgPort
            echo -n "Enter the name of the SSH Key Pair used in risky instances (e.g. \"unauthorizedPair\"): "
            read sshKey
            complianceSecurityCleanup "$sgPort" "$sshKey"
            ;;
        5)
            echo "Exiting..."
            exit 0
            ;;
        *)
            echo "Invalid choice. Please enter a valid option (1, 2, 3, 4, or 5)"
            ;;
        esac
        read -n 1 -s -r -p "Press any key to continue..."
    done
}

# Run the Menu for EC2 script
ec2Menu
