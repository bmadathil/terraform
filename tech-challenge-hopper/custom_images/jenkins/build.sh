#!/bin/bash

# execute build and push for custom Jenkins image

docker buildx build -t ghcr.io/cvpcorp/jenkins:2.461-alpine-jdk17 .
docker push ghcr.io/cvpcorp/jenkins:2.461-alpine-jdk17
