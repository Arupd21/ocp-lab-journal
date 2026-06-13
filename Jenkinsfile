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
  - name: podman
    image: quay.io/podman/stable:latest
    command:
    - sleep
    args:
    - infinity
    securityContext:
      privileged: true
'''
        }
    }

    environment {
        QUAY_REPO = "quay.io/arupd21/httpbin"
        IMAGE_TAG = "${BUILD_NUMBER}"
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

        stage('Build Image') {
            steps {
                container('podman') {
                    echo "Building image: ${QUAY_REPO}:${IMAGE_TAG}"
                    sh """
                    podman build -t ${QUAY_REPO}:${IMAGE_TAG} -f Dockerfile .
                    podman tag ${QUAY_REPO}:${IMAGE_TAG} ${QUAY_REPO}:latest
                    """
                }
            }
        }

        stage('Push Image') {
            steps {
                container('podman') {
                    withCredentials([usernamePassword(
                        credentialsId: 'quay-credentials',
                        usernameVariable: 'QUAY_USER',
                        passwordVariable: 'QUAY_TOKEN'
                    )]) {
                        echo 'Pushing image to Quay.io...'
                        sh """
                        podman login quay.io -u ${QUAY_USER} -p ${QUAY_TOKEN}
                        podman push ${QUAY_REPO}:${IMAGE_TAG}
                        podman push ${QUAY_REPO}:latest
                        """
                    }
                }
            }
        }

        stage('Deploy') {
            steps {
                container('helm') {
                    echo 'Deploying to Kubernetes...'
                    sh """
                    helm upgrade --install httpbin ./04-helm-etcd/httpbin \
                      --namespace default \
                      --set image.repository=${QUAY_REPO} \
                      --set image.tag=${IMAGE_TAG} \
                      --kube-apiserver https://kubernetes.default.svc \
                      --kube-token \$(cat /var/run/secrets/kubernetes.io/serviceaccount/token) \
                      --kube-ca-file /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
                    """
                }
            }
        }

        stage('Verify') {
            steps {
                container('helm') {
                    echo 'Verifying deployment...'
                    sh """
                    helm status httpbin \
                      --namespace default \
                      --kube-apiserver https://kubernetes.default.svc \
                      --kube-token \$(cat /var/run/secrets/kubernetes.io/serviceaccount/token) \
                      --kube-ca-file /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
                    """
                }
            }
        }
    }

    post {
        success {
            echo "Pipeline SUCCESS — image ${QUAY_REPO}:${IMAGE_TAG} deployed!"
        }
        failure {
            echo 'Pipeline FAILED!'
        }
    }
}
