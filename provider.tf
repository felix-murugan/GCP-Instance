terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "6.33.0"
    }
  }
}

provider "google" {
  project     = var.project_id
  region      = var.region
  credentials = "digidense-lp.json"
}

provider "tls" {
  // no config needed
}

