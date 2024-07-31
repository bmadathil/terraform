provider "kubernetes" {
  config_path = "<path-to-your-kubeconfig>"
}

provider "helm" {
  kubernetes {
    config_path = "<path-to-your-kubeconfig>"
  }
}

resource "kubernetes_namespace" "argocd" {
  metadata {
    name = "argocd"
  }
}

resource "helm_release" "argocd" {
  name       = "argocd"
  namespace  = kubernetes_namespace.argocd.metadata[0].name
  chart      = "./argo-cd"  # Adjust the path to your local chart
  skip_crds  = true

  set {
    name  = "server.extraArgs[0]"
    value = "--insecure"
  }

  depends_on = [kubernetes_namespace.argocd]
}

resource "kubernetes_manifest" "gitops_ingress_route" {
  manifest = {
    apiVersion = "traefik.io/v1alpha1"
    kind       = "IngressRoute"
    metadata = {
      name      = "gitops"
      namespace = "argocd"
    }
    spec = {
      entryPoints = ["websecure"]
      routes = [{
        match = "Host(`gitops.splunk.sandbox.cvpcorp.io`)"  # Adjust the host
        kind  = "Rule"
        services = [{
          name      = "argocd-server"
          kind      = "Service"
          namespace = "argocd"
          port      = 80
        }]
      }]
      tls = {
        certResolver = "le"
      }
    }
  }
}

resource "kubernetes_manifest" "argo_application" {
  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = "myapp-argo-application"
      namespace = "argocd"
    }
    spec = {
      project = "default"
      source = {
        repoURL         = "https://gitlab.com/nanuchi/argocd-app-config.git"
        targetRevision  = "HEAD"
        path            = "dev"
      }
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = "myapp"
      }
      syncPolicy = {
        syncOptions = ["CreateNamespace=true"]
        automated = {
          selfHeal = true
          prune    = true
        }
      }
    }
  }
}

