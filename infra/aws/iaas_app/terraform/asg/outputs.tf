output "ignition_file" {
  value = data.ignition_config.main.rendered
}