variable "project_id" {
  description = "GCP project ID"
  type        = string
  default     = "green-global-467406"
}

variable "region" {
  default     = "us-central1"
  description = "Region to deploy into"
}

variable "zone" {
  default     = "us-central1-a"
  description = "Zone to deploy intos"
}

variable "instance_count" {
  description = "Number of VM instances to create"
}
