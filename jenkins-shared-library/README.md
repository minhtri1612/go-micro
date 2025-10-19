# Jenkins Shared Library for Microservices CI/CD

This shared library centralizes the CI/CD logic for all microservices, eliminating code duplication and making maintenance easier.

## Structure

```
jenkins-shared-library/
├── vars/
│   └── ciMicroservice.groovy    # Main pipeline logic
└── README.md
```

## Setup Instructions

### Step 1: Create Shared Library Repository

1. Create a new Git repository for the shared library (e.g., `jenkins-shared-library`)
2. Push this code to that repository

### Step 2: Configure Jenkins Shared Library

1. Go to **Manage Jenkins** → **System** → **Global Pipeline Libraries**
2. Click **Add**
3. Configure:
   - **Name**: `my-devops-library`
   - **Default Version**: `main`
   - **Retrieval Method**: `Git`
   - **Project Repository**: `https://github.com/your-username/jenkins-shared-library.git`
   - **Credentials**: Add your GitHub credentials if private repo

### Step 3: Update Your Jenkinsfiles

Replace your current Jenkinsfiles with the new simplified versions:

- `Jenkinsfile-api_gateway-new` → `Jenkinsfile-api_gateway`
- `Jenkinsfile-client-new` → `Jenkinsfile-client`
- etc.

### Step 4: Configure Multibranch Pipeline

1. **New Item** → **Multibranch Pipeline**: Name it `Monorepo-CI`
2. **Branch Sources**: Add your main repository
3. **Build Configuration**:
   - **Mode**: `By Script Path (Custom)`
   - **Script Path**: `jenkins-pipeline/Jenkinsfile-*`

## How It Works

1. **Jenkins** detects changes in any service
2. **Shared Library** handles the common pipeline logic:
   - Docker build
   - ECR push
   - GitOps update
3. **ArgoCD** detects Git changes and deploys automatically

## Benefits

- ✅ **DRY Principle**: No code duplication
- ✅ **Centralized Logic**: Easy to maintain and update
- ✅ **Consistent Pipelines**: All services follow the same process
- ✅ **GitOps Integration**: Automatic deployments via ArgoCD

