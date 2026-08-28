output "repository_url" {
  description = "Adresse du depot ECR"
  value       = aws_ecr_repository.app.repository_url
}

output "image_uri" {
  description = "Adresse complete de l'image ECR"
  value       = local.image_uri
}

output "image_build_id" {
  description = "Identifiant de la construction de l'image"
  value       = terraform_data.app_image.id
}
