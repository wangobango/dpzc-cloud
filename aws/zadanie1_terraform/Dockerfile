FROM hashicorp/terraform:latest
COPY . .
ENTRYPOINT terraform init && terraform apply -auto-approve &&  sleep 3000 && terraform destroy -auto-approve