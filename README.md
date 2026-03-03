## Project Overview
This repository contains the complete infrastructure and application code for deploying a scalable, secure, and monitored blog application on AWS. The implementation covers all required tasks from 1 to 8, demonstrating core AWS services following infrastructure as code (IaC) principles and DevOps best practices.

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
```bash
AWS-Basic/
├── cloudformation/
│   ├── secure-s3-cf.yml                    # Task 8: S3 bucket template
│   └── complete-infrastructure.yml          # Full stack template (bonus)
├── application-code/
│   ├── index.html                           # Main blog frontend
│   ├── server-info.php                       # Server information endpoint
│   └── config/
│       └── database-config.php                # RDS connection configuration
├── lambda/
│   ├── resize-image-function.py               # Task 5: S3-triggered Lambda
│   └── requirements.txt                        # Python dependencies
├── scripts/
│   ├── deploy-all.sh                           # Master deployment script
│   ├── setup-iam.sh                             # Task 1: IAM setup
│   ├── setup-vpc-ec2.sh                         # Task 2: VPC & EC2 setup
│   ├── setup-alb.sh                              # Task 3: ALB configuration
│   ├── setup-rds.sh                              # Task 4: RDS setup
│   ├── setup-sns-sqs.sh                          # Task 5: Messaging setup
│   ├── setup-cloudfront.sh                        # Task 6: CDN setup
│   ├── setup-monitoring.sh                         # Task 7: Monitoring setup
│   └── deploy-cloudformation.sh                    # Task 8: CF deployment
├── waf/
│   └── waf-rules.json                             # Task 7: WAF rules
├── cloudwatch/
│   ├── alarm-config.json                           # Task 7: CloudWatch alarms
│   └── agent-config.json                            # CloudWatch agent config
├── kms/
│   └── key-policy.json                              # Task 7: KMS key policy
└── README.md                                         # This file
```
## 🚀 Features Implemented
#### Task 1: AWS Account & IAM
- MFA Enabled: Multi-factor authentication configured for root and IAM users
- IAM Users Created: Dedicated users with least privilege access
- Custom Policies: Fine-grained access control policies implemented

```bash
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
```
#### Task 2: Networking & Compute
- Custom VPC: Isolated network with public/private subnets across AZs
- Internet Gateway: Configured for public internet access
- EC2 Instance: Web server with Apache/PHP installed via user-data
- EBS Volume: Additional 2GB volume attached and mounted to /mnt/data
# Create VPC
```bash
aws ec2 create-vpc --cidr-block 10.0.0.0/16 --tag-specifications 'ResourceType=vpc,Tags=[{Key=Name,Value=BlogVPC}]'
```
# Launch EC2 with user-data
```bash
aws ec2 run-instances --image-id ami-0c02fb55956c7d316 --instance-type t2.micro --user-data file://user-data.sh
```
##### Task 3: Scalability & Load Balancing
- Target Group: Health checks configured on port 80
- Application Load Balancer: Internet-facing ALB with cross-zone load balancing
- Listener: HTTP:80 forwarding to target group
- High Availability: EC2 instance registered and healthy

```bash
# Create target group
aws elbv2 create-target-group --name blog-tg --protocol HTTP --port 80 --vpc-id vpc-xxxxxx

# Create load balancer
aws elbv2 create-load-balancer --name blog-alb --subnets subnet-xxxxxx1 subnet-xxxxxx2 --security-groups sg-xxxxxx
```
#### Task 4: Storage & Database
- S3 Bucket: Static assets storage with:
   - Versioning enabled
   - Default encryption (SSE-S3)
   - Public access blocked
- RDS MySQL: Managed database with:
   - Automated backups (7-day retention)
   - Multi-AZ deployment
   - Security group restricted to EC2 only
