pipeline {
  agent any

  options {
    timestamps()
    buildDiscarder(logRotator(numToKeepStr: '20'))
    disableConcurrentBuilds()
  }

  parameters {
    string(name: 'BRANCH', defaultValue: 'main', description: 'Git branch to build')
    choice(name: 'DEPLOY_ENV', choices: ['none','staging','production'], description: 'Where to deploy after push')
  }

  environment {
    GIT_URL        = 'https://github.com/Mbarekwael/spring-petclinic.git'
    APP_NAME       = 'spring-petclinic'
    DOCKER_NS      = 'mbarekwael'                 
    DOCKER_IMAGE   = "${DOCKER_NS}/${APP_NAME}"
    DOCKER_CREDSID = 'dockerhub-creds-wael'       
  }

  stages {
    stage('Checkout') {
      steps {
        checkout([$class: 'GitSCM',
          branches: [[name: "*/${params.BRANCH}"]],
          userRemoteConfigs: [[url: env.GIT_URL]]
        ])
        script {
          env.GIT_COMMIT_SHORT = sh(script: 'git rev-parse --short HEAD', returnStdout: true).trim()
          env.BUILD_VERSION    = "${env.BUILD_NUMBER}-${env.GIT_COMMIT_SHORT}"
          env.DOCKER_TAG       = env.BUILD_VERSION
          echo "Commit=${env.GIT_COMMIT_SHORT}  Version=${env.BUILD_VERSION}"
        }
      }
    }

    stage('Prepare Maven Wrapper') {
      steps {
        sh 'chmod +x mvnw'
        sh './mvnw -v'
      }
    }

    stage('Compute Version in POM') {
      steps {
        
        script {
          def pomVersion = sh(
            script: './mvnw -q -DforceStdout help:evaluate -Dexpression=project.version',
            returnStdout: true
          ).trim()
          echo "POM base version: ${pomVersion}"
        }
        
        sh "./mvnw -B versions:set -DnewVersion=${BUILD_VERSION} -DgenerateBackupPoms=false"
      }
    }

    stage('Parallel Testing') {
      parallel {
        stage('Unit Tests') {
          steps {
            sh "./mvnw -B -DskipITs=true test"
            junit testResults: 'target/surefire-reports/*.xml'
          }
        }
        stage('Integration (safe)') {
          steps {
            
            sh "./mvnw -B verify -DskipTests"
            junit allowEmptyResults: true, testResults: 'target/failsafe-reports/*.xml'
          }
        }
      }
    }

    stage('Package') {
      steps {
        sh "./mvnw -B -DskipTests package"
        archiveArtifacts artifacts: 'target/*.jar', fingerprint: true
      }
    }

    stage('Docker Build & Push') {
      steps {
        script {
          docker.withRegistry('', DOCKER_CREDSID) {
            def img = docker.build("${DOCKER_IMAGE}:${DOCKER_TAG}")
            img.push()
            img.push('latest')
          }
        }
      }
    }

    stage('Deploy') {
      when {
        allOf {
          expression { params.DEPLOY_ENV != 'none' }
          branch 'main'
        }
      }
      steps {
        script {
          def hostPort = (params.DEPLOY_ENV == 'production') ? '8080' : '8082'
          sh """
            docker network inspect petnet >/dev/null 2>&1 || docker network create petnet
            docker rm -f ${APP_NAME}-${params.DEPLOY_ENV} || true
            docker run -d --name ${APP_NAME}-${params.DEPLOY_ENV} --network petnet -p ${hostPort}:8080 ${DOCKER_IMAGE}:${DOCKER_TAG}
          """
        }
      }
    }
  }

  post {
    success {
      echo "✅ ${env.JOB_NAME} #${env.BUILD_NUMBER} pushed ${DOCKER_IMAGE}:${DOCKER_TAG}"
      archiveArtifacts artifacts: 'target/*.jar,image.txt', fingerprint: true, onlyIfSuccessful: false
    }
    failure {
      echo "❌ Build failed — check console log."
    }
  }
}
