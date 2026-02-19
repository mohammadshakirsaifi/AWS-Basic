#!/bin/bash

# Task 5: Create SNS topic and SQS queue for decoupling

set -e

echo "=== Task 5: Setting up SNS and SQS ==="

# Configuration
SNS_TOPIC_NAME="Blog-Notifications"
SQS_QUEUE_NAME="Image-Processing-Queue"
EMAIL_ENDPOINT="your-email@example.com"  # Replace with your email

# 1. Create SNS topic
echo "Creating SNS topic..."
SNS_TOPIC_ARN=$(aws sns create-topic \
    --name $SNS_TOPIC_NAME \
    --attributes DisplayName="Blog Notifications" \
    --query 'TopicArn' \
    --output text)

echo "SNS topic created: $SNS_TOPIC_ARN"

# 2. Create email subscription (optional)
if [ "$EMAIL_ENDPOINT" != "your-email@example.com" ]; then
    echo "Creating email subscription..."
    aws sns subscribe \
        --topic-arn $SNS_TOPIC_ARN \
        --protocol email \
        --notification-endpoint $EMAIL_ENDPOINT
    
    echo "Confirmation email sent to $EMAIL_ENDPOINT"
fi

# 3. Create SQS queue
echo "Creating SQS queue..."
SQS_QUEUE_URL=$(aws sqs create-queue \
    --queue-name $SQS_QUEUE_NAME \
    --attributes '{
        "VisibilityTimeout": "30",
        "MessageRetentionPeriod": "345600",
        "ReceiveMessageWaitTimeSeconds": "20",
        "DelaySeconds": "0",
        "MaximumMessageSize": "262144"
    }' \
    --query 'QueueUrl' \
    --output text)

SQS_QUEUE_ARN=$(aws sqs get-queue-attributes \
    --queue-url $SQS_QUEUE_URL \
    --attribute-names QueueArn \
    --query 'Attributes.QueueArn' \
    --output text)

echo "SQS queue created: $SQS_QUEUE_URL"

# 4. Subscribe SQS queue to SNS topic
echo "Subscribing SQS queue to SNS topic..."
aws sns subscribe \
    --topic-arn $SNS_TOPIC_ARN \
    --protocol sqs \
    --notification-endpoint $SQS_QUEUE_ARN

# 5. Set SQS queue policy to allow SNS to send messages
echo "Setting SQS queue policy..."
cat > sqs-policy.json << EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Service": "sns.amazonaws.com"
            },
            "Action": "sqs:SendMessage",
            "Resource": "$SQS_QUEUE_ARN",
            "Condition": {
                "ArnEquals": {
                    "aws:SourceArn": "$SNS_TOPIC_ARN"
                }
            }
        }
    ]
}
EOF

aws sqs set-queue-attributes \
    --queue-url $SQS_QUEUE_URL \
    --attributes Policy=file://sqs-policy.json

rm sqs-policy.json

# 6. Create dead letter queue for failed messages
echo "Creating dead letter queue..."
DLQ_NAME="${SQS_QUEUE_NAME}-dlq"
DLQ_URL=$(aws sqs create-queue \
    --queue-name $DLQ_NAME \
    --attributes '{
        "MessageRetentionPeriod": "1209600"
    }' \
    --query 'QueueUrl' \
    --output text)

DLQ_ARN=$(aws sqs get-queue-attributes \
    --queue-url $DLQ_URL \
    --attribute-names QueueArn \
    --query 'Attributes.QueueArn' \
    --output text)

# 7. Configure redrive policy for main queue
echo "Configuring redrive policy..."
aws sqs set-queue-attributes \
    --queue-url $SQS_QUEUE_URL \
    --attributes '{
        "RedrivePolicy": "{\"deadLetterTargetArn\":\"'"$DLQ_ARN"'\",\"maxReceiveCount\":\"3\"}"
    }'

echo "=== Task 5 Complete ==="
echo "SNS Topic ARN: $SNS_TOPIC_ARN"
echo "SQS Queue URL: $SQS_QUEUE_URL"
echo "SQS Queue ARN: $SQS_QUEUE_ARN"
echo "DLQ URL: $DLQ_URL"

# Save outputs
cat > sns-sqs-outputs.txt << EOF
SNS_TOPIC_ARN=$SNS_TOPIC_ARN
SQS_QUEUE_URL=$SQS_QUEUE_URL
SQS_QUEUE_ARN=$SQS_QUEUE_ARN
DLQ_URL=$DLQ_URL
DLQ_ARN=$DLQ_ARN
EOF

echo "Outputs saved to sns-sqs-outputs.txt"