```bash
# Create S3 bucket with versioning and encryption
aws s3api create-bucket --bucket blog-static-assets --region us-east-1
aws s3api put-bucket-versioning --bucket blog-static-assets --versioning-configuration Status=Enabled
aws s3api put-bucket-encryption --bucket blog-static-assets --server-side-encryption-configuration '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'

# Create RDS instance
aws rds create-db-instance --db-instance-identifier blog-db --db-instance-class db.t3.micro --engine mysql --master-username admin --master-user-password password123 --allocated-storage 20
```
#### Task 5: Decoupling & Serverless
- SNS Topic: Blog-Notifications for publishing events
- SQS Queue: Image-Processing-Queue for background tasks
- Lambda Function: Python-based image resizer triggered by S3 uploads
- Dead Letter Queue: Configured for failed message handling
```bash
# Create SNS topic
aws sns create-topic --name Blog-Notifications

# Create SQS queue
aws sqs create-queue --queue-name Image-Processing-Queue

# Create Lambda function
aws lambda create-function --function-name resize-image --runtime python3.9 --role arn:aws:iam::account:role/lambda-role --handler resize-image-function.lambda_handler --zip-file fileb://lambda.zip
```
#### Task 6: Domain & Global Delivery
- Route 53: Domain registration and hosted zone configuration
- DNS Records: A-record alias pointing to ALB
- CloudFront: CDN distribution with:
   - S3 origin with OAI (Origin Access Identity)
   - HTTPS redirection
   - Price class: North America & Europe
```bash
# Create CloudFront distribution
aws cloudfront create-distribution --distribution-config file://distribution-config.json

# Create Route 53 record
aws route53 change-resource-record-sets --hosted-zone-id ZONE_ID --change-batch file://route53-changes.json
```
#### Task 7: Monitoring & Security
- CloudWatch
- CloudWatch:
   - CPU ≥80% alarm
   - 5XX error alarm
   - Custom dashboard with key metrics
   - Log aggregation from EC2
- WAF: Web ACL with:
   - AWS managed rules (SQLi, XSS)
   - Rate-based rules (2000 requests per IP)
- KMS: Customer-managed key with:
   - Automatic annual rotation
   - S3 and RDS encryption
```bash
# Create CloudWatch alarm
aws cloudwatch put-metric-alarm --alarm-name High-CPU --metric-name CPUUtilization --namespace AWS/EC2 --statistic Average --period 300 --threshold 80 --comparison-operator GreaterThanThreshold --dimensions Name=InstanceId,Value=i-xxxxxx

# Create KMS key
aws kms create-key --description "Blog encryption key" --tags TagKey=Name,TagValue=blog-key
```
#### Task 8: Automation with IaC
- CloudFormation Template: secure-s3-cf.yml with:
   - Bucket with versioning
   - Default encryption
   - Lifecycle policies
- AWS CLI Deployment:
```bash
# Deploy CloudFormation stack
aws cloudformation deploy \
  --template-file cloudformation/secure-s3-cf.yml \
  --stack-name BlogSecureBucketStack \
  --parameter-overrides BucketNameParam=myblog-bucket-$(date +%s) \
  --region us-east-1
```
#### 🚀 Deployment Instructions
- Prerequisites
- AWS Account with appropriate permissions
- AWS CLI installed and configured (aws configure)
- Git installed
- Basic understanding of AWS services

