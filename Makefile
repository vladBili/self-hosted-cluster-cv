DIRECTORY := $(strip $(shell pwd))

DEPARTMENT ?= production
AWS_ROOT_PROFILE ?= root
AWS_IAM_PROFILE := $(DEPARTMENT)-user
AWS_REGION = eu-central-1

DOMAIN_NAME = vladbilii.click

KUBERNETES_CREDENTIAL_PROVIDER = true

PACKER_AMI_BUILD ?= false
PACKER_AMI_USE ?= true

OIDC := $(if $(filter $(DEPARTMENT),development),false,true)

all: ansible-playbook-final

terraform-root-provision-backend:
	cd Root && \
	export AWS_PROFILE=$(AWS_ROOT_PROFILE) && \
	terraform init && \
	terraform plan -out="plan/planfile" \
	-var="department=${DEPARTMENT}" \
 -var="packer_ami_build=${PACKER_AMI_BUILD}" && \
	terraform apply "plan/planfile"

ifeq ($(PACKER_AMI_BUILD),true)

packer-root-provision-ami: terraform-root-provision-backend
	cd Root/modules/EBS && \
	packer init template.pkr.hcl && \
	packer build \
		-var "vpc_id=$$(cd ../../ && terraform output -json packer_vpc | jq -r '.vpc_id')" \
		-var "subnet_id=$$(cd ../../ && terraform output -json packer_vpc | jq -r '.subnet_id')" \
		-var "region=$(AWS_REGION)" \
		-var "profile=$(AWS_ROOT_PROFILE)" \
		-var "department=$(DEPARTMENT)" \
		-var "pwd=$(DIRECTORY)" \
		-var "credential_provider=${KUBERNETES_CREDENTIAL_PROVIDER}" \
		-var "domain_name=${DOMAIN_NAME}" \
	template.pkr.hcl

aws-root-fetch-iam-credentials: packer-root-provision-ami

else

aws-root-fetch-iam-credentials: terraform-root-provision-backend

endif

aws-root-fetch-iam-credentials:
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
	terraform plan -out="env/$(DEPARTMENT)/plan/planfile-preinit" \
	-var-file="env/$(DEPARTMENT)/variables/$(DEPARTMENT).tfvars" \
	-var="pwd=${DIRECTORY}" \
	-var="build_phase=preinit" \
	-var="packer_ami_use=${PACKER_AMI_USE}" && \
	terraform apply "env/$(DEPARTMENT)/plan/planfile-preinit"

ansible-playbook-preinit: terraform-iam-provision-preinit
	export ANSIBLE_CONFIG="${DIRECTORY}/IAM/ansible/env/${DEPARTMENT}/ansible.cfg" && \
	cd IAM/ansible/env/${DEPARTMENT} && \
	ansible-playbook "${DIRECTORY}/IAM/ansible/playbook/01-playbook-preinit.yaml" \
	-e DEPARTMENT=${DEPARTMENT} \
	-e DIRECTORY=${DIRECTORY} \
	-e REGION=${AWS_REGION}

ansible-playbook-init: ansible-playbook-preinit
	export ANSIBLE_CONFIG="${DIRECTORY}/IAM/ansible/env/${DEPARTMENT}/ansible.cfg" && \
	cd IAM/ansible/env/${DEPARTMENT} && \
	ansible-playbook "${DIRECTORY}/IAM/ansible/playbook/02-playbook-init.yaml" \
	-e DEPARTMENT=${DEPARTMENT} \
	-e DIRECTORY=${DIRECTORY} \
	-e REGION=${AWS_REGION} \
	-e CREDENTIAL_PROVIDER=${KUBERNETES_CREDENTIAL_PROVIDER} \
	-e PACKER_AMI_USE=${PACKER_AMI_USE} \
	-e DOMAIN_NAME=${DOMAIN_NAME}

ansible-playbook-postinit: ansible-playbook-init
	export ANSIBLE_CONFIG="${DIRECTORY}/IAM/ansible/env/${DEPARTMENT}/ansible.cfg" && \
	cd IAM/ansible/env/${DEPARTMENT} && \
	ansible-playbook "${DIRECTORY}/IAM/ansible/playbook/03-playbook-postinit.yaml" \
	-e DEPARTMENT=${DEPARTMENT} \
	-e DIRECTORY=${DIRECTORY} \
	-e REGION=${AWS_REGION} \
	-e DOMAIN_NAME=${DOMAIN_NAME} 

ifeq ($(OIDC),true)

terraform-iam-provision-postinit: ansible-playbook-postinit
	cd IAM/terraform && \
	export AWS_PROFILE=$(AWS_IAM_PROFILE) && \
	terraform plan -out="env/$(DEPARTMENT)/plan/planfile-postinit" \
	-var-file="env/$(DEPARTMENT)/variables/$(DEPARTMENT).tfvars" \
	-var-file="$(DIRECTORY)/IAM/kubernetes/applications/$(DEPARTMENT)/airflow/thumbprint.tfvars" \
	-var="pwd=$(DIRECTORY)" \
	-var="build_phase=postinit" \
	-var="packer_ami_use=${PACKER_AMI_USE}" && \
	terraform apply "env/$(DEPARTMENT)/plan/planfile-postinit"

ansible-playbook-final: terraform-iam-provision-postinit
	export ANSIBLE_CONFIG="${DIRECTORY}/IAM/ansible/env/${DEPARTMENT}/ansible.cfg" && \
	cd IAM/ansible/env/${DEPARTMENT} && \
	ansible-playbook "${DIRECTORY}/IAM/ansible/playbook/03-playbook-postinit.yaml" \
	-e DEPARTMENT=${DEPARTMENT} \
	-e DIRECTORY=${DIRECTORY} \
	-e REGION=${AWS_REGION} \
	-e DOMAIN_NAME=${DOMAIN_NAME}

else

ansible-playbook-final: ansible-playbook-postinit

endif

all: ansible-playbook-final



