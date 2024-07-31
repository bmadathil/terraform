#!/usr/bin/env groovy
multibranchPipelineJob("backend-dev") {
    displayName "backend dev/PR"
    description "Multibranch pipeline job for backend dev/PR"
    branchSources {
        branchSource {
            source {
                github {
                    id("85e8d9a4-299a-44d3-8c46-0c0000f25a8b")
                    repoOwner("cvp-challenges")
                    repository("practice-river-backend")
                    repositoryUrl("https://github.com/cvp-challenges/practice-river-backend.git")
                    configuredByUrl(false)
                    credentialsId("github-credentials")
                    traits {
                        gitHubBranchDiscovery {
                            strategyId(1)
                        }
                        gitHubPullRequestDiscovery {
                            strategyId(2)
                        }
                    }
                }
            }
            buildStrategies {
                excludeRegionByFileBranchBuildStrategy {
                    excludeFilePath("devops/.jenkinsExcludeFile")
                }
            }
        }
    }
    factory {
        workflowBranchProjectFactory {
            scriptPath("devops/Jenkinsfile.dev")
        }
    }
    orphanedItemStrategy {
        discardOldItems
        {
            daysToKeep(2)
            numToKeep(5)
        }
    }
    triggers {
        periodicFolderTrigger {
            interval("2m")
        }
    }
}
