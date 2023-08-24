#!/bin/bash
# This script cleans up the AWS EC2 resources.

export AWS_PAGER=""

# Verify AWS CLI Credentials are setup
if ! (aws configure list); then
    echo "AWS config is not setup or CLI not installed. Please run \"aws configure\"."
    exit 1
fi

# Optionally, you can prompt the user to press Enter before continuing
read -r -p "Press Enter to continue..."

# ANSI escape sequence for bold text
bold=$(tput bold)

# ANSI escape sequence to reset formatting
reset=$(tput sgr0)

# Global variable to track if the stop action is confirmed or canceled
stop_action_confirmed="no"

function costOptimization() {
    # Check if the Number of Days and Threshold are provided as an argument
    if [ $# -eq 2 ]; then
        threshold=$1
        numDays=$2
    else
        threshold=""
        numDays=""
    fi

    # Initialize the ec2_list_output variable to an empty string
    ec2_list_output=""

    if [ -z "$threshold" ] || [ -z "$numDays" ]; then
        echo -e "\nYou did not provide valid values. Please enter values for the CPU Threshold and number of days to calculate the average threshold. \n"
        return 1
    elif (($threshold < 0 || $threshold > 50)); then
        echo -e "\nThreshold should be between 0 and 50. Please provide a valid CPU Threshold value.\n"
        return 1
    elif (($numDays <= 0)); then
        echo -e "\nNumber of days should be a positive integer. Please provide a valid number of days.\n"
        return 1
    else
        # Get the current date in ISO8601 format
        current_timestamp=$(date -u +'%Y-%m-%dT%H:%M:%SZ')
        end_timestamp=$current_timestamp
        start_timestamp=$(date -v -"$numDays"d +'%Y-%m-%dT%H:%M:%SZ')

        # Get a list of instances
        instances=$(aws ec2 describe-instances --query "Reservations[].Instances[].InstanceId" --output json)

        # Loop through each instance to get its CPU utilization metrics
        for instance_id in $(echo "${instances}" | jq -r '.[]'); do
            # Get CPUUtilization metric from CloudWatch for the instance
            average_cpu_utilization=$(aws cloudwatch get-metric-statistics \
                --namespace "AWS/EC2" \
                --metric-name "CPUUtilization" \
                --dimensions "Name=InstanceId,Value=$instance_id" \
                --statistics "Average" \
                --start-time "$start_timestamp" \
                --end-time "$end_timestamp" \
                --period 3600 \
                --query "Datapoints[].Average" \
                --output text)

            if awk -v avg_cpu="$average_cpu_utilization" -v threshold="$threshold" 'BEGIN { exit avg_cpu >= threshold }'; then
                # Check if the instance meets the criteria for termination
                echo -e "\nInstance ID: $instance_id has average CPU utilization below $threshold% and will be terminated."
                ec2_list_output=$instance_id
            fi
        done

    fi
    if [ -z "$ec2_list_output" ]; then
        echo -e "\nNo EC2 instances found for Cost Optimization.\n"
    else
        echo -e "\nEC2 instances for Cost Optimization: ${bold}${ec2_list_output}${reset}\n"
        stopInstances
        if [ "$stop_action_confirmed" = "yes" ]; then
            performCommonActions
        fi
    fi
}

function resourceOptimization() {
    # Check if the Instance Type is provided as an argument
    if [ $# -eq 1 ]; then
        instanceType=$1
    else
        instanceType=""
    fi

    # Check if instanceType is zero
    if [ -z "$instanceType" ]; then
        echo -e "\nYou did not provide an Instance Type. Please provide a valid value.\n"
        return 1
    fi

    # Get the list of all EC2 Instances that are overprovisioned and old configurations (e.g., 't2.micro')
    ec2_list_output=$(aws ec2 describe-instances --filters "Name=instance-type,Values=${instanceType}" --query "Reservations[].Instances[].InstanceId" --output text)
    if [ -z "$ec2_list_output" ]; then
        echo -e "\nNo EC2 instances found for Resource Optimization.\n"
    else
        echo -e "\nEC2 instances for Resource Optimization: ${bold}${ec2_list_output}${reset}\n"
        stopInstances
        if [ "$stop_action_confirmed" = "yes" ]; then
            performCommonActions
        fi
    fi
}

function devEnvironmentCleanup() {
    # Check if the Environment Tag is provided as an argument
    if [ $# -eq 1 ]; then
        envTag=$1
    else
        envTag=""
    fi

    # Check if envTag is zero
    if [ -z "$envTag" ]; then
        echo -e "\nYou did not provide a specific Tag. Please provide a valid value.\n"
        return 1
    fi

    # Get the list of all EC2 Instances a specific tag (e.g., Key=Environment, Value=Development)
    ec2_list_output=$(aws ec2 describe-instances --filters "Name=tag:Environment,Values=$envTag" --query "Reservations[].Instances[].InstanceId" --output text)
    if [ -z "$ec2_list_output" ]; then
        echo -e "\nNo EC2 instances found for tag $envTag in Development Environment Cleanup.\n"
    else
        echo -e "\nEC2 instances for Development Environment Cleanup: ${bold}${ec2_list_output}${reset}\n"
        stopInstances
        if [ "$stop_action_confirmed" = "yes" ]; then
            performCommonActions
        fi
    fi
}

function complianceSecurityCleanup() {
    # Check if the Security Group Port and/or SSH Key are provided as an argument
    if [ $# -eq 2 ]; then
        sgPort=$1
        sshKey=$2
    else
        sgPort=""
        sshKey=""
    fi

    # Initialize the ec2_list_output variable to an empty string
    ec2_list_output=""

    # Check if both sgPort and sshKey are empty
    if [ -z "$sgPort" ] && [ -z "$sshKey" ]; then
        echo -e "\nYou did not provide Port Number or SSH hKey. Please provide a valid value.\n"
        return 1
    fi

    # Check the scenarios and build the ec2_list_output variable accordingly
    if [ ! -z "$sgPort" ] && [ ! -z "$sshKey" ]; then
        sg_id=$(aws ec2 describe-security-groups \
            --filters "Name=ip-permission.to-port,Values=$sgPort" \
            --query "SecurityGroups[?IpPermissions[?ToPort==\`$sgPort\`]].GroupId | [0]" \
            --output text)

        # If sg_id is empty, it means the provided sgPort is invalid, but we have a valid sshKey.
        # In this case, we need to check if the provided sshKey exists in any of the instances' Security Groups.
        if [ -z "$sg_id" ]; then
            ec2_list_output=$(aws ec2 describe-instances \
                --filters "Name=instance-state-name,Values=running" \
                --query "Reservations[].Instances[?SecurityGroups[?contains(IpPermissions[].UserIdGroupPairs[].GroupId, \`$sshKey\`)]] | [].InstanceId" \
                --output text)

            if [ -z "$ec2_list_output" ]; then
                echo -e "\nNo EC2 instances found with Port Number: $sgPort and SSH Key Pair: $sshKey.\n"
                return 1
            fi
        else
            ec2_list_output=$(aws ec2 describe-instances \
                --filters "Name=instance-state-name,Values=running" "Name=instance.group-id,Values=$sg_id" \
                --query "Reservations[].Instances[].InstanceId" \
                --output text)
        fi
    elif [ ! -z "$sgPort" ]; then
        sg_id=$(aws ec2 describe-security-groups \
            --filters "Name=ip-permission.to-port,Values=$sgPort" \
            --query "SecurityGroups[?IpPermissions[?ToPort==\`$sgPort\`]].GroupId | [0]" \
            --output text)

        if [ -z "$sg_id" ]; then
            echo -e "\nNo EC2 instances found with Port Number: $sgPort.\n"
            return 1
        else
            ec2_list_output=$(aws ec2 describe-instances \
                --filters "Name=instance-state-name,Values=running" "Name=instance.group-id,Values=$sg_id" \
                --query "Reservations[].Instances[].InstanceId" \
                --output text)
        fi
    elif [ ! -z "$sshKey" ]; then
        ec2_list_output=$(aws ec2 describe-instances \
            --filters "Name=instance-state-name,Values=running" "Name=key-name,Values=$sshKey" \
            --query "Reservations[].Instances[].InstanceId" \
            --output text)

        # Check if the ec2_list_output is empty for the provided sshKey
        if [ -z "$ec2_list_output" ]; then
            # If ec2_list_output is empty, check if the provided sshKey exists in any of the instances' Security Groups
            ec2_list_output=$(aws ec2 describe-instances \
                --filters "Name=instance-state-name,Values=running" \
                --query "Reservations[].Instances[?SecurityGroups[?contains(IpPermissions[].UserIdGroupPairs[].GroupId, \`$sshKey\`)]] | [].InstanceId" \
                --output text)

            if [ -z "$ec2_list_output" ]; then
                echo -e "\nNo EC2 instances found with SSH Key Pair: $sshKey.\n"
                return 1
            fi
        fi
    fi

    if [ -z "$ec2_list_output" ]; then
        echo -e "\nNo EC2 instances found for Compliance and Security Cleanup.\n"
    else
        echo -e "\nEC2 instances for Compliance and Security Cleanup: ${bold}${ec2_list_output}${reset}\n"
        stopInstances
        if [ "$stop_action_confirmed" = "yes" ]; then
            performCommonActions
        fi
    fi
}

# Stop Instances
function stopInstances() {
    for instance_id in $ec2_list_output; do
        # Ask for confirmation before proceeding with stopping instances
        read -p "Are you sure you want to stop the EC2 instance ${bold}$instance_id${reset}? (yes/no): " confirmation
        case $confirmation in
        [Yy][Ee][Ss] | [Yy])
            echo -e "Stopping EC2 instance: ${bold}$instance_id${reset}\n"
            aws ec2 stop-instances --instance-ids "$instance_id"
            stop_action_confirmed="yes"
            ;;
        *)
            echo -e "Stopping EC2 instance 'Canceled': ${bold}$instance_id${reset}\n"
            stop_action_confirmed="no"
            break # Break out of the loop if the user cancels the stop action
            ;;
        esac
        sleep 10
    done
}

function performCommonActions() {
            createSnapshots
            detachAndDeleteEbsVolumes
            removeSecurityGroupRules
            releaseElasticIPs
            detachAndDeleteNetworkInterfaces
            terminateInstances
}

# Create snapshots for EBS volumes attached to instances
function createSnapshots() {
    for instance_id in $ec2_list_output; do
        # Get the list of EBS volumes attached to the instance
        ebs_volumes=$(aws ec2 describe-volumes --filters "Name=attachment.instance-id,Values=$instance_id" --query "Volumes[].VolumeId" --output text)

        # Loop through each EBS volume to create a snapshot
        for volume_id in $ebs_volumes; do
            echo -e "Creating snapshot for EBS volume: ${bold}$volume_id${reset}\n"
            aws ec2 create-snapshot --volume-id "$volume_id" --description "Backup snapshot for instance $instance_id"
        done
    done
}

# Remove attached EBS Volumes
function detachAndDeleteEbsVolumes() {
    # Loop through each instance to handle EBS volumes
    for instance_id in $ec2_list_output; do
        echo -e "Detaching and deleting EBS volumes for EC2 instance: ${bold}$instance_id${reset}"
        # Get the list of EBS volumes attached to the instance
        ebs_volumes=$(aws ec2 describe-volumes --filters "Name=attachment.instance-id,Values=$instance_id" --query "Volumes[].VolumeId" --output text)
        # Loop through each EBS volume to detach and delete
        for volume_id in $ebs_volumes; do
            # Get the volume's deleteOnTermination status
            deleteOnTerminate=$(aws ec2 describe-volumes --volume-id "$volume_id" --query "Volumes[0].Attachments[0].DeleteOnTermination")

            # Check if deleteOnTermination is set to false
            if [ "$deleteOnTerminate" = "false" ]; then
                echo -e "Detaching EBS volume: ${bold}$volume_id${reset}"
                aws ec2 detach-volume --volume-id "$volume_id"
                sleep 5
                echo -e "Deleting EBS volume: ${bold}$volume_id${reset}\n"
                aws ec2 delete-volume --volume-id "$volume_id"
            else
                echo -e "Skipping detach and delete. This EBS Volume is the root volume. When the instance is terminated the root volume will also be terminated.\n"
            fi
        done
    done
}

# Remove Custom Security Group Rules
function removeSecurityGroupRules() {
    # Loop through each instance to handle Security Groups Rules
    for instance_id in $ec2_list_output; do
        echo "Removing custom Security Group Rules for ${bold}EC2 instance${reset}: ${bold}$instance_id${reset}"

        # Get the security group IDs associated with the instance
        security_group_ids=$(aws ec2 describe-instances --instance-ids "$instance_id" --query "Reservations[].Instances[].SecurityGroups[].GroupId" --output text)

        # Loop through each security group to remove the custom rules
        for sg_id in $security_group_ids; do
            echo "Removing custom rules from ${bold}Security Group${reset}: ${bold}$sg_id${reset}"

            # Get the custom security group rules for the instance
            custom_rules=$(aws ec2 describe-security-groups --group-id "$sg_id" --query "SecurityGroups[0].IpPermissions" --output json)
            echo "The list of rules assigned to the EC2 Instance: $custom_rules"

            # Iterate over each element in the JSON array using jq
            echo "$custom_rules" | jq -c '.[]' | while IFS= read -r rule; do
                # Check if the rule is the default rule ("-1" for "IpProtocol")
                is_default_rule=$(echo "$rule" | jq '.IpProtocol == "-1"')
                if [ "$is_default_rule" = "true" ]; then
                    echo -e "Skipping revoke for default rule: $rule\n"
                    continue
                fi

                # If it is not the default rule, proceed to process it
                from_port=$(echo "$rule" | jq '.FromPort')
                to_port=$(echo "$rule" | jq '.ToPort')
                cidr_ip=$(echo "$rule" | jq -r '.IpRanges[0].CidrIp // empty')
                group_id=$(echo "$rule" | jq -r '.UserIdGroupPairs[0].GroupId // empty')

                # Check if the rule is custom (not the default rule)
                if [[ "$cidr_ip" != "0.0.0.0/0" || "$from_port" != 0 || "$to_port" != 65535 || -n "$group_id" ]]; then
                    echo -e "Revoking custom security group rule: $rule\n"
                    aws ec2 revoke-security-group-ingress --group-id "$sg_id" --protocol $(echo "$rule" | jq -r '.IpProtocol') --port "$from_port"-"$to_port" --cidr "$cidr_ip"
                fi
            done
        done
    done
}

# Release Elastic IPs associated with instances
function releaseElasticIPs() {
    for instance_id in $ec2_list_output; do
        # Get the Elastic IP allocation ID associated with the instance
        elastic_ip_allocation_id=$(aws ec2 describe-addresses --filters "Name=instance-id,Values=$instance_id" --query "Addresses[].AllocationId" --output text)

        if [ -z "$elastic_ip_allocation_id" ]; then
            echo -e "There are no Elastic IPs attached to this EC2 Instance.\n"
        else
            # Loop through each Elastic IP allocation ID to release it
            for elastic_ip_id in $elastic_ip_allocation_id; do
                echo -e "Releasing Elastic IP: ${bold}$elastic_ip_id${reset}\n"
                aws ec2 release-address --allocation-id "$elastic_ip_id"
            done
        fi
    done
}

# Detach and delete Network Interfaces associated with instances
function detachAndDeleteNetworkInterfaces() {
    for instance_id in $ec2_list_output; do
        # Get the Network Interface IDs associated with the instance
        network_interfaces=$(aws ec2 describe-instances --instance-ids "$instance_id" --query "Reservations[].Instances[].NetworkInterfaces[].NetworkInterfaceId" --output text)

        # Loop through each Network Interface to detach and delete it
        for eni_id in $network_interfaces; do
            # Get the network interface deleteOnTermination status
            deleteOnTerminate=$(aws ec2 describe-network-interfaces --network-interface-ids "$eni_id" --query "NetworkInterfaces[].Attachment.DeleteOnTermination" --output text)

            aws ec2 describe-network-interface-attribute --network-interface-id $eni_id --attribute attachment

            # Check if deleteOnTermination is set to false
            if [ "$deleteOnTerminate" = "False" ]; then
                echo "Detaching the Network Interface: ${bold}$eni_id${reset}"
                attachment_id=$(aws ec2 describe-network-interfaces --network-interface-ids "$eni_id" --query "NetworkInterfaces[].Attachment.AttachmentId" --output text)
                aws ec2 detach-network-interface --attachment-id "$attachment_id" --force
                echo "Deleting Network Interface: ${bold}$eni_id${reset}\n"
                aws ec2 delete-network-interface --network-interface-id "$eni_id"
                echo "Detaching the Network Interface: ${bold}$eni_id${reset}"
                aws ec2 detach-network-interface --attachment-id "$eni_id"
                echo "Deleting Network Interface: ${bold}$eni_id${reset}\n"
                aws ec2 delete-network-interface --network-interface-id "$eni_id"
            else
                echo -e "Skipping detach and delete. This Network Interface has Delete On Termination status set to True. When the instance is terminated this Network Interface will also be terminated.\n"
            fi
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
            [Yy][Ee][Ss] | [Yy])
                echo -e "Terminating EC2 instance: ${bold}$instance_id${reset}\n"
                aws ec2 terminate-instances --instance-ids "$instance_id"
                ;;
            *)
                echo -e "Termination canceled for instance: ${bold}$instance_id${reset}\n"
                ;;
            esac
        fi
    done
}

# Menu for the EC2 Cleanup script
function ec2Menu() {
    while true; do
        clear
        echo -ne "=== Menu for EC2 Cleanup === \n"
        echo " 1) Cost Optimization - terminate idle/underutilized(e.g. < 30% Threshold) instances"
        echo " 2) Resource Optimization - terminate overprovisioned/outdated configuration instances"
        echo " 3) Development Enviornment Cleanup - terminate instances tagged with a specific environment"
        echo " 4) Compliance and Security - terminate instances with risky security group rules"
        echo " 5) Exit"
        read -p "Enter your choice (1, 2, 3, 4, or 5): " num
        case $num in
        1)
            echo -n "Enter the threshold for underutilization (e.g., 30): "
            read threshold
            echo -n "Enter the number of days to calculate the average threshold (e.g., 4): "
            read numDays

            costOptimization "$threshold" "$numDays"
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
