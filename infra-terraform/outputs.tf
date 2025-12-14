output "region" {
  value = var.aws_region
}

output "cluster_name" {
  value = var.cluster_name
}

output "kops_cluster_name" {
  value = var.cluster_name
}

output "vpc_id" {
  value       = aws_vpc.demo.id
  description = "VPC ID for kOps cluster"
}