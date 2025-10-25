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
            // Use 'agent any' to define the workspace context needed by later stages
            agent any 
            steps {
                echo 'Checking out code from GitHub...'
                checkout scm
            }
        }

        stage('Security & Tests') {
            // Run tests and security scans inside a Python container agent
            agent {
                docker {
                    image PYTHON_AGENT_IMAGE
                    // Mounting the workspace is crucial for the container to access checked-out files
                    args "-v ${workspace}:/home/jenkins/workspace -w /home/jenkins/workspace/${JOB_NAME}"
                }
            }
            steps {
                script {
                    echo 'Installing dependencies and security tools inside Python agent...'
                    // Install all required tools globally inside the temporary Python container
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
                    
                    // 1. Build the Docker image, tagging it with the unique build number
                    sh "docker build -t ${FULL_IMAGE_NAME}:${env.BUILD_NUMBER} -f ${APP_DIR}/Dockerfile ${APP_DIR}"

                    // 2. Scan the built image using Trivy
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
                // This relies on docker-compose.yml pointing to the correct image name
                sh 'docker-compose up -d'
            }
        }
    }

    post {
        always {
            // The workspace is needed for cleanup, so agent any is implied or required
            agent any 
            // Clean up the workspace
            cleanWs()
            // Cleanup Docker artifacts
            sh 'docker system prune -f || true' 
            // Note: If you don't have 'docker' installed on the host, this command will still fail silently due to '|| true'.
        }
        success {
            echo 'SUCCESS! CI/CD Pipeline finished. New image available on Docker Hub and deployed.'
        }
        failure {
            echo 'FAILURE! Review the console output for security, test, or build stage failures.'
        }
    }
}
