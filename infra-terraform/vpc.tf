# Minimal VPC suitable for a demo. You can skip creating a VPC to use the AWS default VPC.
resource "aws_vpc" "demo" {
  cidr_block = "10.0.0.0/16"
  tags = { Name = "idp-vpc-${var.env}" }
}
