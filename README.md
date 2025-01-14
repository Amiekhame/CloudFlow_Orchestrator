# Project Documentation

## Overview

This project sets up a static website hosted on AWS using Terraform. The infrastructure includes an S3 bucket for hosting the website, a CloudFront distribution for content delivery, and IAM configurations to enable GitHub Actions for deployment and cache invalidations.

---

## Requirements

- **AWS Account**: Ensure you have access to an AWS account.
- **Terraform**: Install Terraform CLI.
- **GitHub Repository**: Repository with the necessary GitHub Actions configurations.

---

## Steps to Deploy the Infrastructure

### 1. Provider Configuration

The `provider` block specifies the AWS region where resources will be created:

```hcl
provider "aws" {
    region = "us-east-1"
}
```

---

### 2. S3 Bucket for Static Website

The project creates an S3 bucket to host the static website. The key configurations include:

- **Bucket Name**: `osho-resume-2`
- **Force Destroy**: Allows automatic deletion of bucket contents when destroyed.
- **Website Configuration**: Configures `index.html` as the main page and `error.html` for error handling.
- **Public Access**: Grants public read access to objects.

#### Code

```hcl
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
```

---

### 3. CloudFront Distribution

A CloudFront distribution is set up to serve the website efficiently:

- **Origin**: Points to the S3 bucket.
- **Default Behavior**: Redirects HTTP to HTTPS and caches content.
- **Certificate**: Uses the default CloudFront certificate.

#### Code2

```hcl
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
```

---

### 4. IAM Role and Policy for GitHub Actions

To automate deployments, an IAM role and policy are created:

- **IAM Role**: Grants permissions for GitHub Actions to assume the role.
- **CloudFront Invalidations**: Allows GitHub Actions to invalidate the CloudFront cache after deployment.

#### Code3

```hcl
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

resource "aws_iam_role_policy_attachment" "attach_policy" {
    role       = aws_iam_role.github_actions_role.name
    policy_arn = aws_iam_policy.cloudfront_invalidation_policy.arn
}
```

---

### 5. Outputs

The Terraform script outputs key information:

- S3 Bucket Name
- CloudFront Distribution ID
- CloudFront Domain Name
- CloudFront URL

#### Code4

```hcl
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
```

---

## Deployment Instructions

1. **Initialize Terraform**:

   ```bash
   terraform init
   ```

2. **Plan the Infrastructure**:

   ```bash
   terraform plan
   ```

3. **Apply the Configuration**:

   ```bash
   terraform apply
   ```

   Confirm the changes when prompted.

4. **Access the Website**:
   - Use the CloudFront URL from the outputs to access the deployed website.
