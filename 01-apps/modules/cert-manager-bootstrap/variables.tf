variable "cloudflare_api_token" {
  description = "Cloudflare API token used by cert-manager for DNS01 ACME challenges. Needs Zone:Read + DNS:Edit on the target zone."
  type        = string
  sensitive   = true
}

variable "namespace" {
  description = "Namespace cert-manager will run in. Pre-created so the DNS01 token Secret can exist before the cert-manager Argo app reconciles."
  type        = string
  default     = "cert-manager"
}

variable "secret_name" {
  description = "Name of the Secret referenced by the ClusterIssuer's apiTokenSecretRef."
  type        = string
  default     = "cloudflare-api-token-secret"
}
