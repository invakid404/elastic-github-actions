#!/bin/bash

if [[ -z $STACK_VERSION ]]; then
  echo -e "\033[31;1mERROR:\033[0m Required environment variable [STACK_VERSION] not set\033[0m"
  exit 1
fi

STACK_VERSION="7.13.4"
MAJOR_VERSION=`echo ${STACK_VERSION} | cut -c 1`

mkdir -p ./elastic-senteca
cat > ./elastic-senteca/Dockerfile <<-EOF
	FROM docker.elastic.co/elasticsearch/elasticsearch:${STACK_VERSION}
	RUN /usr/share/elasticsearch/bin/elasticsearch-plugin install --batch analysis-icu
	EOF

cat ./elastic-senteca/Dockerfile

docker build -t elastic-senteca ./elastic-senteca

docker network create elastic

for (( node=1; node<=${NODES-1}; node++ ))
do
  port_com=$((9300 + $node - 1))
  UNICAST_HOSTS+="es$node:${port_com},"
done

for (( node=1; node<=${NODES-1}; node++ ))
do
  port=$((PORT + $node - 1))
  port_com=$((9300 + $node - 1))
  docker run \
    --rm \
    --env "node.name=es${node}" \
    --env "cluster.name=docker-elasticsearch" \
    --env "cluster.initial_master_nodes=es1" \
    --env "discovery.seed_hosts=es1" \
    --env "cluster.routing.allocation.disk.threshold_enabled=false" \
    --env "bootstrap.memory_lock=true" \
    --env "ES_JAVA_OPTS=-Xms512m -Xmx512m" \
    --env "xpack.security.enabled=false" \
    --env "xpack.license.self_generated.type=basic" \
    --env "http.port=${port}" \
    --env "action.destructive_requires_name=false" \
    --ulimit nofile=65536:65536 \
    --ulimit memlock=-1:-1 \
    --publish "${port}:${port}" \
    --detach \
    --network=elastic \
    --name="es${node}" \
    elastic-senteca
done

docker run \
  --network elastic \
  --rm \
  appropriate/curl \
  --max-time 120 \
  --retry 120 \
  --retry-delay 1 \
  --retry-connrefused \
  --show-error \
  --silent \
  http://es1:$PORT

sleep 10

echo "Elasticsearch up and running"
