#!/bin/sh
# This script cleans up the AWS EC2 resources.

# Verify AWS CLI Credentials are setup
if ! (aws configure list); then
    echo "AWS config is not setup or CLI not installed. Please run \"aws configure\"."
    exit 1
fi

# Get the list of all EC2 Instances
ec2_list_output=$(aws ec2 describe-instances)

# List out all AWS S3 Buckets and Objects
function listBucketsAndObjects() {
    echo "$s3_list_output" | awk '{print $NF}' | while read l; do
        echo " Objects in $l:"
        echo "$s3_list_output" | grep "$l" | nl
        printf "\n"
    done
}
