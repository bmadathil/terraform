terraform {
  backend "s3" {
    bucket         = "tech-chal-unique-terraform-state-bucket"
    key            = "terraform/state/terraform.tfstate"
    region         = "us-east-1"                     
  }
}

