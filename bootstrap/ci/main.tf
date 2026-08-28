data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

resource "terraform_data" "guardrails" {
  input = var.github_repository

  lifecycle {
    precondition {
      condition     = var.create_github_oidc_provider || var.existing_oidc_provider_arn != null
      error_message = "Provide existing_oidc_provider_arn when create_github_oidc_provider is false."
    }
  }
}

resource "aws_iam_openid_connect_provider" "github" {
  count = var.create_github_oidc_provider ? 1 : 0

  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
}

locals {
  github_oidc_provider_arn = var.create_github_oidc_provider ? aws_iam_openid_connect_provider.github[0].arn : var.existing_oidc_provider_arn
  repo_subject_prefix      = "repo:${var.github_owner}/${var.github_repository}"
}

data "aws_iam_policy_document" "assume_plan_role" {
  statement {
    sid     = "GitHubActionsOIDC"
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [local.github_oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values = [
        "${local.repo_subject_prefix}:pull_request*",
        "${local.repo_subject_prefix}:ref:refs/heads/main",
      ]
    }
  }
}

resource "aws_iam_role" "terraform_plan" {
  name               = "multi-vpc-terraform-plan"
  assume_role_policy = data.aws_iam_policy_document.assume_plan_role.json

  max_session_duration = 3600
}

data "aws_iam_policy_document" "plan_permissions" {
  statement {
    sid    = "ReadNetworkingControlPlane"
    effect = "Allow"
    actions = [
      "ec2:Describe*",
      "elasticloadbalancing:Describe*",
      "ssm:GetParameter",
      "sts:GetCallerIdentity",
    ]
    resources = ["*"]
  }

  statement {
    sid       = "ReadStateBucketLocation"
    effect    = "Allow"
    actions   = ["s3:GetBucketLocation"]
    resources = ["arn:${data.aws_partition.current.partition}:s3:::${var.state_bucket_name}"]
  }

  statement {
    sid       = "ListStatePrefix"
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = ["arn:${data.aws_partition.current.partition}:s3:::${var.state_bucket_name}"]

    condition {
      test     = "StringLike"
      variable = "s3:prefix"
      values = [
        var.state_key,
        "${var.state_key}.tflock",
      ]
    }
  }

  statement {
    sid       = "ReadExactState"
    effect    = "Allow"
    actions   = ["s3:GetObject"]
    resources = ["arn:${data.aws_partition.current.partition}:s3:::${var.state_bucket_name}/${var.state_key}"]
  }

  statement {
    sid    = "ManageOnlyLockObject"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
    ]
    resources = ["arn:${data.aws_partition.current.partition}:s3:::${var.state_bucket_name}/${var.state_key}.tflock"]
  }
}

resource "aws_iam_role_policy" "terraform_plan" {
  name   = "multi-vpc-speculative-plan"
  role   = aws_iam_role.terraform_plan.id
  policy = data.aws_iam_policy_document.plan_permissions.json
}
