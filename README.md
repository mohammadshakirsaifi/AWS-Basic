Project Overview

This repository contains the complete infrastructure and application code for deploying a scalable, secure, and monitored blog application on AWS.

The implementation covers Tasks 1–8, demonstrating core AWS services using:

Infrastructure as Code (IaC)

AWS CLI automation

DevOps best practices

Security-first architecture

High availability design

## 🏗️ Architecture Components

| Task   | Component               | Description                                      |
|--------|-------------------------|--------------------------------------------------|
| Task 1 | IAM & Security          | MFA-enabled accounts, IAM users, custom policies |
| Task 2 | Networking & Compute    | Custom VPC, subnets, EC2 with EBS                |
| Task 3 | Load Balancing          | Application Load Balancer with EC2 backend       |
| Task 4 | Storage & Database      | S3 (versioning + encryption) and RDS MySQL       |
| Task 5 | Decoupling & Serverless | SNS, SQS, Lambda image processing                |
| Task 6 | Global Delivery         | Route 53 and CloudFront CDN                      |
| Task 7 | Monitoring & Security   | CloudWatch, WAF, KMS encryption                  |
| Task 8 | Infrastructure as Code  | CloudFormation templates, AWS CLI                |

## 📁 Repository Structure
``txt 
AWS-Basic/
├── cloudformation/
│   ├── secure-s3-cf.yml
│   └── complete-infrastructure.yml
├── application-code/
│   ├── index.html
│   ├── server-info.php
│   └── config/
│       └── database-config.php
├── lambda/
│   ├── resize-image-function.py
│   └── requirements.txt
├── scripts/
│   ├── deploy-all.sh
│   ├── setup-iam.sh
│   ├── setup-vpc-ec2.sh
│   ├── setup-alb.sh
│   ├── setup-rds.sh
│   ├── setup-sns-sqs.sh
│   ├── setup-cloudfront.sh
│   ├── setup-monitoring.sh
│   └── deploy-cloudformation.sh
├── waf/
│   └── waf-rules.json
├── cloudwatch/
│   ├── alarm-config.json
│   └── agent-config.json
├── kms/
│   └── key-policy.json
└── README.md
``
## 🚀 Features Implemented
#### Task 1: AWS Account & IAM
- MFA enabled for root and IAM users
- IAM users created with least-privilege access
- Custom IAM policies implemented
``txt
# Create IAM user
aws iam create-user --user-name blog-admin

# Attach policy
aws iam attach-user-policy \
  --user-name blog-admin \
  --policy-arn arn:aws:iam::aws:policy/AdministratorAccess

# Create virtual MFA device
aws iam create-virtual-mfa-device \
  --virtual-mfa-device-name blog-admin-mfa \
  --outfile /tmp/qrcode.png \
  --bootstrap-method QRCodePNG
``
#### Task 2: Networking & Compute
- Custom VPC with public/private subnets
- Internet Gateway attached
- EC2 instance with Apache/PHP
- 2GB EBS volume mounted to /mnt/data
``txt
# Create VPC
aws ec2 create-vpc \
  --cidr-block 10.0.0.0/16 \
  --tag-specifications 'ResourceType=vpc,Tags=[{Key=Name,Value=BlogVPC}]'

# Launch EC2
aws ec2 run-instances \
  --image-id ami-0c02fb55956c7d316 \
  --instance-type t2.micro \
  --user-data file://user-data.sh
``

##### Task 3: Scalability & Load Balancing
- Application Load Balancer (Internet-facing)
- Target group with health checks (port 80)
- Cross-zone load balancing enabled
``txt
# Create target group
aws elbv2 create-target-group \
  --name blog-tg \
  --protocol HTTP \
  --port 80 \
  --vpc-id vpc-xxxxxx

# Create ALB
aws elbv2 create-load-balancer \
  --name blog-alb \
  --subnets subnet-xxxxxx1 subnet-xxxxxx2 \
  --security-groups sg-xxxxxx
``
#### Task 4: Storage & Database
- S3 Configuration
- Versioning enabled
- Default encryption (SSE-S3)
- Public access blocked
``txt
aws s3api create-bucket --bucket blog-static-assets --region us-east-1

aws s3api put-bucket-versioning \
  --bucket blog-static-assets \
  --versioning-configuration Status=Enabled

aws s3api put-bucket-encryption \
  --bucket blog-static-assets \
  --server-side-encryption-configuration '{
    "Rules":[{
      "ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}
    }]
  }'
``
## RDS MySQL
- Automated backups (7 days)
- Multi-AZ deployment
- Restricted security group
``bash
aws rds create-db-instance \
  --db-instance-identifier blog-db \
  --db-instance-class db.t3.micro \
  --engine mysql \
  --master-username admin \
  --master-user-password password123 \
  --allocated-storage 20
