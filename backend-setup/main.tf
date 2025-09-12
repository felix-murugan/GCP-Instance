terraform {
  backend "local" {
    path = "terraform-backend-bucket.tfstate"
  }
}

provider "google" {
  project = "swagger-470910"
  region  = "us-central1"
}

resource "google_storage_bucket" "tf_state" {
  name                        = "my-terraform-state-bucket"  # Must match your main backend
  location                    = "us-central1"
  uniform_bucket_level_access = true

  versioning {
    enabled = true  # Keeps backup versions of your state
  }
}
