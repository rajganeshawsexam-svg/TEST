resource "aws_s3_bucket" "media" {
  bucket        = "payload-media-${var.env}-${data.aws_caller_identity.current.account_id}"
  force_destroy = true
  tags = merge(var.tags, {
    Name = "payload-media-${var.env}"
  })
}
data "aws_caller_identity" "current" {}


resource "aws_s3_bucket_versioning" "versioning" {
  bucket = aws_s3_bucket.media.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "lifecycle" {
  bucket = aws_s3_bucket.media.id

  rule {
    id     = "archive-old-media"
    status = "Enabled"

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 90
      storage_class = "GLACIER"
    }

    expiration {
      days = 365
    }
  }
}

resource "aws_s3_bucket_public_access_block" "public_access" {
  bucket                  = aws_s3_bucket.media.id
  block_public_acls        = true
  block_public_policy      = true
  ignore_public_acls       = true
  restrict_public_buckets  = true
}

