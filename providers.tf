provider "aws" {
  region = var.AWS_region

  default_tags {
    tags = {
      Name               = var.tag_name
      Owner              = var.tag_owner_email
      Manager            = var.tag_manager_email
      Team               = var.tag_team_email
      Description        = var.tag_description
      Environment        = var.tag_environment
      DataClassification = var.tag_dataclassification
      ManagedBy          = "Terraform"
    }
  }
}

# AWS Provider for us-east-1 (Required by CloudFront ACM certificates)
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"

  default_tags {
    tags = {
      Name               = var.tag_name
      Owner              = var.tag_owner_email
      Manager            = var.tag_manager_email
      Team               = var.tag_team_email
      Description        = var.tag_description
      Environment        = var.tag_environment
      DataClassification = var.tag_dataclassification
      ManagedBy          = "Terraform"
    }
  }
}

provider "incapsula" {
  api_id  = var.incapsula_api_id
  api_key = var.incapsula_api_key
}

# NS1 DNS Provider
provider "ns1" {
  apikey = var.ns1_api_key
}
