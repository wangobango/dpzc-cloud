FROM hashicorp/terraform:latest

COPY . .

RUN mkdir ~/.aws

RUN cp credentials ~/.aws

ENTRYPOINT terraform init && terraform apply -auto-approve &&  sleep 1500 && terraform destroy -auto-approve