FROM jenkins/jenkins:2.461-alpine-jdk17

ENV JAVA_OPTS="-Djenkins.install.runSetupWizard=false" \
    CASC_JENKINS_CONFIG="/var/jenkins_home/casc.yaml" \
    SEED_JOB_REPO_URL="https://repo_url" \
    SEED_JOB_ROOT_DIR="directory_name"

USER root

RUN apk update
RUN apk add docker && addgroup jenkins docker
RUN apk add envsubst

COPY plugins.txt /usr/share/jenkins/ref/
RUN java -jar /opt/jenkins-plugin-manager.jar --plugin-file /usr/share/jenkins/ref/plugins.txt

USER jenkins
