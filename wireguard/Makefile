RUNNER = $(if $(shell command -v podman),podman,docker)
IMAGE = will/raycan/wireguard:latest
CONTAINER = raycan_wireguard

latest:
	${RUNNER} build --tag ${IMAGE} .

run:
	${RUNNER} run \
		-d \
		--name ${CONTAINER} \
		-v /lib/modules:/lib/modules:ro \
		-v $(CURDIR)/volumes/etc/raycan:/etc/raycan:ro \
		-v $(CURDIR)/volumes/etc/wireguard:/etc/wireguard:ro \
		-v $(CURDIR)/volumes/var/log/xray:/var/log/xray \
		${IMAGE}

destroy:
	${RUNNER} stop ${CONTAINER}
	${RUNNER} rm ${CONTAINER}

it:
	${RUNNER} exec -it ${CONTAINER} ash

logs:
	${RUNNER} logs ${CONTAINER}
