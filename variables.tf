variable "project_id" {
  description = "GCP project ID"
  type        = string
  default     = "swagger-470910"
}

variable "region" {
  description = "Region to deploy into"
  default     = "us-central1-a"
}

variable "zone" {
  description = "Zone to deploy into"
  default     = "us-central1-a"
}


variable "ssh_user" {
  description = "Linux username for SSH access"
  type        = string
  default     = "terraform"
}

variable "github_token" {
  type        = string
  description = "GitHub token for cloning private repo"
}
