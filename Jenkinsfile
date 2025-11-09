pipeline {
  agent any
  options { timestamps() }

  parameters {
    string(name: 'BRANCH', defaultValue: 'main', description: 'Git branch to build')
    choice(name: 'DEPLOY_ENV', choices: ['staging', 'production'], description: 'Deployment environment')
  }

  environment {
    GIT_URL = 'https://github.com/Mbarekwael/spring-petclinic.git'
    DOCKER_IMAGE = 'spring-petclinic'
    DOCKER_HUB_USERNAME = 'mbarekwael'
    EMAIL_RECIPIENTS = 'team@example.com'
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
          env.BUILD_VERSION = "${env.BUILD_NUMBER}-${env.GIT_COMMIT_SHORT}"
          env.DOCKER_TAG = env.BUILD_VERSION
          echo "✅ Checked out commit ${env.GIT_COMMIT_SHORT}"
        }
      }
    }

    stage('Build') {
      steps {
        sh '''
          echo "---- Using Java ----"
          java -version
          echo "---- Building ----"
          ./mvnw -B -U -DskipTests=true clean package
        '''
      }
      post {
        always { archiveArtifacts artifacts: 'target/*.jar', fingerprint: true }
      }
    }

    stage('Parallel Testing') {
      parallel {
        stage('Unit Tests') {
          steps {
            sh '''
              ./mvnw -B test -Dtest=!PostgresIntegrationTests
            '''
          }
          post {
            always { junit testResults: 'target/**/TEST-*.xml', allowEmptyResults: false }
          }
        }

        stage('Integration Tests') {
          steps {
            sh '''
              ./mvnw -B verify -Dtest=org.springframework.samples.petclinic.MySqlIntegrationTests
            '''
          }
          post {
            always { junit testResults: 'target/**/TEST-*.xml', allowEmptyResults: true }
          }
        }
      }
    }

    stage('Docker Build & Push') {
      steps {
        script {
          docker.withRegistry('https://index.docker.io/v1/', 'dockerhub-creds-wael') {
            sh '''
              echo "---- Building Docker image ----"
              docker build -t ${DOCKER_IMAGE}:${DOCKER_TAG} .
              docker tag ${DOCKER_IMAGE}:${DOCKER_TAG} ${DOCKER_HUB_USERNAME}/${DOCKER_IMAGE}:${DOCKER_TAG}
              echo "---- Pushing to Docker Hub ----"
              docker push ${DOCKER_HUB_USERNAME}/${DOCKER_IMAGE}:${DOCKER_TAG}
            '''
          }
        }
      }
    }

    stage('Artifact Archiving') {
      steps {
        sh '''
          echo "image=${DOCKER_HUB_USERNAME}/${DOCKER_IMAGE}:${DOCKER_TAG}" > image.txt
        '''
        archiveArtifacts artifacts: 'image.txt', fingerprint: true
      }
    }

    stage('Deployment Simulation') {
      when { expression { params.DEPLOY_ENV == 'staging' && !env.CHANGE_ID } }
      steps {
        sh '''
          docker network inspect petnet >/dev/null 2>&1 || docker network create petnet
          docker rm -f petclinic-${BUILD_NUMBER} >/dev/null 2>&1 || true
          docker run -d --name petclinic-${BUILD_NUMBER} --network petnet -p 8082:8080 ${DOCKER_HUB_USERNAME}/${DOCKER_IMAGE}:${DOCKER_TAG}
          echo "✅ Application deployed successfully on http://localhost:8082"
        '''
      }
    }
  }

  post {
    success {
      echo "✅ Build successful: ${DOCKER_HUB_USERNAME}/${DOCKER_IMAGE}:${DOCKER_TAG}"
      mail to: "${EMAIL_RECIPIENTS}",
           subject: "✅ Jenkins Build SUCCESS #${BUILD_NUMBER}",
           body: "The build and deployment of ${DOCKER_IMAGE}:${DOCKER_TAG} completed successfully."
    }
    failure {
      echo "❌ Build failed!"
      mail to: "${EMAIL_RECIPIENTS}",
           subject: "❌ Jenkins Build FAILED #${BUILD_NUMBER}",
           body: "The Jenkins build for ${DOCKER_IMAGE}:${DOCKER_TAG} has failed. Please check logs."
    }
  }
}
