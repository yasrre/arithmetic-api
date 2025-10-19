#!/bin/bash

# Configuration
IMAGE_NAME="my-arithmetic-api" 
CONTAINER_NAME="arithmetic-api-container"
API_DIR="./api" 
LAST_CHANGE_TIME=$(find "$API_DIR" -type f -exec stat -c %Y {} + | sort -n | tail -1)

echo "Starting continuous deployment script..."
echo "Monitoring directory: $API_DIR"

while true; do
    CURRENT_CHANGE_TIME=$(find "$API_DIR" -type f -exec stat -c %Y {} + | sort -n | tail -1)

    if [ "$CURRENT_CHANGE_TIME" -gt "$LAST_CHANGE_TIME" ]; then
        echo "---------------------------------------------------------"
        echo "Code change detected in $API_DIR at $(date)"
        LAST_CHANGE_TIME="$CURRENT_CHANGE_TIME"

        echo "Stopping and removing existing container (if any)..."
        docker stop "$CONTAINER_NAME" > /dev/null 2>&1
        docker rm "$CONTAINER_NAME" > /dev/null 2>&1

        echo "Building new Docker image..."
        docker build -t "$IMAGE_NAME" .

        if [ $? -eq 0 ]; then
            echo "Docker image built successfully: $IMAGE_NAME"
            echo "Deploying new container..."
            docker run -d --name "$CONTAINER_NAME" -p 5000:5000 "$IMAGE_NAME"
            if [ $? -eq 0 ]; then
                echo "Container deployed and running on port 5000."
                echo "Access API at http://localhost:5000"
            else
                echo "Failed to deploy container."
            fi
        else
            echo "Failed to build Docker image."
        fi
        echo "---------------------------------------------------------"
    fi
    sleep 5
done


    

    sleep 5 # Check every 5 seconds
done
DOCKERHUB_USERNAME="yassineokr" # Your Docker Hub username
IMAGE_NAME="arithmetic-api" # Local image name
FULL_IMAGE_NAME="$DOCKERHUB_USERNAME/$IMAGE_NAME" # For Docker Hub
CONTAINER_NAME="arithmetic-api-container"
GIT_REPO_DIR="." # Monitor the current directory (project_root) for Git changes
POLL_INTERVAL=10

# --- Script Logic ---
echo "Starting continuous deployment script..."
echo "Monitoring Git repository in: $GIT_REPO_DIR"

# Ensure Git is in a clean state and fetch latest info
git fetch origin > /dev/null 2>&1

# Get the last commit hash that was processed
LAST_PROCESSED_COMMIT=$(git rev-parse HEAD)
echo "Initial commit hash: $LAST_PROCESSED_COMMIT"

# Function to perform build, deploy, and push to Docker Hub
deploy_and_push() {
    echo "---------------------------------------------------------"
    echo "New commit detected or forced rebuild at $(date)"

    echo "Stopping and removing existing container (if any)..."
    docker stop "$CONTAINER_NAME" > /dev/null 2>&1
    docker rm "$CONTAINER_NAME" > /dev/null 2>&1

    echo "Building new Docker image: $FULL_IMAGE_NAME..."
    # Tag with 'latest' and also with the commit hash for versioning
    COMMIT_HASH=$(git rev-parse --short HEAD)
    docker build -t "$FULL_IMAGE_NAME:latest" -t "$FULL_IMAGE_NAME:$COMMIT_HASH" .

    if [ $? -eq 0 ]; then
        echo "Docker image built successfully: $FULL_IMAGE_NAME:latest (and $FULL_IMAGE_NAME:$COMMIT_HASH)"
        echo "Deploying new container..."
        docker run -d --name "$CONTAINER_NAME" -p 5000:5000 "$FULL_IMAGE_NAME:latest"
        if [ $? -eq 0 ]; then
            echo "Container deployed and running on port 5000."
            echo "Access API at http://localhost:5000"

            # --- Docker Hub Push ---
            echo "Logging into Docker Hub..."
            # Assumes you've already logged in once with `docker login`
            # or you can add `echo "your_password" | docker login --username your_username --password-stdin`
            # but it's not recommended to hardcode passwords in scripts.

            if docker info > /dev/null 2>&1; then # Check if already logged in or login successful
                echo "Pushing image to Docker Hub: $FULL_IMAGE_NAME:latest"
                docker push "$FULL_IMAGE_NAME:latest"
                docker push "$FULL_IMAGE_NAME:$COMMIT_HASH"
                if [ $? -eq 0 ]; then
                    echo "Image pushed successfully to Docker Hub."
                else
                    echo "Failed to push image to Docker Hub."
                fi
            else
                echo "Not logged into Docker Hub. Please run 'docker login' manually."
            fi
            # --- End Docker Hub Push ---

        else
            echo "Failed to deploy container."
        fi
    else
        echo "Failed to build Docker image."
    fi
    echo "---------------------------------------------------------"
}

while true; do
    # Fetch the latest changes from the remote repository
    git fetch origin > /dev/null 2>&1

    # Get the current latest commit hash from the remote branch
    LATEST_REMOTE_COMMIT=$(git rev-parse @{u}) # @{u} refers to the upstream branch (e.g., origin/main)

    if [ "$LATEST_REMOTE_COMMIT" != "$LAST_PROCESSED_COMMIT" ]; then
        echo "New commit detected on remote repository!"
        # Pull the changes to the local repository
        git pull origin "$(git rev-parse --abbrev-ref --symbolic-full-name @{u} | sed 's/origin\///')" > /dev/null 2>&1 # Pull current branch
        LAST_PROCESSED_COMMIT="$LATEST_REMOTE_COMMIT"
        deploy_and_push # Trigger build, deploy, and push
    else
        echo "No new commits. Waiting..."
    fi

    sleep "$POLL_INTERVAL"
done
