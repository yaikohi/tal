resource "kubernetes_deployment" "nginx" {
  metadata {
    name = "nginx-test"
  }
  spec {
    replicas = 2
    selector {
      match_labels = {
        app = "nginx-test"
      }
    }
    template {
      metadata {
        labels = {
          app = "nginx-test"
        }
      }
      spec {
        container {
          image = "nginx:latest"
          name  = "nginx"
        }
      }
    }
  }
}

resource "kubernetes_service" "nginx" {
  metadata {
    name = "nginx-test"
  }
  spec {
    selector = {
      app = kubernetes_deployment.nginx.spec[0].selector[0].match_labels.app
    }
    port {
      port        = 80
      target_port = 80
    }
    type = "LoadBalancer"
  }
}

output "lb_ip" {
  value = kubernetes_service.nginx.status.0.load_balancer.0.ingress.0.ip
}
