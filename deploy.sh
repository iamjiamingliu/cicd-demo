#!/bin/bash

# CI/CD Deployment Script
# Automatically deploys backend to Render FIRST, then frontend to Vercel

set -e  # Exit on error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print colored output
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Banner
echo ""
echo "=========================================="
echo "   CI/CD Deployment Script"
echo "=========================================="
echo ""

# Load environment variables from .env file if it exists
if [ -f ".env" ]; then
    print_info "Loading environment variables from .env file..."
    export $(cat .env | grep -v '^#' | grep -v '^[[:space:]]*$' | xargs)
    print_success "Environment variables loaded from .env"
    echo ""
fi

# Step 1: Detect current branch
print_info "Detecting current git branch..."
BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)

if [ $? -ne 0 ] || [ -z "$BRANCH" ]; then
    print_error "Failed to detect git branch. Are you in a git repository?"
    exit 1
fi

print_success "Current branch: $BRANCH"
echo ""

# Step 2: Check for required CLI tools
print_info "Checking for required CLI tools..."
SKIP_RENDER=false

# Check for Vercel CLI
if ! command -v vercel &> /dev/null; then
    print_error "Vercel CLI not found. Please install it:"
    echo "  npm install -g vercel"
    exit 1
fi
print_success "Vercel CLI found"

# Check for Render CLI (optional now that we use the API)
if ! command -v render &> /dev/null; then
    print_warning "Render CLI not found. Render deployments will use the API only."
else
    print_success "Render CLI found"
fi

echo ""

# Step 3: Check authentication
print_info "Checking authentication..."

# Check Vercel authentication - prioritize local login over token
print_info "Checking Vercel authentication..."

# First check if we're logged in locally
if vercel whoami &> /dev/null; then
    VERCEL_USER=$(vercel whoami 2>/dev/null | head -1)
    print_success "Logged in to Vercel as: $VERCEL_USER"
    print_info "Using local Vercel credentials (not using VERCEL_TOKEN)"
    # Unset VERCEL_TOKEN to force use of local credentials
    unset VERCEL_TOKEN
elif [ -n "$VERCEL_TOKEN" ]; then
    # Try to validate the token
    print_info "Found VERCEL_TOKEN, validating..."
    if vercel whoami --token "$VERCEL_TOKEN" &> /dev/null; then
        VERCEL_USER=$(vercel whoami --token "$VERCEL_TOKEN" 2>/dev/null | head -1)
        print_success "VERCEL_TOKEN is valid for user: $VERCEL_USER"
    else
        print_error "VERCEL_TOKEN is invalid"
        print_info "Please either:"
        echo "  1. Run 'vercel login' to authenticate locally, OR"
        echo "  2. Update VERCEL_TOKEN in .env file with a valid token from:"
        echo "     https://vercel.com/account/tokens"
        exit 1
    fi
else
    print_warning "Not authenticated with Vercel"
    print_info "Please login to Vercel..."
    vercel login

    if ! vercel whoami &> /dev/null; then
        print_error "Failed to authenticate with Vercel"
        exit 1
    fi

    VERCEL_USER=$(vercel whoami 2>/dev/null | head -1)
    print_success "Successfully logged in as: $VERCEL_USER"
fi

# Check Render authentication
if [ "$SKIP_RENDER" = false ]; then
    if [ -z "$RENDER_API_KEY" ]; then
        print_warning "RENDER_API_KEY not found in environment"
        print_info "Please set your Render API key:"
        echo "  export RENDER_API_KEY=your_api_key_here"
        echo ""
        print_info "Get your API key from: https://dashboard.render.com/u/settings#api-keys"
        echo ""
        read -p "Do you want to continue without deploying to Render? (y/n) " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
        SKIP_RENDER=true
    else
        print_success "RENDER_API_KEY found"
    fi
fi

echo ""

# Step 4: Deploy Backend to Render (FIRST, so we can get the URL for frontend)
# Initialize backend URL - will be set from Render deployment or use default
BACKEND_URL=""

