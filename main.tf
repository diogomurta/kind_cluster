terraform {
  required_version = ">= 0.13"

  required_providers {
    kind = {
      source  = "tehcyx/kind"
      version = "0.0.13"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = ">= 1.7.0"
    }

    helm = {
      source  = "hashicorp/helm"
      version = "2.6.0"
    }
  }
}


provider "kind" {}




resource "kind_cluster" "default" {
  name           = "test-cluster"
  wait_for_ready = true
  node_image     = "kindest/node:v1.21.12"

  kind_config {
    kind        = "Cluster"
    api_version = "kind.x-k8s.io/v1alpha4"

    node {
      role = "control-plane"

      kubeadm_config_patches = [
        "kind: InitConfiguration\nnodeRegistration:\n  kubeletExtraArgs:\n    node-labels: \"ingress-ready=true\"\n"
      ]

      extra_port_mappings {
        container_port = 80
        host_port      = 80
      }
      extra_port_mappings {
        container_port = 443
        host_port      = 443
      }
    }

    node {
      role = "worker"
    }
  }
}


provider "kubectl" {
  host                   = kind_cluster.default.endpoint
  cluster_ca_certificate = kind_cluster.default.cluster_ca_certificate
  client_certificate     = kind_cluster.default.client_certificate
  client_key             = kind_cluster.default.client_key
}



data "kubectl_file_documents" "docs" {
  content = file("ingress/ingress-ngnix.yaml")
}


resource "kubectl_manifest" "ingress-controller" {
  for_each  = data.kubectl_file_documents.docs.manifests
  yaml_body = each.value

  depends_on = [kind_cluster.default]
}


provider "helm" {
  kubernetes {
    host                   = kind_cluster.default.endpoint
    cluster_ca_certificate = kind_cluster.default.cluster_ca_certificate
    client_certificate     = kind_cluster.default.client_certificate
    client_key             = kind_cluster.default.client_key
  }
}



resource "helm_release" "cert-manager" {
  name             = "cert-manager"
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  namespace        = "cert-manager"
  version          = "v1.7.1"
  create_namespace = true

  depends_on = [kubectl_manifest.ingress-controller]

  set {
    name  = "installCRDs"
    value = true
  }
}





resource "helm_release" "rancher" {
  name = "rancher"

  repository       = "https://releases.rancher.com/server-charts/latest"
  chart            = "rancher"
  namespace        = "cattle-system"
  version          = "2.6.7"
  create_namespace = true

  depends_on = [helm_release.cert-manager]
  set {
    name  = "hostname"
    value = "rancher.my.org"
  }
  set {
    name  = "bootstrapPassword"
    value = "admin"
  }
}


#resource "helm_release" "longhorn" {
#  name = "longhorn"
#
#  repository       = "https://charts.longhorn.io"
#  chart            = "longhorn"
#  namespace        = "longhorn-system"
#  version          = "1.3.1"
#  create_namespace = true

#  depends_on = [helm_release.rancher]
#  set {
#    name  = "ingressEnable"
#    value = "true"
#  }
#  set {
#    name  = "ingressHost"
#    value = "longhorn.my.org"
#  }
#}