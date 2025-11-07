pipeline {
  agent any
  options { timestamps() }  // Removed ansiColor for now to avoid missing plugin error

  parameters {
    string(name: 'BRANCH', defaultValue: 'main', description: 'Git branch to build')
    choice(name: 'DEPLOY_ENV', choices: ['staging', 'production'], description: 'Deploy environment')
  }

  environment {
    GIT_URL   = 'https://github.com/Mbarekwael/spring-petclinic.git'
    JAVA_HOME = '/usr/lib/jvm/java-21-openjdk-amd64'  // ✅ Adjust this if Jenkins runs on Windows or another OS
    DOCKER_IMAGE = 'spring-petclinic'
    DOCKER_HUB_USERNAME = 'mbarekwael'  // ✅ your Docker Hub username
  }

  stages {
    stage('Checkout') {
      steps {
        checkout([$class: 'GitSCM',
          branches: [[name: "*/${params.BRANCH}"]],
          userRemoteConfigs: [[url: env.GIT_URL]]
        ])
        script {
          env.GIT_COMMIT_SHORT = sh(returnStdout: true, script: 'git rev-parse --short HEAD').trim()
          env.BUILD_VERSION    = "${env.BUILD_NUMBER}-${env.GIT_COMMIT_SHORT}"
          env.DOCKER_TAG       = env.BUILD_VERSION
          echo "Commit=${env.GIT_COMMIT_SHORT}  BUILD_VERSION=${env.BUILD_VERSION}"
        }
      }
    }

    stage('Build') {
      steps {
        sh '''
          set -eux
          export PATH="${JAVA_HOME}/bin:${PATH}"
          java -version
          chmod +x mvnw || true
          ./mvnw -B -U -DskipTests=true clean package
        '''
      }
      post {
        always {
          archiveArtifacts artifacts: 'target/*.jar', fingerprint: true, onlyIfSuccessful: false
        }
      }
    }

    stage('Parallel Testing') {
      parallel {
        stage('Unit Tests') {
          steps {
            sh '''
              set -eux
              export PATH="${JAVA_HOME}/bin:${PATH}"
              ./mvnw -B -Dspring.docker.compose.skip.in-tests=true \
                     -Dtest=\\!PostgresIntegrationTests \
                     test
            '''
          }
          post {
            always {
              junit testResults: 'target/**/TEST-*.xml', allowEmptyResults: false
            }
          }
        }

        stage('Integration Tests (MySQL only)') {
          steps {
            sh '''
              set -eux
              export PATH="${JAVA_HOME}/bin:${PATH}"
              ./mvnw -B -Dspring.docker.compose.skip.in-tests=true \
                     -Dtest=org.springframework.samples.petclinic.MySqlIntegrationTests \
                     verify
            '''
          }
          post {
            always {
              junit testResults: 'target/**/TEST-*.xml', allowEmptyResults: true
            }
          }
        }
      }
    }

    stage('Docker Image Build & Push') {
      steps {
        script {
          docker.withRegistry('https://index.docker.io/v1/', 'dockerhub-creds-wael') {
            sh '''
              set -eux
              docker build -t ${DOCKER_IMAGE}:${DOCKER_TAG} .
              docker tag ${DOCKER_IMAGE}:${DOCKER_TAG} ${DOCKER_HUB_USERNAME}/${DOCKER_IMAGE}:${DOCKER_TAG}
              docker push ${DOCKER_HUB_USERNAME}/${DOCKER_IMAGE}:${DOCKER_TAG}
            '''
          }
        }
      }
    }

    stage('Artifact Archiving') {
      steps {
        sh 'echo "image=${DOCKER_IMAGE}:${DOCKER_TAG}" > image.txt'
        archiveArtifacts artifacts: 'image.txt', fingerprint: true
      }
    }

    stage('Deployment (staging only)') {
      when {
        expression { params.DEPLOY_ENV == 'staging' && !env.CHANGE_ID }
      }
      steps {
        sh '''
          set -eux
          docker network inspect petnet >/dev/null 2>&1 || docker network create petnet
          docker rm -f petclinic-${BUILD_NUMBER} >/dev/null 2>&1 || true
          docker run -d --name petclinic-${BUILD_NUMBER} --network petnet -p 8082:8080 ${DOCKER_IMAGE}:${DOCKER_TAG}
          echo "✅ Application deployed successfully on staging!"
        '''
      }
    }
  }

  post {
    success {
      echo "✅ ${env.JOB_NAME} #${env.BUILD_NUMBER}  ${env.DOCKER_IMAGE}:${env.DOCKER_TAG}"
    }
    failure {
      echo "❌ Build failed"
    }
    always {
      archiveArtifacts artifacts: 'target/*.jar, image.txt', fingerprint: true, onlyIfSuccessful: false
    }
  }
}
