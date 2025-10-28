pipeline {
    agent any // Run all stages on the Jenkins host VM, which has access to the Docker socket

    environment {
        // --- Configuration Variables ---
        DOCKERHUB_USERNAME = 'yassineokr'
        IMAGE_BASE_NAME = 'arithmetic-api'
        FULL_IMAGE_NAME = "${DOCKERHUB_USERNAME}/${IMAGE_BASE_NAME}"
        DOCKERHUB_CREDENTIALS_ID = 'docker-hub-credentials'
        APP_DIR = 'api' 
        
        // Define the non-standard install path for pip tools
        JENKINS_LOCAL_BIN = '/var/lib/jenkins/.local/bin' 
        
        // Update PATH to include the local bin directory where pip installs executables
        PATH = "${JENKINS_LOCAL_BIN}:${env.PATH}"
    }

    stages {
        stage('Checkout Code') {
            steps {
                echo 'Checking out code from GitHub...'
                checkout scm
            }
        }
        
        // This stage now relies entirely on the host VM's PATH being fixed
        stage('Security, Tests & Build') {
            steps {
                script {
                    echo 'Installing required Python tools globally (fixing PATH issue)...'
                    // The --break-system-packages flag forces installation on Kali/Debian host
                    sh "pip install --break-system-packages -r ${APP_DIR}/requirements.txt bandit safety pytest"
                    
                    // --- SAST (Bandit) ---
                    echo 'Running Bandit SAST scan...'
                    // We must use the executable found in the custom PATH
                    sh "bandit -r ${APP_DIR} -ll -x ${APP_DIR}/test_app.py || true"

                    // --- SCA (Safety) ---
                    echo 'Running Safety SCA check...'
                    sh "safety check -r ${APP_DIR}/requirements.txt || true"

                    // --- Unit Tests (Pytest) ---
                    echo 'Running Pytest unit tests...'
                    sh "pytest ${APP_DIR}"
                    
                    // --- Build & Trivy Scan ---
                    echo 'Building Docker image and tagging for Trivy scan...'
                    // Fix: Use the Dockerfile from the root context '.'
                    sh "docker build -t ${FULL_IMAGE_NAME}:${env.BUILD_NUMBER} -f Dockerfile ."
                    
                    echo 'Scanning image with Trivy (Failing on HIGH or CRITICAL issues)...'
                    // Trivy is assumed to be installed on the host VM and in the PATH
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
            // Cleanup Docker containers/images
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
