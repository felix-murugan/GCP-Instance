variable "project_id" {
  description = "GCP project ID"
  type        = string
  default     = "red-global-467504"
}

variable "region" {
  default     = "us-central1-a"
  description = "Region to deploy into"
}

variable "zone" {
  default     = "us-central1-a"
  description = "Zone to deploy into"
}

variable "instance_count" {
  description = "Number of VM instances to create"
  default     = 1
}
