// Declarative pipeline (Pipeline as Code). See docs/ci-cd.md for how to run
// a Jenkins server that can execute this (ci/jenkins/).
pipeline {
    agent any

    options {
        timestamps()
        timeout(time: 30, unit: 'MINUTES')
        buildDiscarder(logRotator(numToKeepStr: '20'))
        disableConcurrentBuilds()
    }

    parameters {
        string(name: 'REGISTRY', defaultValue: '',
               description: 'Registry to push to, e.g. ghcr.io/<user>. Empty = do not push.')
        booleanParam(name: 'DEPLOY', defaultValue: false,
                     description: 'Deploy to the Kubernetes cluster kubectl points at.')
        booleanParam(name: 'RUN_MAVEN_API_TESTS', defaultValue: true,
                     description: 'Run the Maven/JUnit black-box API tests.')
    }

    environment {
        IMAGE_NAME = 'music-player'
        IMAGE_TAG  = "${env.BUILD_NUMBER}-${(env.GIT_COMMIT ?: 'local').take(7)}"
    }

    stages {
        stage('Checkout') {
            steps { checkout scm }
        }

        stage('Build') {
            steps {
                sh 'cmake -B build -S . -DCMAKE_BUILD_TYPE=Release -DCMAKE_CXX_FLAGS="-Wall -Wextra"'
                sh 'cmake --build build -j"$(nproc)"'
            }
        }

        stage('Unit tests') {
            steps { sh 'ctest --test-dir build --output-on-failure' }
        }

        // Shift-left security: fail fast, before an image is ever built.
        stage('DevSecOps: static checks') {
            parallel {
                stage('SAST (cppcheck)') {
                    steps {
                        sh 'cppcheck --enable=warning,performance,portability --error-exitcode=1 --inline-suppr -q src/'
                    }
                }
                stage('Secret scan (gitleaks)') {
                    steps { sh 'gitleaks detect --source . --redact --no-banner' }
                }
            }
        }

        stage('API smoke test (binary)') {
            steps { sh 'tests/smoke.sh' }
        }

        stage('Docker build') {
            steps { sh 'docker build -t ${IMAGE_NAME}:${IMAGE_TAG} .' }
        }

        stage('DevSecOps: image scan (trivy)') {
            steps {
                sh 'trivy image --exit-code 1 --severity CRITICAL --ignore-unfixed --no-progress ${IMAGE_NAME}:${IMAGE_TAG}'
            }
        }

        stage('API smoke test (container)') {
            steps { sh 'tests/smoke.sh ${IMAGE_NAME}:${IMAGE_TAG}' }
        }

        stage('Maven API tests') {
            when { expression { params.RUN_MAVEN_API_TESTS } }
            steps {
                sh '''
                    # start a throw-away container, run the JUnit suite against it
                    mkdir -p /tmp/mp-songs && head -c 4096 /dev/urandom > /tmp/mp-songs/Maven_Test.mp3
                    chmod -R a+rX /tmp/mp-songs
                    CID=$(docker run -d -p 3998:3000 -v /tmp/mp-songs:/app/songs:ro ${IMAGE_NAME}:${IMAGE_TAG})
                    trap "docker rm -f $CID" EXIT
                    for i in $(seq 1 40); do curl -sf http://127.0.0.1:3998/healthz && break; sleep 0.5; done
                    mvn -B -f api-tests/pom.xml test -Dapi.baseUrl=http://127.0.0.1:3998
                '''
            }
            post { always { junit allowEmptyResults: true, testResults: 'api-tests/target/surefire-reports/*.xml' } }
        }

        stage('Push image') {
            when { expression { params.REGISTRY?.trim() } }
            steps {
                sh '''
                    docker tag ${IMAGE_NAME}:${IMAGE_TAG} ${REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}
                    docker push ${REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}
                '''
            }
        }

        stage('Deploy to Kubernetes') {
            when { expression { params.DEPLOY } }
            steps {
                // rolling update; the script rolls back automatically if the
                // new ReplicaSet never becomes ready.
                sh 'k8s/deploy.sh ${REGISTRY:+$REGISTRY/}${IMAGE_NAME}:${IMAGE_TAG}'
            }
        }
    }

    post {
        success { echo "Build ${env.BUILD_NUMBER} OK — image ${IMAGE_NAME}:${IMAGE_TAG}" }
        failure { echo "Build ${env.BUILD_NUMBER} FAILED" }
        always  { sh 'docker image prune -f >/dev/null 2>&1 || true' }
    }
}
