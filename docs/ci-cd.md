# CI/CD

One pipeline, three syntaxes — pick the system you use:

| File | System |
|---|---|
| [`Jenkinsfile`](../Jenkinsfile) | Jenkins (declarative Pipeline as Code) |
| [`.gitlab-ci.yml`](../.gitlab-ci.yml) | GitLab CI |
| [`.github/workflows/ci.yml`](../.github/workflows/ci.yml) | GitHub Actions (runs on PRs) |

## Stages (the build → test → deploy loop)
1. **Build** — `cmake` with `-Wall -Wextra`.
2. **Unit tests** — `ctest` (`tests/test_utils.cpp`: title parsing, route normalization, metrics output).
3. **DevSecOps** (shift-left, before an image exists): **SAST** `cppcheck`, **secret scan** `gitleaks`.
4. **API smoke test** — `tests/smoke.sh` starts the real binary and checks 18 behaviours (range requests, 404/400 handling, metrics).
5. **Docker build → image scan** (`trivy`, fails on CRITICAL with a fix available) → **smoke test the container** (`tests/smoke.sh <image>`).
6. **Maven API tests** — `api-tests/` (JUnit 5, black-box, run against the container). Maven is used purely as the test harness since the server is C++.
7. **Push** (if `REGISTRY` set) → **Deploy** (`k8s/deploy.sh`, rolling update with automatic rollback).

Run the checks locally:
```bash
cmake -B build -S . && cmake --build build && ctest --test-dir build --output-on-failure && tests/smoke.sh
mvn -f api-tests/pom.xml test -Dapi.baseUrl=http://localhost:3000     # against a running server
```

## Running Jenkins
```bash
docker compose -f ci/jenkins/docker-compose.yml up -d --build         # http://localhost:8080
docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword
```
The image (`ci/jenkins/Dockerfile`) contains cmake, g++, cppcheck, Maven, Docker CLI, kubectl, trivy and gitleaks. Create a *Pipeline from SCM* job pointing at this repo; add a GitHub webhook (`http://<host>:8080/github-webhook/`, use ngrok for a laptop) so a push triggers a build. Build parameters: `REGISTRY`, `DEPLOY`, `RUN_MAVEN_API_TESTS`.

> The Jenkins container mounts the host Docker socket (convenient for a lab; it is root-equivalent — don't do this on a shared server).

## Deployment
See [kubernetes.md](kubernetes.md) (rolling update, blue/green) and the existing Ansible/Docker Compose path in the README.
