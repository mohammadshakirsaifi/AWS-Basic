import boto3
import os
import json
import uuid
import logging
from PIL import Image
from io import BytesIO
from datetime import datetime
import hashlib

# Configure logging for CloudWatch (Task 7)
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize AWS services
s3 = boto3.client('s3')
sns = boto3.client('sns')
sqs = boto3.client('sqs')
dynamodb = boto3.resource('dynamodb')
cloudwatch = boto3.client('cloudwatch')

# Environment variables
SOURCE_BUCKET = os.environ.get('SOURCE_BUCKET')
DEST_BUCKET = os.environ.get('DEST_BUCKET', 'blog-static-assets-processed')
SNS_TOPIC_ARN = os.environ.get('SNS_TOPIC_ARN')  # Task 5: SNS notifications
SQS_QUEUE_URL = os.environ.get('SQS_QUEUE_URL')  # Task 5: SQS queue
DYNAMODB_TABLE = os.environ.get('DYNAMODB_TABLE', 'ImageMetadata')

# Image sizes to generate (width, height, suffix)
IMAGE_SIZES = [
    (1920, 1080, 'full'),      # Full HD
    (1280, 720, 'large'),       # HD
    (800, 600, 'medium'),       # Medium
    (400, 300, 'small'),        # Small
    (150, 150, 'thumbnail')     # Thumbnail
]

def lambda_handler(event, context):
    """
    Main Lambda handler for S3-triggered image resizing
    Task 5: S3-triggered Lambda
    Task 7: CloudWatch logging and metrics
    """
    logger.info(f"Received event: {json.dumps(event)}")
    
    try:
        # Track processing metrics for CloudWatch (Task 7)
        start_time = datetime.now()
        processed_count = 0
        error_count = 0
        
        # Process each record from S3 event
        for record in event['Records']:
            try:
                # Get bucket and key
                bucket = record['s3']['bucket']['name']
                key = record['s3']['object']['key']
                
                logger.info(f"Processing: s3://{bucket}/{key}")
                
                # Process the image
                result = process_image(bucket, key)
                
                # Task 5: Send SNS notification
                send_sns_notification(result)
                
                # Task 5: Queue background task
                queue_background_task(result)
                
                # Store metadata in DynamoDB
                store_metadata(result)
                
                processed_count += 1
                
            except Exception as e:
                error_count += 1
                logger.error(f"Error processing record: {str(e)}")
                
                # Task 5: Send error notification
                send_error_notification(str(e), record)
        
        # Task 7: Send metrics to CloudWatch
        send_cloudwatch_metrics(processed_count, error_count, start_time)
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'Processing complete',
                'processed': processed_count,
                'errors': error_count
            })
        }
        
    except Exception as e:
        logger.error(f"Fatal error: {str(e)}")
        raise e

