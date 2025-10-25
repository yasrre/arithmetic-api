pipeline {
    agent none // Global agent is disabled, we define agents per stage

    environment {
        // --- Configuration Variables ---
        DOCKERHUB_USERNAME = 'yassineokr'
        IMAGE_BASE_NAME = 'arithmetic-api'
        FULL_IMAGE_NAME = "${DOCKERHUB_USERNAME}/${IMAGE_BASE_NAME}"
        DOCKERHUB_CREDENTIALS_ID = 'docker-hub-credentials'
        APP_DIR = 'api'
        
        // Define agents for specific tasks
        PYTHON_AGENT_IMAGE = 'python:3.9-alpine' // For Python tasks
        DIND_AGENT_IMAGE = 'docker:25-dind'      // For Docker CLI tasks (if needed, simplified below)
    }

    stages {
        stage('Checkout Code') {
            agent any // Use the base Jenkins agent for SCM checkout
            steps {
                echo 'Checking out code from GitHub...'
                checkout scm
            }
        }

        stage('Security & Tests') {
            // Use the Python image as an agent to run Python-based commands
            agent {
                docker {
                    image PYTHON_AGENT_IMAGE
                    // Mount the entire workspace so the agent can access all files
                    args "-v ${workspace}:/home/jenkins/workspace -w /home/jenkins/workspace/${JOB_NAME}"
                }
            }
            steps {
                script {
                    echo 'Installing security dependencies inside Python agent...'
                    // Install core dependencies + security tools globally inside the Python agent
                    sh "pip install -r ${APP_DIR}/requirements.txt bandit safety pytest"

                    // --- SAST (Bandit) ---
                    echo 'Running Bandit SAST scan...'
                    sh "bandit -r ${APP_DIR} -ll -x ${APP_DIR}/test_app.py || true" // || true allows pipeline to proceed

                    // --- SCA (Safety) ---
                    echo 'Running Safety SCA check...'
                    sh "safety check -r ${APP_DIR}/requirements.txt || true"

                    // --- Unit Tests (Pytest) ---
                    echo 'Running Pytest unit tests...'
                    sh "pytest ${APP_DIR}"
                }
            }
        }
        
        stage('Build & Image Scan (Trivy)') {
            // Use the base Jenkins agent but grant it Docker CLI access via mounting the socket
            agent {
                label 'jenkins' // Assuming 'jenkins' is the label of your main host agent
                args '-v /var/run/docker.sock:/var/run/docker.sock'
            }
            steps {
                script {
                    echo 'Building Docker image and tagging for Trivy scan...'
                    
                    // 1. Build the Docker image, tagging it with the unique build number
                    sh "docker build -t ${FULL_IMAGE_NAME}:${env.BUILD_NUMBER} -f ${APP_DIR}/Dockerfile ${APP_DIR}"

                    // 2. Scan the built image using the Trivy CLI (Trivy must be installed on the Jenkins host/VM)
                    echo 'Scanning image with Trivy (Failing on HIGH or CRITICAL issues)...'
                    sh "trivy image --exit-code 1 --severity HIGH,CRITICAL ${FULL_IMAGE_NAME}:${env.BUILD_NUMBER}"
                    
                    // 3. Tag the image as 'latest'
                    sh "docker tag ${FULL_IMAGE_NAME}:${env.BUILD_NUMBER} ${FULL_IMAGE_NAME}:latest"
                }
            }
        }
        
        stage('Publish Image to Docker Hub') {
            agent any
            steps {
                echo 'Logging in to Docker Hub and pushing images...'
                withCredentials([usernamePassword(credentialsId: "${DOCKERHUB_CREDENTIALS_ID}", passwordVariable: 'PASS', usernameVariable: 'USER')]) {
                    // Log in using credentials saved in Jenkins
                    sh "echo \$PASS | docker login -u \$USER --password-stdin"
                    
                    // Push the tags
                    sh "docker push ${FULL_IMAGE_NAME}:latest"
                    sh "docker push ${FULL_IMAGE_NAME}:${env.BUILD_NUMBER}"
                }
            }
        }
        
        stage('Deploy Application') {
            agent any
            steps {
                echo 'Deploying application container using Docker Compose...'
                // Use the updated docker-compose.yml to pull and run the latest pushed image
                sh 'docker-compose up -d'
            }
        }
    }

    post {
        always {
            // Clean up the workspace
            cleanWs()
        }
        success {
            echo 'SUCCESS! CI/CD Pipeline finished. New image available on Docker Hub.'
        }
        failure {
            echo 'FAILURE! Check console output. Failed at security, test, or build stage.'
        }
    }
}
