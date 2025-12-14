variable "aws_region" {
  type    = string
  default = "ap-south-1"
}

variable "backend_bucket_name" {
  type        = string
  description = "S3 bucket for Terraform backend AND kOps state"
}

variable "dynamo_table_name" {
  type    = string
  default = "terraform-locks"
}

variable "environment" {
  type    = string
  default = "dev"
}
