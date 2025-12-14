
#!/bin/bash
set -e
terraform init
terraform destroy -auto-approve
