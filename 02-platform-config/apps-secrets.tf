########################################
# Application secrets seeded into OpenBao KVv2 (apps/*).
#
# Per-app paths are read in-cluster by the External Secrets Operator
# using the Kubernetes auth roles defined in kubernetes-auth.tf.
########################################

# ------------------------------------------------------------------
# Homepage: ArgoCD API token for the read-only `homepagesa` account.
# The argocd_account_token resource manages token lifecycle in ArgoCD
# itself; the JWT is stored only in OpenBao, never as a K8s Secret in
# git.
# ------------------------------------------------------------------
resource "argocd_account_token" "homepagesa" {
  account = "homepagesa"
  # No expires_in -> long-lived. Rotate by tainting this resource.
}

# ------------------------------------------------------------------
# *arr API keys — written to OpenBao, consumed by:
#   1. media/arr-keys Secret (init containers seed config.xml; exportarr sidecars)
#   2. apps/homepage Secret (homepage widgets)
# radarr/sonarr/prowlarr are auto-generated (random_id) and injected into the
# apps. lidarr/jellyfin/seerr are sourced from the SAME vars the homepage secret
# uses (below), so the value the media stack injects/scrapes matches the value
# the homepage widget queries with. Keep these two resources in lock-step:
# `media/arr-keys.<x> == homepage.HOMEPAGE_VAR_<X>`.
# Rotate a generated key by `tofu taint random_id.<name>_api_key && tofu apply`,
# then restart the corresponding deployment.
# ------------------------------------------------------------------
resource "random_id" "radarr_api_key" { byte_length = 16 }
resource "random_id" "sonarr_api_key" { byte_length = 16 }
resource "random_id" "prowlarr_api_key" { byte_length = 16 }

resource "vault_kv_secret_v2" "media_arr_keys" {
  mount = vault_mount.kvv2.path
  name  = "media/arr-keys"

  data_json = jsonencode({
    radarr-api-key   = random_id.radarr_api_key.hex
    sonarr-api-key   = random_id.sonarr_api_key.hex
    prowlarr-api-key = random_id.prowlarr_api_key.hex
    lidarr-api-key = var.lidarr_api_key
    jellyfin-api-key = var.jellyfin_api_key
    seerr-api-key    = var.seerr_api_key
  })
}

# ------------------------------------------------------------------
# Homepage secret — all env vars the homepage pod needs.
# `HOMEPAGE_SERVICE_ACCOUNT_API_TOKEN` is kept for the existing
# ArgoCD ServiceAccount lookup; `HOMEPAGE_VAR_*` are widget creds.
# ------------------------------------------------------------------
resource "vault_kv_secret_v2" "homepage" {
  mount = vault_mount.kvv2.path
  name  = "homepage"

  data_json = jsonencode({
    HOMEPAGE_SERVICE_ACCOUNT_API_TOKEN = argocd_account_token.homepagesa.jwt
    HOMEPAGE_VAR_ARGOCD_KEY            = argocd_account_token.homepagesa.jwt
    HOMEPAGE_VAR_RADARR_KEY            = random_id.radarr_api_key.hex
    HOMEPAGE_VAR_SONARR_KEY            = random_id.sonarr_api_key.hex
    HOMEPAGE_VAR_PROWLARR_KEY          = random_id.prowlarr_api_key.hex
    HOMEPAGE_VAR_JELLYFIN_KEY          = var.jellyfin_api_key
    HOMEPAGE_VAR_IMMICH_KEY            = var.immich_api_key
    HOMEPAGE_VAR_QBIT_USERNAME         = var.qbit_username
    HOMEPAGE_VAR_QBIT_PASSWORD         = var.qbit_password
    HOMEPAGE_VAR_LIDARR_KEY            = var.lidarr_api_key
    HOMEPAGE_VAR_SABNZBD_KEY           = var.sabnzbd_api_key
    HOMEPAGE_VAR_SEERR_KEY             = var.seerr_api_key
  })
}

# ------------------------------------------------------------------
# Media downloader VPN credentials (consumed by gluetun in the media ns).
# ------------------------------------------------------------------
resource "vault_kv_secret_v2" "media_vpn" {
  mount = vault_mount.kvv2.path
  name  = "media/vpn"

  data_json = jsonencode({
    vpn-provider          = var.media_vpn_provider
    wireguard-private-key = var.media_wireguard_private_key
    wireguard-addresses   = var.media_wireguard_addresses
    qbit-webui-password = var.qbit_password
    qbit-api-key = "unused"
  })
}

# ------------------------------------------------------------------
# Zot self-hosted registry (registry.ykhi.xyz) credentials.
#   htpasswd -> consumed by the zot pod's auth (yaya-ops zot-htpasswd ExternalSecret).
#   username/password -> the SAME credential in plaintext, for building a
#     dockerconfigjson pull secret in consumer namespaces (e.g. agrelha) and for
#     `docker login registry.ykhi.xyz` when pushing from the dev machine.
# The htpasswd line MUST hash the same password stored in `password`. Generate it
# once (deterministic, no bcrypt-per-apply churn):  htpasswd -nbB ci '<password>'
# and set both var.zot_htpasswd and var.zot_password in secret.tfvars.
# ------------------------------------------------------------------
resource "vault_kv_secret_v2" "zot" {
  mount = vault_mount.kvv2.path
  name  = "zot"

  data_json = jsonencode({
    htpasswd = var.zot_htpasswd
    username = var.zot_username
    password = var.zot_password
  })
}

# ------------------------------------------------------------------
# Immich DB credentials (shared by the postgres chart and the immich app).
# ------------------------------------------------------------------
resource "vault_kv_secret_v2" "immich_db" {
  mount = vault_mount.kvv2.path
  name  = "immich/db"

  data_json = jsonencode({
    password = var.immich_db_password
    postgres-password = var.immich_db_password
    DB_PASSWORD = var.immich_db_password
  })
}
