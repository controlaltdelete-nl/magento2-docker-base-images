PHP_VERSION=php82-fpm
docker build -t base-docker-image .

docker run -it --rm --name=base base-docker-image /bin/bash -c "./start-services && composer self-update --1"