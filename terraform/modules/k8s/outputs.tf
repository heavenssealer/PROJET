output "namespace" {
  value = kubernetes_namespace_v1.this.metadata[0].name
}

output "ingress_host" {
  value = kubernetes_ingress_v1.app.spec[0].rule[0].host
}
