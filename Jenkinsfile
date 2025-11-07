pipeline {
  agent any
  options { timestamps() }

  parameters {
    string(name: 'BRANCH', defaultValue: 'main', description: 'Git branch to build')
    choice(name: 'DEPLOY_ENV', choices: ['staging', 'production'], description: 'Deployment environment')
  }

  environment {
    // ---- CONFIG ----
    GIT_URL = 'https://github.com/Mbarekwael/spring-petclinic.git'
    JAVA_HOME = 'C:\\Program Files\\Eclipse Adoptium\\jdk-25.0.1.8-hotspot'  // ✅ Adjust if Linux
    DOCKER_IMAGE = 'spring-petclinic'
    DOCKER_HUB_USERNAME = 'mbarekwael'
    EMAIL_RECIPIENTS = 'team@example.com'  // ✅ Change to your email(s)
  }

  stages {

    // 1️⃣ CHECKOUT
    stage('Checkout') {
      steps {
        checkout([$class: 'GitSCM',
          branches: [[name: "*/${params.BRANCH}"]],
          userRemoteConfigs: [[url: env.GIT_URL]]
        ])
        script {
          // compute version dynamically
          env.GIT_COMMIT_SHORT = sh(returnStdout: true, script: 'git rev-parse --short HEAD').trim()
          env.BUILD_VERSION = "${env.BUILD_NUMBER}-${env.GIT_COMMIT_SHORT}"
          env.DOCKER_TAG = env.BUILD_VERSION
          echo "✅ Checked out commit ${env.GIT_COMMIT_SHORT}"
        }
      }
    }

    // 2️⃣ BUILD
    stage('Build') {
      steps {
        bat '''
          set JAVA_HOME=%JAVA_HOME%
          set PATH=%JAVA_HOME%\\bin;%PATH%
          echo ---- Using Java ----
          java -version
          echo ---- Building Project ----
          call mvnw.cmd -B -U -DskipTests=true clean package
        '''
      }
      post {
        always {
          archiveArtifacts artifacts: 'target/*.jar', fingerprint: true
        }
      }
    }

    // 3️⃣ PARALLEL TESTING
    stage('Parallel Testing') {
      parallel {
        stage('Unit Tests') {
          steps {
            bat '''
              set JAVA_HOME=%JAVA_HOME%
              set PATH=%JAVA_HOME%\\bin;%PATH%
              call mvnw.cmd -B test -Dtest=!PostgresIntegrationTests
            '''
          }
          post {
            always {
              junit testResults: 'target/**/TEST-*.xml', allowEmptyResults: false
            }
          }
        }

        stage('Integration Tests') {
          steps {
            bat '''
              set JAVA_HOME=%JAVA_HOME%
              set PATH=%JAVA_HOME%\\bin;%PATH%
              call mvnw.cmd -B verify -Dtest=org.springframework.samples.petclinic.MySqlIntegrationTests
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

    // 4️⃣ DOCKER IMAGE BUILD & PUSH
    stage('Docker Build & Push') {
      steps {
        script {
          docker.withRegistry('https://index.docker.io/v1/', 'dockerhub-creds-wael') {
            bat '''
              echo ---- Building Docker image ----
              docker build -t %DOCKER_IMAGE%:%DOCKER_TAG% .
              docker tag %DOCKER_IMAGE%:%DOCKER_TAG% %DOCKER_HUB_USERNAME%/%DOCKER_IMAGE%:%DOCKER_TAG%
              echo ---- Pushing to Docker Hub ----
              docker push %DOCKER_HUB_USERNAME%/%DOCKER_IMAGE%:%DOCKER_TAG%
            '''
          }
        }
      }
    }

    // 5️⃣ ARTIFACT ARCHIVING
    stage('Artifact Archiving') {
      steps {
        sh '''
          echo "image=${DOCKER_HUB_USERNAME}/${DOCKER_IMAGE}:${DOCKER_TAG}" > image.txt
        '''
        archiveArtifacts artifacts: 'image.txt', fingerprint: true
      }
    }

    // 6️⃣ DEPLOYMENT SIMULATION (staging only)
    stage('Deployment Simulation') {
      when { expression { params.DEPLOY_ENV == 'staging' && !env.CHANGE_ID } }
      steps {
        bat '''
          echo ---- Simulating Deployment ----
          docker network inspect petnet >nul 2>&1 || docker network create petnet
          docker rm -f petclinic-%BUILD_NUMBER% >nul 2>&1 || echo "No old container"
          docker run -d --name petclinic-%BUILD_NUMBER% --network petnet -p 8082:8080 %DOCKER_HUB_USERNAME%/%DOCKER_IMAGE%:%DOCKER_TAG%
          echo "Application deployed successfully on http://localhost:8082"
        '''
      }
    }
  }

  // 🧩 POST ACTIONS (EMAIL + STATUS)
  post {
    success {
      echo "✅ Build successful: ${env.DOCKER_HUB_USERNAME}/${env.DOCKER_IMAGE}:${env.DOCKER_TAG}"
      mail to: "${env.EMAIL_RECIPIENTS}",
           subject: "✅ Jenkins Build SUCCESS #${env.BUILD_NUMBER}",
           body: "The build and deployment of ${env.DOCKER_IMAGE}:${env.DOCKER_TAG} completed successfully."
    }
    failure {
      echo "❌ Build failed!"
      mail to: "${env.EMAIL_RECIPIENTS}",
           subject: "❌ Jenkins Build FAILED #${env.BUILD_NUMBER}",
           body: "The Jenkins build for ${env.DOCKER_IMAGE}:${env.DOCKER_TAG} has failed. Please check Jenkins logs."
    }
  }
}