# Determine expected backend service name based on branch
case "$BRANCH" in
    prod|production|main)
        EXPECTED_SERVICE_NAME="cicd-demo-backend-prod"
        ;;
    gamma)
        EXPECTED_SERVICE_NAME="cicd-demo-backend-gamma"
        ;;
    beta)
        EXPECTED_SERVICE_NAME="cicd-demo-backend-beta"
        ;;
    *)
        # Sanitize branch name for service name
        SANITIZED_BRANCH=$(echo "$BRANCH" | sed 's/[^a-zA-Z0-9]/-/g' | tr '[:upper:]' '[:lower:]')
        EXPECTED_SERVICE_NAME="cicd-demo-backend-$SANITIZED_BRANCH"
        ;;
esac

# Set default backend URL based on expected service name
DEFAULT_BACKEND_URL="https://${EXPECTED_SERVICE_NAME}.onrender.com"

if [ "$SKIP_RENDER" = false ]; then
    print_info "Deploying backend to Render..."
    cd backend

    if ! command -v jq &> /dev/null; then
        print_error "'jq' is not installed, but is required to use the Render API."
        print_info "Please install it to continue (e.g., 'brew install jq' on macOS)."
        exit 1
    fi

    # Determine service name based on branch
    case "$BRANCH" in
        prod|production|main)
            SERVICE_NAME="cicd-demo-backend-prod"
            ;;
        gamma)
            SERVICE_NAME="cicd-demo-backend-gamma"
            ;;
        beta)
            SERVICE_NAME="cicd-demo-backend-beta"
            ;;
        *)
            # Sanitize branch name for service name (replace special chars with hyphens)
            SANITIZED_BRANCH=$(echo "$BRANCH" | sed 's/[^a-zA-Z0-9]/-/g' | tr '[:upper:]' '[:lower:]')
            SERVICE_NAME="cicd-demo-backend-$SANITIZED_BRANCH"
            ;;
    esac

    print_info "Service name: $SERVICE_NAME"

    RENDER_API_BASE_URL="https://api.render.com/v1"
    SERVICE_JSON=""
    NEXT_CURSOR=""

    print_info "Checking if Render service '$SERVICE_NAME' exists..."
    while true; do
        SERVICE_LIST_URL="${RENDER_API_BASE_URL}/services?limit=100"
        if [ -n "$NEXT_CURSOR" ]; then
            SERVICE_LIST_URL="${SERVICE_LIST_URL}&cursor=${NEXT_CURSOR}"
        fi

        SERVICE_RESPONSE_FILE=$(mktemp)
        SERVICE_HTTP_STATUS=$(curl -sS -H "Authorization: Bearer $RENDER_API_KEY" -o "$SERVICE_RESPONSE_FILE" -w "%{http_code}" "$SERVICE_LIST_URL")
        CURL_EXIT_CODE=$?
        if [ $CURL_EXIT_CODE -ne 0 ]; then
            SERVICE_HTTP_STATUS=0
        fi

        if [ "$SERVICE_HTTP_STATUS" -ne 200 ]; then
            print_error "Failed to query Render services (HTTP $SERVICE_HTTP_STATUS)."
            if [ -s "$SERVICE_RESPONSE_FILE" ]; then
                print_warning "Render API response:"
                sed 's/^/    /' "$SERVICE_RESPONSE_FILE"
            fi
            rm -f "$SERVICE_RESPONSE_FILE"
            exit 1
        fi

        SERVICE_JSON=$(jq -c --arg name "$SERVICE_NAME" 'map(select(.service.name == $name)) | first // empty' "$SERVICE_RESPONSE_FILE")

        if [ -n "$SERVICE_JSON" ] && [ "$SERVICE_JSON" != "null" ]; then
            rm -f "$SERVICE_RESPONSE_FILE"
            break
        fi

        NEXT_CURSOR=$(jq -r '.[-1].cursor // empty' "$SERVICE_RESPONSE_FILE")
        rm -f "$SERVICE_RESPONSE_FILE"

        if [ -z "$NEXT_CURSOR" ]; then
            break
        fi
    done

    if [ -z "$SERVICE_JSON" ] || [ "$SERVICE_JSON" = "null" ]; then
        print_warning "Service '$SERVICE_NAME' not found on Render."
        print_error "Backend service must be created manually (one-time setup)."
        echo ""
        print_info "Please create the Render service manually from your dashboard:"
        echo "  1. Go to: https://dashboard.render.com/create?type=web"
        echo "  2. Connect your GitHub repository: acm-industry/cicd-demo"
        echo "  3. Configure the service with these exact settings:"
        echo "     - Name: $SERVICE_NAME"
        echo "     - Branch: $BRANCH"
        echo "     - Root Directory: backend"
        echo "     - Runtime: Python 3"
        echo "     - Build Command: pip install -r requirements.txt"
        echo "     - Start Command: python server.py"
        echo "     - Plan: Free"
        echo "  4. Add Environment Variables:"
        echo "     - FLASK_ENV=production"
        echo "     - PORT=8080"
        echo "     - PYTHON_VERSION=3.11.0"
        echo "  5. Set Health Check Path: /get-test"
        echo ""
        print_info "After creating the service, re-run this script to deploy."
        echo ""
        exit 1
    else
        SERVICE_ID=$(echo "$SERVICE_JSON" | jq -r '.service.id')
        SERVICE_DASHBOARD_URL=$(echo "$SERVICE_JSON" | jq -r '.service.dashboardUrl // ""')
        BACKEND_URL=$(echo "$SERVICE_JSON" | jq -r '.service.serviceDetails.url // empty')

        if [ -z "$BACKEND_URL" ] || [ "$BACKEND_URL" = "null" ]; then
            BACKEND_URL="$DEFAULT_BACKEND_URL"
        fi

        print_success "Service '$SERVICE_NAME' found with ID: $SERVICE_ID"
        if [ -n "$SERVICE_DASHBOARD_URL" ]; then
            print_info "Dashboard URL: $SERVICE_DASHBOARD_URL"
        fi

        print_info "Triggering deployment via Render API..."
        DEPLOY_PAYLOAD=$(jq -n --arg clear "do_not_clear" '{"clearCache":$clear}')
        DEPLOY_RESPONSE_FILE=$(mktemp)
        DEPLOY_HTTP_STATUS=$(curl -sS -X POST \
            -H "Authorization: Bearer $RENDER_API_KEY" \
            -H "Content-Type: application/json" \
            -o "$DEPLOY_RESPONSE_FILE" \
            -w "%{http_code}" \
            -d "$DEPLOY_PAYLOAD" \
            "${RENDER_API_BASE_URL}/services/${SERVICE_ID}/deploys")
        CURL_EXIT_CODE=$?
        if [ $CURL_EXIT_CODE -ne 0 ]; then
            DEPLOY_HTTP_STATUS=0
        fi

        if [ "$DEPLOY_HTTP_STATUS" -lt 200 ] || [ "$DEPLOY_HTTP_STATUS" -ge 300 ]; then
            print_error "Failed to trigger Render deployment (HTTP $DEPLOY_HTTP_STATUS)."
            if [ -s "$DEPLOY_RESPONSE_FILE" ]; then
                print_warning "Render API response:"
                sed 's/^/    /' "$DEPLOY_RESPONSE_FILE"
            fi
            rm -f "$DEPLOY_RESPONSE_FILE"
            exit 1
        fi

        DEPLOY_ID=$(jq -r '.id // empty' "$DEPLOY_RESPONSE_FILE")
        rm -f "$DEPLOY_RESPONSE_FILE"

        if [ -z "$DEPLOY_ID" ]; then
            print_error "Render API response did not include a deploy ID."
            exit 1
        fi

        print_info "Triggered Render deploy (ID: $DEPLOY_ID). Waiting for completion..."

        MAX_WAIT_SECONDS=${RENDER_DEPLOY_TIMEOUT:-900}
        POLL_INTERVAL=5
        ELAPSED=0
        DEPLOY_STATUS=""
        DEPLOY_FAILED=false

        while [ $ELAPSED -lt $MAX_WAIT_SECONDS ]; do
            STATUS_RESPONSE_FILE=$(mktemp)
            STATUS_HTTP_STATUS=$(curl -sS \
                -H "Authorization: Bearer $RENDER_API_KEY" \
                -o "$STATUS_RESPONSE_FILE" \
                -w "%{http_code}" \
                "${RENDER_API_BASE_URL}/services/${SERVICE_ID}/deploys/${DEPLOY_ID}")
            CURL_EXIT_CODE=$?
            if [ $CURL_EXIT_CODE -ne 0 ]; then
                STATUS_HTTP_STATUS=0
            fi

            if [ "$STATUS_HTTP_STATUS" -ne 200 ]; then
                print_warning "Could not fetch Render deploy status (HTTP $STATUS_HTTP_STATUS). Retrying..."
                rm -f "$STATUS_RESPONSE_FILE"
                sleep $POLL_INTERVAL
                ELAPSED=$((ELAPSED + POLL_INTERVAL))
                continue
            fi

            DEPLOY_STATUS=$(jq -r '.status // empty' "$STATUS_RESPONSE_FILE")
            rm -f "$STATUS_RESPONSE_FILE"

            case "$DEPLOY_STATUS" in
                live|deployed|succeeded|ready)
                    print_success "Backend deployed successfully (status: $DEPLOY_STATUS)"
                    break
                    ;;
                build_failed|failed|canceled|cancelled|timed_out|deactivated)
                    DEPLOY_FAILED=true
                    print_error "Render deployment failed (status: $DEPLOY_STATUS)"
                    break
                    ;;
                *)
                    print_info "Render deploy status: $DEPLOY_STATUS (waiting...)"
                    sleep $POLL_INTERVAL
                    ELAPSED=$((ELAPSED + POLL_INTERVAL))
                    ;;
            esac
        done

        if [ "$DEPLOY_FAILED" = true ]; then
            exit 1
        fi

        if [ $ELAPSED -ge $MAX_WAIT_SECONDS ] && [ "$DEPLOY_STATUS" != "live" ] && [ "$DEPLOY_STATUS" != "ready" ] && [ "$DEPLOY_STATUS" != "deployed" ] && [ "$DEPLOY_STATUS" != "succeeded" ]; then
            print_warning "Timed out waiting for Render deployment to finish."
            print_warning "Continuing, but verify the backend deployment in the Render dashboard."
        fi

        print_info "Backend URL: $BACKEND_URL"
    fi

    cd ..
