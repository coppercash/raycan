CONTAINER = tproxy
RUNNER := $(if $(shell command -v podman),podman,docker)

latest:
	${RUNNER} build --tag will/raycan/${CONTAINER}:latest .

it:
	${RUNNER} run \
		--hostname ${CONTAINER} \
		-it \
		--rm \
		--name ${CONTAINER} \
		--entrypoint bash \
		-v $(CURDIR)/volumes/etc/raycan:/etc/raycan:ro \
		-v $(CURDIR)/volumes/var/log/xray:/var/log/xray \
		will/raycan/${CONTAINER}:latest

run:
	${RUNNER} run \
		-d \
		--rm \
		--name ${CONTAINER} \
		-v $(CURDIR)/volumes/etc/raycan:/etc/raycan:ro \
		-v $(CURDIR)/volumes/var/log/xray:/var/log/xray \
		will/raycan/${CONTAINER}:latest

stop:
	${RUNNER} stop ${CONTAINER}
