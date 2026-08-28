locals {
  namespace = "orchestration-demo"
  app_name  = "orchestration-demo"
  labels = {
    app        = local.app_name
    managed-by = "terraform"
  }
}

resource "kubernetes_namespace_v1" "this" {
  metadata {
    name = local.namespace
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
      project                        = var.project_name
    }
  }
}

resource "kubernetes_config_map_v1" "app" {
  metadata {
    name      = "${local.app_name}-config"
    namespace = kubernetes_namespace_v1.this.metadata[0].name
  }

  data = {
    APP_VERSION = var.image_tag
    PLATFORM    = "Kubernetes Minikube"
  }
}

resource "kubernetes_deployment_v1" "app" {
  metadata {
    name      = local.app_name
    namespace = kubernetes_namespace_v1.this.metadata[0].name
    labels    = local.labels
  }

  spec {
    replicas = var.replicas

    selector {
      match_labels = { app = local.app_name }
    }

    strategy {
      type = "RollingUpdate"
      rolling_update {
        max_surge       = "1"
        max_unavailable = "0"
      }
    }

    template {
      metadata {
        labels = local.labels
      }

      spec {
        automount_service_account_token = false

        security_context {
          run_as_non_root = true
          run_as_user     = 1000
          run_as_group    = 1000
          fs_group        = 1000
        }

        container {
          name              = "app"
          image             = var.image
          image_pull_policy = "Never"

          port {
            name           = "http"
            container_port = 8080
          }

          env_from {
            config_map_ref {
              name = kubernetes_config_map_v1.app.metadata[0].name
            }
          }

          resources {
            requests = {
              cpu    = "100m"
              memory = "64Mi"
            }
            limits = {
              cpu    = "500m"
              memory = "128Mi"
            }
          }

          readiness_probe {
            http_get {
              path = "/health"
              port = "http"
            }
            initial_delay_seconds = 3
            period_seconds        = 5
          }

          liveness_probe {
            http_get {
              path = "/health"
              port = "http"
            }
            initial_delay_seconds = 10
            period_seconds        = 10
          }

          security_context {
            allow_privilege_escalation = false
            read_only_root_filesystem  = true
            run_as_non_root            = true
            capabilities {
              drop = ["ALL"]
            }
          }
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "app" {
  metadata {
    name      = local.app_name
    namespace = kubernetes_namespace_v1.this.metadata[0].name
  }

  spec {
    selector = { app = local.app_name }
    port {
      name        = "http"
      port        = 80
      target_port = "http"
    }
    type = "ClusterIP"
  }
}

resource "kubernetes_ingress_v1" "app" {
  metadata {
    name      = local.app_name
    namespace = kubernetes_namespace_v1.this.metadata[0].name
    annotations = {
      "nginx.ingress.kubernetes.io/limit-rps" = "20"
    }
  }

  spec {
    ingress_class_name = "nginx"
    rule {
      host = "demo.local"
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = kubernetes_service_v1.app.metadata[0].name
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }
}

resource "kubernetes_horizontal_pod_autoscaler_v2" "app" {
  metadata {
    name      = local.app_name
    namespace = kubernetes_namespace_v1.this.metadata[0].name
  }

  spec {
    min_replicas = var.replicas
    max_replicas = 6

    scale_target_ref {
      api_version = "apps/v1"
      kind        = "Deployment"
      name        = kubernetes_deployment_v1.app.metadata[0].name
    }

    metric {
      type = "Resource"
      resource {
        name = "cpu"
        target {
          type                = "Utilization"
          average_utilization = 60
        }
      }
    }

    behavior {
      scale_up {
        stabilization_window_seconds = 0
        select_policy                = "Max"
        policy {
          period_seconds = 60
          type           = "Pods"
          value          = 2
        }
      }
      scale_down {
        stabilization_window_seconds = 120
        select_policy                = "Max"
        policy {
          period_seconds = 60
          type           = "Percent"
          value          = 50
        }
      }
    }
  }
}

resource "kubernetes_network_policy_v1" "app" {
  metadata {
    name      = "${local.app_name}-ingress"
    namespace = kubernetes_namespace_v1.this.metadata[0].name
  }

  spec {
    pod_selector {
      match_labels = { app = local.app_name }
    }
    policy_types = ["Ingress"]

    ingress {
      from {
        namespace_selector {
          match_labels = {
            "kubernetes.io/metadata.name" = "ingress-nginx"
          }
        }
      }
      from {
        pod_selector {}
      }
      ports {
        port     = "http"
        protocol = "TCP"
      }
    }
  }
}

resource "kubernetes_manifest" "tag_policy" {
  manifest = {
    apiVersion = "admissionregistration.k8s.io/v1"
    kind       = "ValidatingAdmissionPolicy"
    metadata = {
      name = "${var.project_name}-immutable-tags"
    }
    spec = {
      failurePolicy = "Fail"
      matchConstraints = {
        resourceRules = [{
          apiGroups   = [""]
          apiVersions = ["v1"]
          operations  = ["CREATE", "UPDATE"]
          resources   = ["pods"]
        }]
      }
      validations = [{
        expression = "object.spec.containers.all(c, c.image.matches('^.+:[^/]+$') && !c.image.endsWith(':latest'))"
        message    = "Chaque conteneur doit utiliser un tag different de latest."
      }]
    }
  }
}

resource "kubernetes_manifest" "tag_policy_binding" {
  manifest = {
    apiVersion = "admissionregistration.k8s.io/v1"
    kind       = "ValidatingAdmissionPolicyBinding"
    metadata = {
      name = "${var.project_name}-immutable-tags"
    }
    spec = {
      policyName        = kubernetes_manifest.tag_policy.manifest.metadata.name
      validationActions = ["Deny"]
      matchResources = {
        namespaceSelector = {
          matchLabels = {
            "app.kubernetes.io/managed-by" = "terraform"
          }
        }
      }
    }
  }
}
