// CI for Nova: build the image, smoke-test the running container, and run
// the API test suite once api-tests/pom.xml exists. Deploy is intentionally
// not here yet — deploy.yml needs an interactive SSH password (--ask-pass),
// which a Jenkins job can't supply; that comes in a later step.

pipeline {
    agent any

    options {
        timestamps()
        disableConcurrentBuilds()
    }

    environment {
        IMAGE       = 'music-player'
        CONTAINER   = "music-player-ci-${BUILD_NUMBER}"
        // Host port for the smoke-test container, kept off 3000 so a running
        // local instance doesn't collide with CI.
        HOST_PORT   = '3100'
        // The BuildKit path tries to reach Windows Credential Manager, which
        // fails over SSH/service logons on the home host (see ansible/README.md).
        // The legacy builder works there and is harmless elsewhere.
        DOCKER_BUILDKIT = '0'
    }

    stages {
        stage('Build image') {
            steps {
                sh 'docker build -t ${IMAGE}:${BUILD_NUMBER} -t ${IMAGE}:latest .'
            }
        }

        stage('Smoke test') {
            steps {
                sh '''
                    docker run -d --name ${CONTAINER} -p ${HOST_PORT}:3000 ${IMAGE}:${BUILD_NUMBER}
                    for i in $(seq 1 20); do
                        if curl -sf http://localhost:${HOST_PORT}/api/songs; then
                            echo "API is up"
                            exit 0
                        fi
                        sleep 1
                    done
                    echo "API never came up; container logs:"
                    docker logs ${CONTAINER}
                    exit 1
                '''
            }
            post {
                always {
                    sh 'docker rm -f ${CONTAINER} || true'
                }
            }
        }

        stage('API tests') {
            when { expression { fileExists('api-tests/pom.xml') } }
            steps {
                sh 'cd api-tests && mvn -B test -Dapi.baseUrl=http://localhost:${HOST_PORT}'
            }
        }
    }
}
