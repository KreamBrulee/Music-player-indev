// CI/CD for Nova. On every push: build the image, smoke-test the running
// container, run the API tests (once api-tests/pom.xml exists). On master,
// also deploy to the EC2 app instance with Ansible.
//
// Jenkins setup this expects:
//   - Plugins: Git, GitHub, Pipeline, SSH Agent
//   - Credential (kind "SSH Username with private key", id 'ec2-deploy-key'):
//     a PASSPHRASE-FREE key whose public half is in the app instance's
//     authorized_keys. Jenkins can't type a passphrase, so this must not be
//     the Mac's passphrase-protected key.
//   - Docker and Ansible installed on the agent (ansible/jenkins.yml does this).

pipeline {
    agent any

    options {
        timestamps()
        disableConcurrentBuilds()
    }

    environment {
        IMAGE     = 'music-player'
        CONTAINER = "music-player-ci-${BUILD_NUMBER}"
        // Smoke-test host port, off 3000 so it never clashes with anything
        // else on the agent (Grafana also uses 3000 on the monitoring host).
        HOST_PORT = '3100'
        DEPLOY_BRANCH = 'master'
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
                    ok=0
                    for i in $(seq 1 20); do
                        if curl -sf http://localhost:${HOST_PORT}/api/songs >/dev/null; then
                            echo "API is up"; ok=1; break
                        fi
                        sleep 1
                    done
                    if [ "$ok" -ne 1 ]; then
                        echo "API never came up; container logs:"; docker logs ${CONTAINER}; exit 1
                    fi
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
                sh '''
                    docker run -d --name ${CONTAINER} -p ${HOST_PORT}:3000 ${IMAGE}:${BUILD_NUMBER}
                    for i in $(seq 1 20); do
                        curl -sf http://localhost:${HOST_PORT}/api/songs >/dev/null && break
                        sleep 1
                    done
                    cd api-tests && mvn -B test -Dapi.baseUrl=http://localhost:${HOST_PORT}
                '''
            }
            post {
                always {
                    sh 'docker rm -f ${CONTAINER} || true'
                }
            }
        }

        stage('Deploy to EC2') {
            when {
                expression { (env.GIT_BRANCH ?: env.BRANCH_NAME ?: '').endsWith(env.DEPLOY_BRANCH) }
            }
            steps {
                sshagent(credentials: ['ec2-deploy-key']) {
                    sh '''
                        cd ansible
                        ansible-playbook -i inventory-ec2.ini deploy-ec2.yml
                    '''
                }
            }
        }
    }
}
