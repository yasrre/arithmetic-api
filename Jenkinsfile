pipeline {
    // Agent none requires explicit agent definition in all stages that run shell commands
    agent none 

    environment {
        // --- Configuration Variables ---
        DOCKERHUB_USERNAME = 'yassineokr'
        IMAGE_BASE_NAME = 'arithmetic-api'
        FULL_IMAGE_NAME = "${DOCKERHUB_USERNAME}/${IMAGE_BASE_NAME}"
        DOCKERHUB_CREDENTIALS_ID = 'docker-hub-credentials'
        APP_DIR = 'api' // Subdirectory where your code resides
        PYTHON_AGENT_IMAGE = 'python:3.9-alpine' 
    }

    stages {
        stage('Checkout Code') {
            // This stage MUST define the workspace context by using a valid agent
            agent any 
            steps {
                echo 'Checking out code from GitHub...'
                checkout scm
            }
        }

        stage('Security & Tests') {
            // Run tests and security scans inside a Python container agent
            // The Docker Pipeline plugin will now handle workspace mapping automatically
            agent {
                docker {
                    image PYTHON_AGENT_IMAGE
                    // NOTE: The 'args' line that used ${workspace} has been removed.
                }
            }
            steps {
                script {
                    echo 'Installing dependencies and security tools inside Python agent...'
                    // The paths are relative to the workspace, which is automatically mapped inside the Docker container
                    sh "pip install -r ${APP_DIR}/requirements.txt bandit safety pytest"

                    // --- SAST (Bandit) ---
                    echo 'Running Bandit SAST scan...'
                    sh "bandit -r ${APP_DIR} -ll -x ${APP_DIR}/test_app.py || true"

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
            // Run on the standard Jenkins agent, relying on host Docker/Trivy CLI access
            agent any 
            steps {
                script {
                    echo 'Building Docker image and tagging for Trivy scan...'
                    
                    // Build the Docker image, tagging it with the unique build number
                    sh "docker build -t ${FULL_IMAGE_NAME}:${env.BUILD_NUMBER} -f ${APP_DIR}/Dockerfile ${APP_DIR}"

                    // Scan the built image using Trivy
                    echo 'Scanning image with Trivy (Failing on HIGH or CRITICAL issues)...'
                    sh "trivy image --exit-code 1 --severity HIGH,CRITICAL ${FULL_IMAGE_NAME}:${env.BUILD_NUMBER}"
                    
                    // Tag the image as 'latest'
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
                // This relies on docker-compose.yml pointing to the correct image name
                sh 'docker-compose up -d'
            }
        }
    }

    post {
        always {
            // cleanWs is the only step in post that requires a node context.
            cleanWs()
            // Cleanup Docker artifacts
            sh 'docker system prune -f || true' 
        }
        success {
            echo 'SUCCESS! CI/CD Pipeline finished. New image available on Docker Hub and deployed.'
        }
        failure {
            echo 'FAILURE! Review the console output for security, test, or build stage failures.'
        }
    }
}
