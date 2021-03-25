APP = raycan
POD = xserver
RUNNER := $(if $(shell command -v podman),podman,docker)

latest:
	${RUNNER} build --tag will/${POD}:latest .

interactive:
	${RUNNER} run \
		--hostname ${POD} \
		-v $(CURDIR)/volumes/etc/${APP}:/etc/${APP}:ro \
		-v $(CURDIR)/volumes/var/log/${APP}:/var/log/${APP} \
		-it \
		--rm \
		--name ${POD} \
		--entrypoint ash \
		${POD}:latest

run:
	${RUNNER} run \
		--hostname ${POD} \
		-v $(CURDIR)/volumes/etc/${APP}:/etc/${APP}:ro \
		-v $(CURDIR)/volumes/var/log/${APP}:/var/log/${APP} \
		-d \
		--rm \
		--name ${POD} \
		${POD}:latest

stop:
	${RUNNER} stop ${POD}
