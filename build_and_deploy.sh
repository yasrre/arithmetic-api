#!/bin/bash

# Configuration
REPO_PATH="./" 
DOCKER_IMAGE_NAME="arithmetic-api" 
DOCKERHUB_USERNAME="yassineokr" 
DOCKERHUB_REPO_NAME="arithmetic-api" 
CONTAINER_NAME="arithmetic_api_container" 
PORT=5000 
LAST_COMMIT_HASH="" 

echo "Starting continuous integration and deployment script..."

# Function to build and deploy Docker image
build_and_deploy() {
    echo "Changes detected or new commit pushed. Building Docker image..."

    # Stop and remove existing container if running
    if docker ps -a --format '{{.Names}}' | grep -q "$CONTAINER_NAME"; then
        echo "Stopping and removing existing container: $CONTAINER_NAME"
        docker stop "$CONTAINER_NAME"
        docker rm "$CONTAINER_NAME"
    fi

    # Build the Docker image
    docker build -t "$DOCKER_IMAGE_NAME" .

    if [ $? -eq 0 ]; then
        echo "Docker image '$DOCKER_IMAGE_NAME' built successfully."

        # Run the new container
        echo "Deploying new container..."
        docker run -d --name "$CONTAINER_NAME" -p "$PORT:$PORT" "$DOCKER_IMAGE_NAME"

        if [ $? -eq 0 ]; then
            echo "Container '$CONTAINER_NAME' deployed successfully and listening on port $PORT."
            echo "API should be accessible at http://localhost:$PORT"
        else
            echo "Error: Failed to deploy container."
        fi
    else
        echo "Error: Docker image build failed."
    fi
}

# Function to commit and push to Docker Hub
push_to_docker_hub() {
    echo "Pushing image to Docker Hub..."

    # Get the current commit hash for tagging
    CURRENT_COMMIT_TAG=$(git rev-parse --short HEAD)
    DOCKERHUB_FULL_TAG="$DOCKERHUB_USERNAME/$DOCKERHUB_REPO_NAME:$CURRENT_COMMIT_TAG"
    LATEST_TAG="$DOCKERHUB_USERNAME/$DOCKERHUB_REPO_NAME:latest"

    # Tag the built image
    docker tag "$DOCKER_IMAGE_NAME" "$DOCKERHUB_FULL_TAG"
    docker tag "$DOCKER_IMAGE_NAME" "$LATEST_TAG"

    echo "Tagged image as $DOCKERHUB_FULL_TAG and $LATEST_TAG"

    # Log in to Docker Hub (if not already logged in)
    # It's recommended to do `docker login` manually once before running the script
    # or pass credentials as environment variables in a more secure setup.
    # docker login -u "$DOCKERHUB_USERNAME" -p "$DOCKERHUB_PASSWORD" # Use with caution for CI/CD

    # Push the tagged images
    docker push "$DOCKERHUB_FULL_TAG"
    docker push "$LATEST_TAG"

    if [ $? -eq 0 ]; then
        echo "Successfully pushed images to Docker Hub: $DOCKERHUB_FULL_TAG, $LATEST_TAG"
    else
        echo "Error: Failed to push images to Docker Hub."
    fi
}

# Initial build and deploy
echo "Performing initial build and deploy..."
build_and_deploy
push_to_docker_hub
LAST_COMMIT_HASH=$(git rev-parse HEAD)
echo "Initial setup complete. Last processed commit: $LAST_COMMIT_HASH"

# Main monitoring loop
while true; do
    echo "Monitoring Git repository for new commits (current: $LAST_COMMIT_HASH)..."
    git fetch origin # Fetch latest changes from the remote repository
    CURRENT_COMMIT_HASH=$(git rev-parse HEAD)
    LATEST_REMOTE_COMMIT_HASH=$(git rev-parse origin/master) # Assuming 'master' branch

    if [ "$CURRENT_COMMIT_HASH" != "$LAST_COMMIT_HASH" ] || [ "$LATEST_REMOTE_COMMIT_HASH" != "$LAST_COMMIT_HASH" ]; then
        echo "New commit detected!"
        # Pull latest changes if they are not already in your local HEAD
        git pull origin master # Adjust branch if needed

        build_and_deploy
        push_to_docker_hub
        LAST_COMMIT_HASH=$(git rev-parse HEAD)
        echo "Updated. New last processed commit: $LAST_COMMIT_HASH"
    else
        echo "No new commits. Waiting..."
    fi

    sleep 10 # Check every 10 seconds
done