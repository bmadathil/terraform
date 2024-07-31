# hopper

.DEFAULT_GOAL := help
.PHONY: identity

### --- primary targets (these show up when help target is used)

# call scripts in ascending order
create: banner check-vars mod-scripts ### Creates infrastructure and services, and deploys workloads
	@00_init/init.sh
	@01-identity/init.sh
	@11-infrastructure/init.sh
	@20-aws-services/init.sh
	@50-workloads/init.sh
	@90_post/init.sh

# data loading example
load-data: banner check-vars mod-scripts ### Load CSV files from data folder to S3 for processing
	@80_load-data/init.sh

# destroys all resources
destroy: zap-confirm ### Destroys all services and infrastrucure
	@99_destroy/destroy.sh

## -- end primary targets

### --- helper targets (internal use)

# ensures all scripts are executable
mod-scripts:
	@(find . -name "*.sh" -execdir chmod u+x {} +)

# destroy confirmation
zap-confirm: check-vars
	@(read -p "Are you sure? This action will destroy the cluster, its contents, and all local state files. [y/N]: " zap && case "$$zap" in [yY]) true;; *) false;; esac)

# display a banner (optional)
banner:
	@clear
	@./func.sh bnr "H4sIAAAAAAAAA01NuxUDMQjrmUJlUvjokz1S+T15EIaPBFeczEeWEQ4YV52NAY1nn+BdHhk2JgoYb0rc4mmmXihF82qhk8PDVtiMT/cXLf+Qkuitult9YwQnq/qfSF5rre+inoVNr9220ROqCqtpYVIjOv65UVznpici/suzwVsIAQAA"
	@./func.sh msg PROJECT_TAG_OR_MESSAGE
	@sleep 1s

# checks for required env vars
check-vars:
	@./func.sh hdr Checking for required environment variables 

ifndef AWS_ACCESS_KEY_ID
	$(error AWS_ACCESS_KEY_ID is undefined)
endif

ifndef AWS_SECRET_ACCESS_KEY
	$(error AWS_SECRET_ACCESS_KEY is undefined)
endif

ifndef AWS_DEFAULT_REGION
	$(error AWS_DEFAULT_REGION is undefined)
endif

	@./func.sh msg Required environment variables present.

# helper target when troubleshooting a single stack
dev: mod-scripts
	@pulumi login s3://pulumi-state-$(shell cat ./runtime/.cluster-id)-${AWS_DEFAULT_REGION}

# display primary targets (targets with "###" help blocks above)
help:
	@grep -E '^[a-zA-Z_-]+:.*?### .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?### "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'
