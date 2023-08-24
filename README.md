# Bash Script to clean up AWS Resources

## Objective:

It is important to clean up any unused resources, and one of the best ways to do that is by automating the process through bash scripts.I wanted to write up a bash script that can cleanup my AWS resources. 

### Main Menu Overview
The Main Menu serves as the gateway for users to select their desired AWS resource for cleanup.

### S3 
In my article, [Bash Scripts to Clean Up AWS Resources (Part 1 — S3 Resources)](https://medium.com/@rachelvfmurphy/bash-scripts-to-clean-up-aws-resources-part-1-s3-resources-e6a865ee3e60), I guide you through the creation of a bash script designed to clean up AWS S3 resources.   
The script's objective is to identify and remove unused S3 buckets and objects older than 30 days.

### EC2
Discover how to effectively manage your AWS EC2 instances in my article series **Part 2: Cleaning Up AWS Resources — EC2 Instances** across three parts: [1](https://medium.com/@rachelvfmurphy/part-2-cleaning-up-aws-resources-ec2-instances-c2b23fdca3b6), [2](https://medium.com/@rachelvfmurphy/part-2-ec2-cleanup-building-use-case-functions-step-3-1893c8f1cdc6), [3](https://medium.com/@rachelvfmurphy/part-2-ec2-cleanup-perform-common-actions-step-4-10ecb597005).   
I delve into use case scenarios, step-by-step procedures, and provide a script to help you streamline the process of cleaning up EC2 resources.

## Requirements
A valid AWS account with Access Key and Secret Key.  

## Getting Started:
- Clone the project.
- After cloning the repository, you'll need to install the following dependencies (Use the latest. I used Homebrew for most of my MacOS installs).  
  
  Install jq:  
  `brew install jq`  

    AWS CLI  
    [Install or update the latest version of the AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)


- Change permissions of the script prior to executing.  
  `chmod +x cleanup_menu.sh`  
  `chmod +x s3_cleanup.sh`  
  `chmod +x ec2_cleanup.sh`  

- Set up AWS CLI by entering the AWS CLI configs.  
  `export AWS_ACCESS_KEY=<AWS_ACCESS_KEY_ID>`    
  `export AWS_SECRET_KEY=<AWS_SECRET_ACCESS_KEY>`  
  `export AWS_EC2_REGION=<AWS_DEFAULT_REGION>` 

## Usage
- To run the scripts in the terminal via main menu:  
`./cleanup_menu.sh`  

- To run individual scripts:  
`./s3_cleanup.sh`  