#### Step 1: Clone the Repository
```bash
git clone https://github.com/mohammadshakirsaifi/AWS-Basic.git
cd AWS-Basic
```
#### Step 2: Configure Deployment
Edit scripts/deployment-config.env with your specific values:
```bash
export AWS_REGION="us-east-1"
export VPC_ID="vpc-xxxxxx"              # Your VPC ID
export PUBLIC_SUBNET_1="subnet-xxxxxx1"  # Public subnet in AZ1
export PUBLIC_SUBNET_2="subnet-xxxxxx2"  # Public subnet in AZ2
export EC2_INSTANCE_ID="i-xxxxxx"        # Your EC2 instance ID
export EC2_SG_ID="sg-xxxxxx"             # Your EC2 security group
export DOMAIN_NAME="yourblog.com"        # Your domain (optional)
export EMAIL_NOTIFICATIONS="admin@yourblog.com"
```
#### Step 3: Run Master Deployment
```bash
cd scripts
chmod +x *.sh
./deploy-all.sh
The script will sequentially execute all tasks and provide a deployment summary.
```
####  Task Verification
###### Task 1: IAM
```bash
aws iam list-users
aws iam list-mfa-devices --user-name YourUserName
```
###### Task 2: VPC & EC2
``` bash
aws ec2 describe-vpcs --vpc-ids $VPC_ID
aws ec2 describe-instances --instance-ids $EC2_INSTANCE_ID
```
###### Task 3: Load Balancing
```bash
aws elbv2 describe-target-health --target-group-arn $TG_ARN
# Access application: http://${ALB_DNS}
```
###### Task 4: Storage & Database
```bash
aws s3 ls s3://${CF_BUCKET_NAME}
mysql -h ${RDS_ENDPOINT} -u admin -p -e "SHOW DATABASES;"
```
###### Task 5: Decoupling
```bash
aws sns publish --topic-arn $SNS_TOPIC_ARN --message "Test Notification"
aws sqs receive-message --queue-url $SQS_QUEUE_URL --max-number-of-messages 1
```
###### Task 6: Global Delivery
```bash
curl -I https://${CLOUDFRONT_DOMAIN}/index.html
dig ${DOMAIN_NAME}
```
###### Task 7: Monitoring
```bash
# Check CloudWatch dashboard
open "https://console.aws.amazon.com/cloudwatch/home?region=us-east-1#dashboards:name=Blog-Application-Dashboard"

# Test KMS encryption
echo "Secret" > test.txt
aws kms encrypt --key-id alias/blog-key --plaintext fileb://test.txt --output text --query CiphertextBlob
```
###### Task 8: Infrastructure as Code
```bash
aws cloudformation describe-stacks --stack-name BlogSecureBucketStack --query "Stacks[0].Outputs"
aws s3api get-bucket-versioning --bucket $CF_BUCKET_NAME
```
###### 📊 Monitoring Dashboard
Access the CloudWatch dashboard at:
```text
https://console.aws.amazon.com/cloudwatch/home?region=us-east-1#dashboards:name=Blog-Application-Dashboard
```
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
```bash
cd scripts
./cleanup.sh
```
Or manually delete:
1. Delete CloudFormation stack
2. Empty and delete S3 buckets
3. Terminate RDS instance
4. Delete Load Balancer
5. Disable and delete CloudFront distribution
6. Delete Lambda functions
7. Detach and delete EBS volumes
8. Terminate EC2 instances
9. Release Elastic IPs
10. Delete CloudWatch log groups

## 📸 Screenshots
<img width="1536" height="1024" alt="image" src="https://github.com/user-attachments/assets/0719702c-320c-4da1-8da0-de19a12a4e37" />

**Task1-IAM-MFA** → **IAM Dashboard showing MFA enabled**
<img width="1536" height="1024" alt="image" src="https://github.com/user-attachments/assets/36d24626-48ad-446f-bd7a-552b021916d1" />

**Task2-VPC-EC2** → **VPC with EC2 instance running and public IP attached**
<img width="1536" height="1024" alt="image" src="https://github.com/user-attachments/assets/d7ef0985-3a5e-4b2e-8c98-b561d925b956" />

**Task3-ALB** → **Application Load Balancer listeners and healthy target group**
<img width="1536" height="1024" alt="image" src="https://github.com/user-attachments/assets/ed39c67a-d07b-4390-a065-9542709e249d" />

**Task4-S3-RDS** → **S3 bucket and RDS endpoint with database status**
<img width="1536" height="1024" alt="image" src="https://github.com/user-attachments/assets/7ce42f90-a550-4066-94fa-adb54418a73c" />

**Task5-SNS-SQS-Lambda** → **SNS topic, SQS queue, and Lambda trigger**
**SNS topic created (post notifications)**
  <img width="1536" height="1024" alt="image" src="https://github.com/user-attachments/assets/a003d8f7-e8f7-4211-8255-353e487b6189" />
**SQS queue (background tasks)**
<img width="1536" height="1024" alt="image" src="https://github.com/user-attachments/assets/9fd4a59e-cf77-4164-a94c-173637b5c42a" />
**Lambda + S3 trigger (image resize)**
<img width="1536" height="1024" alt="image" src="https://github.com/user-attachments/assets/88fd2f99-46bf-4fa8-81e4-659a140cb297" />

