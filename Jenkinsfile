pipeline {
    agent any

    environment {
        EC2_USER = "ec2-user"
        EC2_HOST = "3.227.246.28"
        REMOTE_DIR = "/home/ec2-user/self-healing-monitor"
    }
    stages {
        stage('Checkout Source') {
            steps {
                echo "==== STAGE 1/6: Checking out source code from GitHub ===="
                git branch: 'main',
                    credentialsId: 'github-token',
                    url: 'https://github.com/sujaldharmelwar/self-healing-monitor-TT.git'
                echo "==== STAGE 1/6 COMPLETE: Source code checked out ===="
            }
        }
        stage('Prepare EC2 Directory') {
            steps {
                echo "==== STAGE 2/6: Creating target directory on EC2 (${EC2_HOST}) ===="
                bat '''
                ssh -i "C:\\Program Files\\Jenkins\\keys\\KP-WINDOWS SERVER.pem" -o StrictHostKeyChecking=no %EC2_USER%@%EC2_HOST% "mkdir -p %REMOTE_DIR%"
                '''
                echo "==== STAGE 2/6 COMPLETE: Remote directory ready ===="
            }
        }
        stage('Copy Project to EC2') {
            steps {
                echo "==== STAGE 3/6: Copying scripts/config to EC2 ===="
                bat '''
                scp -i "C:\\Program Files\\Jenkins\\keys\\KP-WINDOWS SERVER.pem" -o StrictHostKeyChecking=no -r scripts config README.md Jenkinsfile .gitignore %EC2_USER%@%EC2_HOST%:%REMOTE_DIR%
                '''
                echo "==== STAGE 3/6 COMPLETE: Files copied to EC2 ===="
            }
        }
        stage('Convert CRLF to LF') {
            steps {
                echo "==== STAGE 4/6: Converting Windows line endings to Unix (CRLF -> LF) ===="
                bat '''
                ssh -i "C:\\Program Files\\Jenkins\\keys\\KP-WINDOWS SERVER.pem" -o StrictHostKeyChecking=no %EC2_USER%@%EC2_HOST% "sed -i 's/\\r$//' %REMOTE_DIR%/scripts/*.sh && sed -i 's/\\r$//' %REMOTE_DIR%/config/monitor.conf"
                '''
                echo "==== STAGE 4/6 COMPLETE: Line endings fixed ===="
            }
        }
        stage('Make Scripts Executable') {
            steps {
                echo "==== STAGE 5/6: Setting execute permission on scripts ===="
                bat '''
                ssh -i "C:\\Program Files\\Jenkins\\keys\\KP-WINDOWS SERVER.pem" -o StrictHostKeyChecking=no %EC2_USER%@%EC2_HOST% "chmod +x %REMOTE_DIR%/scripts/*.sh"
                '''
                echo "==== STAGE 5/6 COMPLETE: Scripts are executable ===="
            }
        }
        stage('Run Self-Healing Monitor') {
            steps {
                echo "==== STAGE 6/6: Running process_check.sh on EC2 (this checks nginx status, starts/restarts it if needed, and runs the health check) ===="
                bat '''
                ssh -i "C:\\Program Files\\Jenkins\\keys\\KP-WINDOWS SERVER.pem" -o StrictHostKeyChecking=no %EC2_USER%@%EC2_HOST% "cd %REMOTE_DIR%/scripts && ./process_check.sh"
                '''
                echo "==== STAGE 6/6 COMPLETE: Monitor script finished - scroll up to the 'STEP 1/4' - 'STEP 4/4' lines above to see nginx's status at each point ===="
            }
        }
    }
    post {
        success {
            echo 'SUCCESS: Self-Healing Monitoring completed successfully.'
        }
        failure {
            echo 'FAILURE: Critical failure detected. Check the "STEP" lines above to see exactly which stage and which nginx status check failed.'
        }
        always {
            echo 'Pipeline execution completed.'
        }
    }
}