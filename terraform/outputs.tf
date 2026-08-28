output "ecr_repository_url" {
  description = "Adresse du depot ECR"
  value       = module.ecs.repository_url
}

output "ecr_image_uri" {
  description = "Image Docker stockee dans ECR"
  value       = module.ecs.image_uri
}

output "ecs_cluster_name" {
  value = module.ecs.cluster_name
}

output "ecs_service_name" {
  value = module.ecs.service_name
}

output "kubernetes_namespace" {
  value = module.k8s.namespace
}

output "kubernetes_url" {
  value = "http://${module.k8s.ingress_host}"
}
