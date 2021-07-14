output "kubeconfig-admin" {
  value = module.bootkube.kubeconfig-admin
}

# values.yaml content for all deployed charts.
output "pod-checkpointer_values" {
  value = module.bootkube.pod-checkpointer_values
}

output "kube-apiserver_values" {
  value = module.bootkube.kube-apiserver_values
}

output "kubernetes_values" {
  value = module.bootkube.kubernetes_values
}

output "kubelet_values" {
  value = module.bootkube.kubelet_values
}

output "calico_values" {
  value = module.bootkube.calico_values
}

output "lokomotive_values" {
  value = module.bootkube.lokomotive_values
}

output "bootstrap-secrets_values" {
  value = module.bootkube.bootstrap-secrets_values
}

output "node-local-dns_values" {
  value = module.bootkube.node-local-dns_values
}
