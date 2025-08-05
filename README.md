# HTML CSS Docker ECS CI/CD Project

A static website project that demonstrates CI/CD using Docker, GitHub Actions, and deployment to AWS ECS Fargate.

## Project Structure

```
html-css-docker-ecs-cicd/
├── index.html                  # Static HTML page
├── styles.css                  # CSS for styling
├── Dockerfile                  # Dockerfile to containerize the app
├── README.md                   # Instructions for setup and usage
└── .github/
    └── workflows/
        └── deploy-to-ecs.yml   # GitHub Actions CI/CD pipeline
```

## Prerequisites

Before setting up this project, ensure you have:

- AWS CLI configured with appropriate permissions
- Docker installed locally
- GitHub repository created
- AWS account with ECS, ECR, and IAM access

## AWS Setup Instructions

### 1. Create Amazon ECR Repository

```bash
# Create ECR repository
aws ecr create-repository --repository-name html-site --region ap-south-1

# Get the repository URI
aws ecr describe-repositories --repository-names html-site --region ap-south-1 --query 'repositories[0].repositoryUri' --output text
```

### 2. Create ECS Cluster

```bash
# Create ECS cluster
aws ecs create-cluster --cluster-name html-app-cluster --region ap-south-1
```

### 3. Create ECS Task Definition

Create a file named `task-definition.json`:

```json
{
    "family": "html-app-task",
    "networkMode": "awsvpc",
    "requiresCompatibilities": ["FARGATE"],
    "cpu": "256",
    "memory": "512",
    "executionRoleArn": "arn:aws:iam::YOUR_ACCOUNT_ID:role/ecsTaskExecutionRole",
    "containerDefinitions": [
        {
            "name": "html-app-container",
            "image": "YOUR_ACCOUNT_ID.dkr.ecr.ap-south-1.amazonaws.com/html-site:latest",
            "portMappings": [
                {
                    "containerPort": 80,
                    "protocol": "tcp"
                }
            ],
            "essential": true,
            "logConfiguration": {
                "logDriver": "awslogs",
                "options": {
                    "awslogs-group": "/ecs/html-app",
                    "awslogs-region": "ap-south-1",
                    "awslogs-stream-prefix": "ecs"
                }
            }
        }
    ]
}
```

Register the task definition:

```bash
aws ecs register-task-definition --cli-input-json file://task-definition.json --region ap-south-1
```

### 4. Create ECS Service

```bash
# Create ECS service
aws ecs create-service \
    --cluster html-app-cluster \
    --service-name html-app-service \
    --task-definition html-app-task:1 \
    --desired-count 1 \
    --launch-type FARGATE \
    --network-configuration "awsvpcConfiguration={subnets=[subnet-12345678],securityGroups=[sg-12345678],assignPublicIp=ENABLED}" \
    --region ap-south-1
```

### 5. Create CloudWatch Log Group

```bash
aws logs create-log-group --log-group-name /ecs/html-app --region ap-south-1
```

## GitHub Secrets Setup

Add the following secrets to your GitHub repository (Settings → Secrets and variables → Actions):

| Secret Name | Description | Example Value |
|-------------|-------------|---------------|
| `AWS_ACCESS_KEY_ID` | AWS Access Key ID | AKIAIOSFODNN7EXAMPLE |
| `AWS_SECRET_ACCESS_KEY` | AWS Secret Access Key | wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY |
| `AWS_REGION` | AWS Region | ap-south-1 |
| `ECR_REPOSITORY` | ECR Repository Name | html-site |
| `ECS_CLUSTER_NAME` | ECS Cluster Name | html-app-cluster |
| `ECS_SERVICE_NAME` | ECS Service Name | html-app-service |
| `CONTAINER_NAME` | Container Name in Task Definition | html-app-container |

## Local Development

### Building and Testing Locally

1. **Build the Docker image:**
   ```bash
   docker build -t html-app .
   ```

2. **Run the container locally:**
   ```bash
   docker run -p 8080:80 html-app
   ```

3. **Access the application:**
   Open your browser and navigate to `http://localhost:8080`

### Pushing to ECR Manually

