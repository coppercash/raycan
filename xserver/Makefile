CONTAINER = xserver
RUNNER := $(if $(shell command -v podman),podman,docker)

latest:
	${RUNNER} build --tag will/raycan/${CONTAINER}:latest .

it:
	${RUNNER} run \
		--hostname ${CONTAINER} \
		-it \
		--rm \
		--name ${CONTAINER} \
		--entrypoint ash \
		-v $(CURDIR)/volumes/etc/raycan:/etc/raycan:ro \
		-v $(CURDIR)/volumes/var/log/xray:/var/log/xray \
		-v $(CURDIR)/volumes/var/html:/var/html \
		-v $(CURDIR)/volumes/var/acmesh/cert:/var/acmesh/cert \
		-v $(CURDIR)/volumes/var/log/acmesh:/var/log/acmesh \
		-p 443:443 \
		-p 80:80 \
		-e SERVER_NAME=${SERVER_NAME} \
		will/raycan/${CONTAINER}:latest

run:
	${RUNNER} run \
		-d \
		--rm \
		--name ${CONTAINER} \
		-v $(CURDIR)/volumes/etc/raycan:/etc/raycan:ro \
		-v $(CURDIR)/volumes/var/log/xray:/var/log/xray \
		-v $(CURDIR)/volumes/var/html:/var/html \
		-v $(CURDIR)/volumes/var/acmesh/cert:/var/acmesh/cert \
		-v $(CURDIR)/volumes/var/log/acmesh:/var/log/acmesh \
		-p 443:443 \
		-p 80:80 \
		-e SERVER_NAME=${SERVER_NAME} \
		will/raycan/${CONTAINER}:latest

staging:
	${RUNNER} run \
		--rm \
		--name ${CONTAINER} \
		-v $(CURDIR)/volumes/var/log/acmesh:/var/log/acmesh \
		-v $(CURDIR)/volumes/var/html:/var/html \
		-v $(CURDIR)/volumes/var/acmesh/cert:/var/acmesh/cert \
		-p 443:443 \
		-p 80:80 \
		-e SERVER_NAME=${SERVER_NAME} \
		will/raycan/${CONTAINER}:latest -t

stop:
	${RUNNER} stop ${CONTAINER}
