#!/bin/bash

# Task 7: Set up CloudWatch alarms, WAF, and KMS encryption

set -e

echo "=== Task 7: Setting up Monitoring & Security ==="

# Configuration
ALB_ARN="arn:aws:elasticloadbalancing:us-east-1:123456789012:loadbalancer/app/blog-alb/xxxxxx"  # Replace with your ALB ARN
EC2_INSTANCE_ID="i-xxxxxx"  # Replace with your EC2 instance ID
SNS_TOPIC_ARN="arn:aws:sns:us-east-1:123456789012:Blog-Notifications"  # Replace with your SNS topic ARN
KMS_KEY_ALIAS="blog-key"

# ============================================
# PART 1: CloudWatch Alarms and Logs
# ============================================

echo "Setting up CloudWatch alarms..."

# 1. CPU Utilization Alarm
aws cloudwatch put-metric-alarm \
    --alarm-name "Blog-High-CPU" \
    --alarm-description "Alert when CPU exceeds 80%" \
    --metric-name CPUUtilization \
    --namespace AWS/EC2 \
    --statistic Average \
    --period 300 \
    --evaluation-periods 2 \
    --threshold 80 \
    --comparison-operator GreaterThanThreshold \
    --dimensions Name=InstanceId,Value=$EC2_INSTANCE_ID \
    --alarm-actions $SNS_TOPIC_ARN \
    --ok-actions $SNS_TOPIC_ARN \
    --insufficient-data-actions $SNS_TOPIC_ARN

# 2. ALB 5XX Error Alarm
aws cloudwatch put-metric-alarm \
    --alarm-name "Blog-ALB-5XX-Errors" \
    --alarm-description "Alert when ALB returns > 10 5XX errors in 5 minutes" \
    --metric-name HTTPCode_ELB_5XX_Count \
    --namespace AWS/ApplicationELB \
    --statistic Sum \
    --period 300 \
    --evaluation-periods 2 \
    --threshold 10 \
    --comparison-operator GreaterThanThreshold \
    --dimensions Name=LoadBalancer,Value=$ALB_ARN \
    --alarm-actions $SNS_TOPIC_ARN

# 3. ALB Target Response Time Alarm
aws cloudwatch put-metric-alarm \
    --alarm-name "Blog-High-Latency" \
    --alarm-description "Alert when target response time exceeds 2 seconds" \
    --metric-name TargetResponseTime \
    --namespace AWS/ApplicationELB \
    --statistic Average \
    --period 300 \
    --evaluation-periods 2 \
    --threshold 2 \
    --comparison-operator GreaterThanThreshold \
    --dimensions Name=LoadBalancer,Value=$ALB_ARN \
    --alarm-actions $SNS_TOPIC_ARN

# 4. RDS Database Connections Alarm
aws cloudwatch put-metric-alarm \
    --alarm-name "Blog-RDS-Connections" \
    --alarm-description "Alert when database connections exceed 100" \
    --metric-name DatabaseConnections \
    --namespace AWS/RDS \
    --statistic Average \
    --period 300 \
    --evaluation-periods 2 \
    --threshold 100 \
    --comparison-operator GreaterThanThreshold \
    --dimensions Name=DBInstanceIdentifier,Value=blog-db \
    --alarm-actions $SNS_TOPIC_ARN

