POD = raycan
RUNNER := $(if $(shell command -v podman),podman,docker)

latest:
	${RUNNER} build --tag ${POD}:latest .

interactive:
	${RUNNER} run \
		--hostname ${POD} \
		-v $(CURDIR)/volumes/etc/${POD}:/etc/${POD}:ro \
		-v $(CURDIR)/volumes/var/log/${POD}:/var/log/${POD} \
		-it \
		--rm \
		--name ${POD} \
		--entrypoint ash \
		${POD}:latest

run:
	${RUNNER} run \
		--hostname ${POD} \
		-v $(CURDIR)/volumes/etc/${POD}:/etc/${POD}:ro \
		-v $(CURDIR)/volumes/var/log/${POD}:/var/log/${POD} \
		-d \
		--rm \
		--name ${POD} \
		${POD}:latest

stop:
	${RUNNER} stop ${POD}
