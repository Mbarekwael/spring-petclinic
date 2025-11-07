pipeline {
  agent any
  options { timestamps() }

  environment {
    // --- CONFIGURATION ---
    GIT_URL = 'https://github.com/Mbarekwael/spring-petclinic.git'
    JAVA_HOME = 'C:\\Program Files\\Eclipse Adoptium\\jdk-25.0.1.8-hotspot'  
    DOCKER_IMAGE = 'spring-petclinic'
    DOCKER_HUB_USERNAME = 'mbarekwael'             
  }

  stages {
   
    stage('Checkout') {
      steps {
        checkout([$class: 'GitSCM',
          branches: [[name: "*/main"]],
          userRemoteConfigs: [[url: env.GIT_URL]]
        ])
      }
    }

    stage('Build') {
      steps {
        bat '''
          set JAVA_HOME=%JAVA_HOME%
          set PATH=%JAVA_HOME%\\bin;%PATH%
          echo ---- Using Java ----
          java -version
          echo ---- Building with Maven ----
          call mvnw.cmd -B -U -DskipTests=true clean package
        '''
      }
      post {
        always {
          archiveArtifacts artifacts: 'target/*.jar', fingerprint: true
        }
      }
    }

    
    stage('Docker Build & Push') {
      steps {
        script {
          docker.withRegistry('https://index.docker.io/v1/', 'dockerhub-creds-wael') {
            bat '''
              echo ---- Building Docker image ----
              docker build -t %DOCKER_IMAGE%:%BUILD_NUMBER% .
              docker tag %DOCKER_IMAGE%:%BUILD_NUMBER% %DOCKER_HUB_USERNAME%/%DOCKER_IMAGE%:%BUILD_NUMBER%
              echo ---- Pushing to Docker Hub ----
              docker push %DOCKER_HUB_USERNAME%/%DOCKER_IMAGE%:%BUILD_NUMBER%
            '''
          }
        }
      }
    }

    
    stage('Run Container (Optional)') {
      steps {
        bat '''
          docker rm -f petclinic-%BUILD_NUMBER% >nul 2>&1 || echo "No old container"
          docker run -d --name petclinic-%BUILD_NUMBER% -p 8082:8080 %DOCKER_HUB_USERNAME%/%DOCKER_IMAGE%:%BUILD_NUMBER%
          echo ---- App running on http://localhost:8082 ----
        '''
      }
    }
  }

  post {
    success {
      echo "✅ Build successful: ${env.DOCKER_HUB_USERNAME}/${env.DOCKER_IMAGE}:${env.BUILD_NUMBER}"
    }
    failure {
      echo "❌ Build failed!"
    }
  }
}
