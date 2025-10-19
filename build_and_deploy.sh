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