else
    print_warning "Skipping Render deployment"
    print_info "Using default backend URL: $DEFAULT_BACKEND_URL"
    BACKEND_URL="$DEFAULT_BACKEND_URL"
fi

# Ensure we have a backend URL for frontend deployment
if [ -z "$BACKEND_URL" ]; then
    print_warning "No backend URL available, using default"
    BACKEND_URL="$DEFAULT_BACKEND_URL"
fi

print_info "Backend URL for frontend: $BACKEND_URL"

echo ""

# Step 5: Deploy Frontend to Vercel (SECOND, using backend URL)
print_info "Deploying frontend to Vercel..."
cd frontend

# Determine deployment environment and project name based on branch
VERCEL_DEPLOY_FLAGS=()
case "$BRANCH" in
    prod|production|main)
        VERCEL_ENV_TARGET="production"
        VERCEL_DEPLOY_FLAGS=("--prod")
        PROJECT_NAME="prod-cicd-demo"
        print_info "Deploying to PRODUCTION environment"
        ;;
    gamma)
        VERCEL_ENV_TARGET="preview"
        PROJECT_NAME="gamma-cicd-demo"
        print_info "Deploying to GAMMA (pre-production) environment as a Vercel PREVIEW"
        ;;
    beta)
        VERCEL_ENV_TARGET="preview"
        PROJECT_NAME="beta-cicd-demo"
        print_info "Deploying to BETA (staging) environment as a Vercel PREVIEW"
        ;;
    *)
        VERCEL_ENV_TARGET="preview"
        # Sanitize branch name for project name (replace special chars with hyphens)
        SANITIZED_BRANCH=$(echo "$BRANCH" | sed 's/[^a-zA-Z0-9]/-/g' | tr '[:upper:]' '[:lower:]')
        PROJECT_NAME="${SANITIZED_BRANCH}-cicd-demo"
        print_info "Deploying to PREVIEW environment for branch '$BRANCH'"
        ;;