# 5. Configure CloudWatch Logs agent on EC2
echo "Creating CloudWatch Logs agent configuration..."
cat > /tmp/cloudwatch-agent-config.json << EOF
{
    "agent": {
        "metrics_collection_interval": 60,
        "run_as_user": "root"
    },
    "logs": {
        "logs_collected": {
            "files": {
                "collect_list": [
                    {
                        "file_path": "/var/log/httpd/access_log",
                        "log_group_name": "/blog/apache/access",
                        "log_stream_name": "{instance_id}",
                        "timezone": "UTC"
                    },
                    {
                        "file_path": "/var/log/httpd/error_log",
                        "log_group_name": "/blog/apache/error",
                        "log_stream_name": "{instance_id}",
                        "timezone": "UTC"
                    },
                    {
                        "file_path": "/var/log/messages",
                        "log_group_name": "/blog/system/messages",
                        "log_stream_name": "{instance_id}",
                        "timezone": "UTC"
                    }
                ]
            }
        },
        "log_stream_name": "blog-{instance_id}"
    },
    "metrics": {
        "metrics_collected": {
            "cpu": {
                "measurement": [
                    "cpu_usage_idle",
                    "cpu_usage_iowait",
                    "cpu_usage_user",
                    "cpu_usage_system"
                ],
                "metrics_collection_interval": 60,
                "totalcpu": false
            },
            "disk": {
                "measurement": [
                    "used_percent",
                    "inodes_free"
                ],
                "metrics_collection_interval": 60,
                "resources": [
                    "*"
                ]
            },
            "diskio": {
                "measurement": [
                    "io_time"
                ],
                "metrics_collection_interval": 60,
                "resources": [
                    "*"
                ]
            },
            "mem": {
                "measurement": [
                    "mem_used_percent"
                ],
                "metrics_collection_interval": 60
            },
            "netstat": {
                "measurement": [
                    "tcp_established",
                    "tcp_time_wait"
                ],
                "metrics_collection_interval": 60
            },
            "swap": {
                "measurement": [
                    "swap_used_percent"
                ],
                "metrics_collection_interval": 60
            }
        }
    }
}
EOF

# ============================================
# PART 2: WAF Configuration
# ============================================

echo "Setting up WAF Web ACL..."

# Create Web ACL
WAF_ACL_ID=$(aws wafv2 create-web-acl \
    --name "Blog-WebACL" \
    --scope REGIONAL \
    --default-action '{"Allow": {}}' \
    --description "WAF Web ACL for blog application" \
    --rules '[
        {
            "Name": "AWS-AWSManagedRulesCommonRuleSet",
            "Priority": 0,
            "Statement": {
                "ManagedRuleGroupStatement": {
                    "VendorName": "AWS",
                    "Name": "AWSManagedRulesCommonRuleSet"
                }
            },
            "OverrideAction": {
                "None": {}
            },
            "VisibilityConfig": {
                "SampledRequestsEnabled": true,
                "CloudWatchMetricsEnabled": true,
                "MetricName": "AWSManagedRulesCommonRuleSet"
            }
        },
        {
            "Name": "AWS-AWSManagedRulesSQLiRuleSet",
            "Priority": 1,
            "Statement": {
                "ManagedRuleGroupStatement": {
                    "VendorName": "AWS",
                    "Name": "AWSManagedRulesSQLiRuleSet"
                }
            },
            "OverrideAction": {
                "None": {}
            },
            "VisibilityConfig": {
                "SampledRequestsEnabled": true,
                "CloudWatchMetricsEnabled": true,
                "MetricName": "AWSManagedRulesSQLiRuleSet"
            }
        },
        {
            "Name": "RateBasedRule",
            "Priority": 2,
            "Statement": {
                "RateBasedStatement": {
                    "Limit": 2000,
                    "AggregateKeyType": "IP"
                }
            },
            "Action": {
                "Block": {}
            },
            "VisibilityConfig": {
                "SampledRequestsEnabled": true,
                "CloudWatchMetricsEnabled": true,
                "MetricName": "RateBasedRule"
            }
        }
    ]' \
    --visibility-config '{
        "SampledRequestsEnabled": true,
        "CloudWatchMetricsEnabled": true,
        "MetricName": "BlogWebACL"
    }' \
    --query 'Summary.Id' \
    --output text)

echo "WAF Web ACL created: $WAF_ACL_ID"

# Associate Web ACL with ALB
aws wafv2 associate-web-acl \
    --web-acl-arn "arn:aws:wafv2:us-east-1:123456789012:regional/webacl/Blog-WebACL/$WAF_ACL_ID" \
    --resource-arn $ALB_ARN

echo "WAF Web ACL associated with ALB"

# ============================================
# PART 3: KMS Encryption
# ============================================

echo "Setting up KMS encryption..."

# Create KMS key
KMS_KEY_ID=$(aws kms create-key \
    --description "KMS key for blog application encryption" \
    --policy '{
        "Version": "2012-10-17",
        "Statement": [
            {
                "Effect": "Allow",
                "Principal": {
                    "AWS": "arn:aws:iam::123456789012:root"
                },
                "Action": "kms:*",
                "Resource": "*"
            }
        ]
    }' \
    --tags '[{"TagKey":"Name","TagValue":"blog-key"}]' \
    --query 'KeyMetadata.KeyId' \
    --output text)

