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
}
