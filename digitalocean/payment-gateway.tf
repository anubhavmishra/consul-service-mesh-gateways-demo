resource "kubernetes_deployment" "payment_gateway" {
  depends_on = [helm_release.consul]

  metadata {
    name = "payment-gateway"
    labels = {
      app = "payment-gateway"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "payment-gateway"
      }
    }

    template {
      metadata {
        labels = {
          app     = "payment-gateway"
          version = "v0.1"
        }

        annotations = {
          "consul.hashicorp.com/connect-inject"            = "true"
          "consul.hashicorp.com/connect-service-upstreams" = "currency:9091"
          "consul.hashicorp.com/connect-service-name"      = "payment-gateway"
        }
      }

      spec {
        container {
          image = "nicholasjackson/fake-service:v0.7.8"
          name  = "payment-gateway"

          port {
            name           = "http"
            container_port = 9090
          }

          env {
            name  = "LISTEN_ADDR"
            value = "0.0.0.0:9090"
          }

          env {
            name  = "UPSTREAM_URIS"
            value = "http://localhost:9091"
          }

          env {
            name  = "MESSAGE"
            value = "successfully used the payment gateway in digitalocean."
          }

          env {
            name  = "NAME"
            value = "Payment Gateway"
          }

          resources {
            limits {
              cpu    = "0.5"
              memory = "512Mi"
            }
            requests {
              cpu    = "0.1"
              memory = "50Mi"
            }
          }
        }
      }
    }
  }
}