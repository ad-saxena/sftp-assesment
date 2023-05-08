provider "aws" {
  region = "eu-west-1"
  profile = "terraform"
}

resource "aws_transfer_server" "sftp_server" {
  identity_provider_type = "SERVICE_MANAGED"
  endpoint_type = "PUBLIC"
}

# create s3 buckets
resource "aws_s3_bucket" "incoming_files" {
  bucket = "incoming-files-sc"
}
resource "aws_lambda_permission" "allow_bucket" {
  statement_id  = "AllowExecutionFromS3Bucket"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.sftp_lambda.arn
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.incoming_files.arn
}
resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = aws_s3_bucket.incoming_files.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.sftp_lambda.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "AWSLogs/"
    filter_suffix       = ".log"
  }

  depends_on = [aws_lambda_permission.allow_bucket]
}

resource "aws_s3_bucket" "processed_data" {
  bucket = "processed-data-scc"
}

resource "aws_s3_bucket" "error_logs" {
  bucket = "error-logs-sc"
}

resource "aws_iam_role" "S3-sftp-role" {
  name = "s3-sftp-role" 

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = {
          "Service": "transfer.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_policy_attachment" "sftp-read-write-policy" {
  policy_arn = "arn:aws:iam::816666353898:policy/sftp-read-write-policy"
  name = "sftp-read-write-policy"
  roles = ["${aws_iam_role.S3-sftp-role.name}"]
}
 
# Create an iam policy for sftp user

resource "aws_iam_policy" "sftp-user-policy" {
  name        = "sftp-user-policy-terraform"
#   path        = "/"
  description = "My sftp user policy policy"

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "AllowListingOfUserFolder",
            "Action": [
                "s3:ListBucket"
            ],
            "Effect": "Allow",
            "Resource": [
                "arn:aws:s3:::incoming-files-sc/sftpuser"
            ],
            "Condition": {
                "StringLike": {
                    "s3:prefix": [
                        "arn:aws:s3:::incoming-files-sc/sftpuser/*",
                        "arn:aws:s3:::incoming-files-sc/sftpuser/"
                    ]
                }
            }
        },
        {
            "Sid": "HomeDirObjectAccess",
            "Effect": "Allow",
            "Action": [
                "s3:PutObject",
                "s3:GetObject",
                "s3:DeleteObject",
                "s3:GetObjectVersion"
            ],
            "Resource": "arn:aws:s3:::incoming-files-sc/sftpuser/*"
        }
    ]
})
}
# Create an SFTP user and assign to server created above
resource "aws_transfer_user" "sftp_user" {
  server_id = aws_transfer_server.sftp_server.id
  user_name  = "sftpuser"
  
  # Assign the IAM role to the SFTP user
  role = aws_iam_role.S3-sftp-role.arn
  policy = aws_iam_policy.sftp-user-policy.policy
#   role = aws_iam_role.sftp_s3_role.arn
  
  
  # Define the home directory for the SFTP user
  home_directory_type = "LOGICAL"
  home_directory_mappings {
    entry  = "/"
    target = "/${aws_s3_bucket.incoming_files.id}/sftpuser"
  }
}
resource "aws_transfer_ssh_key" "sftp_ssh_key" {
  server_id = aws_transfer_server.sftp_server.id
  user_name = aws_transfer_user.sftp_user.user_name
  body      = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDM6m6Hmd6jI8RXhOuZUm3L5N2xxL+6+eLTG6XcLRzkiX83QJyZP+UplESHJtmBdWuSfDvIOi8L9y+oxYEt9Pk8xiysNyvMtHF8DC20aZk68OPQJApkdE6U3x5/SgvY/RgSg3ON8nr171M4NGA8VqKo8COatUIADD3VctcK32cwkMjZWBYpAcpxmxFTxRS0t+qejTEBIzX1xpVFvDFuIuZNgcoPiRP9mUOU7NBXTVDknCYGXfzvAr7Yhzf/wszUdjFhx9rw2PXqkyiw7RnkEFZJf0WhTtGEfVfJVHhoZPnnFX1SXU8/z4B473oky6pEBd83Ep92PZPJT3Zpn+yIMKWZSFxS4FjnfAzCG+scCmN32o6xjy1XLa+e/ndJDztUVQHhQB8kco6a4jFMzDaxS+jmCEG7Ujfb6agMAJLWYU69isJJI4oh6rwimRTP5a2icc0vbtNUSxPyCUdLZuCdRGrA227ymn0hrjK4J2vtHaviXkNtU6fXBuxtPABLHccWzr8= adsaxena@Ads-MacBook-Air-2.local"
}


