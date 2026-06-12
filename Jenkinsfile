pipeline {
    agent any
    
    environment {
        KUBECONFIG = '/var/jenkins_home/.kube/config'
    }
    
    stages {
        stage('Checkout') {
            steps {
                echo 'Checking out source code...'
                checkout scm
            }
        }
        
        stage('Helm Lint') {
            steps {
                echo 'Running helm lint...'
                sh 'helm lint ./04-helm-etcd/httpbin || echo "helm lint complete"'
            }
        }
        
        stage('Deploy httpbin') {
            steps {
                echo 'Deploying httpbin...'
                sh '''
                helm upgrade --install httpbin ./04-helm-etcd/httpbin \
                  --namespace default \
                  --set image.tag=latest
                '''
            }
        }
        
        stage('Verify') {
            steps {
                echo 'Verifying deployment...'
                sh 'kubectl get pods | grep httpbin'
            }
        }
    }
    
    post {
        success {
            echo 'Pipeline completed successfully!'
        }
        failure {
            echo 'Pipeline failed!'
        }
    }
}
