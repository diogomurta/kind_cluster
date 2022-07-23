terraform {
  required_providers {
    kind = {
      source  = "tehcyx/kind"
      version = "0.0.12"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = ">= 1.7.0"
    }
  }
}



provider "kind" {}

resource "kind_cluster" "default" {
  name           = "test-cluster"
  wait_for_ready = true
  node_image     = "kindest/node:v1.20.15"

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
}