esac

print_info "Project name: $PROJECT_NAME"

# Create or update vercel.json to set the project name
print_info "Configuring Vercel project name..."
if [ -f "vercel.json" ]; then
    # Backup existing vercel.json
    cp vercel.json vercel.json.bak
    # Update the name field or add it if it doesn't exist
    if grep -q '"name"' vercel.json; then
        # Replace existing name
        sed -i.tmp "s/\"name\"[[:space:]]*:[[:space:]]*\"[^\"]*\"/\"name\": \"$PROJECT_NAME\"/" vercel.json && rm -f vercel.json.tmp
    else
        # Add name field to JSON
        sed -i.tmp 's/{/{\n  "name": "'"$PROJECT_NAME"'",/' vercel.json && rm -f vercel.json.tmp
    fi
else
    # Create new vercel.json
    cat > vercel.json <<EOF
{
  "name": "$PROJECT_NAME"
}
EOF
fi

# Prepare shared Vercel CLI arguments (token + project) for both env updates and deployment
VERCEL_TOKEN_FLAG=()
if [ -n "$VERCEL_TOKEN" ]; then
    VERCEL_TOKEN_FLAG=("--token" "$VERCEL_TOKEN")
fi

# After vercel.json is configured, link the backend URL as a project environment variable
if [ -n "$BACKEND_URL" ]; then
    print_info "Setting NEXT_PUBLIC_API_URL for Vercel project '$PROJECT_NAME'..."

    VERCEL_ENV_FLAGS=("--project" "$PROJECT_NAME")
    VERCEL_ENV_FLAGS+=("${VERCEL_TOKEN_FLAG[@]}")

    env -u VERCEL_PROJECT_ID -u VERCEL_ORG_ID \
        vercel env rm NEXT_PUBLIC_API_URL "$VERCEL_ENV_TARGET" --yes "${VERCEL_ENV_FLAGS[@]}" 2>/dev/null || true

    if printf '%s' "$BACKEND_URL" | env -u VERCEL_PROJECT_ID -u VERCEL_ORG_ID \
        vercel env add NEXT_PUBLIC_API_URL "$VERCEL_ENV_TARGET" --yes "${VERCEL_ENV_FLAGS[@]}"; then
        VERCEL_ENV_EXIT_CODE=0
    else
        VERCEL_ENV_EXIT_CODE=${PIPESTATUS[1]}
    fi

    if [ $VERCEL_ENV_EXIT_CODE -ne 0 ]; then
        print_warning "Failed to add environment variable to Vercel project."
        print_warning "The deployment will proceed, but git-based deployments may not have the correct backend URL."
    else
        print_success "Set NEXT_PUBLIC_API_URL for the '$VERCEL_ENV_TARGET' environment."
    fi
