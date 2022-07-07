# VERSION defines the version for the docker containers.
# To build a specific set of containers with a version,
# you can use the VERSION as an arg of the docker build command (e.g make docker VERSION=0.0.2)
VERSION ?= 0.0.1

# REGISTRY defines the registry where we store our images.
# To push to a specific registry,
# you can use the REGISTRY as an arg of the docker build command (e.g make docker REGISTRY=my_registry.com/username)
# You may also change the default value if you are using a different registry as a default
REGISTRY ?= registry.gitlab.com/devops0077/k8s-laravel


# Commands
docker: docker-build docker-push

fpm:
	docker build . --target fpm -t ${REGISTRY}/php-fpm:${VERSION} -f docker/php/8.1-alpine3.16/Dockerfile
	docker push ${REGISTRY}/php-fpm:${VERSION}
cli:
	docker build . --target cli -t ${REGISTRY}/php-cli:${VERSION} -f docker/php/8.1-alpine3.16/Dockerfile
	docker push ${REGISTRY}/php-cli:${VERSION}
cron:
	docker build . --target cron -t ${REGISTRY}/cron:${VERSION} -f docker/php/8.1-alpine3.16/Dockerfile
	docker push ${REGISTRY}/cron:${VERSION}
nginx:
	docker build . --target nginx -t ${REGISTRY}/nginx:${VERSION} -f docker/nginx/1.22-alpine/Dockerfile
	docker push ${REGISTRY}/nginx:${VERSION}

docker-build:
	docker build . --target cli -t ${REGISTRY}/php-cli:${VERSION} -f docker/php/8.1-alpine3.16/Dockerfile
	docker build . --target cron -t ${REGISTRY}/cron:${VERSION} -f docker/php/8.1-alpine3.16/Dockerfile
	docker build . --target fpm -t ${REGISTRY}/php-fpm:${VERSION} -f docker/php/8.1-alpine3.16/Dockerfile
	docker build . --target nginx -t ${REGISTRY}/nginx:${VERSION} -f docker/nginx/1.22-alpine/Dockerfile

docker-push:
	docker push ${REGISTRY}/php-cli:${VERSION}
	docker push ${REGISTRY}/cron:${VERSION}
	docker push ${REGISTRY}/php-fpm:${VERSION}
	docker push ${REGISTRY}/nginx:${VERSION}