``
#### Task 5: Decoupling & Serverless
- SNS topic for notifications
- SQS queue for background tasks
- Lambda function (Python image resizing)
- Dead Letter Queue enabled
``bash
aws sns create-topic --name Blog-Notifications
aws sqs create-queue --queue-name Image-Processing-Queue
aws lambda create-function \
  --function-name resize-image \
  --runtime python3.9 \
  --role arn:aws:iam::account-id:role/lambda-role \
  --handler resize-image-function.lambda_handler \
  --zip-file fileb://lambda.zip
``
#### Task 6: Domain & Global Delivery
- Route 53 hosted zone
- A-record alias to ALB
- CloudFront CDN
- HTTPS redirection enabled
  ``bash
aws cloudfront create-distribution \
  --distribution-config file://distribution-config.json

aws route53 change-resource-record-sets \
  --hosted-zone-id ZONE_ID \
  --change-batch file://route53-changes.json
``

#### Task 7: Monitoring & Security
- CloudWatch
- CPU ≥ 80% alarm
- 5XX error alarm
- Custom dashboard
- Log aggregation
``bash
aws cloudwatch put-metric-alarm \
  --alarm-name High-CPU \
  --metric-name CPUUtilization \
  --namespace AWS/EC2 \
  --statistic Average \
  --period 300 \
  --threshold 80 \
  --comparison-operator GreaterThanThreshold \
  --dimensions Name=InstanceId,Value=i-xxxxxx
``
  #### KMS
``bash
aws kms create-key \
  --description "Blog encryption key" \
  --tags TagKey=Name,TagValue=blog-key
``
#### WAF
- AWS managed rule sets (SQLi, XSS)
- Rate-based rule (2000 req/IP)

#### Deployment Instructions
- Prerequisites
- AWS Account
- AWS CLI installed and configured (aws configure)
- Git installed

#### Step 1: Clone Repository
``bash
git clone https://github.com/mohammadshakirsaifi/AWS-Basic.git
cd AWS-Basic
``
#### Step 2: Configure Environment
scripts/deployment-config.env
``txt
Example:

export AWS_REGION="us-east-1"
export VPC_ID="vpc-xxxxxx"
export PUBLIC_SUBNET_1="subnet-xxxxxx1"
export PUBLIC_SUBNET_2="subnet-xxxxxx2"
export EC2_INSTANCE_ID="i-xxxxxx"
export EC2_SG_ID="sg-xxxxxx"
export DOMAIN_NAME="yourblog.com"
export EMAIL_NOTIFICATIONS="admin@yourblog.com"
``
#### Step 3: Deploy
``bash
cd scripts
chmod +x *.sh
./deploy-all.sh
``
#### Monitoring Dashboard
Access:
https://console.aws.amazon.com/cloudwatch/home?region=us-east-1#dashboards:name=Blog-Application-Dashboard
## 🔒 Security Features

| Feature            | Implementation                             |
|-------------------|--------------------------------------------|
| MFA                | Enabled for all IAM users                  |
| Encryption at Rest | S3 (SSE-S3), RDS (KMS), EBS (KMS)         |
| Network Security   | Security groups, private subnets           |
| Web Security       | WAF (SQLi/XSS protection)                  |
| Access Control     | Least-privilege IAM roles                  |
| Monitoring         | CloudTrail, CloudWatch Logs                |

#### 🧹 Clean Up
To avoid charges:
``bash
cd scripts
./cleanup.sh
``
Or manually delete:
- CloudFormation stacks
- S3 buckets
- RDS instances
- ALB
- CloudFront distribution
- Lambda functions
- EC2 instances
- EBS volumes
- CloudWatch log groups
#### 📝 License
Licensed under the MIT License.

## 👤 Author
Mohammad Shakir Saifi
GitHub: https://github.com/mohammadshakirsaifi
Repository: AWS-Basic

#### 🙏 Acknowledgments
- AWS Documentation
- AWS CloudFormation User Guide
- AWS Well-Architected Framework

#### 📸 Screenshots
Task	Screenshot
- Task 1	screenshots/task1-iam-mfa.png
- Task 2	screenshots/task2-vpc-ec2.png
- Task 3	screenshots/task3-alb.png
- Task 4	screenshots/task4-s3-rds.png
- Task 5	screenshots/task5-sns-sqs-lambda.png
- Task 6	screenshots/task6-route53-cloudfront.png
- Task 7	screenshots/task7-cloudwatch-waf-kms.png
- Task 8	screenshots/task8-cloudformation.png
