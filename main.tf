provider "aws" {
    region = "us-east-1" 
}

# 1. Created an S3 Bucket for the Static Website
resource "aws_s3_bucket" "website_bucket" {
    bucket = "osho-resume-2" 
    force_destroy = true   

    tags = {
        Name = "StaticWebsiteBucket"
    }
}

resource "aws_s3_bucket_website_configuration" "website_config" {
    bucket = aws_s3_bucket.website_bucket.id

    index_document {
        suffix = "index.html"
    }

    error_document {
        key = "error.html"
    }
}

resource "aws_s3_bucket_public_access_block" "website_bucket_public_access_block" {
    bucket = aws_s3_bucket.website_bucket.id

    block_public_acls       = false
    block_public_policy     = false
    ignore_public_acls      = false
    restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "website_bucket_policy" {
    bucket = aws_s3_bucket.website_bucket.id

    policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
            {
                Sid       = "PublicReadGetObject"
                Effect    = "Allow"
                Principal = "*"
                Action    = "s3:GetObject"
                Resource  = "${aws_s3_bucket.website_bucket.arn}/*"
            }
        ]
    })
}

# 2. CloudFront Distribution
resource "aws_cloudfront_distribution" "cdn" {
    origin {
        domain_name = aws_s3_bucket.website_bucket.bucket_regional_domain_name
        origin_id   = "S3-osho-resume"
    }

    enabled             = true
    default_root_object = "index.html"

    default_cache_behavior {
        target_origin_id       = "S3-osho-resume"
        viewer_protocol_policy = "redirect-to-https"

        allowed_methods = ["GET", "HEAD"]
        cached_methods  = ["GET", "HEAD"]

        forwarded_values {
            query_string = false

            cookies {
                forward = "none"
            }
    }
        min_ttl     = 0
        default_ttl = 3600
        max_ttl     = 86400
    }

    viewer_certificate {
        cloudfront_default_certificate = true
    }

    restrictions {
        geo_restriction {
            restriction_type = "none"
        }
    }

    tags = {
        Name = "CloudFrontForWebsite"
    }
}

# 3. IAM Role for GitHub Actions
resource "aws_iam_role" "github_actions_role" {
    name = "githubactionsrole"

    assume_role_policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
            {
                Effect = "Allow"
                Principal = {
                    Federated = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/token.actions.githubusercontent.com"
                }
                Action = "sts:AssumeRoleWithWebIdentity"
                Condition = {
                    StringEquals = {
                        "token.actions.githubusercontent.com:sub" = "repo:Amiekhame/resume_challenge:ref:refs/heads/main"
                    }
                }
            }
        ]
    })
}

data "aws_caller_identity" "current" {}

# 4. IAM Policy for CloudFront Invalidations
resource "aws_iam_policy" "cloudfront_invalidation_policy" {
    name        = "CloudFrontInvalidationPolicy"
    description = "Policy to allow GitHub Actions to invalidate CloudFront cache"

    policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
            {
                Effect   = "Allow"
                Action   = "cloudfront:CreateInvalidation"
                Resource = "arn:aws:cloudfront::${data.aws_caller_identity.current.account_id}:distribution/${aws_cloudfront_distribution.cdn.id}"
            }
        ]
    })
}

# Attach Policy to Role
resource "aws_iam_role_policy_attachment" "attach_policy" {
    role       = aws_iam_role.github_actions_role.name
    policy_arn = aws_iam_policy.cloudfront_invalidation_policy.arn
}

# Outputs
output "s3_bucket_name" {
    value = aws_s3_bucket.website_bucket.bucket
}

output "cloudfront_distribution_id" {
    value = aws_cloudfront_distribution.cdn.id
}

output "cloudfront_distribution_domain_name" {
    value = aws_cloudfront_distribution.cdn.domain_name
}

output "cloudfront_url" {
    value = "https://${aws_cloudfront_distribution.cdn.domain_name}"
}
