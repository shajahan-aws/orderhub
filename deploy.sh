#!/bin/bash
set -e

IMAGE=$1
PREV_IMAGE=$2
CONTAINER_NAME="orderhub"
PORT=8080

if [ -z "$IMAGE" ]; then
    echo "ERROR: Target Docker image not provided!"
    exit 1
fi

echo "=========================================="
echo "Starting Deployment for Image: $IMAGE"
echo "=========================================="

# Function to verify container health
check_health() {
    local retries=5
    local wait_seconds=3
    for i in $(seq 1 $retries); do
        echo "Health check attempt $i/$retries..."
        if curl -s http://localhost:$PORT/health | grep -q '"status":"UP"'; then
            return 0
        fi
        sleep $wait_seconds
    done
    return 1
}

# 1. Pull Target Image
echo "Step 1: Pulling Image $IMAGE..."
docker pull "$IMAGE" || true

# 2. Backup & Stop Existing Container
if docker ps -a --format '{{.Names}}' | grep -Eq "^${CONTAINER_NAME}$"; then
    echo "Step 2: Stopping existing container $CONTAINER_NAME..."
    docker stop "$CONTAINER_NAME" || true
    docker rm "$CONTAINER_NAME" || true
fi

# 3. Start New Container
echo "Step 3: Starting container $CONTAINER_NAME..."
docker run -d \
    --name "$CONTAINER_NAME" \
    -p $PORT:$PORT \
    --health-cmd="python -c \"import urllib.request; urllib.request.urlopen('http://127.0.0.1:8080/health')\"" \
    --health-interval=5s \
    "$IMAGE"

# 4. Perform Health Check & Automatic Rollback Logic
echo "Step 4: Verifying Deployment Health..."
if check_health; then
    echo "SUCCESS: Container is UP and Healthy!"
    echo "Executing Smoke Test..."
    curl -s http://localhost:$PORT/version
    echo ""
    echo "Deployment Finished Successfully!"
else
    echo "CRITICAL WARNING: Health check failed for $IMAGE!"
    
    if [ -n "$PREV_IMAGE" ]; then
        echo "Initiating Automatic Rollback to Previous Stable Image: $PREV_IMAGE..."
        docker stop "$CONTAINER_NAME" || true
        docker rm "$CONTAINER_NAME" || true
        
        docker run -d \
            --name "$CONTAINER_NAME" \
            -p $PORT:$PORT \
            "$PREV_IMAGE"
        
        if check_health; then
            echo "ROLLBACK SUCCESSFUL: Restored Production to $PREV_IMAGE"
            exit 2 # Unique exit status indicating deployment failed but rollback succeeded
        else
            echo "FATAL: Rollback to $PREV_IMAGE also failed!"
            exit 1
        fi
    else
        echo "ERROR: No previous image specified for rollback."
        exit 1
    fi
fi