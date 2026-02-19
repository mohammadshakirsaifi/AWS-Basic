#!/bin/bash

# Task 8: Deploy CloudFormation template using AWS CLI

set -e

echo "=== Task 8: Deploying CloudFormation Stack ==="

# Configuration
STACK_NAME="BlogSecureBucketStack"
TEMPLATE_FILE="../cloudformation/secure-s3-cf.yml"
BUCKET_NAME_PREFIX="myblog-static-assets"
ENVIRONMENT="dev"

# Generate unique bucket name
UNIQUE_SUFFIX=$(date +%s)
BUCKET_NAME="${BUCKET_NAME_PREFIX}-${ENVIRONMENT}-${UNIQUE_SUFFIX}"

echo "Deploying stack: $STACK_NAME"
echo "Bucket name: $BUCKET_NAME"

# 1. Validate CloudFormation template
echo "Validating CloudFormation template..."
aws cloudformation validate-template \
    --template-body file://$TEMPLATE_FILE

if [ $? -ne 0 ]; then
    echo "Template validation failed!"
    exit 1
fi

echo "Template validation successful"

# 2. Deploy stack
echo "Deploying CloudFormation stack..."
aws cloudformation deploy \
    --template-file $TEMPLATE_FILE \
    --stack-name $STACK_NAME \
    --parameter-overrides \
        EnvironmentName=$ENVIRONMENT \
        BucketNamePrefix=$BUCKET_NAME_PREFIX \
    --capabilities CAPABILITY_IAM \
    --tags \
        Key=Project,Value=BlogApplication \
        Key=Environment,Value=$ENVIRONMENT \
        Key=ManagedBy,Value=CloudFormation

# 3. Wait for stack creation to complete
echo "Waiting for stack creation to complete..."
aws cloudformation wait stack-create-complete \
    --stack-name $STACK_NAME

# 4. Get stack outputs
echo "Stack outputs:"
aws cloudformation describe-stacks \
    --stack-name $STACK_NAME \
    --query 'Stacks[0].Outputs' \
    --output table

# 5. List stack resources
echo "Stack resources:"
aws cloudformation list-stack-resources \
    --stack-name $STACK_NAME \
    --query 'StackResourceSummaries[*].[LogicalResourceId,ResourceType,ResourceStatus]' \
    --output table

# 6. Upload a test file to the bucket
echo "Testing bucket by uploading a test file..."
BUCKET_NAME=$(aws cloudformation describe-stacks \
    --stack-name $STACK_NAME \
    --query 'Stacks[0].Outputs[?OutputKey==`BucketName`].OutputValue' \
    --output text)

echo "Test file content" > /tmp/test-file.txt

aws s3 cp /tmp/test-file.txt s3://$BUCKET_NAME/test-file.txt

# 7. Enable versioning (already enabled in template, but verify)
echo "Verifying bucket versioning..."
aws s3api get-bucket-versioning \
    --bucket $BUCKET_NAME

# 8. Verify encryption
echo "Verifying bucket encryption..."
aws s3api get-bucket-encryption \
    --bucket $BUCKET_NAME

echo "=== Task 8 Complete ==="
echo "Stack Name: $STACK_NAME"
echo "Bucket Name: $BUCKET_NAME"
echo ""
echo "To delete the stack (clean up):"
echo "aws cloudformation delete-stack --stack-name $STACK_NAME"

# Save outputs
cat > cloudformation-outputs.txt << EOF
CF_STACK_NAME=$STACK_NAME
CF_BUCKET_NAME=$BUCKET_NAME
CF_ENVIRONMENT=$ENVIRONMENT
EOF

echo "Outputs saved to cloudformation-outputs.txt"

# Clean up
rm -f /tmp/test-file.txt