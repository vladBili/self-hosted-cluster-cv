DIRECTORY := $(strip $(shell pwd))

DEPARTMENT ?= development
AWS_ROOT_PROFILE ?= root
AWS_IAM_PROFILE := $(DEPARTMENT)-user
AWS_REGION = eu-central-1

all: ansible-playbook-postinit

terraform-root-provision-backend:
	cd Root && \
	export AWS_PROFILE=$(AWS_ROOT_PROFILE) && \
	terraform init && \
	terraform plan -out="plan/planfile" && \
	terraform apply "plan/planfile"

aws-root-fetch-iam-credentials: terraform-root-provision-backend
	$(eval CREDENTIALS := $(shell aws secretsmanager get-secret-value \
		--secret-id credentials/$(DEPARTMENT)/$(AWS_IAM_PROFILE) \
		--query SecretString --output text \
		--profile $(AWS_ROOT_PROFILE)))
	$(eval AWS_ACCESS_KEY_ID := $(shell echo '$(CREDENTIALS)' | jq -r .AWS_ACCESS_KEY_ID))
	$(eval AWS_SECRET_ACCESS_KEY := $(shell echo '$(CREDENTIALS)' | jq -r .AWS_SECRET_ACCESS_KEY))

aws-root-configure-iam-profile: aws-root-fetch-iam-credentials
	aws configure set aws_access_key_id $(AWS_ACCESS_KEY_ID) --profile $(AWS_IAM_PROFILE)&& \
	aws configure set aws_secret_access_key $(AWS_SECRET_ACCESS_KEY) --profile $(AWS_IAM_PROFILE) &&\
	aws configure set region $(AWS_REGION) --profile $(AWS_IAM_PROFILE)

terraform-iam-init: aws-root-configure-iam-profile
	cd IAM/terraform && \
	export AWS_PROFILE=$(AWS_ROOT_PROFILE) && \
	terraform init --backend-config="env/$(DEPARTMENT)/config/conf.hcl" --reconfigure && \
	terraform workspace select $(DEPARTMENT) || terraform workspace new $(DEPARTMENT) 

terraform-iam-provision-preinit: terraform-iam-init
	cd IAM/terraform && \
	export AWS_PROFILE=$(AWS_IAM_PROFILE) && \
	terraform plan -out="env/$(DEPARTMENT)/plan/planfile-preinit" -var-file="env/$(DEPARTMENT)/variables/$(DEPARTMENT).tfvars" \
	-var="pwd=${DIRECTORY}" -var="build_phase=preinit" && \
	terraform apply "env/$(DEPARTMENT)/plan/planfile-preinit"

ansible-playbook-preinit: terraform-iam-provision-preinit
	export ANSIBLE_CONFIG="${DIRECTORY}/IAM/ansible/env/${DEPARTMENT}/ansible.cfg" && \
	cd IAM/ansible/env/${DEPARTMENT} && \
	ansible-playbook "${DIRECTORY}/IAM/ansible/01-playbook-preinit.yaml" \
	-e department=${DEPARTMENT} -e directory=${DIRECTORY} -e region=${AWS_REGION}

ansible-playbook-init: ansible-playbook-preinit
	export ANSIBLE_CONFIG="${DIRECTORY}/IAM/ansible/env/${DEPARTMENT}/ansible.cfg" && \
	cd IAM/ansible/env/${DEPARTMENT} && \
	ansible-playbook "${DIRECTORY}/IAM/ansible/02-playbook-init.yaml" \
	-e department=${DEPARTMENT} -e directory=${DIRECTORY} -e region=${AWS_REGION}

ansible-playbook-postinit: ansible-playbook-init
	export ANSIBLE_CONFIG="${DIRECTORY}/IAM/ansible/env/${DEPARTMENT}/ansible.cfg" && \
	cd IAM/ansible/env/${DEPARTMENT} && \
	ansible-playbook "${DIRECTORY}/IAM/ansible/03-playbook-postinit.yaml" \
	-e department=${DEPARTMENT} -e directory=${DIRECTORY} -e region=${AWS_REGION}



