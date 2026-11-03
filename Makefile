TF ?= terraform
MODULES := modules/vpc modules/eks modules/iam-github-oidc
ENVS := environments/dev environments/prod

.PHONY: fmt validate test lint security check clean

fmt:            ## Format all Terraform files
	$(TF) fmt -recursive

validate:       ## init (no backend) and validate every module and environment
	@for d in $(MODULES) $(ENVS); do \
		echo "== $$d"; \
		(cd $$d && $(TF) init -backend=false -input=false >/dev/null && $(TF) validate) || exit 1; \
	done

test:           ## Run terraform test with mock providers (no AWS credentials needed)
	@for d in $(MODULES); do echo "== $$d"; (cd $$d && $(TF) test) || exit 1; done

lint:           ## tflint with the AWS ruleset
	tflint --init
	tflint --recursive --config "$(CURDIR)/.tflint.hcl"

security:       ## checkov static analysis
	checkov -d . --framework terraform --quiet --compact

check: fmt validate test lint security  ## Everything CI runs

clean:          ## Remove local provider caches
	find . -type d -name .terraform -prune -exec rm -rf {} +
