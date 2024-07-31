FROM pulumi/pulumi-nodejs:3.119.0
WORKDIR /hopper

RUN apt-get update -y && \
    apt-get upgrade -y && \
    apt-get install -y \
    build-essential \
    ca-certificates \
    curl \
    git \
    jq \
    make \
    python3 \
    unzip \
    vim

# install awscli
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" && \
    unzip awscliv2.zip && \
    ./aws/install && \
    rm -rf aws && \
    rm awscliv2.zip

# install kubectl for eks
RUN curl -O "https://s3.us-west-2.amazonaws.com/amazon-eks/1.28.2/2023-10-12/bin/linux/amd64/kubectl" && \
    install -o root -g root -m 0755 kubectl /usr/bin/kubectl && \
    rm kubectl

RUN pulumi plugin install resource aws
RUN pulumi plugin install resource awsx
RUN pulumi plugin install resource command
RUN pulumi plugin install resource eks
RUN pulumi plugin install resource docker
RUN pulumi plugin install resource kubernetes
RUN pulumi plugin install resource random

# install and configure pnpm
RUN npm install -g pnpm && \
    pnpm config set store-dir /hopper/runtime/.pnpm-store

COPY stacks .
COPY func.sh .

COPY entrypoint_debug.sh .
RUN chmod +x ./entrypoint_debug.sh

COPY Makefile .

ENTRYPOINT ["make"]
CMD ["help"]
