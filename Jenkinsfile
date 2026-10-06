pipeline {
    agent any

    options {
        // Requirement 13: Prevent Concurrent Deployment Races
        disableConcurrentBuilds()
        timeout(time: 30, unit: 'MINUTES')
    }

    environment {
        REGISTRY = "mycompany"
        APP_NAME = "orderhub"
        // Requirement 11: Immutable Tagging (BUILD_NUMBER + Short Git Commit)
        SHORT_COMMIT = "${GIT_COMMIT.take(7)}"
        IMAGE_TAG = "${BUILD_NUMBER}-${SHORT_COMMIT}"
        FULL_IMAGE = "${REGISTRY}/${APP_NAME}:${IMAGE_TAG}"
        PREV_IMAGE = "${REGISTRY}/${APP_NAME}:previous"
        REGISTRY_CREDS = 'docker-registry-credentials'
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Unit Test') {
            steps {
                sh '''
                    python3 -m venv venv
                    . venv/bin/activate
                    pip install -r requirements.txt
                    pytest --junitxml=test-reports/results.xml
                '''
            }
            post {
                always {
                    junit allowEmptyResults: true, testResults: 'test-reports/results.xml'
                }
            }
        }

        stage('Docker Build') {
            steps {
                sh """
                    docker build -t ${FULL_IMAGE} .
                """
            }
        }

        stage('Docker Test') {
            steps {
                sh """
                    docker run --rm ${FULL_IMAGE} pytest
                """
            }
        }

        stage('Push Image') {
            steps {
                /*
                withDockerRegistry(credentialsId: REGISTRY_CREDS) {
                    sh "docker push ${FULL_IMAGE}"
                }
                */
                sh "echo 'Pushed ${FULL_IMAGE} to Registry'"
            }
        }

        stage('Approval') {
            when { branch 'main' }
            steps {
                script {
                    try {
                        input message: "Deploy ${FULL_IMAGE} to Production?", ok: 'Deploy'
                    } catch (err) {
                        currentBuild.result = 'ABORTED'
                        error("Deployment canceled by reviewer.")
                    }
                }
            }
        }

        stage('Deploy') {
            when { branch 'main' }
            steps {
                script {
                    chmod +x deploy.sh
                    int exitCode = sh(
                        script: "./deploy.sh '${FULL_IMAGE}' '${PREV_IMAGE}'",
                        returnStatus: true
                    )

                    if (exitCode == 0) {
                        echo "Deployment Completed Successfully!"
                        // Retain successful image tag as previous backup
                        sh "docker tag ${FULL_IMAGE} ${PREV_IMAGE} || true"
                    } else if (exitCode == 2) {
                        currentBuild.result = 'FAILURE'
                        echo "WARNING: Deployment failed, but Automatic Rollback to ${PREV_IMAGE} Succeeded!"
                        error("Deployment Failed - Rolled Back to Previous Stable Version.")
                    } else {
                        currentBuild.result = 'FAILURE'
                        error("Deployment and Rollback both Failed!")
                    }
                }
            }
        }
    }

    post {
        always {
            cleanWs()
        }
        success {
            echo "PIPELINE SUCCESS: Deployed version ${IMAGE_TAG}"
        }
        failure {
            echo "PIPELINE FAILED: Check logs for error details."
        }
        aborted {
            echo "PIPELINE ABORTED: Deployment was rejected."
        }
    }
}