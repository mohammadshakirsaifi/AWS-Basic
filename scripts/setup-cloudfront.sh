#!/bin/bash

# Task 6: Set up CloudFront for S3 bucket

set -e

echo "=== Task 6: Setting up CloudFront for S3 ==="

# Configuration
S3_BUCKET_NAME="blog-static-assets-yourname"  # Replace with your bucket name
DOMAIN_NAME="yourblog.com"  # Replace with your domain (if registered)

# 1. Create CloudFront origin access identity
echo "Creating CloudFront origin access identity..."
OAI_ID=$(aws cloudfront create-cloud-front-origin-access-identity \
    --cloud-front-origin-access-identity-config \
    "CallerReference=blog-oai-$(date +%s),Comment=OAI for blog S3 bucket" \
    --query 'CloudFrontOriginAccessIdentity.Id' \
    --output text)

OAI_CANONICAL_ID=$(aws cloudfront get-cloud-front-origin-access-identity \
    --id $OAI_ID \
    --query 'CloudFrontOriginAccessIdentity.S3CanonicalUserId' \
    --output text)

echo "OAI created: $OAI_ID"

# 2. Create CloudFront distribution
echo "Creating CloudFront distribution..."

# Create distribution config
cat > distribution-config.json << EOF
{
    "CallerReference": "blog-distribution-$(date +%s)",
    "Aliases": {
        "Quantity": 1,
        "Items": ["$DOMAIN_NAME"]
    },
    "DefaultRootObject": "index.html",
    "Origins": {
        "Quantity": 1,
        "Items": [
            {
                "Id": "S3-${S3_BUCKET_NAME}",
                "DomainName": "${S3_BUCKET_NAME}.s3.amazonaws.com",
                "S3OriginConfig": {
                    "OriginAccessIdentity": "origin-access-identity/cloudfront/${OAI_ID}"
                }
            }
        ]
    },
    "DefaultCacheBehavior": {
        "TargetOriginId": "S3-${S3_BUCKET_NAME}",
        "ViewerProtocolPolicy": "redirect-to-https",
        "AllowedMethods": {
            "Quantity": 2,
            "Items": ["GET", "HEAD"],
            "CachedMethods": {
                "Quantity": 2,
                "Items": ["GET", "HEAD"]
            }
        },
        "CachePolicyId": "658327ea-f89d-4fab-a63d-7e88639e58f6",
        "Compress": true
    },
    "Comment": "CloudFront distribution for blog static assets",
    "Enabled": true,
    "PriceClass": "PriceClass_100",
    "ViewerCertificate": {
        "CloudFrontDefaultCertificate": true
    },
    "Logging": {
        "Enabled": true,
        "IncludeCookies": false,
        "Bucket": "blog-logs-bucket.s3.amazonaws.com",
        "Prefix": "cloudfront-logs/"
    }
}
EOF

DISTRIBUTION_ID=$(aws cloudfront create-distribution \
    --distribution-config file://distribution-config.json \
    --query 'Distribution.Id' \
    --output text)

DISTRIBUTION_DOMAIN=$(aws cloudfront get-distribution \
    --id $DISTRIBUTION_ID \
    --query 'Distribution.DomainName' \
    --output text)

echo "CloudFront distribution created: $DISTRIBUTION_ID"
echo "CloudFront domain: $DISTRIBUTION_DOMAIN"

# 3. Update S3 bucket policy to allow CloudFront access
echo "Updating S3 bucket policy..."
cat > s3-bucket-policy.json << EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "CanonicalUser": "$OAI_CANONICAL_ID"
            },
            "Action": "s3:GetObject",
            "Resource": "arn:aws:s3:::${S3_BUCKET_NAME}/*"
        }
    ]
}
EOF

aws s3api put-bucket-policy \
    --bucket $S3_BUCKET_NAME \
    --policy file://s3-bucket-policy.json

# 4. If domain is registered in Route 53, create A record to CloudFront
if [ "$DOMAIN_NAME" != "yourblog.com" ]; then
    echo "Creating Route 53 A record to point domain to CloudFront..."
    
    # Get hosted zone ID
    HOSTED_ZONE_ID=$(aws route53 list-hosted-zones-by-name \
        --dns-name $DOMAIN_NAME \
        --query 'HostedZones[0].Id' \
        --output text | cut -d'/' -f3)
    
    # Create change batch
    cat > route53-changes.json << EOF
    {
        "Changes": [
            {
                "Action": "UPSERT",
                "ResourceRecordSet": {
                    "Name": "$DOMAIN_NAME",
                    "Type": "A",
                    "AliasTarget": {
                        "HostedZoneId": "Z2FDTNDATAQYW2",
                        "DNSName": "$DISTRIBUTION_DOMAIN",
                        "EvaluateTargetHealth": false
                    }
                }
            }
        ]
    }
EOF
    
    aws route53 change-resource-record-sets \
        --hosted-zone-id $HOSTED_ZONE_ID \
        --change-batch file://route53-changes.json
    
    echo "Route 53 record created/updated"
fi

# Clean up temporary files
rm -f distribution-config.json s3-bucket-policy.json route53-changes.json

echo "=== Task 6 Complete ==="
echo "CloudFront Distribution ID: $DISTRIBUTION_ID"
echo "CloudFront Domain: $DISTRIBUTION_DOMAIN"
echo "OAI ID: $OAI_ID"

echo ""
echo "Next steps:"
echo "1. Wait for distribution to deploy (status: Deployed)"
echo "2. Test your S3 content via CloudFront: https://$DISTRIBUTION_DOMAIN/index.html"
echo "3. If using custom domain, update your DNS"

# Save outputs
cat > cloudfront-outputs.txt << EOF
CLOUDFRONT_DIST_ID=$DISTRIBUTION_ID
CLOUDFRONT_DOMAIN=$DISTRIBUTION_DOMAIN
OAI_ID=$OAI_ID
OAI_CANONICAL_ID=$OAI_CANONICAL_ID
EOF

echo "Outputs saved to cloudfront-outputs.txt"