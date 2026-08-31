# local dev == CI. `make test` runs exactly what ci/gate.sh runs in GitHub
# Actions — this Makefile's only job is making sure a pinned helm is on
# PATH first, so a laptop running Helm 4 doesn't quietly diverge from the
# 3.x version this repo publishes with.
HELM_VERSION         ?= 3.21.4
BIN                  := $(CURDIR)/.bin
HELM                 := $(BIN)/helm
export PATH          := $(BIN):$(PATH)
export KUBE_VERSIONS ?= 1.25.0 1.33.0

UNAME_S := $(shell uname -s | tr A-Z a-z)
UNAME_M := $(shell uname -m)
ifeq ($(UNAME_M),x86_64)
  HELM_ARCH := amd64
else ifeq ($(UNAME_M),aarch64)
  HELM_ARCH := arm64
else
  HELM_ARCH := $(UNAME_M)
endif

.PHONY: tools test lint unittest render kubeconform package-check deps clean bump-version

tools: $(HELM)

$(HELM):
	@mkdir -p $(BIN)
	@echo "fetching pinned helm v$(HELM_VERSION) ($(UNAME_S)/$(HELM_ARCH))..."
	@curl -fsSL https://get.helm.sh/helm-v$(HELM_VERSION)-$(UNAME_S)-$(HELM_ARCH).tar.gz \
	  | tar -xz -C $(BIN) --strip-components=1 $(UNAME_S)-$(HELM_ARCH)/helm

deps: tools
	./ci/gate.sh deps

lint: tools
	./ci/gate.sh lint

unittest: tools
	./ci/gate.sh unittest

render: tools
	./ci/gate.sh render

kubeconform: tools
	./ci/gate.sh kubeconform

package-check: tools
	./ci/gate.sh package-check

test: tools
	./ci/gate.sh all

bump-version:
	@test -n "$(VERSION)" || { echo "usage: make bump-version VERSION=X.Y.Z"; exit 2; }
	hack/bump-version.sh $(VERSION)

clean:
	rm -rf deployment/charts statefulset/charts deployment/Chart.lock statefulset/Chart.lock dist .bin
