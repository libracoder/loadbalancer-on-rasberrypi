provider "helm" {
  kubernetes {
    config_path = "~/.kube/config"
  }
}

provider "kubernetes" {
  config_path    = "~/.kube/config"
  config_context = "pi"
}

resource "kubernetes_namespace" "metallb" {
  metadata {
    name = "metallb"
  }
}

resource "helm_release" "metal_lb" {
  name       = "metallb"
  repository = "https://metallb.github.io/metallb"
  chart      = "metallb"
  namespace = kubernetes_namespace.metallb.metadata[0].name

  set {
    name  = "labels.pod-security.kubernetes\\.io/enforce"
    value = "privileged"
  }

  set {
    name  = "labels.pod-security.kubernetes\\.io/audit"
    value = "privileged"
  }

  set {
    name  = "labels.pod-security.kubernetes\\.io/warn"
    value = "privileged"
  }

  set {
    name  = "speaker.secretName"
    value = "memberlist"
  }
}

data "kubectl_file_documents" "metal_lb" {
  content = file("metal-lb-config.yaml")
}

resource "kubectl_manifest" "metal_lb" {
  for_each  = data.kubectl_file_documents.metal_lb.manifests
  yaml_body = each.value
}