fi

# Deploy to Vercel (will create project if it doesn't exist)
print_info "Deploying to Vercel..."
echo ""

# Create a temporary file to capture output while also displaying it
TEMP_OUTPUT=$(mktemp)

DEPLOY_CMD_ARGS=("vercel" "deploy")
DEPLOY_CMD_ARGS+=("${VERCEL_DEPLOY_FLAGS[@]}")
DEPLOY_CMD_ARGS+=("-m" "githubDeployment=1" "-m" "githubCommitRef=$BRANCH")
DEPLOY_CMD_ARGS+=("--project" "$PROJECT_NAME")
DEPLOY_CMD_ARGS+=("--build-env" "NEXT_PUBLIC_API_URL=$BACKEND_URL" "--env" "NEXT_PUBLIC_API_URL=$BACKEND_URL")
DEPLOY_CMD_ARGS+=("${VERCEL_TOKEN_FLAG[@]}")

env -u VERCEL_PROJECT_ID -u VERCEL_ORG_ID "${DEPLOY_CMD_ARGS[@]}" 2>&1 | tee "$TEMP_OUTPUT"
DEPLOY_EXIT_CODE=${PIPESTATUS[0]}

echo ""

# Restore original vercel.json if we backed it up
if [ -f "vercel.json.bak" ]; then
    mv vercel.json.bak vercel.json
fi

# Extract URL from the output
VERCEL_URL=$(grep -Eo 'https://[^ ]+' "$TEMP_OUTPUT" | tail -1)
rm -f "$TEMP_OUTPUT"

if [ $DEPLOY_EXIT_CODE -ne 0 ] || [ -z "$VERCEL_URL" ]; then
    print_error "Failed to deploy frontend to Vercel"
    cd ..
    exit 1
fi

print_success "Frontend deployed to: $VERCEL_URL"
cd ..

echo ""
print_success "=========================================="
print_success "  Deployment Complete!"
print_success "=========================================="
echo ""
print_info "Frontend URL: $VERCEL_URL"
if [ -n "$BACKEND_URL" ]; then
    print_info "Backend URL: $BACKEND_URL"
fi
echo ""
