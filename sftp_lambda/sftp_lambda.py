import boto3
import paramiko
import io
import logging

s3_client = boto3.client('s3')

def lambda_handler(event, context):
    # Get the name of the uploaded file and its contents from the SFTP event
    filename = event['detail']['source']['path']
    contents = event['detail']['source']['body']

    # Download the file from the SFTP server
    sftp_client = paramiko.SFTPClient.from_transport(
        paramiko.Transport((os.environ['SFTP_SERVER_URL'], 22))
    )
    sftp_client.connect(
        username=os.environ['SFTP_SERVER_USER'],
        password=os.environ['SFTP_SERVER_PASSWORD']
    )
    file_obj = io.BytesIO()
    sftp_client.getfo(filename, file_obj)
    file_obj.seek(0)
    sftp_client.close()

    # Store the file contents in the incoming files S3 bucket
    s3_client.put_object(
        Bucket=os.environ['INCOMING_FILES_BUCKET'],
        Key=filename,
        Body=file_obj
    )

    # Validate the file contents
    is_valid = validate_file(file_obj)

    if is_valid:
        # Store the file in the processed data S3 bucket
        s3_client.put_object(
            Bucket=os.environ['PROCESSED_DATA_BUCKET'],
            Key=filename,
            Body=file_obj
        )
    else:
        # Store an error log in the error logs S3 bucket
        error_msg = f"Invalid file format for {filename}"
        logging.error(error_msg)
        s3_client.put_object(
            Bucket=os.environ['ERROR_LOGS_BUCKET'],
            Key=f"{filename}.log",
            Body=error_msg.encode('utf-8')
        )

def validate_file(file_obj):
    # Insert your file validation logic here
    return True
