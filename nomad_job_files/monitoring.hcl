job "monitoring" {
  datacenters = ["dc1"]

  type = "service"

  constraint {
    attribute = "${attr.cpu.arch}"
    operator  = "!="
    value     = "arm"
  }

  group "monitoring" {
    count = 1

    restart {
      attempts = 10
      interval = "5m"
      delay    = "25s"
      mode     = "delay"
    }

    task "prometheus" {
      driver = "docker"

			artifact {
			  source      = "https://raw.githubusercontent.com/takuan-osho/faas-nomad/dev/test/nomad_job_files/monitoring.hcl"
			  destination = "local/prometheus.yml.tpl"
				mode        = "file"
			}

      template {
        source        = "local/prometheus.yml.tpl"
        destination   = "/etc/prometheus/prometheus.yml"
        change_mode   = "noop"
        change_signal = "SIGINT"
      }

      config {
        image = "prom/prometheus:v2.3.1"

        args = [
          "--config.file=/etc/prometheus/prometheus.yml",
          "--storage.tsdb.path=/prometheus",
          "--storage.tsdb.retention=180d",
        ]

        dns_servers = ["${NOMAD_IP_http}", "8.8.8.8", "8.8.8.4"]

        port_map {
          http = 9090
        }

        volumes = [
          "etc/prometheus/prometheus.yml:/etc/prometheus/prometheus.yml",
        ]
      }

      resources {
        cpu    = 200 # 200 MHz
        memory = 256 # 256MB

        network {
          mbits = 10

          port "http" {
            static = 9090
          }
        }
      }

      service {
        port = "http"
        name = "prometheus"
        tags = ["monitoring"]

        check {
          type     = "http"
          port     = "http"
          interval = "10s"
          timeout  = "2s"
          path     = "/graph"
        }
      }
    }

    task "grafana" {
      driver = "docker"

      config {
        image = "grafana/grafana:5.2.1"

        port_map {
          http = 3000
        }
      }

      resources {
        cpu    = 200 # 500 MHz
        memory = 256 # 256MB

        network {
          mbits = 10

          port "http" {
            static = 3000
          }
        }
      }
    }
  }
}
