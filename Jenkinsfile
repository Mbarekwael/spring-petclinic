pipeline {
  agent any
  options { timestamps(); ansiColor('xterm') }


  environment {
    GIT_URL = 'https://github.com/Mbarekwael/spring-petclinic.git'
    DOCKER_IMAGE = "spring-petclinic"
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
          echo "Commit=${env.GIT_COMMIT_SHORT}  BUILD_VERSION=${env.BUILD_VERSION}"
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
          # Ensure Maven has a writable local repo inside Jenkins workspace
          WORKDIR=$(pwd)
          mkdir -p $WORKDIR/.m2
          export MAVEN_OPTS="-Dmaven.repo.local=$WORKDIR/.m2"

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

    stage('Deploy (staging only)') {
      when { expression { params.DEPLOY_ENV == 'staging' } }
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
    always { archiveArtifacts artifacts: 'target/*.jar', fingerprint: true, onlyIfSuccessful: false }
  }
}
