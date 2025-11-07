pipeline {
  agent any
  options { timestamps(); ansiColor('xterm') }

  environment {
    GIT_URL = 'https://github.com/Mbarekwael/spring-petclinic.git'
    GIT_BRANCH = 'main'
    DOCKER_IMAGE = "spring-petclinic"
  }

  stages {

    stage('Clean Workspace') {
      steps {
        echo '🧹 Cleaning workspace...'
        deleteDir()
      }
    }

    stage('Checkout') {
      steps {
        echo "🔄 Checking out branch: ${env.GIT_BRANCH}"
        git branch: "${env.GIT_BRANCH}", url: "${env.GIT_URL}"
        script {
          env.GIT_COMMIT_SHORT = sh(returnStdout: true, script: 'git rev-parse --short HEAD').trim()
          env.BUILD_VERSION = "${env.BUILD_NUMBER}-${env.GIT_COMMIT_SHORT}"
          env.DOCKER_TAG = env.BUILD_VERSION
          echo "✅ Checked out commit ${env.GIT_COMMIT_SHORT}"
        }
      }
    }

    stage('Build with Java 24 (Temurin)') {
      agent {
        docker {
          image 'maven:3.9.9-eclipse-temurin-24-alpine'
          args '-v /var/run/docker.sock:/var/run/docker.sock'
        }
      }
      steps {
        sh '''
          set -eux
          mkdir -p /tmp/.m2
          export MAVEN_OPTS="-Dmaven.repo.local=/tmp/.m2"

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

    stage('Docker Image Build') {
      steps {
        sh '''
          set -eux
          docker build -t ${DOCKER_IMAGE}:${DOCKER_TAG} .
          docker images | head -n 5
        '''
      }
    }

    stage('Deploy to Staging') {
      steps {
        sh '''
          set -eux
          docker network inspect petnet >/dev/null 2>&1 || docker network create petnet
          docker rm -f petclinic-${BUILD_NUMBER} >/dev/null 2>&1 || true
          docker run -d --name petclinic-${BUILD_NUMBER} --network petnet -p 8082:8080 ${DOCKER_IMAGE}:${DOCKER_TAG}
          echo "✅ Application deployed successfully"
        '''
      }
    }
  }

  post {
    success { echo "✅ Build #${env.BUILD_NUMBER} successful (${env.DOCKER_IMAGE}:${env.DOCKER_TAG})" }
    failure { echo "❌ Build failed" }
  }
}
