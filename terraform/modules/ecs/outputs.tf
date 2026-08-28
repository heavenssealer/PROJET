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


output "cluster_name" {
  description = "Nom du cluster ECS"
  value       = aws_ecs_cluster.this.name
}

output "security_group_id" {
  description = "Identifiant du Security Group ECS"
  value       = aws_security_group.ecs.id
}

output "service_name" {
  description = "Nom du service ECS"
  value       = aws_ecs_service.app.name
}

output "task_definition_arn" {
  description = "ARN de la Task Definition"
  value       = aws_ecs_task_definition.app.arn
}
