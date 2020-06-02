
terraform {
    required_version = ">= 0.12.0"
    required_providers {
        google = "3.23.0"
        random = "~> 2.2"
    }
}

provider "google" {
    region = var.region
    credentials = var.creds
    project = "andybaran-seedproject"
}

resource "random_id" "id" {
    byte_length = 4
    prefix = var.project_name
}

resource "google_project" "project" {
    name = var.project_name
    project_id = random_id.id.hex
    folder_id = var.folder_id
    billing_account = var.billing_account
    auto_create_network = false
    
    lifecycle {
            prevent_destroy = true
    }
}

resource "google_project_service" "common_services" {
    for_each = toset([
        "compute.googleapis.com",
        "logging.googleapis.com",
        "monitoring.googleapis.com",
        "storage-component.googleapis.com",
    ])
    
    service = each.key
    project =  google_project.project.project_id
    disable_dependent_services = true
  }

resource "google_project_service" "requested_services" {
    for_each = toset(var.requested_services)
    
    service = each.key
    project =  google_project.project.project_id
    disable_dependent_services = true
}


# We need compute engine api enabled before we can create networks
resource "google_compute_network" "provisioning-vpc" {

  depends_on = [google_project_service.common_services]
  
  name = "provisioning-vpc"
  project = google_project.project.project_id
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "provisioning-subnet" {
  name          = join("",[google_project.project.name,"-primary-subnet"])
  ip_cidr_range = "10.10.0.0/16"
  project       = google_project.project.project_id
  region        = var.region
  network       = google_compute_network.provisioning-vpc.self_link
  secondary_ip_range {
    range_name    = join("",[google_project.project.name,"-secondary-range"])
    ip_cidr_range = "192.168.10.0/24"
  }
}

resource "google_service_account" "admin_service_account" {
  account_id   = "admin-gcpkms"
  display_name = "Admin service account for GCP"
  project =  google_project.project.project_id
  depends_on = [google_project.project]
}

resource "google_project_iam_member" "proj_owners" {
    project = google_project.project.id
    role = "roles/owner"

    members = [
      "serviceAccount:google_service_account.admin_service_account.email",
      "user:andy.baran@hashicorp.com",
    ]
}