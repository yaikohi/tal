variable "kubeconfig_path" {
  type = string
}
variable "lb_cidr" {
  type        = string
  description = "CIDR for LoadBalancer IPs"
}