# Create alias for the key
aws kms create-alias \
    --alias-name "alias/$KMS_KEY_ALIAS" \
    --target-key-id $KMS_KEY_ID

echo "KMS key created: $KMS_KEY_ID"

# Enable key rotation
aws kms enable-key-rotation --key-id $KMS_KEY_ID

echo "KMS key rotation enabled"

# Encrypt a sample file with KMS
echo "Testing KMS encryption..."
echo "This is a secret message" > /tmp/secret.txt

aws kms encrypt \
    --key-id $KMS_KEY_ID \
    --plaintext fileb:///tmp/secret.txt \
    --output text \
    --query CiphertextBlob \
    | base64 --decode > /tmp/secret.txt.encrypted

echo "File encrypted successfully"

# ============================================
# PART 4: Create Dashboard
# ============================================

echo "Creating CloudWatch dashboard..."

cat > /tmp/blog-dashboard.json << EOF
{
    "widgets": [
        {
            "type": "metric",
            "x": 0,
            "y": 0,
            "width": 12,
            "height": 6,
            "properties": {
                "metrics": [
                    [ "AWS/EC2", "CPUUtilization", "InstanceId", "$EC2_INSTANCE_ID" ]
                ],
                "period": 300,
                "stat": "Average",
                "region": "us-east-1",
                "title": "EC2 CPU Utilization"
            }
        },
        {
            "type": "metric",
            "x": 12,
            "y": 0,
            "width": 12,
            "height": 6,
            "properties": {
                "metrics": [
                    [ "AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", "$ALB_ARN" ]
                ],
                "period": 300,
                "stat": "Average",
                "region": "us-east-1",
                "title": "ALB Target Response Time"
            }
        },
        {
            "type": "metric",
            "x": 0,
            "y": 6,
            "width": 8,
            "height": 6,
            "properties": {
                "metrics": [
                    [ "AWS/ApplicationELB", "HTTPCode_Target_4XX_Count", "LoadBalancer", "$ALB_ARN" ],
                    [ "AWS/ApplicationELB", "HTTPCode_Target_5XX_Count", "LoadBalancer", "$ALB_ARN" ]
                ],
                "period": 300,
                "stat": "Sum",
                "region": "us-east-1",
                "title": "ALB Error Codes"
            }
        },
        {
            "type": "metric",
            "x": 8,
            "y": 6,
            "width": 8,
            "height": 6,
            "properties": {
                "metrics": [
                    [ "AWS/RDS", "DatabaseConnections", "DBInstanceIdentifier", "blog-db" ]
                ],
                "period": 300,
                "stat": "Average",
                "region": "us-east-1",
                "title": "RDS Database Connections"
            }
        },
        {
            "type": "metric",
            "x": 16,
            "y": 6,
            "width": 8,
            "height": 6,
            "properties": {
                "metrics": [
                    [ "AWS/WAFV2", "BlockedRequests", "WebACL", "Blog-WebACL", "Region", "us-east-1" ]
                ],
                "period": 300,
                "stat": "Sum",
                "region": "us-east-1",
                "title": "WAF Blocked Requests"
            }
        }
    ]
}
EOF

aws cloudwatch put-dashboard \
    --dashboard-name "Blog-Application-Dashboard" \
    --dashboard-body file:///tmp/blog-dashboard.json

echo "CloudWatch dashboard created"

# Clean up
rm -f /tmp/cloudwatch-agent-config.json /tmp/secret.txt /tmp/secret.txt.encrypted /tmp/blog-dashboard.json

echo "=== Task 7 Complete ==="
echo "CloudWatch Alarms: Created"
echo "WAF Web ACL ID: $WAF_ACL_ID"
echo "KMS Key ID: $KMS_KEY_ID"
echo "KMS Key Alias: alias/$KMS_KEY_ALIAS"
echo "CloudWatch Dashboard: Blog-Application-Dashboard"

# Save outputs
cat > monitoring-outputs.txt << EOF
WAF_ACL_ID=$WAF_ACL_ID
KMS_KEY_ID=$KMS_KEY_ID
KMS_KEY_ALIAS=$KMS_KEY_ALIAS
CLOUDWATCH_DASHBOARD=Blog-Application-Dashboard
EOF

echo "Outputs saved to monitoring-outputs.txt"