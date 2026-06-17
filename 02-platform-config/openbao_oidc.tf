# Super-admin policy used by the OIDC admin role.
#
# The OIDC auth backend and its `admin` role themselves are NOT managed by
# Terraform: hashicorp/vault's `vault_jwt_auth_backend` resource is
# incompatible with OpenBao's `oidc`-typed mount (both import and create/PUT
# against /v1/auth/oidc/config fail). There is no openbao/openbao provider
# in either registry as of writing.
#
# Bootstrap OIDC manually once with the `bao` CLI (see
# tal/docs/OPENBAO-RUNBOOK.md, section "Bootstrap OIDC manually"); the
# admin role binds back to this policy.
resource "vault_policy" "super_admin" {
  name   = "super-admin"
  policy = <<EOT
path "*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}
EOT
}
