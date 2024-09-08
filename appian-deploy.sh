#!/bin/bash

# Import stage
curl -X GET \
  https://your-appian-domain.com/suite/api/v1/applications/$APPLICATION_ID/export \
  -H "Authorization: Basic " \
  -H "Content-Type: application/zip" \
  -o $ZIP_FILE_PATH

# Push stage
git add $ZIP_FILE_PATH
git commit -m "Automated commit"
git remote add origin $GIT_REPO_URL
git push -u origin master

# Pull stage
git pull origin master

# Build stage
curl -X POST \
  https://your-appian-domain.com/suite/api/v1/applications/$APPLICATION_ID/build \
  -H "Authorization: Basic " \
  -H "Content-Type: application/json" \
  -d "{}"

# SonarQube stage
sonar-scanner -Dsonar.host.url=$SONAR_HOST_URL -Dsonar.login=$SONAR_LOGIN -Dsonar.password=$SONAR_PASSWORD -Dsonar.projectKey=$SONAR_PROJECT_KEY -Dsonar.git.repository.url=$GIT_REPO_URL

# ClamAV stage
curl -X POST \
  $CLAMAV_URL \
  -H "Authorization: Basic " \
  -H "Content-Type: application/json" \
  -d "{\"file\": \"$ZIP_FILE_PATH\"}"

# Deploy stage
curl -X POST \
  https://your-appian-domain.com/suite/api/v1/applications/$APPLICATION_ID/deploy \
  -H "Authorization: Basic " \
  -H "Content-Type: application/json" \
  -d "{\"environment\": \"$ENVIRONMENT\"}"
