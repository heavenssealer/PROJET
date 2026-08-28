pipeline {
  agent any

  options {
    disableConcurrentBuilds()
    skipDefaultCheckout(true)
  }

  parameters {
    string(
      name: 'ALLOWED_CIDR',
      defaultValue: '',
      description: 'IPv4 publique autorisee pour ECS, au format x.x.x.x/32'
    )
  }

  environment {
    PATH                  = "${env.HOME}/bin:/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
    AWS_DEFAULT_REGION    = 'us-east-1'
    AWS_REGION            = 'us-east-1'
    AWS_ACCESS_KEY_ID     = credentials('aws-academy-access-key-id')
    AWS_SECRET_ACCESS_KEY = credentials('aws-academy-secret-access-key')
    AWS_SESSION_TOKEN     = credentials('aws-academy-session-token')
    TF_IN_AUTOMATION      = 'true'
    TF_INPUT              = 'false'
  }

  stages {
    stage('Checkout') {
      steps {
        checkout scm
        script {
          env.TF_VAR_image_tag = sh(
            returnStdout: true,
            script: 'git rev-parse --short=12 HEAD'
          ).trim()
          env.TF_VAR_allowed_cidr = params.ALLOWED_CIDR.trim()
        }
      }
    }

    stage('Preflight') {
      steps {
        sh '''
          set -eu
          test -n "$TF_VAR_allowed_cidr"
          docker version
          aws sts get-caller-identity
          minikube -p minikube status
          kubectl --context minikube cluster-info
        '''
      }
    }

    stage('Validate') {
      steps {
        dir('terraform') {
          sh '''
            set -eu
            terraform init -input=false
            terraform fmt -check -recursive
            terraform validate
          '''
        }
      }
    }

    stage('Plan') {
      steps {
        dir('terraform') {
          sh '''
            set -eu
            terraform plan -input=false -out=tfplan
            terraform show -no-color tfplan > tfplan.txt
          '''
        }
        archiveArtifacts artifacts: 'terraform/tfplan.txt', fingerprint: true
      }
    }

    stage('Approve') {
      steps {
        timeout(time: 20, unit: 'MINUTES') {
          input message: 'Appliquer le plan sur ECS et Kubernetes ?', ok: 'Appliquer'
        }
      }
    }

    stage('Apply') {
      steps {
        dir('terraform') {
          sh 'terraform apply -input=false -auto-approve tfplan'
        }
      }
    }

    stage('Verify') {
      steps {
        dir('terraform') {
          sh '''
            set -eu
            CLUSTER_NAME="$(terraform output -raw ecs_cluster_name)"
            SERVICE_NAME="$(terraform output -raw ecs_service_name)"
            NAMESPACE="$(terraform output -raw kubernetes_namespace)"
            kubectl --context minikube -n "$NAMESPACE" rollout status deployment/orchestration-demo --timeout=180s
            kubectl --context minikube -n "$NAMESPACE" get deployment,pods,service,ingress,hpa
            aws ecs wait services-stable --cluster "$CLUSTER_NAME" --services "$SERVICE_NAME"
            aws ecs describe-services --cluster "$CLUSTER_NAME" --services "$SERVICE_NAME" --query 'services[0].{desired:desiredCount,running:runningCount,status:status}'
            DESIRED="$(aws ecs describe-services --cluster "$CLUSTER_NAME" --services "$SERVICE_NAME" --query 'services[0].desiredCount' --output text)"
            RUNNING="$(aws ecs describe-services --cluster "$CLUSTER_NAME" --services "$SERVICE_NAME" --query 'services[0].runningCount' --output text)"
            test "$RUNNING" = "$DESIRED"
          '''
        }
      }
    }
  }
}
