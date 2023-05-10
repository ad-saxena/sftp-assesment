# sftp-assesment
**Introduction** <br>
This Terraform configuration file creates an AWS infrastructure for an SFTP server that allows users to upload files, process them, and store them in separate S3 buckets along with CICD Automation using GitHub actions. 

**Architecture Diagram** <br>
<br>
<img width="594" alt="SFTP-Architecture" src="https://github.com/ad-saxena/sftp-assesment/assets/43133440/dfd719e1-0ce4-4b1b-b922-b7010e2d89dc">

  
**Provider** <br>
The AWS provider is specified in this file, along with the `region` and `profile` values. 
  
**SFTP Server** <br>
This file creates an SFTP server using the `aws_transfer_server` resource. The `identity_provider_type` is set to `SERVICE_MANAGED`, which means that AWS manages the identities and credentials of the users. The `endpoint_type` is set to `PUBLIC` (initial for test later in production will configure with Security groups), which makes the SFTP server accessible over the internet. 
  
**S3 Buckets** <br> 
The file creates three S3 buckets: `incoming_files`, `processed_data`, and `error_logs`. These buckets are used to store the incoming files, processed data, and error logs, respectively. 
  
**Lambda Permission and S3 Bucket Notification** <br>
The file creates an `aws_lambda_permission` resource that allows the `aws_s3_bucket_notification` resource to invoke a Lambda function when a new object is created in the `incoming_files` bucket. The `aws_s3_bucket_notification` resource is used to create an S3 bucket notification that invokes a Lambda function when a new object is created in the `incoming_files` bucket. 
  
**IAM Role and Policy Attachment** <br>
An `aws_iam_role` resource is created in this file to define a role for the SFTP user to access S3 buckets. This role is assigned to the SFTP user and allows them to read and write to the `incoming_files` bucket. An `aws_iam_policy_attachment` resource is created to attach the policy to the role. 
  
**IAM Policy** <br>
An `aws_iam_policy` resource is created to define a policy for the SFTP user. This policy allows the user to list, put, get, and delete objects in their home directory. 
  
**SFTP User and SSH Key** <br> 
The file creates an `aws_transfer_user` resource to define an SFTP user and assigns the IAM role and policy created earlier to this user. An `aws_transfer_ssh_key` resource is created to define an SSH key for the SFTP user to access the SFTP server. 
 
**Continuous Deployment** <br>  
The workflow consists of a single job called `terraform_apply`, which is run on the latest version of Ubuntu. The job has the following steps: 
  
1. `checkout` - This step checks out the code from the repository to the runner's file system. 
2. `Install Terraform` - This step installs Terraform version 0.12.15 by downloading and unzipping it from the official HashiCorp releases website. The `terraform` binary is then moved to the `/usr/local/bin/` directory, which is in the `PATH` environment variable. 
3. `Verify Terraform version` - This step verifies that the correct version of Terraform has been installed by printing the version number to the console. 
4. `Terraform init` - This step initializes the Terraform working directory, setting up any necessary provider plugins and backends. It requires AWS access keys to be stored in the repository secrets for authentication purposes. 
5. `Terraform validation` - This step validates the syntax and configuration of the Terraform code, ensuring that it is valid and can be applied without errors. 
6. `Terraform apply` - This step applies the Terraform code to the AWS infrastructure, creating or updating resources as necessary. It requires AWS access keys to be stored in the repository secrets for authentication purposes. 
7. `Terraform destroy` (commented out) - This step is commented out by default but can be uncommented to allow for destruction of the infrastructure created by the Terraform code. 
  
Secrets 
  
This action requires two secrets to be stored in the repository: 
  
- `AWS_ACCESS_KEY_ID` - The AWS access key ID for authenticating with AWS. 
- `AWS_SECRET_ACCESS_KEY` - The AWS secret access key for authenticating with AWS. 
