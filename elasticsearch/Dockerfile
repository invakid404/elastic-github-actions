FROM docker:stable

RUN apk add --update bash

COPY . .

ENTRYPOINT ["/run-elasticsearch.sh"]
