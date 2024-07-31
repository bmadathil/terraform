multibranchPipelineJob("data-api-dev") {
    displayName "data-api dev/PR"
    description "Multibranch pipeline job for data-api dev/PR"
    branchSources {
        branchSource {
            source {
                github {
                    id("1707f764-c5a9-44b5-bf4a-71909b1de714")
                    repoOwner("cvp-challenges")
                    repository("practice-river-data-api")
                    repositoryUrl("https://github.com/cvp-challenges/practice-river-data-api.git")
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
