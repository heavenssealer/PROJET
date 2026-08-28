variable "aws_region" {
  description = "Region AWS utilisee pour le projet"
  type        = string
  default     = "us-east-1"

  validation {
    condition     = var.aws_region == "us-east-1"
    error_message = "Le projet doit etre deploye dans us-east-1."
  }
}

variable "project_name" {
  description = "Nom utilise pour identifier les ressources"
  type        = string
  default     = "ipssi-orchestration"
}

variable "image_tag" {
  description = "Tag de l'image Docker"
  type        = string
  default     = "v1"

  validation {
    condition     = var.image_tag != "latest"
    error_message = "Le tag latest est interdit."
  }
}

variable "allowed_cidr" {
  description = "Adresse IP autorisee a contacter le service ECS"
  type        = string

  validation {
    condition     = can(cidrhost(var.allowed_cidr, 0)) && endswith(var.allowed_cidr, "/32")
    error_message = "L'adresse doit etre fournie au format x.x.x.x/32."
  }
}

variable "kubeconfig_path" {
  description = "Chemin vers le kubeconfig"
  type        = string
  default     = "~/.kube/config"
}

variable "kubernetes_context" {
  description = "Contexte et profil Minikube"
  type        = string
  default     = "minikube"
}

variable "ecs_desired_count" {
  description = "Nombre minimal de taches ECS"
  type        = number
  default     = 2

  validation {
    condition     = var.ecs_desired_count >= 2
    error_message = "Au moins deux taches ECS sont necessaires."
  }
}

variable "kubernetes_replicas" {
  description = "Nombre minimal de pods Kubernetes"
  type        = number
  default     = 2

  validation {
    condition     = var.kubernetes_replicas >= 2
    error_message = "Au moins deux pods Kubernetes sont necessaires."
  }
}