**Task6-Route53-CloudFront** → **Route 53 hosted zone and CloudFront distribution**
**Domain registered in Route 53 (Hosted Zone)**
  <img width="1536" height="1024" alt="image" src="https://github.com/user-attachments/assets/d5023213-a500-4dd5-bb2d-d17dcdd40c99" />
**Record (A/AAAA) alias pointing to ALB**
  <img width="1536" height="1024" alt="image" src="https://github.com/user-attachments/assets/7d552ad9-253a-4a0d-83d9-1a1241896015" />
**CloudFront distribution with S3 origin**
  <img width="1536" height="1024" alt="image" src="https://github.com/user-attachments/assets/e4c4e547-c185-45a8-b8d3-207fe11dda24" />

**Task7-CloudWatch-WAF-KMS** → **CloudWatch alarm, WAF rule, and KMS key**
**CloudWatch alarm + log group enabled**
  <img width="1536" height="1024" alt="image" src="https://github.com/user-attachments/assets/e92dfc4c-a27a-4243-b9ca-173cdcf1498a" />
**AWS WAF Web ACL associated with ALB**
  <img width="1536" height="1024" alt="image" src="https://github.com/user-attachments/assets/4f24aee2-0ab9-41e7-b219-8e2f6bd06d47" />
**KMS key + S3/RDS encryption enabled**
  <img width="1536" height="1024" alt="image" src="https://github.com/user-attachments/assets/bfcdfd9a-ed22-47f0-bca0-ea39355b39fd" />

**Task8-CloudFormation** → **CloudFormation stack status: CREATE_COMPLETE**
  <img width="1536" height="1024" alt="image" src="https://github.com/user-attachments/assets/50c572ae-1432-4bd2-adb5-beceab84232f" />
###### SSE-S3 (AES256) version
```txt
AWSTemplateFormatVersion: '2010-09-09'
Description: S3 bucket with versioning and SSE-S3 encryption

Resources:
  BlogBucket:
    Type: AWS::S3::Bucket
    Properties:
      BucketName: blog-static-assets-demo
      VersioningConfiguration:
        Status: Enabled
      BucketEncryption:
        ServerSideEncryptionConfiguration:
          - ServerSideEncryptionByDefault:
              SSEAlgorithm: AES256
```
###### KMS-managed keys (SSE-KMS) version
- Uses the AWS-managed key for S3 (aws/s3). To use your own CMK, replace KMSMasterKeyID with your key ARN or ID.
```txt
AWSTemplateFormatVersion: '2010-09-09'
Description: S3 bucket with versioning and SSE-KMS encryption

Resources:
  BlogBucket:
    Type: AWS::S3::Bucket
    Properties:
      BucketName: blog-static-assets-demo
      VersioningConfiguration:
        Status: Enabled
      BucketEncryption:
        ServerSideEncryptionConfiguration:
          - ServerSideEncryptionByDefault:
              SSEAlgorithm: aws:kms
              KMSMasterKeyID: alias/aws/s3   # or arn:aws:kms:region:acct:key/uuid
```
**CloudFormation-Deploy-Cli**
###### s3-bucket.yaml (CloudFormation Template)
```bash
AWSTemplateFormatVersion: '2010-09-09'
Description: S3 bucket for static blog assets with versioning and encryption enabled

Resources:
  BlogS3Bucket:
    Type: AWS::S3::Bucket
    Properties:
      BucketName: blog-static-assets-demo-12345
      VersioningConfiguration:
        Status: Enabled
      BucketEncryption:
        ServerSideEncryptionConfiguration:
          - ServerSideEncryptionByDefault:
              SSEAlgorithm: AES256

Outputs:
  BucketName:
    Description: Name of the S3 bucket
    Value: !Ref BlogS3Bucket
```
 ```txt
aws cloudformation deploy \
  --template-file s3-bucket.yaml \
  --stack-name blog-s3-stack \
  --capabilities CAPABILITY_NAMED_IAM
```
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
