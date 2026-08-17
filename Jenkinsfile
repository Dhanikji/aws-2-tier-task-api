pipeline {
    agent any

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
                sh 'podman build -t task-api:jenkins ./app'
            }
        }

    }
}
