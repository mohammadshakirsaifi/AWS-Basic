#!/bin/bash

# Task 4: Set up RDS MySQL and connect from EC2

set -e

echo "=== Task 4: Setting up RDS MySQL ==="

# Configuration
DB_INSTANCE_IDENTIFIER="blog-db"
DB_NAME="blogdb"
DB_USERNAME="admin"
DB_PASSWORD="YourSecurePassword123!"
DB_INSTANCE_CLASS="db.t3.micro"
DB_ENGINE="mysql"
DB_ENGINE_VERSION="8.0.35"
DB_ALLOCATED_STORAGE="20"
VPC_ID="vpc-xxxxxx"  # Replace with your VPC ID
EC2_SG_ID="sg-xxxxxx"  # Replace with your EC2 security group ID

# 1. Create DB subnet group
echo "Creating DB subnet group..."
aws rds create-db-subnet-group \
    --db-subnet-group-name "blog-db-subnet-group" \
    --db-subnet-group-description "Subnet group for blog RDS" \
    --subnet-ids '["subnet-xxxxxx1", "subnet-xxxxxx2", "subnet-xxxxxx3"]'  # Replace with your subnet IDs

# 2. Create security group for RDS
echo "Creating security group for RDS..."
RDS_SG_ID=$(aws ec2 create-security-group \
    --group-name "rds-sg" \
    --description "Security group for RDS MySQL" \
    --vpc-id $VPC_ID \
    --query 'GroupId' \
    --output text)

# Allow MySQL access from EC2 security group
aws ec2 authorize-security-group-ingress \
    --group-id $RDS_SG_ID \
    --protocol tcp \
    --port 3306 \
    --source-group $EC2_SG_ID

echo "RDS security group created: $RDS_SG_ID"

# 3. Create RDS instance
echo "Creating RDS MySQL instance (this will take 5-10 minutes)..."
aws rds create-db-instance \
    --db-instance-identifier $DB_INSTANCE_IDENTIFIER \
    --db-name $DB_NAME \
    --master-username $DB_USERNAME \
    --master-user-password $DB_PASSWORD \
    --db-instance-class $DB_INSTANCE_CLASS \
    --engine $DB_ENGINE \
    --engine-version $DB_ENGINE_VERSION \
    --allocated-storage $DB_ALLOCATED_STORAGE \
    --storage-type gp2 \
    --storage-encrypted \
    --vpc-security-group-ids $RDS_SG_ID \
    --db-subnet-group-name "blog-db-subnet-group" \
    --publicly-accessible \
    --backup-retention-period 7 \
    --backup-window "03:00-04:00" \
    --maintenance-window "sun:04:00-sun:05:00" \
    --auto-minor-version-upgrade \
    --deletion-protection \
    --enable-cloudwatch-logs-exports '["error","general","slowquery"]' \
    --tags Key=Name,Value=BlogDatabase Key=Environment,Value=Production

# Wait for instance to be available
echo "Waiting for RDS instance to become available..."
aws rds wait db-instance-available \
    --db-instance-identifier $DB_INSTANCE_IDENTIFIER

# Get RDS endpoint
RDS_ENDPOINT=$(aws rds describe-db-instances \
    --db-instance-identifier $DB_INSTANCE_IDENTIFIER \
    --query 'DBInstances[0].Endpoint.Address' \
    --output text)

RDS_PORT=$(aws rds describe-db-instances \
    --db-instance-identifier $DB_INSTANCE_IDENTIFIER \
    --query 'DBInstances[0].Endpoint.Port' \
    --output text)

echo "=== Task 4 Complete ==="
echo "RDS Endpoint: $RDS_ENDPOINT:$RDS_PORT"
echo "Database Name: $DB_NAME"
echo "Username: $DB_USERNAME"

# 4. Test connection from EC2 (requires EC2 instance ID)
echo ""
echo "To test connection from EC2, SSH into your instance and run:"
echo "mysql -h $RDS_ENDPOINT -P $RDS_PORT -u $DB_USERNAME -p$DB_PASSWORD $DB_NAME -e 'SHOW TABLES;'"

# Save outputs
cat > rds-outputs.txt << EOF
RDS_ENDPOINT=$RDS_ENDPOINT
RDS_PORT=$RDS_PORT
DB_NAME=$DB_NAME
DB_USERNAME=$DB_USERNAME
DB_PASSWORD=$DB_PASSWORD
RDS_SG_ID=$RDS_SG_ID
EOF

echo "Outputs saved to rds-outputs.txt"