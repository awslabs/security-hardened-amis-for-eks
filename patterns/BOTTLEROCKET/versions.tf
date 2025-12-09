terraform {
  backend "s3" {
    bucket  = "BUCKET_NAME"
    key     = "BOTTLEROCKET"
    region  = "us-west-2"
    encrypt = true
  }
}