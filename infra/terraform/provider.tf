terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # REMOTE STATE - S3 + DynamoDB lock (README compliance)
  backend "s3" {
    bucket = "capstone-tf-state-bignald" # CHANGE THIS
    key    = "infra/terraform.tfstate"
    region = "us-east-1"
    #dynamodb_table = "terraform-locks"
    use_lockfile = true
    encrypt      = true
  }
}

