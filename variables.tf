variable "allow_plus_sign" {
  type        = bool
  default     = true
  description = "Enables support for plus sign suffixes on email addresses"
}

variable "bucket_lifecycle_rules" {
  type = list(any)
  default = [
    {
      id      = "two-week-retention"
      enabled = true

      expiration = {
        days = 14
      }

      noncurrent_version_expiration = {
        noncurrent_days = 14
      }
    }
  ]
  description = "S3 bucket lifecycle rules"
}

variable "bucket_name" {
  type        = string
  description = "S3 bucket name where SES stores emails"
}

variable "bucket_prefix" {
  type        = string
  default     = "inbound-mail"
  description = "S3 key name prefix where SES stores email"
}

variable "from_email" {
  type        = string
  description = "Forwarded emails will come from this verified address"
}

variable "kms_key_arn" {
  type        = string
  default     = null
  description = "KMS key ARN used for encryption"
}

variable "lambda_name" {
  type        = string
  default     = "EmailForwarder"
  description = "The name of the Lambda function"
}

variable "recipient_mapping" {
  type        = map(any)
  description = "Map of recipients and the addresses to forward on to"
}

variable "region" {
  type        = string
  default     = null
  description = "The AWS region where the resources will be created. If omitted, the default provider region is used."
}

variable "s3_access_logging" {
  type = object({
    enabled                  = optional(bool, true)
    expiration_days          = optional(number, 720)
    transition_days          = optional(number, 90)
    transition_storage_class = optional(string, "GLACIER_IR")
  })
  default     = {}
  nullable    = false
  description = "S3 server access logging configuration for the SES forwarder bucket. 'expiration_days' and 'transition_days' set the retention of the access logs."

  validation {
    condition     = var.s3_access_logging.expiration_days > var.s3_access_logging.transition_days
    error_message = "'s3_access_logging.expiration_days' must be greater than 's3_access_logging.transition_days'."
  }
}

variable "ses_rule_name" {
  type        = string
  default     = "EmailForwarder"
  description = "The name of the SES rule that invokes the Lambda function"
}

variable "ses_rule_set_name" {
  type        = string
  default     = "EmailForwarder"
  description = "The name of the active Rule Set in SES which you have already configured"
}

variable "subject_prefix" {
  type        = string
  default     = ""
  description = "String to prepend to the subject of forwarded mail"
}

variable "tags" {
  type        = map(string)
  default     = null
  description = "Map of tags to set on Terraform created resources"
}
