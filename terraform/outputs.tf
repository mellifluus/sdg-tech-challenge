output "networks" {
  description = "Docker networks created by the stack."
  value = {
    data = docker_network.data.name
  }
}
