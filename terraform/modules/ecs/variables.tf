variable "project_name" {
  description = "Nom du projet"
  type        = string
}

variable "aws_region" {
  description = "Region AWS"
  type        = string
}

variable "image_tag" {
  description = "Tag de l'image Docker"
  type        = string
}

variable "local_image_name" {
  description = "Nom local de l'image Docker"
  type        = string
}

variable "application_source" {
  description = "Chemin vers le code de l'application"
  type        = string
}
