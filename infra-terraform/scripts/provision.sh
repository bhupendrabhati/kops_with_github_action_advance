
#!/bin/bash
set -e
trap 'terraform destroy -auto-approve' ERR

terraform init
terraform apply -auto-approve
