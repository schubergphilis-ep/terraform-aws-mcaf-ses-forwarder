mock_provider "archive" {}

mock_provider "aws" {
  override_data {
    target = data.aws_region.default
    values = {
      region = "eu-west-1"
    }
  }

  override_data {
    target = data.aws_caller_identity.default
    values = {
      account_id = "123456789012"
    }
  }

  override_data {
    target = data.aws_iam_policy_document.lambda_policy
    values = {
      json = "{}"
    }
  }

  override_data {
    target = data.aws_iam_policy_document.logs_bucket
    values = {
      json = "{}"
    }
  }

  mock_resource "aws_sqs_queue" {
    defaults = {
      arn = "arn:aws:sqs:eu-west-1:123456789012:fake-queue"
    }
  }
}

override_module {
  target = module.s3_bucket
  outputs = {
    id   = "ses-forwarder-test"
    name = "ses-forwarder-test"
    arn  = "arn:aws:s3:::ses-forwarder-test"
  }
}

override_module {
  target = module.access_logs
  outputs = {
    name = "ses-forwarder-test-access-logs"
    arn  = "arn:aws:s3:::ses-forwarder-test-access-logs"
  }
}

override_module {
  target = module.lambda
  outputs = {
    name = "EmailForwarder"
    arn  = "arn:aws:lambda:eu-west-1:123456789012:function:EmailForwarder"
  }
}

variables {
  bucket_name = "ses-forwarder-test"
  from_email  = "forwarder@example.com"

  recipient_mapping = {
    "hello@example.com" = ["user@example.org"]
  }
}

run "access_logging_enabled_by_default" {
  command = plan

  assert {
    condition     = length(module.access_logs) == 1
    error_message = "Expected the access logs bucket to be created when s3_access_logging is enabled (default)."
  }

  assert {
    condition     = local.access_logs_bucket_name == "ses-forwarder-test-access-logs"
    error_message = "Expected the access logs bucket to be named '<bucket_name>-access-logs'."
  }
}

run "access_logging_long_bucket_name" {
  command = plan

  variables {
    bucket_name = "mns-core-management-ses-forwarder-inbound-mail-storage"
  }

  assert {
    condition     = local.access_logs_bucket_name == "mns-core-management-ses-forwarder-inbound-mail-stor-access-logs"
    error_message = "Expected bucket_name to be truncated so the access logs bucket name fits the 63 character limit."
  }
}

run "access_logging_long_bucket_name_trailing_hyphen" {
  command = plan

  variables {
    bucket_name = "mns-core-management-ses-forwarder-inbound-mail-bkt-prod"
  }

  assert {
    condition     = local.access_logs_bucket_name == "mns-core-management-ses-forwarder-inbound-mail-bkt-access-logs"
    error_message = "Expected the trailing '-' left by truncating bucket_name to be trimmed."
  }
}

run "access_logging_disabled" {
  command = plan

  variables {
    s3_access_logging = { enabled = false }
  }

  assert {
    condition     = length(module.access_logs) == 0
    error_message = "Expected no access logs bucket to be created when s3_access_logging is disabled."
  }
}

run "access_logging_invalid_retention" {
  command = plan

  variables {
    s3_access_logging = { expiration_days = 30 }
  }

  expect_failures = [
    var.s3_access_logging,
  ]
}
