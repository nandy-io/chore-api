ACCOUNT=nandyio
IMAGE=chore-api
VERSION=0.1
NAME=$(IMAGE)-$(ACCOUNT)
NETWORK=klot.io
VOLUMES=-v ${PWD}/secret/:/opt/nandy-io/secret/ \
		-v ${PWD}/lib/:/opt/nandy-io/lib/ \
		-v ${PWD}/test/:/opt/nandy-io/test/ \
		-v ${PWD}/bin/:/opt/nandy-io/bin/
ENVIRONMENT=-e SLEEP=0.1 \
			-e MYSQL_HOST=mysql-klotio \
			-e MYSQL_PORT=3306 \
			-e REDIS_HOST=redis-klotio \
			-e REDIS_PORT=6379 \
			-e REDIS_CHANNEL=nandy.io/chore
PORT=6765

.PHONY: cross build network shell test run push install update reset remove

cross:
	docker run --rm --privileged multiarch/qemu-user-static:register --reset

build:
	docker build . -t $(ACCOUNT)/$(IMAGE):$(VERSION)

kube:
	-kubectl proxy --address=127.0.0.1 --port=7580 --accept-hosts='.*' &

network:
	-docker network create $(NETWORK)

shell: kube network
	-docker run -it --rm --name=$(NAME) --network=$(NETWORK) $(VOLUMES) $(ENVIRONMENT) $(ACCOUNT)/$(IMAGE):$(VERSION) sh

test: network
	docker run -it --network=$(NETWORK) $(VOLUMES) $(ENVIRONMENT) $(ACCOUNT)/$(IMAGE):$(VERSION) sh -c "coverage run -m unittest discover -v test && coverage report -m --include 'lib/*.py'"

run: kube network
	docker run --rm --name=$(NAME) --network=$(NETWORK) $(VOLUMES) $(ENVIRONMENT) -p 127.0.0.1:$(PORT):80 --expose=80 $(ACCOUNT)/$(IMAGE):$(VERSION)

start: kube network
	docker run -d --name=$(NAME) --network=$(NETWORK) $(VOLUMES) $(ENVIRONMENT) -p 127.0.0.1:$(PORT):80 --expose=80 $(ACCOUNT)/$(IMAGE):$(VERSION)

stop:
	docker rm -f $(NAME)

push:
	docker push $(ACCOUNT)/$(IMAGE):$(VERSION)

install:
	kubectl create -f kubernetes/account.yaml
	kubectl create -f kubernetes/api.yaml

update:
	kubectl replace -f kubernetes/account.yaml
	kubectl replace -f kubernetes/api.yaml

remove:
	-kubectl delete -f kubernetes/api.yaml
	-kubectl delete -f kubernetes/account.yaml

reset: remove install
