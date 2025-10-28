pipeline {
    // Define a single Docker agent for the entire pipeline
    agent {
        docker {
            image 'python:3.9-alpine' // Use Alpine Python as the base
            // Mount Docker socket, workspace, run as root for permissions
            // Running as root simplifies apk add and Docker socket access (ensure host socket permissions are correct - chmod 666)
            args '-v /var/run/docker.sock:/var/run/docker.sock -v ${workspace}:/workspace -w /workspace -u root' 
            // Use custom workspace to ensure consistency
            customWorkspace '/workspace'
        }
    }

    environment {
        // --- Configuration Variables ---
        DOCKERHUB_USERNAME = 'yassineokr'
        IMAGE_BASE_NAME = 'arithmetic-api'
        FULL_IMAGE_NAME = "${DOCKERHUB_USERNAME}/${IMAGE_BASE_NAME}"
        DOCKERHUB_CREDENTIALS_ID = 'docker-hub-credentials'
        APP_DIR = 'api' // Subdirectory where your code resides

        // Set PATH to include tools installed locally
        PATH = "/usr/local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
    }

    stages {
        stage('Setup Tools') {
            steps {
                echo 'Installing required tools (Docker CLI, Compose, Trivy, Python tools)...'
                // Install necessary packages inside the Alpine agent
                sh 'apk update && apk add --no-cache docker-cli docker-compose bash git wget tar gzip'
                
                // Install Trivy binary (Replace with latest version if needed)
                sh 'wget https://github.com/aquasecurity/trivy/releases/download/v0.52.2/trivy_0.52.2_Linux-64bit.tar.gz' 
                sh 'tar zxvf trivy_0.52.2_Linux-64bit.tar.gz'
                sh 'mv trivy /usr/local/bin/'
                sh 'rm trivy_0.52.2_Linux-64bit.tar.gz LICENSE README.md' // Clean up downloaded files
                
                // Install Python dependencies and security tools
                sh 'pip install --upgrade pip'
                sh "pip install -r ${APP_DIR}/requirements.txt bandit safety pytest gunicorn" 
            }
        }

        stage('Checkout Code') {
            steps {
                echo 'Checking out code from GitHub...'
                // Git command is now available inside the agent
                checkout scm 
            }
        }

        stage('Security & Tests') {
            steps {
                script {
                    // All tools are installed globally in the agent's environment
                    echo 'Running Bandit SAST scan...'
                    sh "bandit -r ${APP_DIR} -ll -x ${APP_DIR}/test_app.py || true"

                    echo 'Running Safety SCA check...'
                    sh "safety check -r ${APP_DIR}/requirements.txt || true"

                    echo 'Running Pytest unit tests...'
                    sh "pytest ${APP_DIR}"
                }
            }
        }
        
        stage('Build & Image Scan (Trivy)') {
            steps {
                script {
                    echo 'Building Docker image and tagging for Trivy scan...'
                    // Docker CLI is now available inside the agent
                    sh "docker build -t ${FULL_IMAGE_NAME}:${env.BUILD_NUMBER} -f ${APP_DIR}/Dockerfile ${APP_DIR}"

                    echo 'Scanning image with Trivy (Failing on HIGH or CRITICAL issues)...'
                    // Trivy CLI is now available inside the agent
                    sh "trivy image --exit-code 1 --severity HIGH,CRITICAL ${FULL_IMAGE_NAME}:${env.BUILD_NUMBER}"
                    
                    echo 'Tagging image as latest...'
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
                // Docker Compose is now available inside the agent
                sh 'docker-compose up -d'
            }
        }
    }

    post {
        always {
            echo 'Cleaning up workspace...'
            cleanWs()
            // Optional: Cleanup Docker artifacts (run inside the agent)
            // sh 'docker system prune -f || true' 
        }
        success {
            echo 'SUCCESS! CI/CD Pipeline finished. New image available on Docker Hub and deployed.'
        }
        failure {
            echo 'FAILURE! Review the console output for security, test, or build stage failures.'
        }
    }
}
