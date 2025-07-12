terraform {
  backend "gcs" {
    bucket = "zentraflow-terraform-state"
    prefix = "terraform/state"
  }
}
