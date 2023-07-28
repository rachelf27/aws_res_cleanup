# Bash Script to clean up AWS Resources

## Objective:

It is important to clean up any unused resources, and one of the best ways to do that is by automating the process through bash scripts.I wanted to write up a bash script that can cleanup my AWS resources. In this article, I will walk you through the creation of a bash script to clean up AWS resources, starting with S3 as the first script. For a write up and walk through see here.

### S3
The goal of this script is to identify and remove any AWS S3 buckets and objects that have not been used for 30 days. To determine if a bucket is eligible for deletion, we will inspect the last modified date of its objects. If any object is older than 30 days, we will consider the bucket for cleanup.


