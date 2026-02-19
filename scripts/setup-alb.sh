#!/bin/bash

# Task 3: Configure ALB with EC2 backend
# This script sets up Application Load Balancer with target groups

set -e

echo "=== Task 3: Setting up Application Load Balancer ==="

# Configuration
VPC_ID="vpc-xxxxxx"  # Replace with your VPC ID
SUBNET_1="subnet-xxxxxx1"  # Replace with your public subnet 1
SUBNET_2="subnet-xxxxxx2"  # Replace with your public subnet 2
EC2_INSTANCE_ID="i-xxxxxx"  # Replace with your EC2 instance ID
ALB_NAME="blog-alb"
TG_NAME="blog-tg"
SG_NAME="alb-sg"

# 1. Create security group for ALB
echo "Creating security group for ALB..."
SG_ID=$(aws ec2 create-security-group \
    --group-name $SG_NAME \
    --description "Security group for Blog ALB" \
    --vpc-id $VPC_ID \
    --query 'GroupId' \
    --output text)

# Allow HTTP from anywhere
aws ec2 authorize-security-group-ingress \
    --group-id $SG_ID \
    --protocol tcp \
    --port 80 \
    --cidr 0.0.0.0/0

# Allow HTTPS if needed
aws ec2 authorize-security-group-ingress \
    --group-id $SG_ID \
    --protocol tcp \
    --port 443 \
    --cidr 0.0.0.0/0

echo "Security group created: $SG_ID"

# 2. Create target group
echo "Creating target group..."
TG_ARN=$(aws elbv2 create-target-group \
    --name $TG_NAME \
    --protocol HTTP \
    --port 80 \
    --vpc-id $VPC_ID \
    --health-check-protocol HTTP \
    --health-check-path / \
    --health-check-interval-seconds 30 \
    --health-check-timeout-seconds 5 \
    --healthy-threshold-count 2 \
    --unhealthy-threshold-count 2 \
    --query 'TargetGroups[0].TargetGroupArn' \
    --output text)

echo "Target group created: $TG_ARN"

# 3. Register EC2 instance with target group
echo "Registering EC2 instance with target group..."
aws elbv2 register-targets \
    --target-group-arn $TG_ARN \
    --targets Id=$EC2_INSTANCE_ID

# 4. Create load balancer
echo "Creating Application Load Balancer..."
ALB_ARN=$(aws elbv2 create-load-balancer \
    --name $ALB_NAME \
    --subnets $SUBNET_1 $SUBNET_2 \
    --security-groups $SG_ID \
    --scheme internet-facing \
    --type application \
    --ip-address-type ipv4 \
    --query 'LoadBalancers[0].LoadBalancerArn' \
    --output text)

echo "Load balancer created: $ALB_ARN"

# Wait for ALB to be active
echo "Waiting for load balancer to become active..."
aws elbv2 wait load-balancer-available \
    --load-balancer-arns $ALB_ARN

# 5. Create listener
echo "Creating listener..."
LISTENER_ARN=$(aws elbv2 create-listener \
    --load-balancer-arn $ALB_ARN \
    --protocol HTTP \
    --port 80 \
    --default-actions Type=forward,TargetGroupArn=$TG_ARN \
    --query 'Listeners[0].ListenerArn' \
    --output text)

echo "Listener created: $LISTENER_ARN"

# 6. Get ALB DNS name
ALB_DNS=$(aws elbv2 describe-load-balancers \
    --load-balancer-arns $ALB_ARN \
    --query 'LoadBalancers[0].DNSName' \
    --output text)

echo "=== Task 3 Complete ==="
echo "ALB DNS: http://$ALB_DNS"
echo "Target Group ARN: $TG_ARN"
echo ""
echo "Next steps:"
echo "1. Test ALB by visiting: http://$ALB_DNS"
echo "2. Configure Route 53 to point your domain to this ALB"
echo "3. Verify health checks in AWS Console"

# Save outputs to file
cat > alb-outputs.txt << EOF
ALB_NAME=$ALB_NAME
ALB_ARN=$ALB_ARN
ALB_DNS=$ALB_DNS
TG_NAME=$TG_NAME
TG_ARN=$TG_ARN
SG_ID=$SG_ID
LISTENER_ARN=$LISTENER_ARN
EOF

echo "Outputs saved to alb-outputs.txt"