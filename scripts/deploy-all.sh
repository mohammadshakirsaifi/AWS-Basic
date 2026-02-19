#!/bin/bash

# Master deployment script for all tasks
# This script orchestrates the entire deployment process

set -e

echo "========================================="
echo "AWS Blog Application - Complete Deployment"
echo "========================================="
echo ""

# Check prerequisites
echo "Checking prerequisites..."
command -v aws >/dev/null 2>&1 || { echo "AWS CLI is required but not installed. Aborting." >&2; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "jq is required but not installed. Installing..." >&2; sudo yum install -y jq; }
command -v mysql >/dev/null 2>&1 || { echo "MySQL client is required. Installing..." >&2; sudo yum install -y mysql; }

# Load configuration if exists
if [ -f "deployment-config.env" ]; then
    source deployment-config.env
else
    echo "Creating default configuration..."
    cat > deployment-config.env << EOF
# AWS Deployment Configuration
export AWS_REGION="us-east-1"
export VPC_ID="vpc-xxxxxx"
export PUBLIC_SUBNET_1="subnet-xxxxxx1"
export PUBLIC_SUBNET_2="subnet-xxxxxx2"
export EC2_INSTANCE_ID="i-xxxxxx"
export EC2_SG_ID="sg-xxxxxx"
export DOMAIN_NAME="yourblog.com"
export EMAIL_NOTIFICATIONS="admin@yourblog.com"
EOF
    echo "Please edit deployment-config.env with your values and run again"
    exit 1
fi

source deployment-config.env

# Create logs directory
mkdir -p deployment-logs

# Function to log and run commands
run_task() {
    TASK_NAME=$1
    SCRIPT_PATH=$2
    
    echo ""
    echo "========================================="
    echo "Running: $TASK_NAME"
    echo "========================================="
    echo ""
    
    LOG_FILE="deployment-logs/$(date +%Y%m%d-%H%M%S)-${TASK_NAME}.log"
    
    if [ -f "$SCRIPT_PATH" ]; then
        bash "$SCRIPT_PATH" 2>&1 | tee "$LOG_FILE"
        
        if [ ${PIPESTATUS[0]} -eq 0 ]; then
            echo "✅ $TASK_NAME completed successfully"
        else
            echo "❌ $TASK_NAME failed. Check log: $LOG_FILE"
            exit 1
        fi
    else
        echo "⚠️  Script not found: $SCRIPT_PATH"
    fi
    
    echo ""
    sleep 5
}

# Task 3: Scalability & Load Balancing
run_task "Task 3: ALB Setup" "./setup-alb.sh"

# Load ALB outputs
if [ -f "alb-outputs.txt" ]; then
    source alb-outputs.txt
fi

# Task 4: Storage & Database
run_task "Task 4: RDS Setup" "./setup-rds.sh"

# Task 5: Decoupling & Serverless
run_task "Task 5: SNS/SQS Setup" "./setup-sns-sqs.sh"

# Task 6: CloudFront & Domain
run_task "Task 6: CloudFront Setup" "./setup-cloudfront.sh"

# Task 7: Monitoring & Security
run_task "Task 7: Monitoring Setup" "./setup-monitoring.sh"

# Task 8: Infrastructure as Code
run_task "Task 8: CloudFormation" "./deploy-cloudformation.sh"

# Create deployment summary
echo ""
echo "========================================="
echo "Deployment Summary"
echo "========================================="
echo ""

cat > deployment-summary.txt << EOF
AWS Blog Application - Deployment Summary
Generated: $(date)

=== Task 3: Load Balancing ===
ALB DNS: ${ALB_DNS:-Not configured}
ALB ARN: ${ALB_ARN:-Not configured}
Target Group: ${TG_NAME:-Not configured}

=== Task 4: Database ===
RDS Endpoint: ${RDS_ENDPOINT:-Not configured}
Database Name: ${DB_NAME:-Not configured}

=== Task 5: Messaging ===
SNS Topic ARN: ${SNS_TOPIC_ARN:-Not configured}
SQS Queue URL: ${SQS_QUEUE_URL:-Not configured}

=== Task 6: CDN ===
CloudFront Domain: ${CLOUDFRONT_DOMAIN:-Not configured}
Distribution ID: ${CLOUDFRONT_DIST_ID:-Not configured}

=== Task 7: Security ===
WAF ACL ID: ${WAF_ACL_ID:-Not configured}
KMS Key ID: ${KMS_KEY_ID:-Not configured}
Dashboard: ${CLOUDWATCH_DASHBOARD:-Not configured}

=== Task 8: IaC ===
CloudFormation Stack: ${CF_STACK_NAME:-Not configured}
S3 Bucket: ${CF_BUCKET_NAME:-Not configured}

=== Access URLs ===
Application URL: http://${ALB_DNS:-Not configured}
CloudFront URL: https://${CLOUDFRONT_DOMAIN:-Not configured}
S3 Bucket: s3://${CF_BUCKET_NAME:-Not configured}

EOF

cat deployment-summary.txt

echo ""
echo "✅ All tasks completed successfully!"
echo "📋 Summary saved to: deployment-summary.txt"
echo "📁 Logs saved to: deployment-logs/"
echo ""
echo "Next steps:"
echo "1. Test your application at: http://${ALB_DNS}"
echo "2. Check CloudWatch dashboard: Blog-Application-Dashboard"
echo "3. Monitor SQS queue for messages"
echo "4. Upload test images to S3 to trigger Lambda"
echo ""
echo "To clean up resources (when done):"
echo "aws cloudformation delete-stack --stack-name $CF_STACK_NAME"