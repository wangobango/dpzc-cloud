FROM hashicorp/terraform:latest

COPY . .

RUN mkdir ~/.aws

RUN cp credentials ~/.aws

ENTRYPOINT terraform init && terraform apply -auto-approve &&  sleep 3000 && terraform destroy -auto-approve