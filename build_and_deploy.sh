#!/bin/bash

# --- Configuration ---
# Replace YOUR_DOCKERHUB_USERNAME with your actual Docker Hub username
DOCKERHUB_USERNAME="yassineokr" # <--- ENSURE THIS IS "yassineokr"
IMAGE_NAME="arithmetic-api" # Local image name
FULL_IMAGE_NAME="$DOCKERHUB_USERNAME/$IMAGE_NAME" # For Docker Hub: e.g., yassineokr/arithmetic-api
CONTAINER_NAME="arithmetic-api-container"
GIT_REPO_DIR="." # Monitor the current directory (project_root) for Git changes
POLL_INTERVAL=10 # Check for new commits every 10 seconds

# --- Script Logic ---
echo "Starting continuous deployment script..."
echo "Monitoring Git repository in: $GIT_REPO_DIR"

# Ensure Git is in a clean state and fetch latest info
git fetch origin > /dev/null 2>&1

# Get the last commit hash that was processed
LAST_PROCESSED_COMMIT=$(git rev-parse HEAD)
echo "Initial local commit hash: $LAST_PROCESSED_COMMIT"

# Function to perform build, deploy, and push to Docker Hub
deploy_and_push() {
    echo "---------------------------------------------------------"
    echo "New commit detected or forced rebuild at $(date)"

    echo "Stopping and removing existing container (if any)..."
    docker stop "$CONTAINER_NAME" > /dev/null 2>&1
    docker rm "$CONTAINER_NAME" > /dev/null 2>&1

    echo "Building new Docker image: $FULL_IMAGE_NAME..."
    # Tag with 'latest' and also with the commit hash for versioning
    COMMIT_HASH=$(git rev-parse --short HEAD) # Get the short hash of the current HEAD commit
    docker build -t "$FULL_IMAGE_NAME:latest" -t "$FULL_IMAGE_NAME:$COMMIT_HASH" .

    if [ $? -eq 0 ]; then
        echo "Docker image built successfully: $FULL_IMAGE_NAME:latest (and $FULL_IMAGE_NAME:$COMMIT_HASH)"
        echo "Deploying new container..."
        docker run -d --name "$CONTAINER_NAME" -p 5000:5000 "$FULL_IMAGE_NAME:latest"
        if [ $? -eq 0 ]; then
            echo "Container deployed and running on port 5000."
            echo "Access API at http://localhost:5000"

            # --- Docker Hub Push ---
            echo "Attempting to push image to Docker Hub..."
            # Assumes you've already logged in once with `docker login`
            # The `docker info` command with `grep Username` checks if a login session is active
            if docker info 2>&1 | grep -q "Username: $DOCKERHUB_USERNAME"; then
                echo "Successfully logged in to Docker Hub as $DOCKERHUB_USERNAME."
                echo "Pushing image to Docker Hub: $FULL_IMAGE_NAME:latest"
                docker push "$FULL_IMAGE_NAME:latest"
                if [ $? -eq 0 ]; then
                    echo "Pushed $FULL_IMAGE_NAME:latest successfully."
                else
                    echo "Failed to push $FULL_IMAGE_NAME:latest."
                fi

                echo "Pushing image to Docker Hub: $FULL_IMAGE_NAME:$COMMIT_HASH"
                docker push "$FULL_IMAGE_NAME:$COMMIT_HASH"
                 if [ $? -eq 0 ]; then
                    echo "Pushed $FULL_IMAGE_NAME:$COMMIT_HASH successfully."
                else
                    echo "Failed to push $FULL_IMAGE_NAME:$COMMIT_HASH."
                fi
            else
                echo "Not logged into Docker Hub as $DOCKERHUB_USERNAME. Please run 'docker login' manually and provide your Docker Hub credentials."
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

# --- Main Loop ---
while true; do
    # Fetch the latest changes from the remote repository without merging
    git fetch origin > /dev/null 2>&1

    # Get the current latest commit hash from the remote tracking branch
    # `@{u}` refers to the upstream branch (e.g., origin/main)
    LATEST_REMOTE_COMMIT=$(git rev-parse @{u})

    if [ "$LATEST_REMOTE_COMMIT" != "$LAST_PROCESSED_COMMIT" ]; then
        echo "New commit detected on remote repository ($LAST_PROCESSED_COMMIT -> $LATEST_REMOTE_COMMIT)!"
        
        # Pull the changes to the local repository. Use --ff-only to ensure a fast-forward merge if possible.
        # If there are local commits that diverge, you might need 'git pull --rebase' here,
        # but for a CI/CD script that primarily pushes from one source, --ff-only is safer.
        git pull --ff-only origin "$(git rev-parse --abbrev-ref --symbolic-full-name @{u} | sed 's/origin\///')" > /dev/null 2>&1
        
        if [ $? -eq 0 ]; then
            LAST_PROCESSED_COMMIT="$LATEST_REMOTE_COMMIT"
            deploy_and_push # Trigger build, deploy, and push
        else
            echo "Error: Failed to fast-forward pull from remote. Local changes might be divergent. Please resolve manually or consider 'git pull --rebase'."
            # To prevent continuous errors, we might want to sleep longer or exit here in a real CI/CD
        fi
    else
        echo "No new commits on remote. Waiting..."
    fi

    sleep "$POLL_INTERVAL"
done
