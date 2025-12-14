terraform {
    backend "s3" {
        #bucket         = "YOUR_BACKEND_BUCKET_NAME"
        key            = "terraform/infra-terraform.tfstate"
        region         = "ap-south-1"
        #dynamodb_table = "YOUR_DYNAMODB_TABLE_NAME"
        encrypt        = true
    }
}