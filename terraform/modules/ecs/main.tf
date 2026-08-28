resource "aws_ecr_repository" "app" {
  name                 = "${var.project_name}-app"
  image_tag_mutability = "IMMUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }
}

resource "aws_ecr_lifecycle_policy" "app" {
  repository = aws_ecr_repository.app.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Conserver les dix dernieres images"

        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 10
        }

        action = {
          type = "expire"
        }
      }
    ]
  })
}

locals {
  image_uri = "${aws_ecr_repository.app.repository_url}:${var.image_tag}"

  source_hash = sha256(join("", [
    for filename in sort(fileset(var.application_source, "**")) :
    filesha256("${var.application_source}/${filename}")
  ]))
}

resource "terraform_data" "app_image" {
  triggers_replace = [
    var.image_tag,
    local.source_hash
  ]

  provisioner "local-exec" {
    command = <<-EOT
      set -eu
      aws ecr get-login-password --region "$AWS_REGION" | docker login --username AWS --password-
      stdin "$ECR_REGISTRY"
      docker build --pull --tag "$LOCAL_IMAGE" --tag "$ECR_IMAGE" "$APP_SOURCE"
      docker push "$ECR_IMAGE"
    EOT

    environment = {
      APP_SOURCE   = var.application_source
      AWS_REGION   = var.aws_region
      ECR_IMAGE    = local.image_uri
      ECR_REGISTRY = split("/", aws_ecr_repository.app.repository_url)[0]
      LOCAL_IMAGE  = var.local_image_name
    }
  }

  depends_on = [aws_ecr_repository.app]
}
