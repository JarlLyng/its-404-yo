.DEFAULT_GOAL := help
PROJECT := Its404Yo.xcodeproj
SCHEME := Its404Yo
DEST := platform=macOS
SPM_DIR := .build-spm

.PHONY: help generate open build test clean

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}'

generate: ## Generate the Xcode project from project.yml
	xcodegen generate

open: generate ## Generate and open in Xcode
	open $(PROJECT)

build: generate ## Build the app (no code signing)
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -destination '$(DEST)' \
		-clonedSourcePackagesDirPath $(SPM_DIR) CODE_SIGNING_ALLOWED=NO build

test: generate ## Run the unit tests
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -destination '$(DEST)' \
		-clonedSourcePackagesDirPath $(SPM_DIR) CODE_SIGNING_ALLOWED=NO test

clean: ## Remove generated project and build artifacts
	rm -rf $(PROJECT) $(SPM_DIR) DerivedData build