```bash
# Login to ECR
aws ecr get-login-password --region ap-south-1 | docker login --username AWS --password-stdin YOUR_ACCOUNT_ID.dkr.ecr.ap-south-1.amazonaws.com

# Build and tag the image
docker build -t html-site .
docker tag html-site:latest YOUR_ACCOUNT_ID.dkr.ecr.ap-south-1.amazonaws.com/html-site:latest

# Push to ECR
docker push YOUR_ACCOUNT_ID.dkr.ecr.ap-south-1.amazonaws.com/html-site:latest
```

## CI/CD Pipeline

### How it Works

The GitHub Actions workflow (`deploy-to-ecs.yml`) performs the following steps:

1. **Trigger:** Push to `main` branch
2. **Checkout:** Code is checked out from the repository
3. **AWS Configuration:** Sets up AWS credentials using GitHub secrets
4. **ECR Login:** Authenticates with Amazon ECR
5. **Build & Push:** Builds Docker image and pushes to ECR
6. **ECS Update:** Forces new deployment of ECS service
7. **Wait for Stability:** Ensures the service is stable before completing

### Pipeline Features

- **Automatic deployment** on every push to main
- **Docker image caching** for faster builds
- **Secure credential management** using GitHub secrets
- **ECS service stability check** to ensure successful deployment
- **Multi-region support** via configurable AWS region

## Testing the Deployment

### 1. Check ECS Service Status

```bash
aws ecs describe-services \
    --cluster html-app-cluster \
    --services html-app-service \
    --region ap-south-1
```

### 2. Get the Public IP

```bash
# Get the task ARN
TASK_ARN=$(aws ecs list-tasks --cluster html-app-cluster --service-name html-app-service --region ap-south-1 --query 'taskArns[0]' --output text)

# Get the network interface ID
NETWORK_INTERFACE_ID=$(aws ecs describe-tasks --cluster html-app-cluster --tasks $TASK_ARN --region ap-south-1 --query 'tasks[0].attachments[0].details[?name==`networkInterfaceId`].value' --output text)

# Get the public IP
PUBLIC_IP=$(aws ec2 describe-network-interfaces --network-interface-ids $NETWORK_INTERFACE_ID --region ap-south-1 --query 'NetworkInterfaces[0].Association.PublicIp' --output text)

echo "Your application is accessible at: http://$PUBLIC_IP"
```

### 3. Monitor Logs

```bash
# Get the task ARN
TASK_ARN=$(aws ecs list-tasks --cluster html-app-cluster --service-name html-app-service --region ap-south-1 --query 'taskArns[0]' --output text)

# View logs
aws logs tail /ecs/html-app --follow --region ap-south-1
```

## Troubleshooting

### Common Issues

1. **ECS Service fails to start:**
   - Check task definition for correct image URI
   - Verify ECR repository exists and image is pushed
   - Check security groups allow inbound traffic on port 80

2. **GitHub Actions fails:**
   - Verify all GitHub secrets are correctly set
   - Check AWS credentials have appropriate permissions
   - Ensure ECS cluster and service names match

3. **Application not accessible:**
   - Verify security groups allow inbound traffic
   - Check that the task is running and healthy
   - Ensure the container is listening on port 80

### Required AWS Permissions

Your AWS credentials need the following permissions:

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "ecr:GetAuthorizationToken",
                "ecr:BatchCheckLayerAvailability",
                "ecr:GetDownloadUrlForLayer",
                "ecr:BatchGetImage",
                "ecr:PutImage",
                "ecr:InitiateLayerUpload",
                "ecr:UploadLayerPart",
                "ecr:CompleteLayerUpload"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "ecs:UpdateService",
                "ecs:DescribeServices",
                "ecs:DescribeTasks",
                "ecs:ListTasks"
            ],
            "Resource": "*"
        }
    ]
}
```

## Cost Optimization

- Use Fargate Spot for non-production workloads
- Set appropriate CPU and memory limits
- Monitor CloudWatch metrics for resource utilization
- Consider using Application Load Balancer for better traffic management

## Security Best Practices

- Use IAM roles with minimal required permissions
- Enable VPC flow logs for network monitoring
- Use security groups to restrict traffic
- Regularly update base images for security patches
- Enable CloudTrail for API call logging




## License

This project is open source and available under the MIT License. 