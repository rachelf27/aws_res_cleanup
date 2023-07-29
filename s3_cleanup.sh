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

# Function to list Buckets and Objects
function listBucketsAndObjects() {
    # Check if the ageThresholdDays is provided as an argument
    if [ $# -eq 1 ]; then
        ageThresholdDays=$1
    else
        ageThresholdDays=0
    fi

    aws s3 ls | awk '{print $NF}' | while read -r bucket; do
        if [ $ageThresholdDays -eq 0 ]; then
            # List all objects in the bucket
            echo " Objects in ${bold}$bucket${reset}"
            aws s3 ls "$bucket" | nl
            printf "\n"
        else
            # List only objects older than the ageThresholdDays
            echo " Objects in ${bold}$bucket${reset} (Older than $ageThresholdDays days)"
            aws s3api list-objects --bucket "$bucket" --query 'Contents[?LastModified < `'"$(date -v-${ageThresholdDays}d -u +%Y-%m-%dT%H:%M:%SZ)"'`].{Key: Key}' --output text | nl
            printf "\n"
        fi
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
            aws s3api delete-object --bucket "$bucket" --key "$objName"
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
        aws s3 rb "s3://$bucket"
    done
}

# Menu for the S3 Cleanup script
function s3Menu() {
    while true; do
    clear
    echo -ne "=== Menu for S3 Cleanup === \n"
        echo " 1) List all available Buckets and Objects"
        echo " 2) List only Buckets and Objects older than 30 days"
        echo " 3) Delete Objects Older Than 30 Days"
        echo " 4) Delete Empty Buckets"
        echo " 5) Exit"
        read -p "Enter your choice: " num
        case $num in
            1)
                listBucketsAndObjects
                ;;
            2)
                echo -n "Enter the age threshold (in days): "
                read ageThreshold
                listBucketsAndObjects "$ageThreshold"
                ;;
            3)
                printf '\n***Deleting Objects Older Than 30 Days***\n'
                deleteObjectsOlderThan30Days
                ;;
            4)
                printf '\n***Deleting Empty Buckets***\n'
                deleteEmptyBuckets
                ;;
            5)
                echo "Exiting..."
                exit 0
                ;;
            *)
                echo "Invalid choice. Please try again"
                ;;
        esac
        read -n 1 -s -r -p "Press any key to continue..."
    done
}

# Run the Menu for S3 script
s3Menu
