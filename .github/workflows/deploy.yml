name: Deploy to GCP VM

on:
  push:
    branches:
      - main   # Trigger on push to main

jobs:
  terraform:
    runs-on: ubuntu-latest

    steps:
      # Checkout repo
      - name: Checkout
        uses: actions/checkout@v4

      # Setup Terraform
      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3

      # Authenticate with GCP using service account JSON from GitHub Secrets
      - name: Authenticate to GCP
        id: auth
        uses: google-github-actions/auth@v2
        with:
          credentials_json: ${{ secrets.GCP_CREDENTIALS }}

      # Setup gcloud CLI (uses auth credentials from above step)
      - name: Set up gcloud CLI
        uses: google-github-actions/setup-gcloud@v2
        with:
          project_id: ${{ secrets.GCP_PROJECT_ID }}
          install_components: gke-gcloud-auth-plugin
          export_default_credentials: true

      # 🔍 Debug step - confirm authentication worked
      - name: Verify GCP Key & Auth
        run: |
          echo "Using credentials file: $GOOGLE_APPLICATION_CREDENTIALS"
          echo "Key details:"
          cat $GOOGLE_APPLICATION_CREDENTIALS | jq '.client_email, .project_id'

          echo "Activating service account..."
          gcloud auth activate-service-account --key-file=$GOOGLE_APPLICATION_CREDENTIALS

          echo "Listing active accounts..."
          gcloud auth list

          echo "Describing project..."
          gcloud projects describe ${{ secrets.GCP_PROJECT_ID }}

      # Terraform Init
      - name: Terraform Init
        run: terraform init

      # Terraform Plan
      - name: Terraform Plan
        run: terraform plan -out=tfplan

      # Terraform Apply
      - name: Terraform Apply
        run: terraform apply -auto-approve tfplan

      # Show Terraform Outputs (e.g. VM external IP)
      - name: Show VM Outputs
        run: terraform output