def process_image(source_bucket, source_key):
    """
    Resize image and upload multiple versions to S3
    Task 4: S3 upload with versioning and encryption
    """
    try:
        # Download image from S3
        response = s3.get_object(Bucket=source_bucket, Key=source_key)
        image_data = response['Body'].read()
        
        # Generate image hash for versioning
        image_hash = hashlib.md5(image_data).hexdigest()
        
        # Open image with PIL
        original_image = Image.open(BytesIO(image_data))
        
        # Get image metadata
        image_format = original_image.format
        original_width, original_height = original_image.size
        
        logger.info(f"Original: {original_width}x{original_height}, Format: {image_format}")
        
        # Generate unique ID
        image_id = str(uuid.uuid4())
        filename = os.path.basename(source_key)
        name_without_ext = os.path.splitext(filename)[0]
        
        processed_images = []
        
        # Generate resized versions
        for width, height, suffix in IMAGE_SIZES:
            # Calculate aspect ratio
            aspect_ratio = original_width / original_height
            target_aspect = width / height
            
            if aspect_ratio > target_aspect:
                new_width = width
                new_height = int(width / aspect_ratio)
            else:
                new_height = height
                new_width = int(height * aspect_ratio)
            
            # Resize image
            resized = original_image.copy()
            resized.thumbnail((new_width, new_height), Image.Resampling.LANCZOS)
            
            # Create final image with padding if needed
            if (new_width, new_height) != (width, height):
                background = Image.new('RGB', (width, height), (255, 255, 255))
                paste_x = (width - new_width) // 2
                paste_y = (height - new_height) // 2
                background.paste(resized, (paste_x, paste_y))
                final_image = background
            else:
                final_image = resized
            
            # Save to buffer
            output_buffer = BytesIO()
            save_format = 'JPEG' if image_format not in ['PNG', 'GIF', 'WEBP'] else image_format
            final_image.save(output_buffer, format=save_format, quality=85, optimize=True)
            output_buffer.seek(0)
            
            # Generate destination key
            extension = '.jpg' if save_format == 'JPEG' else f'.{save_format.lower()}'
            dest_key = f"processed/{name_without_ext}/{suffix}{extension}"
            
            # Task 4: Upload to S3 with encryption and metadata
            s3.put_object(
                Bucket=DEST_BUCKET,
                Key=dest_key,
                Body=output_buffer,
                ContentType=f'image/{save_format.lower()}',
                ServerSideEncryption='AES256',  # Task 4: Enable encryption
                Metadata={
                    'original_key': source_key,
                    'image_id': image_id,
                    'image_hash': image_hash,
                    'size_type': suffix,
                    'original_width': str(original_width),
                    'original_height': str(original_height),
                    'processed_width': str(width),
                    'processed_height': str(height),
                    'timestamp': datetime.now().isoformat()
                },
                Tagging='version=1&type=processed'  # S3 tagging for management
            )
            
            processed_images.append({
                'key': dest_key,
                'url': f"https://{DEST_BUCKET}.s3.amazonaws.com/{dest_key}",
                'size_type': suffix,
                'width': width,
                'height': height,
                'format': save_format
            })
            
            logger.info(f"Uploaded: {dest_key}")
        
        # Task 4: Enable versioning is done at bucket level, not per object
        
        return {
            'status': 'success',
            'image_id': image_id,
            'image_hash': image_hash,
            'original_key': source_key,
            'original_bucket': source_bucket,
            'processed_images': processed_images,
            'destination_bucket': DEST_BUCKET,
            'timestamp': datetime.now().isoformat()
        }
        
    except Exception as e:
        logger.error(f"Image processing failed: {str(e)}")
        raise e

def send_sns_notification(result):
    """
    Task 5: Send SNS notification for processed images
    """
    if not SNS_TOPIC_ARN:
        logger.warning("SNS_TOPIC_ARN not configured")
        return
    
    try:
        message = {
            'subject': f"Image Processing Complete - {result['image_id']}",
            'message': f"Successfully processed {result['original_key']}",
            'details': {
                'image_id': result['image_id'],
                'original_key': result['original_key'],
                'versions': len(result['processed_images']),
                'sizes': [img['size_type'] for img in result['processed_images']]
            },
            'timestamp': result['timestamp']
        }
        
        response = sns.publish(
            TopicArn=SNS_TOPIC_ARN,
            Message=json.dumps(message),
            Subject=f"Image Processing: {result['original_key']}",
            MessageAttributes={
                'status': {
                    'DataType': 'String',
                    'StringValue': 'success'
                },
                'image_id': {
                    'DataType': 'String',
                    'StringValue': result['image_id']
                }
            }
        )
        
        logger.info(f"SNS notification sent: {response['MessageId']}")
        
    except Exception as e:
        logger.error(f"SNS notification failed: {str(e)}")

