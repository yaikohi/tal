variable "persistence_enabled" {
  description = "Enable persistent storage for PostgreSQL"
  type        = bool
  default     = true
}

variable "postgres_password" {
  description = "Password for the PostgreSQL postgres superuser"
  type        = string
  default     = "immich-postgres-password"
  sensitive   = true
}

variable "db_username" {
  description = "Database username for Immich"
  type        = string
  default     = "immich"
}

variable "db_password" {
  description = "Database password for Immich user"
  type        = string
  default     = "immich-password"
  sensitive   = true
}

variable "db_name" {
  description = "Database name for Immich"
  type        = string
  default     = "immich"
}

variable "storage_class" {
  description = "Storage class for PostgreSQL persistence"
  type        = string
  default     = ""
}

variable "storage_size" {
  description = "Storage size for PostgreSQL"
  type        = string
  default     = "20Gi"
}
