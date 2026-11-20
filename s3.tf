locals {
  # S3 bucket names are limited to 63 characters: truncate the bucket name to fit the "-access-logs" suffix,
  # and trim any "-" or "." the truncation leaves at the end
  access_logs_bucket_name = "${trim(substr(var.bucket_name, 0, 51), "-.")}-access-logs"
}

data "aws_iam_policy_document" "logs_bucket" {
  statement {
    sid     = "AllowSESPuts"
    actions = ["s3:PutObject"]

    principals {
      type        = "Service"
      identifiers = ["ses.amazonaws.com"]
    }

    resources = ["arn:aws:s3:::${var.bucket_name}/*"]

    condition {
      test     = "StringEquals"
      variable = "aws:Referer"
      values   = [local.account_id]
    }
  }
}

module "s3_bucket" {
  #checkov:skip=CKV_AWS_19: False positive: https://github.com/bridgecrewio/checkov/issues/3847. The S3 bucket created by this module supports encryption with KMS.
  #checkov:skip=CKV_AWS_145: False positive: https://github.com/bridgecrewio/checkov/issues/3847. The S3 bucket created by this module support encryption with KMS.
  source  = "schubergphilis-ep/mcaf-s3/aws"
  version = "~> 4.0.0"

  region         = local.account_region
  name           = var.bucket_name
  kms_key_arn    = var.kms_key_arn
  lifecycle_rule = var.bucket_lifecycle_rules
  policy         = data.aws_iam_policy_document.logs_bucket.json
  tags           = var.tags

  logging = var.s3_access_logging.enabled ? {
    target_bucket = module.access_logs[0].name
    target_prefix = "logs/"
    target_object_key_format = {
      format_type           = "partitioned"
      partition_date_source = "EventTime"
    }
  } : null
}

# S3 bucket to store the server access logs of the SES forwarder bucket
module "access_logs" {
  count = var.s3_access_logging.enabled ? 1 : 0

  source  = "schubergphilis-ep/mcaf-s3/aws"
  version = "~> 4.0.0"

  region = local.account_region
  name   = local.access_logs_bucket_name
  tags   = var.tags

  lifecycle_rule = [
    {
      id      = "RetentionPolicy"
      enabled = true

      abort_incomplete_multipart_upload = {
        days_after_initiation = 3
      }

      expiration = {
        days = var.s3_access_logging.expiration_days
      }

      noncurrent_version_expiration = {
        noncurrent_days = 7
      }

      transition = [
        {
          days          = var.s3_access_logging.transition_days
          storage_class = var.s3_access_logging.transition_storage_class
        }
      ]
    },
    {
      id         = "expired-delete-markers"
      enabled    = true
      expiration = { expired_object_delete_marker = true }
    },
  ]

  logging_source_bucket_arns = [module.s3_bucket.arn]
}