def queue_background_task(result):
    """
    Task 5: Queue background tasks in SQS
    """
    if not SQS_QUEUE_URL:
        logger.warning("SQS_QUEUE_URL not configured")
        return
    
    try:
        # Create tasks for background processing
        tasks = [
            {
                'task_type': 'generate_metadata',
                'image_id': result['image_id'],
                'original_key': result['original_key']
            },
            {
                'task_type': 'analyze_image',
                'image_id': result['image_id'],
                'processed_images': result['processed_images']
            },
            {
                'task_type': 'update_search_index',
                'image_id': result['image_id'],
                'metadata': {
                    'original_key': result['original_key'],
                    'sizes': [img['size_type'] for img in result['processed_images']]
                }
            }
        ]
        
        for task in tasks:
            response = sqs.send_message(
                QueueUrl=SQS_QUEUE_URL,
                MessageBody=json.dumps(task),
                MessageAttributes={
                    'task_type': {
                        'DataType': 'String',
                        'StringValue': task['task_type']
                    },
                    'image_id': {
                        'DataType': 'String',
                        'StringValue': result['image_id']
                    }
                },
                MessageGroupId=result['image_id'],  # For FIFO queue ordering
                MessageDeduplicationId=f"{result['image_id']}-{task['task_type']}"
            )
            
            logger.info(f"SQS task queued: {task['task_type']} - {response['MessageId']}")
        
    except Exception as e:
        logger.error(f"SQS queueing failed: {str(e)}")

def store_metadata(result):
    """
    Store image metadata in DynamoDB
    """
    try:
        table = dynamodb.Table(DYNAMODB_TABLE)
        
        # Prepare item
        item = {
            'image_id': result['image_id'],
            'image_hash': result['image_hash'],
            'original_key': result['original_key'],
            'original_bucket': result['original_bucket'],
            'timestamp': result['timestamp'],
            'processed_versions': result['processed_images'],
            'version_count': len(result['processed_images']),
            'status': 'completed',
            'ttl': int(datetime.now().timestamp()) + (30 * 24 * 60 * 60)  # 30 days TTL
        }
        
        # Store in DynamoDB
        response = table.put_item(Item=item)
        
        logger.info(f"Metadata stored in DynamoDB")
        
    except Exception as e:
        logger.error(f"DynamoDB storage failed: {str(e)}")

def send_cloudwatch_metrics(processed, errors, start_time):
    """
    Task 7: Send metrics to CloudWatch
    """
    try:
        duration = (datetime.now() - start_time).total_seconds()
        
        metrics = [
            {
                'MetricName': 'ImagesProcessed',
                'Value': processed,
                'Unit': 'Count',
                'Dimensions': [
                    {'Name': 'FunctionName', 'Value': 'ResizeImageFunction'},
                    {'Name': 'Environment', 'Value': os.environ.get('ENVIRONMENT', 'dev')}
                ]
            },
            {
                'MetricName': 'ProcessingErrors',
                'Value': errors,
                'Unit': 'Count',
                'Dimensions': [
                    {'Name': 'FunctionName', 'Value': 'ResizeImageFunction'}
                ]
            },
            {
                'MetricName': 'ProcessingDuration',
                'Value': duration,
                'Unit': 'Seconds',
                'Dimensions': [
                    {'Name': 'FunctionName', 'Value': 'ResizeImageFunction'}
                ]
            }
        ]
        
        # Task 7: Send to CloudWatch
        cloudwatch.put_metric_data(
            Namespace='BlogApplication',
            MetricData=metrics
        )
        
        logger.info(f"CloudWatch metrics sent")
        
    except Exception as e:
        logger.error(f"CloudWatch metrics failed: {str(e)}")

def send_error_notification(error, record):
    """
    Send error notification via SNS
    """
    if not SNS_TOPIC_ARN:
        return
    
    try:
        error_details = {
            'subject': 'Image Processing Error',
            'error': error,
            's3_record': record,
            'timestamp': datetime.now().isoformat()
        }
        
        sns.publish(
            TopicArn=SNS_TOPIC_ARN,
            Message=json.dumps(error_details),
            Subject='Lambda Error - Image Processing',
            MessageAttributes={
                'status': {
                    'DataType': 'String',
                    'StringValue': 'error'
                }
            }
        )
        
    except Exception as e:
        logger.error(f"Error notification failed: {str(e)}")