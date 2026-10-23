.DEFAULT_GOAL := help
PROJECT := Its404Yo.xcodeproj
SCHEME := Its404Yo
DEST := platform=macOS
SPM_DIR := .build-spm

.PHONY: sitemap design design-check footer social help generate open build test clean

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

CHROME ?= /Applications/Google Chrome.app/Contents/MacOS/Google Chrome
CARD   := file://$(CURDIR)/docs/social-card.html

social: ## Render the social card: GitHub preview (docs/) + og:image (site/assets/)
	@mkdir -p .build-social
	"$(CHROME)" --headless=new --disable-gpu --hide-scrollbars --force-device-scale-factor=2 \
		--window-size=1280,640 --screenshot=.build-social/github.png "$(CARD)" >/dev/null 2>&1
	"$(CHROME)" --headless=new --disable-gpu --hide-scrollbars --force-device-scale-factor=2 \
		--window-size=1200,630 --screenshot=.build-social/og.png "$(CARD)#og" >/dev/null 2>&1
	sips -z 640 1280 .build-social/github.png --out docs/social-preview.png >/dev/null
	cp .build-social/og.png site/assets/og.png
	@rm -rf .build-social
	@echo "docs/social-preview.png  (1280x640, upload in GitHub: Settings > Social preview)"
	@echo "site/assets/og.png       (2400x1260, served as og:image)"

DESIGN_TAG ?= v1.35.1

# scripts/iamjarl-vendor.mjs is the design system's own copy script (its dist/vendor.mjs, checked
# against the tag's sri.json when it was taken). It copies what the pages load to
# site/assets/iamjarl-design@<tag>/, checks each dist/ file against that tag's hashes, and pastes
# the store buttons, the JSON-LD offer and the footer's cross-links again from the same tag.
# Vendored rather than loaded from jsDelivr: the privacy page names Umami as the only third party.
design: ## Vendor iamjarl-design at DESIGN_TAG: <ij-footer>, store buttons, cross-links, identity + font
	node scripts/iamjarl-vendor.mjs $(DESIGN_TAG) --root site

design-check: ## Exit 1 if the vendored copy or a pasted piece differs from DESIGN_TAG
	node scripts/iamjarl-vendor.mjs $(DESIGN_TAG) --root site --check

footer: design ## Alias for `make design`

sitemap: ## Regenerate site/sitemap.xml with lastmod from git (the Pages deploy runs this too)
	python3 scripts/sitemap.py

clean: ## Remove generated project and build artifacts
	rm -rf $(PROJECT) $(SPM_DIR) DerivedData build
