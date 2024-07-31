#!/usr/bin/env groovy

def env = "test"
def app = "data-api"
def repoOwner = "cvp-challenges"
def repository = "practice-river-${app}"
def httpsRepoUrl = "https://github.com/${repoOwner}/${repository}.git"
def jenkinsfilePath = "devops/Jenkinsfile.${env}"
def githubCredentialsName = "github-credentials"

pipelineJob("${app}-${env}") {
    displayName "${app} ${env}"
    description "Pipeline job for ${app} ${env}"
    definition {
        cpsScm {
            lightweight()
            scm {
                git {
                    remote {
                        credentials(githubCredentialsName)
                        github("${repoOwner}/${repository}")
                        url(httpsRepoUrl)
                    }
                    branch("main")
                }
            }
            scriptPath(jenkinsfilePath)
        }
    }
    properties {
        githubProjectUrl(httpsRepoUrl)
        buildDiscarder {
            strategy {
                logRotator {
                    daysToKeepStr("2")
                    numToKeepStr("5")
                    artifactDaysToKeepStr("2")
                    artifactNumToKeepStr("5")
                }
            }
        }
        parameters {
            parameterDefinitions {
                stringParam {
                    name("IMAGE_TAG")
                    defaultValue("latest")
                    description("Image tag from the successful ${env} build.")
                    trim(true)
                }
            }
        }
    }
}
