#!/usr/bin/env groovy
import groovy.json.JsonSlurperClassic
@Library('jenkins-shared-library')_

PUSH_SCRATCH_ORG_DURATION_DAYS=1;
PKG_SCRATCH_ORG_DURATION_DAYS=7;
SCRATCH_ORG_DURATION_DAYS=0; //based on what type of build, this will get set with the correct val from the above 2
SCRATCH_ORG_USERNAME=''; // the username to use for most SFDX commands once the scratch org is created
SFDX_PROJECT_JSON=null; // object which holds the values from the sfdx-project.json file in the project. Reloaded upon package create version
LAST_COMMIT_AUTHOR='';

RUN_ARTIFACT_DIR="tests/${BUILD_NUMBER}"

pipeline {
    agent { 
      kubernetes {
        label 'sfdx'
        yaml libraryResource('pod_templates/sfdx_agent.yaml')
      }
    }
    environment {
        //can't quite use withCredentials in each stage, as new tmp dirs get created clobbering stuff
        DEV_HUB_JWT_KEY_FILE = credentials("${env.JWT_CRED_ID_DH}")
    }
    parameters {
        booleanParam(
            name: "CREATEPACKAGE",
            description: "Create a package from the current commit",
            defaultValue: false
        )
        booleanParam(
            name: "PROMOTEPACKAGE",
            description: "Promote the latest package created",
            defaultValue: false
        )
    }
    stages {
        stage ('Checkout code') {
            steps {
                git branch: "${env.BRANCH_NAME}",
                  credentialsId: 'github-ssh',
                  url: 'git@github.com:sercante-llc/protected-campaign-statuses.git'
                
                //loads info from sfdx-project.json for use in this script
                script {
                    SFDX_PROJECT_JSON = jsonObjectFromFile('sfdx-project.json')
                    LAST_COMMIT_AUTHOR = sh returnStdout: true, script: 'git log --format="%ae" | head -1'
                    sh 'git config --global user.email admin+jenkins@sercante.com;git config --global user.name sercante-jenkins'
                }
            }
        }

        stage('Authenticate Devhub') {
            steps {
                container('sfdx') {
                    script {
                        sh "sfdx --version"
                        sh "sfdx force:auth:jwt:grant --clientid ${env.CONNECTED_APP_CONSUMER_KEY_DH} --username ${env.HUB_ORG_DH} --jwtkeyfile ${env.DEV_HUB_JWT_KEY_FILE} --setdefaultdevhubusername --instanceurl ${env.SFDC_HOST_DH}"
                    }
                }
            }
        }

        stage('Create Scratch Org') {
            when {
                expression { !params.PROMOTEPACKAGE }
            }
            steps {
                container('sfdx') {
                    script {
                        if(params.CREATEPACKAGE) {
                            SCRATCH_ORG_DURATION_DAYS = PKG_SCRATCH_ORG_DURATION_DAYS
                        }
                        else {
                            SCRATCH_ORG_DURATION_DAYS = PUSH_SCRATCH_ORG_DURATION_DAYS
                        }
                        jsonString = sh returnStdout: true, script: "sfdx force:org:create --noancestors --definitionfile config/project-scratch-def.json --json --durationdays ${SCRATCH_ORG_DURATION_DAYS} --wait 10"
                        echo jsonString
                        robj = jsonObjectFromString(jsonString)

                        SCRATCH_ORG_USERNAME=robj.result.username
                        robj = null
                    }
                }
            }
        }
        
        stage('Push to Scratch Org') {
            when {
                expression { !params.CREATEPACKAGE && !params.PROMOTEPACKAGE }
            }
            steps {
                container('sfdx') {
                    script {
                        sh "sfdx force:source:push --targetusername ${SCRATCH_ORG_USERNAME}"
                        // assign permset
                        // sh "sfdx force:user:permset:assign --targetusername ${SCRATCH_ORG_USERNAME} --permsetname DreamHouse"
                    }
                }
            }
        }

        stage('Create Package and Install') {
            when {
                expression { params.CREATEPACKAGE}
            }
            steps {
                container('sfdx') {
                    script {
                        //create the package version
                        sh 'date'
                        jsonString = sh returnStdout: true, script: "sfdx force:package:version:create --package \"${SFDX_PROJECT_JSON.packageDirectories[0].package}\" --wait 30 --codecoverage --installationkeybypass --json"
                        sh 'date'
                        echo jsonString
                        robj = jsonObjectFromString(jsonString)

                        //refresh the sfdx-project.json file as a new version would have been put there
                        SFDX_PROJECT_JSON = jsonObjectFromFile('sfdx-project.json')
                        def lastVersionAlias = sfdxGetLatestPackageVersion(SFDX_PROJECT_JSON.packageDirectories[0].versionName,SFDX_PROJECT_JSON)
                        echo lastVersionAlias
                        def pkgVersionId = SFDX_PROJECT_JSON.packageAliases[lastVersionAlias]
                        echo pkgVersionId

                        //it takes a while for packages to be available
                        //currently publishwait option doesn't work, need to manually poll. https://github.com/forcedotcom/cli/issues/160
                        timeout(60) {
                            waitUntil {
                                script {
                                    //echo "starting package build"
                                    rstat = sh returnStatus:true, script: "sfdx force:package:install --package \"${lastVersionAlias}\" --targetusername ${SCRATCH_ORG_USERNAME} --wait 10 --json > stdout.json 2>&1"
                                    //echo "got rstat of ${rstat}"
                                    
                                    if(rstat !=0) {
                                        robj = jsonObjectFromFile('stdout.json')
                                        echo "Error from install attempt: ${robj.message}"
                                        if(robj.message.contains('not fully available')) {
                                            echo "Anticipated this, waiting 60s in script then have Jenkins try again"
                                            sleep(60)
                                            return false
                                        }
                                        error("Package Version Create command failed: ${robj.message}")
                                    }
                                    else {
                                        return true
                                    }
                                }
                            }
                        }
                    }
                }
                script {
                    //commit the file as a new version was created
                    sh 'git add "sfdx-project.json"'
                    sh 'git commit -m "Created new package version"'
                    sshagent(['github-ssh']) {
                        sh "git push origin ${env.BRANCH_NAME}"
                    }
                }
            }
        }

        stage('Promote Package') {
            when {
                expression { params.PROMOTEPACKAGE }
            }
            steps {
                //first create the version in SFDX
                script {
                    def lastVersionAlias = sfdxGetLatestPackageVersion(SFDX_PROJECT_JSON.packageDirectories[0].versionName,SFDX_PROJECT_JSON)
                    def pkgVersionId = SFDX_PROJECT_JSON.packageAliases[lastVersionAlias]
                    container('sfdx') {
                        jsonString = sh returnStdout: true, script: "sfdx force:package:version:promote --package \"${lastVersionAlias}\" --json --noprompt"
                        echo jsonString
                    }
                    def relVerNo = SFDX_PROJECT_JSON.packageDirectories[0].versionName
                    echo "will release ${relVerNo}"
                
                    container('curl') {
                        //tag the release in github so we can easily branch from it later
                        githubRelease('protected-campaign-statuses', relVerNo)
                    }

                    //prep the sfdx project file to be the next dev version
                    def nextVersNo = getNextVersionNumber('patch', relVerNo)

                    def sfdxProjectFileContents = readFile('sfdx-project.json')
                    //replace the versionName
                    sfdxProjectFileContents = sfdxProjectFileContents.replaceAll("\"$relVerNo\"", "\"$nextVersNo\"")
                    //replace nextVersionName
                    sfdxProjectFileContents = sfdxProjectFileContents.replaceAll("\"${relVerNo}.NEXT\"", "\"${nextVersNo}.NEXT\"")
                    // echo sfdxProjectFileContents
                    writeFile(file: 'sfdx-project.json', text: sfdxProjectFileContents, encoding: 'UTF-8')                        
                    
                    sh 'git add "sfdx-project.json"'
                    sh "git commit -m 'Set version to $nextVersNo for next development effort'"
                    sshagent(['github-ssh']) {
                        sh "git push origin ${env.BRANCH_NAME}"
                    }
                }
            }
        }

        stage('Notify Slack') {
            steps {
                container('sfdx') {
                    script {
                        def messageHeader = "`${SFDX_PROJECT_JSON.name}` version *${env.BRANCH_NAME}-${SFDX_PROJECT_JSON.packageDirectories[0].versionNumber}*"

                        if(!params.CREATEPACKAGE && !params.PROMOTEPACKAGE && LAST_COMMIT_AUTHOR != 'sercante-jenkins') {

                            //ok now do the stuff to get Slack notification. First up, getting the front door URL for the pushed code
                            jsonString = sh returnStdout: true, script: "sfdx force:org:open --json --urlonly --targetusername ${SCRATCH_ORG_USERNAME}"
                            //echo jsonString
                            robj = jsonObjectFromString(jsonString)
                            def magicUrl=robj.result.url
                            robj = null
                        
                            //next we generate a password
                            jsonString = sh returnStdout: true, script: "sfdx force:user:password:generate --json --targetusername ${SCRATCH_ORG_USERNAME}"
                            //echo jsonString
                            robj = jsonObjectFromString(jsonString)
                            SCRATCH_ORG_PASSWORD=robj.result.password
                            robj = null

                            def line1 = "${messageHeader} ready to test: "
                            def line2 = "- <${magicUrl}|Auto Login> to this *temporary org* which is available for ${SCRATCH_ORG_DURATION_DAYS} days to validate"
                            def line3 = "- Login manually by using username `${SCRATCH_ORG_USERNAME}` and password `${SCRATCH_ORG_PASSWORD}`"
                            def line4 = "If testing looks good, <${JOB_URL}build?delay=0sec|Start a Package Create build>"
                            slackSend (channel: "api-notifications", color: 'good', message: "${line1}\n${line2}\n${line3}\n${line4}")
                        }
                        if(params.CREATEPACKAGE) {
                            def lastVersionAlias = sfdxGetLatestPackageVersion(SFDX_PROJECT_JSON.packageDirectories[0].versionName,SFDX_PROJECT_JSON)
                            def pkgVersionId = SFDX_PROJECT_JSON.packageAliases[lastVersionAlias]
                            //get the front door URL for the scratch org that has 
                            jsonString = sh returnStdout: true, script: "sfdx force:org:open --json --urlonly --targetusername ${SCRATCH_ORG_USERNAME}"
                            //echo jsonString
                            robj = jsonObjectFromString(jsonString)
                            def pkgMagicUrl=robj.result.url
                            robj = null
                        
                            //next we generate a password
                            jsonString = sh returnStdout: true, script: "sfdx force:user:password:generate --json --targetusername ${SCRATCH_ORG_USERNAME}"
                            //echo jsonString
                            robj = jsonObjectFromString(jsonString)
                            SCRATCH_ORG_PASSWORD=robj.result.password
                            robj = null

                            def line1 = "${messageHeader} PackageVersion Created: "
                            def line2 = "- <${pkgMagicUrl}|Auto Login> to this *temporary org* with the Package Version installed already, which is available for ${SCRATCH_ORG_DURATION_DAYS} days to validate"
                            def line3 = "- Login manually by using username `${SCRATCH_ORG_USERNAME}` and password `${SCRATCH_ORG_PASSWORD}`"
                            def line4 = "- Direct Package Install URLs: <https://test.salesforce.com/packaging/installPackage.apexp?p0=${pkgVersionId}|Test Org> or <https://login.salesforce.com/packaging/installPackage.apexp?p0=${pkgVersionId}|Production Org>"
                            def line5 = "If the package looks good, <${JOB_URL}build?delay=0sec|promote it>."
                            slackSend (channel: "api-notifications", color: 'good', message: "${line1}\n${line2}\n${line3}\n${line4}\n${line5}")
                        }
                        if(params.PROMOTEPACKAGE) {
                            slackSend (channel: "product-development", color: 'good', message: "${messageHeader} PackageVersion Promoted. It might take up to an hour for the version to be reflected in Salesforce")
                        }
                    }
                }
            }
        }
    }
    post { always { script {
        slackNotification()
    } } }
}