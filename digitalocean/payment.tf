resource "kubernetes_deployment" "payment" {
  depends_on = [helm_release.consul]

  metadata {
    name = "payment"
    labels = {
      app = "payment"
    }
  }

  spec {
    replicas = 2

    selector {
      match_labels = {
        app = "payment"
      }
    }

    template {
      metadata {
        labels = {
          app     = "payment"
          version = "v0.1"
        }

        annotations = {
          "consul.hashicorp.com/connect-inject"            = "true"
          "consul.hashicorp.com/connect-service-upstreams" = "currency:9091"
          "consul.hashicorp.com/connect-service-name"      = "payment"
        }
      }

      spec {
        container {
          image = "nicholasjackson/fake-service:v0.4.1"
          name  = "payment"

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
            value = "payment successful from digitalocean."
          }

          env {
            name  = "NAME"
            value = "Payment"
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