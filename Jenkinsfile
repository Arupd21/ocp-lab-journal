pipeline {
    agent {
        kubernetes {
            yaml '''
apiVersion: v1
kind: Pod
spec:
  containers:
  - name: helm
    image: alpine/helm:3.16.4
    command:
    - sleep
    args:
    - infinity
'''
        }
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
                container('helm') {
                    echo 'Running helm lint...'
                    sh 'helm lint ./04-helm-etcd/httpbin'
                }
            }
        }

        stage('Deploy httpbin') {
            steps {
                container('helm') {
                    echo 'Deploying httpbin...'
                    sh '''
                    helm upgrade --install httpbin ./04-helm-etcd/httpbin \
                      --namespace default \
                      --set image.tag=latest \
                      --kube-apiserver https://kubernetes.default.svc \
                      --kube-token $(cat /var/run/secrets/kubernetes.io/serviceaccount/token) \
                      --kube-ca-file /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
                    '''
                }
            }
        }

        stage('Verify') {
            steps {
                container('helm') {
                    echo 'Verifying deployment...'
                    sh '''
                    helm status httpbin \
                      --namespace: default \
                      --kube-apiserver https://kubernetes.default.svc \
                      --kube-token $(cat /var/run/secrets/kubernetes.io/serviceaccount/token) \
                      --kube-ca-file /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
                    '''
                }
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
