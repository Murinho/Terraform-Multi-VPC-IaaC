SHELL := /bin/bash
ROOT := live/dev

.PHONY: fmt validate test plan check

fmt:
	terraform fmt -recursive

validate:
	cd $(ROOT) && terraform init -backend=false && terraform validate

test:
	cd $(ROOT) && terraform init -backend=false && terraform test

plan:
	cd $(ROOT) && terraform plan

check: fmt validate test
