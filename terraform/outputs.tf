output "bucket_name" {
  description = "Name of the created GCS bucket"
  value       = google_storage_bucket.demo_bucket.name
}

output "bucket_url" {
  description = "URL of the created GCS bucket"
  value       = google_storage_bucket.demo_bucket.url
}

output "bucket_location" {
  description = "Location of the created GCS bucket"
  value       = google_storage_bucket.demo_bucket.location
}

output "demo_object_name" {
  description = "Name of the demo object in the bucket"
  value       = google_storage_bucket_object.demo_object.name
}

output "project_id" {
  description = "GCP Project ID"
  value       = var.project_id
}

output "region" {
  description = "GCP Region"
  value       = var.region
}

output "environment" {
  description = "Environment"
  value       = var.environment
}
