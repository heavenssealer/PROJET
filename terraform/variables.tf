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
