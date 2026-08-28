locals {
  local_image_name = "orchestration-demo:${var.image_tag}"
}

module "ecs" {
  source = "./modules/ecs"

  project_name       = var.project_name
  aws_region         = var.aws_region
  image_tag          = var.image_tag
  local_image_name   = local.local_image_name
  application_source = "${path.root}/../app"
  allowed_cidr       = var.allowed_cidr
  desired_count      = var.ecs_desired_count
}

resource "terraform_data" "minikube_prerequisites" {
  triggers_replace = [var.kubernetes_context]

  provisioner "local-exec" {
    command = <<-EOT
      set -eu
      minikube -p "$MINIKUBE_PROFILE" status >/dev/null
      minikube -p "$MINIKUBE_PROFILE" addons enable ingress
      minikube -p "$MINIKUBE_PROFILE" addons enable metrics-server
    EOT

    environment = {
      MINIKUBE_PROFILE = var.kubernetes_context
    }
  }
}

resource "terraform_data" "minikube_image" {
  triggers_replace = [module.ecs.image_build_id, var.kubernetes_context]

  provisioner "local-exec" {
    command = <<-EOT
      set -eu
      minikube -p "$MINIKUBE_PROFILE" image load "$LOCAL_IMAGE"
    EOT

    environment = {
      MINIKUBE_PROFILE = var.kubernetes_context
      LOCAL_IMAGE      = local.local_image_name
    }
  }

  depends_on = [terraform_data.minikube_prerequisites]
}

module "k8s" {
  source = "./modules/k8s"

  project_name = var.project_name
  image        = local.local_image_name
  image_tag    = var.image_tag
  replicas     = var.kubernetes_replicas

  depends_on = [terraform_data.minikube_image]
}
