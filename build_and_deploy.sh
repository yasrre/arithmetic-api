#!/bin/bash

# --- Configuration ---
# Replace YOUR_DOCKERHUB_USERNAME with your actual Docker Hub username
DOCKERHUB_USERNAME="yassineokr" # <--- This is what you correctly set
IMAGE_NAME="arithmetic-api" # Local image name
FULL_IMAGE_NAME="$DOCKERHUB_USERNAME/$IMAGE_NAME" # For Docker Hub
CONTAINER_NAME="arithmetic-api-container"
GIT_REPO_DIR="." # Monitor the current directory (project_root) for Git changes
POLL_INTERVAL=10 # Check every 10 seconds

# --- Script Logic ---
echo "Starting continuous deployment script..."
echo "Monitoring Git repository in: $GIT_REPO_DIR"

# Ensure Git is in a clean state and fetch latest info
# The `git fetch` command is now outside the loop to get the initial upstream state.
# It's okay if it fails for the very first run if there's no upstream yet, the loop will handle it.
git fetch origin > /dev/null 2>&1 || true

# Get the last commit hash that was processed
# This tries to get the commit hash of the upstream branch (origin/main)
# If it fails (e.g., no upstream yet), it defaults to the local HEAD.
LAST_PROCESSED_COMMIT=$(git rev-parse @{u} 2>/dev/null || git rev-parse HEAD)
echo "Initial local commit hash: $LAST_PROCESSED_COMMIT"

# Function to perform build, deploy, and push to Docker Hub
deploy_and_push() {
    echo "---------------------------------------------------------"
    echo "New commit detected or forced rebuild at $(date)"

    echo "Stopping and removing existing container (if any)..."
    # Use -f to force stop/remove if needed
    docker stop "$CONTAINER_NAME" > /dev/null 2>&1 || true
    docker rm "$CONTAINER_NAME" > /dev/null 2>&1 || true

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
            echo "Attempting to push image to Docker Hub..."
            # Check if logged in. If not, this might prompt or fail depending on Docker config.
            # It's better to ensure 'docker login' is done manually once before running this script.
            if docker info > /dev/null 2>&1 && docker login --username "$DOCKERHUB_USERNAME" > /dev/null 2>&1; then # Check if already logged in or login successful
                echo "Successfully logged in to Docker Hub as $DOCKERHUB_USERNAME."
                echo "Pushing image to Docker Hub: $FULL_IMAGE_NAME:latest"
                docker push "$FULL_IMAGE_NAME:latest"
                if [ $? -eq 0 ]; then
                    echo "Pushed $FULL_IMAGE_NAME:latest successfully."
                else
                    echo "Failed to push $FULL_IMAGE_NAME:latest to Docker Hub."
                fi

                echo "Pushing image to Docker Hub: $FULL_IMAGE_NAME:$COMMIT_HASH"
                docker push "$FULL_IMAGE_NAME:$COMMIT_HASH"
                if [ $? -eq 0 ]; then
                    echo "Pushed $FULL_IMAGE_NAME:$COMMIT_HASH successfully."
                else
                    echo "Failed to push $FULL_IMAGE_NAME:$COMMIT_HASH to Docker Hub."
                fi
            else
                echo "Not logged into Docker Hub or login failed. Please run 'docker login' manually before starting the script."
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
    # Fetch the latest changes from the remote repository without merging
    git fetch origin > /dev/null 2>&1

    # Get the current latest commit hash from the remote branch
    LATEST_REMOTE_COMMIT=$(git rev-parse @{u} 2>/dev/null) # @{u} refers to the upstream branch (e.g., origin/main)

    # Check if LATEST_REMOTE_COMMIT is empty (e.g., no upstream branch configured yet)
    if [ -z "$LATEST_REMOTE_COMMIT" ]; then
        echo "Warning: Upstream branch not found. Ensure your local branch is tracking a remote branch (e.g., 'git branch --set-upstream-to=origin/main main'). Falling back to local HEAD check."
        LATEST_REMOTE_COMMIT=$(git rev-parse HEAD) # Fallback to local HEAD if no remote upstream
    fi

    # Update LAST_PROCESSED_COMMIT with the current local HEAD before comparison
    # This prevents an immediate rebuild after a pull if local and remote are already aligned
    CURRENT_LOCAL_COMMIT=$(git rev-parse HEAD)

    if [ "$LATEST_REMOTE_COMMIT" != "$CURRENT_LOCAL_COMMIT" ]; then
        echo "New commit detected on remote repository ($CURRENT_LOCAL_COMMIT -> $LATEST_REMOTE_COMMIT)!"
        # Pull the changes to the local repository. Use --ff-only to ensure clean history if possible.
        # If `--ff-only` fails due to divergence, a manual intervention (rebase/merge) might be needed.
        # For a simple CI loop, assuming linear history is common.
        git pull --ff-only origin "$(git rev-parse --abbrev-ref --symbolic-full-name @{u} | sed 's/origin\///')" > /dev/null 2>&1
        if [ $? -ne 0 ]; then
            echo "Warning: 'git pull --ff-only' failed. Remote history has diverged. Manual 'git pull --rebase' or 'git pull' might be needed on this machine."
            # Optionally, you might want to skip deployment here or trigger a notification
        else
            LAST_PROCESSED_COMMIT="$LATEST_REMOTE_COMMIT" # Update processed commit only on successful pull
            deploy_and_push # Trigger build, deploy, and push
        fi
    else
        echo "No new commits on remote. Waiting..."
    fi

    sleep "$POLL_INTERVAL"
done
