output "ecr_image_uri" {
  description = "Image Docker stockee dans ECR"
  value       = module.ecs.image_uri
}
