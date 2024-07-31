#!/usr/bin/env groovy
multibranchPipelineJob("frontend-dev") {
    displayName "frontend dev/PR"
    description "Multibranch pipeline job for frontend dev/PR"
    branchSources {
        branchSource {
            source {
                github {
                    id("64eafd97-4b5e-45d6-b74e-4845e42d1a0e")
                    repoOwner("cvp-challenges")
                    repository("practice-river-frontend")
                    repositoryUrl("https://github.com/cvp-challenges/practice-river-frontend.git")
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
