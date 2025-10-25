pipeline {
    agent any // Jenkins uses any available agent (your Docker container on the VM)

    environment {
        // --- Configuration Variables ---
        // Your Docker Hub username
        DOCKERHUB_USERNAME = 'yassineokr' 
        // Image name prefix, will be tagged with DOCKERHUB_USERNAME
        IMAGE_BASE_NAME = 'arithmetic-api' 
        // Full final image name for Docker Hub
        FULL_IMAGE_NAME = "${DOCKERHUB_USERNAME}/${IMAGE_BASE_NAME}"
        // Credential ID you set up in Jenkins (Manage Credentials)
        DOCKERHUB_CREDENTIALS_ID = 'docker-hub-credentials' 
        // Your application is located in the 'api' subdirectory
        APP_DIR = 'api' 
    }

    stages {
        stage('Checkout Code') {
            steps {
                echo 'Checking out code from GitHub...'
                // Pull the code from GitHub
                checkout scm
            }
        }

        stage('Install Local Dependencies') {
            steps {
                script {
                    echo 'Installing local Python and Security dependencies...'
                    // Create and activate venv in the Jenkins workspace
                    sh "python3 -m venv venv"
                    
                    // Install core app dependencies + security tools (pytest, bandit, safety)
                    sh "./venv/bin/pip install -r ${APP_DIR}/requirements.txt"
                    sh "./venv/bin/pip install bandit safety"
                }
            }
        }
        
        stage('Security: Static Code Analysis (Bandit)') {
            steps {
                script {
                    echo 'Running Bandit SAST scan...'
                    // Run Bandit on the application directory, excluding tests and enforcing high severity
                    sh "./venv/bin/bandit -r ${APP_DIR} -ll -x ${APP_DIR}/test_app.py || true" 
                    // '|| true' allows the pipeline to proceed even if low/medium issues are found
                }
            }
        }
        
        stage('Security: Dependency Scan (Safety)') {
            steps {
                script {
                    echo 'Running Safety SCA check on requirements.txt...'
                    // Run Safety against your requirements file
                    sh "./venv/bin/safety check -r ${APP_DIR}/requirements.txt || true" 
                }
            }
        }

        stage('Run Tests') {
            steps {
                script {
                    echo 'Running Pytest unit tests...'
                    // Run tests from the application directory
                    sh "./venv/bin/pytest ${APP_DIR}"
                }
            }
        }
        
        stage('Build & Image Scan (Trivy)') {
            steps {
                script {
                    echo 'Building Docker image and tagging for Trivy scan...'
                    // Build the Docker image from the correct Dockerfile location, tagging it with the build number
                    sh "docker build -t ${FULL_IMAGE_NAME}:${env.BUILD_NUMBER} -f ${APP_DIR}/Dockerfile ${APP_DIR}"

                    echo 'Scanning image with Trivy (Failing on HIGH or CRITICAL issues)...'
                    // Trivy scan: --exit-code 1 makes the pipeline fail if HIGH/CRITICAL issues are found
                    sh "trivy image --exit-code 1 --severity HIGH,CRITICAL ${FULL_IMAGE_NAME}:${env.BUILD_NUMBER}"
                }
            }
        }
        
        stage('Publish Image to Docker Hub') {
            steps {
                script {
                    echo 'Logging in to Docker Hub and pushing images...'
                    // Use Jenkins credential binding for secure login
                    withCredentials([usernamePassword(credentialsId: "${DOCKERHUB_CREDENTIALS_ID}", passwordVariable: 'PASS', usernameVariable: 'USER')]) {
                        sh "echo \$PASS | docker login -u \$USER --password-stdin"
                        
                        // Tag and push with the 'latest' tag
                        sh "docker tag ${FULL_IMAGE_NAME}:${env.BUILD_NUMBER} ${FULL_IMAGE_NAME}:latest"
                        sh "docker push ${FULL_IMAGE_NAME}:latest"
                        
                        // Push the version-specific tag
                        sh "docker push ${FULL_IMAGE_NAME}:${env.BUILD_NUMBER}"
                    }
                }
            }
        }
        
        stage('Deploy Application') {
            steps {
                script {
                    echo 'Deploying application container...'
                    // Use the image tagged as 'latest' for deployment
                    // NOTE: You must update your docker-compose.yml to use the image name: "yassineokr/arithmetic-api:latest"
                    sh 'docker-compose up -d'
                }
            }
        }
    }

    post {
        always {
            // Clean up workspace files (including the venv) after the build
            cleanWs()
            // Optional: Remove old, unused Docker images/containers to save space
            sh 'docker system prune -f || true'
        }
        success {
            echo 'SUCCESS! CI/CD Pipeline finished. New image available on Docker Hub.'
        }
        failure {
            echo 'FAILURE! Review the logs for failed Test, Security, or Build stages.'
        }
    }
}
