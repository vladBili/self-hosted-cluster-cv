locals {
  iam_policy = {
    development = data.aws_iam_policy_document.iam_policy_documents_primary,
    production  = data.aws_iam_policy_document.iam_policy_documents_production
  }
}

# IAM Users
resource "aws_iam_user" "iam_users" {
  for_each             = var.user_department_map
  name                 = "${each.key}-user"
  path                 = "/${var.target}/"
  permissions_boundary = aws_iam_policy.iam_permission_boundaries[each.value].arn
  tags = {
    description = "${each.key} user for performing actions in AWS"
    department  = each.value
  }
}

resource "aws_iam_access_key" "iam_access_keys" {
  for_each = var.users
  user     = aws_iam_user.iam_users[each.key].name
}

resource "aws_secretsmanager_secret" "iam_credentials_secret_name" {
  for_each = var.user_department_map
  name     = "credentials/${each.value}/${each.key}-user"
}

resource "aws_secretsmanager_secret_version" "iam_credentials_secret_keys" {
  for_each  = var.user_department_map
  secret_id = aws_secretsmanager_secret.iam_credentials_secret_name[each.key].id
  secret_string = jsonencode({
    AWS_ACCESS_KEY_ID     = aws_iam_access_key.iam_access_keys[each.key].id
    AWS_SECRET_ACCESS_KEY = aws_iam_access_key.iam_access_keys[each.key].secret
  })
}


# IAM Groups
resource "aws_iam_group" "iam_groups" {
  for_each = var.departments
  name     = "${each.value}-department"
  path     = "/${var.target}/"
}

# IAM Users to IAM groups
resource "aws_iam_group_membership" "iam_group_memberships" {
  for_each = var.departments
  name     = "${each.value}-department-membership"

  users = [
    for user, group in var.user_department_map : aws_iam_user.iam_users[user].name
    if group == each.value
  ]

  group      = aws_iam_group.iam_groups[each.key].name
  depends_on = [aws_iam_user.iam_users]
}

# IAM Permision Boundaries 
data "aws_iam_policy_document" "iam_permission_boundaries_document" {

  for_each = var.departments

  # Terraform state
  statement {
    sid    = "AllowTerraformBackendStateFiles"
    effect = "Allow"
    actions = [
      "s3:PutObject",
      "s3:ListBucket",
      "s3:GetObject",
      "s3:DeleteObject",
      "s3:HeadObject"
    ]
    resources = [
      "${var.resource_arns["S3"]["state_bucket"]}/backend/${each.key}/state",
      "${var.resource_arns["S3"]["state_bucket"]}/env:*/backend/${each.key}/state",
      "${var.resource_arns["S3"]["state_bucket"]}/env:*/backend/${each.key}/state.tflock"
    ]
  }

  # Global Statements
  statement {
    sid    = "AllowGlobalStatements"
    effect = "Allow"
    actions = [
      "iam:Get*",
      "iam:List*",
      "iam:Attach*",
      "iam:Add*",
      "iam:Tag*",
      "iam:Create*",
      "iam:Pass*",
      "iam:Detach*",
      "iam:Delete*",
      "iam:Remove*",
      "iam:Update*",
      "ssm:Describe*",
      "route53:Create*",
      "route53:Get*",
      "route53:Change*",
      "route53:List*",
      "route53:Delete*",
      "events:Describe*",
      "events:List*",
      "ec2:Describe*",
      "ec2:CreateRoute",            #*/*
      "ec2:DisassociateAddress",    #*/*
      "ec2:DetachNetworkInterface", #*/*
      "lambda:List*",
      "lambda:AddPermission",
      "lambda:RemovePermission",
      "ssm:GetParameter",
      "autoscaling:Describe*",
      "secretsmanager:Describe*"
    ]
    resources = ["*"]
  }

  statement {
    sid       = "EnforceResourceTagMatch"
    effect    = "Allow"
    actions   = ["*"]
    resources = ["*"]

    condition {
      test     = "StringEqualsIfExists"
      variable = "aws:ResourceTag/department"
      values   = ["$${aws:PrincipalTag/department}"]
    }
  }

  statement {
    sid       = "EnforceRequestTagMatch"
    effect    = "Allow"
    actions   = ["*"]
    resources = ["*"]

    condition {
      test     = "StringEqualsIfExists"
      variable = "aws:RequestTag/department"
      values   = ["$${aws:PrincipalTag/department}"]
    }
  }
}


# IAM Policy 
data "aws_iam_policy_document" "iam_policy_documents_primary" {
  statement {
    effect = "Allow"
    actions = [
      "iam:*",
      "ec2:*",
      "s3:*",
      "ssm:*",
      "secretsmanager:*"
    ]
    resources = ["*"]
  }
}

data "aws_iam_policy_document" "iam_policy_documents_secondary" {
  statement {
    effect = "Allow"
    actions = [
      "elasticloadbalancing:*",
      "autoscaling:*",
      "rds:*",
      "route53:*",
      "events:*",
      "lambda:*"
    ]
    resources = ["*"]
  }
}

data "aws_iam_policy_document" "iam_policy_documents_production" {
  source_policy_documents = [
    data.aws_iam_policy_document.iam_policy_documents_primary.json,
    data.aws_iam_policy_document.iam_policy_documents_secondary.json
  ]
}

resource "aws_iam_policy" "iam_permission_boundaries" {
  for_each = var.departments
  name     = "${each.key}-permission-boundary"
  path     = "/${var.target}/"
  policy   = data.aws_iam_policy_document.iam_permission_boundaries_document[each.key].json
}

resource "aws_iam_policy" "iam_policies" {
  for_each = var.departments
  name     = "${each.key}-policy"
  path     = "/${var.target}/"
  policy   = local.iam_policy[each.key].json
}


# IAM Policies to Groups
resource "aws_iam_group_policy_attachment" "project_policy_attachment" {
  for_each   = var.departments
  group      = aws_iam_group.iam_groups[each.key].name
  policy_arn = aws_iam_policy.iam_policies[each.key].arn
}


