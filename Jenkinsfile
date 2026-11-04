pipeline {
    agent any

    options {
        timestamps()
        disableConcurrentBuilds()
    }

    parameters {
        choice(
            name: 'ACTION',
            choices: ['DEPLOY_GREEN', 'ROLLBACK_BLUE'],
            description: 'Choose deployment or rollback action'
        )
    }

    environment {
        VLE8_HOST = '172.31.9.79'
        VLE8_USER = 'ubuntu'
        SSH_KEY = '/var/lib/jenkins/.ssh/vle8_deploy'
        REMOTE_DIR = '/home/ubuntu/vle8-blue-green-ci'
    }

    stages {
        stage('Checkout and Validate') {
            steps {
                checkout scm
                sh '''
                    test -f app/Dockerfile
                    test -f app/blue/index.html
                    test -f app/green/index.html
                    test -f k8s/deployment-blue.yaml
                    test -f k8s/deployment-green.yaml
                    test -f k8s/service.yaml
                    echo "Project validation successful"
                '''
            }
        }

        stage('Transfer Source and Build Images') {
            when {
                expression { params.ACTION == 'DEPLOY_GREEN' }
            }
            steps {
                sh '''
                    set -eu
                    tar czf source.tar.gz app k8s

                    ssh -i "$SSH_KEY" -o StrictHostKeyChecking=accept-new \
                        "$VLE8_USER@$VLE8_HOST" \
                        "mkdir -p $REMOTE_DIR"

                    scp -i "$SSH_KEY" -o StrictHostKeyChecking=accept-new \
                        source.tar.gz "$VLE8_USER@$VLE8_HOST:$REMOTE_DIR/"

                    ssh -i "$SSH_KEY" "$VLE8_USER@$VLE8_HOST" "
                        set -e
                        cd $REMOTE_DIR
                        tar -xzf source.tar.gz

                        sudo docker build --build-arg APP_COLOR=blue \
                            -t vle8-bluegreen:v1 -f app/Dockerfile app

                        sudo docker build --build-arg APP_COLOR=green \
                            -t vle8-bluegreen:v2 -f app/Dockerfile app

                        sudo docker save vle8-bluegreen:v1 vle8-bluegreen:v2 |
                            sudo k3s ctr -n k8s.io images import -
                    "
                '''
            }
        }

        stage('Deploy Green') {
            when {
                expression { params.ACTION == 'DEPLOY_GREEN' }
            }
            steps {
                sh '''
                    ssh -i "$SSH_KEY" "$VLE8_USER@$VLE8_HOST" "
                        cd $REMOTE_DIR &&
                        sudo k3s kubectl apply -f k8s/deployment-green.yaml &&
                        sudo k3s kubectl rollout restart deployment/myapp-green &&
                        sudo k3s kubectl rollout status deployment/myapp-green --timeout=120s
                    "
                '''
            }
        }

        stage('Verify Green') {
            when {
                expression { params.ACTION == 'DEPLOY_GREEN' }
            }
            steps {
                sh '''
                    set -e

                    GREEN_HTML=$(ssh -i "$SSH_KEY" "$VLE8_USER@$VLE8_HOST" \
                        "sudo k3s kubectl exec deployment/myapp-green -- wget -qO- http://127.0.0.1/")

                    echo "$GREEN_HTML" | grep -q "GREEN ENVIRONMENT"

                    COLOR=$(ssh -i "$SSH_KEY" "$VLE8_USER@$VLE8_HOST" \
                        "sudo k3s kubectl get service myapp-service -o jsonpath='{.spec.selector.color}'")

                    test "$COLOR" = "blue"

                    echo "Green passed validation. Live traffic remains on Blue."
                '''
            }
        }

        stage('Manual Approval') {
            when {
                expression { params.ACTION == 'DEPLOY_GREEN' }
            }
            steps {
                input message: 'Green v2 is ready. Switch live traffic to Green?',
                      ok: 'Approve Traffic Switch'
            }
        }

        stage('Switch Traffic to Green') {
            when {
                expression { params.ACTION == 'DEPLOY_GREEN' }
            }
            steps {
                sh '''
                    set -eu
                    PATCH='{"spec":{"selector":{"app":"myapp","color":"green"}}}'
                    ssh -i "$SSH_KEY" "$VLE8_USER@$VLE8_HOST" \
                        "sudo k3s kubectl patch service myapp-service --type merge -p '$PATCH'"
                '''
            }
        }

        stage('Rollback to Blue') {
            when {
                expression { params.ACTION == 'ROLLBACK_BLUE' }
            }
            steps {
                sh '''
                    set -eu
                    PATCH='{"spec":{"selector":{"app":"myapp","color":"blue"}}}'
                    ssh -i "$SSH_KEY" "$VLE8_USER@$VLE8_HOST" \
                        "sudo k3s kubectl patch service myapp-service --type merge -p '$PATCH'"
                '''
            }
        }

        stage('Verify Live Traffic') {
            steps {
                script {
                    def expectedText = params.ACTION == 'DEPLOY_GREEN' ? 'GREEN ENVIRONMENT' : 'BLUE ENVIRONMENT'
                    def expectedColor = params.ACTION == 'DEPLOY_GREEN' ? 'green' : 'blue'

                    withEnv(["EXPECTED_TEXT=${expectedText}", "EXPECTED_COLOR=${expectedColor}"]) {
                        sh """
                            set -eu

                            HTML=\$(ssh -i "\$SSH_KEY" "\$VLE8_USER@\$VLE8_HOST" "sudo k3s kubectl exec deployment/myapp-blue -- wget -qO- http://myapp-service/")

                            printf '%s' "\$HTML" | grep -Fq "\$EXPECTED_TEXT"

                            COLOR=\$(ssh -i "\$SSH_KEY" "\$VLE8_USER@\$VLE8_HOST" "sudo k3s kubectl get service myapp-service -o jsonpath='{.spec.selector.color}'")

                            test "\$COLOR" = "\$EXPECTED_COLOR"

                            echo "Live traffic verified: \$EXPECTED_TEXT"
                        """
                    }
                }
            }
        }
    }

    post {
        success {
            echo 'VLE-8 Blue-Green pipeline completed successfully.'
        }
        failure {
            echo 'VLE-8 pipeline failed. Check the Jenkins console output.'
        }
    }
}