resource "aws_iam_role" "lambda_role" {
  name = "lambda_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_policy_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
  role       = aws_iam_role.lambda_role.name
}

resource "aws_iam_role_policy_attachment" "transfer_policy_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSTransferLoggingAccess"
  role       = aws_iam_role.lambda_role.name
}

data "aws_iam_policy_document" "lambda_policy" {
  statement {
    effect = "Allow"
    actions = [
      "s3:PutObject",
      "s3:PutObjectAcl",
      "s3:GetObject",
      "s3:DeleteObject",
      "sftp:*"
    ]
    resources = [
      aws_s3_bucket.incoming_files.arn,
      aws_s3_bucket.processed_data.arn,
      aws_s3_bucket.error_logs.arn,
      aws_transfer_server.sftp_server.arn,
    ]
  }
}

resource "aws_iam_policy" "lambda_iam_policy" {
  name   = "lambda_iam_policy"
  policy = data.aws_iam_policy_document.lambda_policy.json
}

resource "aws_iam_role_policy_attachment" "lambda_iam_policy_attachment" {
  policy_arn = aws_iam_policy.lambda_iam_policy.arn
  role       = aws_iam_role.lambda_role.name
}

resource "aws_lambda_function" "sftp_lambda" {
  filename      = "sftp_lambda.zip"
  function_name = "sftp_lambda"
  role          = aws_iam_role.lambda_role.arn
  handler       = "sftp_lambda.handler"
  runtime       = "python3.8"
  timeout       = 60

  environment {
    variables = {
      INCOMING_FILES_BUCKET = aws_s3_bucket.incoming_files.id
      PROCESSED_DATA_BUCKET = aws_s3_bucket.processed_data.id
      ERROR_LOGS_BUCKET = aws_s3_bucket.error_logs.id
    }
  }

  source_code_hash = filebase64("sftp_lambda.zip")
}

resource "aws_s3_bucket_notification" "sftp_lambda_trigger" {
  bucket = aws_s3_bucket.incoming_files.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.sftp_lambda.arn
    events              = ["s3:ObjectCreated:*"]
  }
}

resource "aws_sns_topic" "sre_notifications" {
  name = "sre_notifications"
}

resource "aws_sns_topic_subscription" "sre_notifications_subscription" {
topic_arn = aws_sns_topic.sre_notifications.arn
protocol = "email"
endpoint = "amandeepsaxena2@gmail.com"
}

# resource "aws_sns_topic_subscription" "sre_notifications_slack_subscription" {
# topic_arn = aws_sns_topic.sre_notifications.arn
# protocol = "https"
# endpoint = "https://hooks.slack.com/services/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"
# }

data "aws_ssm_parameter" "sftp_server_url" {
    name = "/sftp_server/url"
}

data "aws_ssm_parameter" "sftp_server_user" {
name = "/sftp_server/user"
}

data "aws_ssm_parameter" "sftp_server_password" {
name = "/sftp_server/password"
}

data "aws_ssm_parameter" "sns_topic_arn" {
name = "/sns/topic/arn"
}

data "archive_file" "sftp_lambda_zip" {
type = "zip"
output_path = "${path.module}/sftp_lambda.zip"
source_dir = "${path.module}/sftp_lambda"

depends_on = [
aws_iam_role_policy_attachment.lambda_policy_attachment,
aws_iam_role_policy_attachment.transfer_policy_attachment,
aws_iam_policy.lambda_iam_policy,
]
}

output "sftp_server_endpoint" {
value = aws_transfer_server.sftp_server.endpoint
}
output "sftp_user" {
  value = aws_transfer_user.sftp_user.user_name
}

output "sns_topic_arn" {
value = data.aws_ssm_parameter.sns_topic_arn.value
sensitive = true
}

