all:

buildenv:
	docker build . -t sel4webserverdev

env:
	docker run --name sel4webserverdev --rm -v $(shell pwd):/code -w /code/ -it sel4webserverdev 2> /dev/null || docker exec -it sel4webserverdev sh
