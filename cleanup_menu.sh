#!/bin/bash
# This script is the Main Menu for cleaning up ALL AWS resources.

while true; do
    clear
    echo -ne "=== Main Menu for AWS Rescource Cleanup === \n"
    echo " 1) AWS S3 "
    echo " 2) AWS EC2 "
    echo " 3) Exit "
    read -p "Enter your choice: " num
    case $num in
    1)
        source s3_cleanup.sh
        ;;
    2)
        source ec2_cleanup.sh
        ;;
    3)
        echo "exiting..."
        exit 0
        ;;
    *)
        echo "Invalid choice. Please try again"
        ;;
    esac
done
