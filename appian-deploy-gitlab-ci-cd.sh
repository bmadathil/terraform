stages:
  - import
  - push
  - pull
  - build
  - sonarqube
  - clamav
  - deploy

variables:
  API_USERNAME: "your-username"
  API_PASSWORD: "your-password"
  APPLICATION_ID: "your-application-id"
  GIT_USERNAME: "your-git-username"
  GIT_PASSWORD: "your-git-password"
  GIT_REPO_URL: "https://github.com/your-username/your-repo-name.git"
  ZIP_FILE_PATH: "/path/to/your/application.zip"
  ENVIRONMENT: "Development"
  SONAR_HOST_URL: "https://your-sonarqube-instance.com"
  SONAR_LOGIN: "your-sonarqube-username"
  SONAR_PASSWORD: "your-sonarqube-password"
  SONAR_PROJECT_KEY: "your-sonarqube-project-key"
  CLAMAV_USERNAME: "your-clamav-username"
  CLAMAV_PASSWORD: "your-clamav-password"
  CLAMAV_URL: "https://your-clamav-instance.com/api/v1/scan"

import:
  stage: import
  script:
    - curl -X GET \
      https://your-appian-domain.com/suite/api/v1/applications/$APPLICATION_ID/export \
      -H 'Authorization: Basic ' \
      -H 'Content-Type: application/zip' \
      -o $ZIP_FILE_PATH

push:
  stage: push
  script:
    - git add $ZIP_FILE_PATH
    - git commit -m "Automated commit"
    - git remote add origin $GIT_REPO_URL
    - git push -u origin master

pull:
  stage: pull
  script:
    - git pull origin master

build:
  stage: build
  script:
    - curl -X POST \
      https://your-appian-domain.com/suite/api/v1/applications/$APPLICATION_ID/build \
      -H 'Authorization: Basic ' \
      -H 'Content-Type: application/json' \
      -d '{}'

sonarqube:
  stage: sonarqube
  script:
    - sonar-scanner -Dsonar.host.url=$SONAR_HOST_URL -Dsonar.login=$SONAR_LOGIN -Dsonar.password=$SONAR_PASSWORD -Dsonar.projectKey=$SONAR_PROJECT_KEY -Dsonar.git.repository.url=$GIT_REPO_URL

clamav:
  stage: clamav
  script:
    - curl -X POST \
      $CLAMAV_URL \
      -H 'Authorization: Basic ' \
      -H 'Content-Type: application/json' \
      -d '{"file": "'$ZIP_FILE_PATH'"}'

deploy:
  stage: deploy
  script:
    - curl -X POST \
      https://your-appian-domain.com/suite/api/v1/applications/$APPLICATION_ID/deploy \
      -H 'Authorization: Basic ' \
      -H 'Content-Type: application/json' \
      -d '{"environment": "'$ENVIRONMENT'"}'
