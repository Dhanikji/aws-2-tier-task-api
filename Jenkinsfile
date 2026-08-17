pipeline {
    agent any

    environment {
        AWS_REGION      = 'ap-south-1'
        ECR_REGISTRY    = '427025827458.dkr.ecr.ap-south-1.amazonaws.com'
        ECR_REPOSITORY  = 'task-api'
        IMAGE_TAG       = "jenkins-${BUILD_NUMBER}"

        EC2_INSTANCE_1  = 'i-08f5e98b5a8851860'
        EC2_INSTANCE_2  = 'i-075c4345ba12b9e60'
    }

    stages {

        stage('Install Dependencies') {
            steps {
                dir('app') {
                    sh 'npm ci'
                }
            }
        }

        stage('Run Tests') {
            steps {
                dir('app') {
                    sh 'npm test'
                }
            }
        }

        stage('Build Image') {
            steps {
                sh '''
                    podman build --platform linux/amd64 \
                        -t ${ECR_REGISTRY}/${ECR_REPOSITORY}:${IMAGE_TAG} \
                        ./app
                '''
            }
        }

        stage('Login to ECR') {
            steps {
                sh '''
                    aws ecr get-login-password --region ${AWS_REGION} | \
                        podman login \
                        --username AWS \
                        --password-stdin ${ECR_REGISTRY}
                '''
            }
        }

        stage('Push Image') {
            steps {
                sh '''
                    podman push \
                        ${ECR_REGISTRY}/${ECR_REPOSITORY}:${IMAGE_TAG}
                '''
            }
        }

        stage('Deploy to EC2') {
            steps {
                sh '''
                    echo "=========================================="
                    echo "Deploying ${ECR_REPOSITORY}:${IMAGE_TAG}"
                    echo "=========================================="

                    COMMAND_ID=$(aws ssm send-command \
                        --region ${AWS_REGION} \
                        --instance-ids ${EC2_INSTANCE_1} ${EC2_INSTANCE_2} \
                        --document-name "AWS-RunShellScript" \
                        --parameters "commands=[
                            \\"aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_REGISTRY}\\",
                            \\"docker pull ${ECR_REGISTRY}/${ECR_REPOSITORY}:${IMAGE_TAG}\\",
                            \\"docker rm -f task-api || true\\",
                            \\"docker run -d --name task-api --restart unless-stopped -p 8080:8080 ${ECR_REGISTRY}/${ECR_REPOSITORY}:${IMAGE_TAG}\\"
                        ]" \
                        --query 'Command.CommandId' \
                        --output text)

                    echo "SSM Command ID: ${COMMAND_ID}"

                    for INSTANCE_ID in ${EC2_INSTANCE_1} ${EC2_INSTANCE_2}; do

                        echo "Waiting for deployment on ${INSTANCE_ID}..."

                        while true; do

                            STATUS=$(aws ssm get-command-invocation \
                                --region ${AWS_REGION} \
                                --command-id "${COMMAND_ID}" \
                                --instance-id "${INSTANCE_ID}" \
                                --query 'Status' \
                                --output text)

                            echo "${INSTANCE_ID}: ${STATUS}"

                            if [ "${STATUS}" = "Success" ]; then
                                break
                            fi

                            if [ "${STATUS}" = "Failed" ] || \
                               [ "${STATUS}" = "Cancelled" ] || \
                               [ "${STATUS}" = "TimedOut" ] || \
                               [ "${STATUS}" = "Cancelling" ]; then

                                echo "Deployment failed on ${INSTANCE_ID}"

                                aws ssm get-command-invocation \
                                    --region ${AWS_REGION} \
                                    --command-id "${COMMAND_ID}" \
                                    --instance-id "${INSTANCE_ID}" \
                                    --query '[StandardOutputContent,StandardErrorContent]' \
                                    --output text

                                exit 1
                            fi

                            sleep 5
                        done

                        echo "Deployment successful on ${INSTANCE_ID}"

                    done
                '''
            }
        }

        stage('Verify Deployment') {
            steps {
                sh '''
                    echo "=========================================="
                    echo "Verifying deployment"
                    echo "=========================================="

                    COMMAND_ID=$(aws ssm send-command \
                        --region ${AWS_REGION} \
                        --instance-ids ${EC2_INSTANCE_1} ${EC2_INSTANCE_2} \
                        --document-name "AWS-RunShellScript" \
                        --parameters 'commands=["docker ps --filter name=task-api","curl -s http://localhost:8080/health"]' \
                        --query 'Command.CommandId' \
                        --output text)

                    echo "Verification Command ID: ${COMMAND_ID}"

                    for INSTANCE_ID in ${EC2_INSTANCE_1} ${EC2_INSTANCE_2}; do

                        echo "Checking ${INSTANCE_ID}..."

                        while true; do

                            STATUS=$(aws ssm get-command-invocation \
                                --region ${AWS_REGION} \
                                --command-id "${COMMAND_ID}" \
                                --instance-id "${INSTANCE_ID}" \
                                --query 'Status' \
                                --output text)

                            echo "${INSTANCE_ID}: ${STATUS}"

                            if [ "${STATUS}" = "Success" ]; then
                                break
                            fi

                            if [ "${STATUS}" = "Failed" ] || \
                               [ "${STATUS}" = "Cancelled" ] || \
                               [ "${STATUS}" = "TimedOut" ]; then

                                echo "Verification failed on ${INSTANCE_ID}"

                                aws ssm get-command-invocation \
                                    --region ${AWS_REGION} \
                                    --command-id "${COMMAND_ID}" \
                                    --instance-id "${INSTANCE_ID}" \
                                    --query '[StandardOutputContent,StandardErrorContent]' \
                                    --output text

                                exit 1
                            fi

                            sleep 3
                        done

                        echo "=========================================="
                        echo "RESULT: ${INSTANCE_ID}"
                        echo "=========================================="

                        aws ssm get-command-invocation \
                            --region ${AWS_REGION} \
                            --command-id "${COMMAND_ID}" \
                            --instance-id "${INSTANCE_ID}" \
                            --query '[StandardOutputContent,StandardErrorContent]' \
                            --output text

                    done
                '''
            }
        }
    }

    post {
        success {
            echo "=========================================="
            echo "END-TO-END DEPLOYMENT SUCCESSFUL"
            echo "=========================================="
            echo "Image: ${ECR_REGISTRY}/${ECR_REPOSITORY}:${IMAGE_TAG}"
            echo "EC2-1: ${EC2_INSTANCE_1}"
            echo "EC2-2: ${EC2_INSTANCE_2}"
            echo "Application health checks passed."
            echo "=========================================="
        }

        failure {
            echo "=========================================="
            echo "PIPELINE FAILED"
            echo "=========================================="
            echo "Check the stage above for the failure."
            echo "=========================================="
        }
    }
}
