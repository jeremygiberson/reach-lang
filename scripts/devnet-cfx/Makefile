IMAGE=reachsh/devnet-cfx
ROOT=../..
include $(ROOT)/DEPS

.PHONY: build
build:
	$(ROOT)/scripts/build-image.sh $(IMAGE) Dockerfile
	TAG_ONLY=1 $(ROOT)/scripts/docker-push.sh $(IMAGE)

.PHONY: build-m1
build-m1: build

.PHONY: build-devnet-cfx
build-devnet-cfx: build

.PHONY: push
push:
	$(ROOT)/scripts/docker-push.sh $(IMAGE)

.PHONY: run
run: build
	docker run -t -p 12537:12537 $(IMAGE):latest

.PHONY: status
status:
	@curl -sSf -X POST \
	  -H "Content-Type: application/json" \
	  --data '{"jsonrpc":"2.0", "method": "cfx_clientVersion", "params":[], "id":67}' \
	  http://localhost:12537
