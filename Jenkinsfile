pipeline {
    agent any // Run all stages on the Jenkins host VM, which has access to the Docker socket

    environment {
        // --- Configuration Variables ---
        DOCKERHUB_USERNAME = 'yassineokr'
        IMAGE_BASE_NAME = 'arithmetic-api'
        FULL_IMAGE_NAME = "${DOCKERHUB_USERNAME}/${IMAGE_BASE_NAME}"
        DOCKERHUB_CREDENTIALS_ID = 'docker-hub-credentials'
        APP_DIR = 'api'
    }

    stages {
        stage('Checkout Code') {
            steps {
                echo 'Checking out code from GitHub...'
                checkout scm
            }
        }
        
        // COMBINED STAGE: Relying on the host VM to have Python tools installed
        stage('Security, Tests & Build') {
            steps {
                script {
                    echo 'Installing required Python tools globally (assuming host environment)...'
                    // Rely on host's Python or ensure these packages are installed globally on the VM
                    sh "pip install --break-system-packages -r ${APP_DIR}/requirements.txt bandit safety pytest"
                    
                    // --- SAST (Bandit) ---
                    echo 'Running Bandit SAST scan...'
                    sh "bandit -r ${APP_DIR} -ll -x ${APP_DIR}/test_app.py || true"

                    // --- SCA (Safety) ---
                    echo 'Running Safety SCA check...'
                    sh "safety check -r ${APP_DIR}/requirements.txt || true"

                    // --- Unit Tests (Pytest) ---
                    echo 'Running Pytest unit tests...'
                    sh "pytest ${APP_DIR}"
                    
                    // --- Build & Trivy Scan ---
                    echo 'Building Docker image and tagging for Trivy scan...'
                    sh "docker build -t ${FULL_IMAGE_NAME}:${env.BUILD_NUMBER} -f ${APP_DIR}/Dockerfile ${APP_DIR}"
                    
                    echo 'Scanning image with Trivy (Failing on HIGH or CRITICAL issues)...'
                    sh "trivy image --exit-code 1 --severity HIGH,CRITICAL ${FULL_IMAGE_NAME}:${env.BUILD_NUMBER}"
                    
                    sh "docker tag ${FULL_IMAGE_NAME}:${env.BUILD_NUMBER} ${FULL_IMAGE_NAME}:latest"
                }
            }
        }
        
        stage('Publish Image to Docker Hub') {
            steps {
                echo 'Logging in to Docker Hub and pushing images...'
                withCredentials([usernamePassword(credentialsId: "${DOCKERHUB_CREDENTIALS_ID}", passwordVariable: 'PASS', usernameVariable: 'USER')]) {
                    sh "echo \$PASS | docker login -u \$USER --password-stdin"
                    sh "docker push ${FULL_IMAGE_NAME}:latest"
                    sh "docker push ${FULL_IMAGE_NAME}:${env.BUILD_NUMBER}"
                }
            }
        }
        
        stage('Deploy Application') {
            steps {
                echo 'Deploying application container using Docker Compose...'
                sh 'docker-compose up -d'
            }
        }
    }

    post {
        always {
            cleanWs()
        }
        success {
            echo 'SUCCESS! CI/CD Pipeline finished. New image available on Docker Hub and deployed.'
        }
        failure {
            echo 'FAILURE! Review the console output for security, test, or build stage failures.'
        }
    }
}
