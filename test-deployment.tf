data "kubectl_file_documents" "test-deployment" {
  content = file("test-deployment.yaml")
}

resource "kubectl_manifest" "test-deployment" {
  for_each  = data.kubectl_file_documents.test-deployment.manifests
  yaml_body = each.value
}