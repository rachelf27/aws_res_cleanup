#!/bin/bash
# This script cleans up the AWS S3 resources.

# ANSI escape sequence for bold text
bold=$(tput bold)

# ANSI escape sequence to reset formatting
reset=$(tput sgr0)

# Verify AWS CLI Credentials are setup
if ! (aws configure list); then
    echo "AWS config is not setup or CLI not installed. Please run \"aws configure\"."
    exit 1
fi

# Get the list of all S3 buckets and objects
s3_list_output=$(aws s3 ls)

# List out all AWS S3 Buckets and Objects
function listBucketsAndObjects() {
    echo "$s3_list_output" | nl
    printf "\n"

    aws s3 ls | awk '{print $NF}' | while read bucket; do
        echo " Objects in ${bold}$bucket${reset}"
        aws s3 ls $bucket | nl
        printf "\n"
    done
}

# Function to delete objects older than 30 days
function deleteObjectsOlderThan30Days() {
    ageThresholdDays=30

    aws s3 ls | awk '{print $NF}' | while read -r bucket; do
        echo " Objects in $bucket: "
        aws s3api list-objects --bucket "$bucket" --query 'Contents[?LastModified < `'"$(date -v-${ageThresholdDays}d -u +%Y-%m-%dT%H:%M:%SZ)"'`].{Key: Key}' --output text | while read -r objName; do
            if [ "$objName" == None ]; then
                printf "  This is an Empty Bucket. \n"
                continue
            else
                printf "  Deleting \"${bold}$objName${reset}\" in bucket \"${bold}$bucket${reset}\"\n"
            fi
            # Uncomment the line below to delete the objects
            #aws s3api delete-object --bucket "$bucket" --key "$objName"
        done
    done
}

# Function to delete empty buckets
function deleteEmptyBuckets() {
    aws s3 ls | awk '{print $NF}' | while read -r bucket; do
        # Check if the bucket has any objects
        if aws s3api list-objects --bucket "$bucket" --query 'Contents' 2>/dev/null | grep -q 'Key'; then
            continue
        fi

        echo "Deleting empty bucket: ${bold}$bucket${reset}"

        # Uncomment the line below to delete the empty bucket
        #aws s3 rb "s3://$bucket"
    done
}
printf '\n***List all available Buckets and Objects***\n'
listBucketsAndObjects
printf '\n***Deleting Objects Older Than 30 Days***\n'
deleteObjectsOlderThan30Days
printf '\n***Deleting Empty Buckets***\n'
deleteEmptyBuckets
