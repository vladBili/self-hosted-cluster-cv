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
      "elasticloadbalancing:*",
      "ssm:GetParameter"
    ]
    resources = ["*"]
  }

  # AWS System Manager (SSM)
  statement {
    sid    = "AllowSSMRequestStatements"
    effect = "Allow"
    actions = [
      "ssm:AddTagsToResource",
      "ssm:PutParameter"
    ]
    resources = ["*"]
    condition {
      test     = "StringEqualsIfExists"
      variable = "aws:RequestTag/department"
      values   = ["$${aws:PrincipalTag/department}"]
    }
  }

  statement {
    sid    = "AllowSSMResourceStatements"
    effect = "Allow"
    actions = [
      "ssm:AddTagsToResource",
      "ssm:GetParameter",
      "ssm:GetParameters",
      "ssm:ListTagsForResource",
      "ssm:DeleteParameter"
    ]
    resources = [
      "arn:aws:ssm:${var.region}:${var.account_id}:parameter/*"
    ]
    condition {
      test     = "StringEqualsIfExists"
      variable = "aws:ResourceTag/department"
      values   = ["$${aws:PrincipalTag/department}"]
    }
  }

  # AWS Key Managment Service (KMS)
  statement {
    sid    = "AllowKMSResourceStatements"
    effect = "Allow"
    actions = [
      "kms:Encrypt"
    ]
    resources = [
      "arn:aws:kms:${var.region}:${var.account_id}:key/*"
    ]
    condition {
      test     = "StringEqualsIfExists"
      variable = "aws:ResourceTag/department"
      values   = ["$${aws:PrincipalTag/department}"]
    }
  }

  # AWS Lambda
  statement {
    sid    = "AllowLambdaRequestStatements"
    effect = "Allow"
    actions = [
      "lambda:Create*",
      "lambda:TagResource"
    ]
    resources = [
      "arn:aws:lambda:${var.region}:${var.account_id}:function:*"
    ]
    condition {
      test     = "StringEqualsIfExists"
      variable = "aws:RequestTag/department"
      values   = ["$${aws:PrincipalTag/department}"]
    }
  }

  statement {
    sid    = "AllowLambdaResourceStatements"
    effect = "Allow"
    actions = [
      "lambda:Get*",
      "lambda:Delete*"
    ]
    resources = [
      "arn:aws:lambda:${var.region}:${var.account_id}:function:*"
    ]
    condition {
      test     = "StringEqualsIfExists"
      variable = "aws:ResourceTag/department"
      values   = ["$${aws:PrincipalTag/department}"]
    }
  }

  # AWS Event Bridge
  statement {
    sid    = "AllowEventBridgeRequestStatements"
    effect = "Allow"
    actions = [
      "events:PutRule"
    ]
    resources = [
      "arn:aws:events:${var.region}:${var.account_id}:rule/*"
    ]
    condition {
      test     = "StringEqualsIfExists"
      variable = "aws:RequestTag/department"
      values   = ["$${aws:PrincipalTag/department}"]
    }
  }

  statement {
    sid    = "AllowEventBridgeResourceStatements"
    effect = "Allow"
    actions = [
      "events:PutTargets",
      "events:RemoveTargets",
      "events:TagResource",
      "events:UntagResource",
      "events:DeleteRule"

    ]
    resources = [
      "arn:aws:events:${var.region}:${var.account_id}:rule/*"
    ]
    condition {
      test     = "StringEqualsIfExists"
      variable = "aws:ResourceTag/department"
      values   = ["$${aws:PrincipalTag/department}"]
    }
  }

  # AWS Elastic Cloud Computing (EC2)
  statement {
    sid    = "AllowEC2RequestStatements"
    effect = "Allow"
    actions = [
      "ec2:CreateTags",
      "ec2:CreateVpc",
      "ec2:CreateSubnet",
      "ec2:CreateInternetGateway",
      "ec2:CreateNatGateway",
      "ec2:CreateSecurityGroup",
      "ec2:CreateRouteTable",
      "ec2:RunInstances",
      "ec2:ImportKeyPair",
      "ec2:AllocateAddress",
      "ec2:AssociateAddress"
    ]
    resources = ["*"]
    condition {
      test     = "StringEqualsIfExists"
      variable = "aws:RequestTag/department"
      values   = ["$${aws:PrincipalTag/department}"]
    }
  }

  statement {
    sid    = "AllowEC2ResourceStatements"
    effect = "Allow"
    actions = [
      "ec2:CreateTags",
      "ec2:CreateSubnet",
      "ec2:CreateNatGateway",
      "ec2:CreateRouteTable",
      "ec2:CreateRoute",
      "ec2:CreateSecurityGroup",
      "ec2:CreateNetworkInterface",
      "ec2:RunInstances",
      "ec2:StartInstances",
      "ec2:Terminate*",
      "ec2:Release*",
      "ec2:Detach*",
      "ec2:Delete*",
      "ec2:Terminate*",
      "ec2:AuthorizeSecurityGroup*",
      "ec2:RevokeSecurityGroup*",
      "ec2:Associate*",
      "ec2:Disassociate*",
      "ec2:Modify*",
      "ec2:Attach*",
      "ec2:Detach*",
      "ec2:Stop*"
    ]
    resources = [
      "arn:aws:ec2:${var.region}:${var.account_id}:vpc/*",
      "arn:aws:ec2:${var.region}:${var.account_id}:subnet/*",
      "arn:aws:ec2:${var.region}:${var.account_id}:route-table/*",
      "arn:aws:ec2:${var.region}:${var.account_id}:image/*",
      "arn:aws:ec2:${var.region}:${var.account_id}:security-group/*",
      "arn:aws:ec2:${var.region}:${var.account_id}:security-group-rule/*",
      "arn:aws:ec2:${var.region}:${var.account_id}:key-pair/*",
      "arn:aws:ec2:${var.region}:${var.account_id}:network-interface/*",
      "arn:aws:ec2:${var.region}:${var.account_id}:natgateway/*",
      "arn:aws:ec2:${var.region}:${var.account_id}:internet-gateway/*",
      "arn:aws:ec2:${var.region}:${var.account_id}:instance/*",
      "arn:aws:ec2:${var.region}:${var.account_id}:elastic-ip/*",
      "arn:aws:ec2:${var.region}:${var.account_id}:volume/*"
    ]
    condition {
      test     = "StringEqualsIfExists"
      variable = "aws:ResourceTag/department"
      values   = ["$${aws:PrincipalTag/department}"]
    }
  }

  # Elastic Load Balancing 
  statement {
    sid    = "AllowELBRequestStatements"
    effect = "Allow"
    actions = [
      "elasticloadbalancing:CreateLoadBalancer",
      "elasticloadbalancing:AddTags"
    ]
    resources = [
      "*"
    ]
    condition {
      test     = "StringEqualsIfExists"
      variable = "aws:RequestTag/department"
      values   = ["$${aws:PrincipalTag/department}"]
    }
  }

  statement {
    sid    = "AllowELBResourceStatements"
    effect = "Allow"
    actions = [
      "elasticloadbalancing:AddTags",
      "elasticloadbalancing:ModifyLoadBalancerAttributes"
    ]
    resources = [
      "arn:aws:elasticloadbalancing:${var.region}:${var.account_id}:loadbalancer/net/*"
    ]
    condition {
      test     = "StringEqualsIfExists"
      variable = "aws:ResourceTag/department"
      values   = ["$${aws:PrincipalTag/department}"]
    }
  }


}


# IAM Policy 
data "aws_iam_policy_document" "iam_policy_documents" {
  for_each = var.departments

  # S3 Statetments
  statement {
    sid       = "ListStateBucketWithFolders"
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = ["${var.resource_arns["S3"]["state_bucket"]}"]
    condition {
      test     = "StringLike"
      variable = "s3:prefix"
      values   = ["backend/${each.key}/state"]
    }
  }

  # Access to state file
  statement {
    sid     = "AccessStateFiles"
    effect  = "Allow"
    actions = ["s3:GetObject", "s3:PutObject"]
    resources = [
      "${var.resource_arns["S3"]["state_bucket"]}/backend/${each.key}/state",
      "${var.resource_arns["S3"]["state_bucket"]}/env:*/backend/${each.key}/state"
    ]
  }

  statement {
    sid     = "AccessStateLocks"
    effect  = "Allow"
    actions = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:HeadObject"]
    resources = [
      "${var.resource_arns["S3"]["state_bucket"]}/backend/${each.key}/state.tflock",
      "${var.resource_arns["S3"]["state_bucket"]}/env:*/backend/${each.key}/state.tflock"
    ]
  }

  # SSM Statetments
  statement {
    sid    = "SSMStatetments"
    effect = "Allow"
    actions = [
      "ssm:GetParameter",
      "ssm:GetParameters",
      "ssm:PutParameter",
      "ssm:DeleteParameter",
      "ssm:ListTagsForResource",
      "ssm:AddTagsToResource"
    ]
    resources = [
      "arn:aws:ssm:${var.region}:${var.account_id}:parameter/kubernetes/${each.key}/*",
      "*"
    ]
  }

  # Lambda Statetments
  statement {
    sid    = "LambdaStatetments"
    effect = "Allow"
    actions = [
      "lambda:CreateFunction",
      "lambda:TagResource",
      "lambda:GetFunctionConfiguration",
      "lambda:ListVersionsByFunction",
      "lambda:InvokeFunction",
      "lambda:GetFunction",
      "lambda:DeleteFunction",
      "lambda:UpdateFunctionConfiguration",
      "lambda:UpdateFunctionCode",
      "lambda:AddPermission",
      "lambda:RemovePermission"
    ]
    resources = [
      "arn:aws:lambda:${var.region}:${var.account_id}:function:*",
      "arn:aws:lambda:${var.region}:${var.account_id}:function:*:*"
    ]
  }

  # Cloud Watch Statetments
  statement {
    sid    = "EventStatetments"
    effect = "Allow"
    actions = [
      "events:TagResource",
      "events:PutRule",
      "events:DescribeRule",
      "events:ListTagsForResource",
      "events:DeleteRule",
      "events:PutTargets",
      "events:RemoveTargets"
    ]
    resources = [
      "arn:aws:events:${var.region}:${var.account_id}:rule/*"
    ]
  }

  # EC2 Statements
  statement {
    effect = "Allow"
    actions = [
      "ec2:CreateTags",
      "ec2:CreateVpc",
      "ec2:CreateInternetGateway",
      "ec2:CreateSubnet",
      "ec2:CreateRouteTable",
      "ec2:CreateRoute",
      "ec2:CreateSecurityGroup",
      "ec2:CreateNetworkInterface",
      "ec2:AuthorizeSecurityGroupIngress",
      "ec2:AuthorizeSecurityGroupEgress",
      "ec2:Describe*",
      "ec2:RunInstances",
      "ec2:CreateNatGateway",
      "ec2:AllocateAddress",
      "ec2:DeleteNatGateway",
      "ec2:ImportKeyPair",
      "ec2:DeleteKeyPair",
      "ec2:DisassociateAddress",
      "ec2:DeleteNetworkInterface",
      "ec2:DeleteVpc",
      "ec2:DeleteTags",
      "ec2:DeleteSubnet",
      "ec2:RevokeSecurityGroupIngress",
      "ec2:RevokeSecurityGroupEgress",
      "ec2:DeleteSecurityGroup",
      "ec2:DeleteRouteTable",
      "ec2:DeleteInternetGateway",
      "ec2:DetachInternetGateway",
      "ec2:ModifyVpcAttribute",
      "ec2:ModifySubnetAttribute",
      "ec2:ModifySecurityGroupRules",
      "ec2:AttachInternetGateway",
      "ec2:TerminateInstances",
      "ec2:AssociateRouteTable",
      "ec2:DisassociateRouteTable",
      "ec2:ReleaseAddress",
      "ec2:DescribeAvailabilityZones",
      "ec2:AssociateAddress",
      "ec2:StopInstances",
      "ec2:Modify*",
      "ec2:StartInstances"
    ]
    resources = ["*"]
  }

  # IAM
  statement {
    effect = "Allow"
    actions = [
      "iam:CreateRole",
      "iam:CreatePolicy",
      "iam:TagRole",
      "iam:TagPolicy",
      "iam:CreateInstanceProfile",
      "iam:TagInstanceProfile",
      "iam:PassRole",
      "iam:CreatePolicyVersion",
      "iam:DeletePolicyVersion",
      "iam:GetPolicyVersion",
      "iam:ListRolePolicies",
      "iam:ListAttachedRolePolicies",
      "iam:ListInstanceProfilesForRole",
      "iam:ListPolicyVersions",
      "iam:DeleteRole",
      "iam:DeletePolicy",
      "iam:DeleteInstanceProfile",
      "iam:AttachRolePolicy",
      "iam:GetInstanceProfile",
      "iam:AddRoleToInstanceProfile",
      "iam:DetachRolePolicy",
      "iam:RemoveRoleFromInstanceProfile",
      "iam:GetRole",
      "iam:GetPolicy",
      "iam:CreateServiceLinkedRole"
    ]
    resources = ["*"]
  }

  # Route 53
  statement {
    effect = "Allow"
    actions = [
      "route53:CreateHostedZone",
      "route53:GetChange",
      "route53:GetHostedZone",
      "route53:ListTagsForResource",
      "route53:ListResourceRecordSets",
      "route53:DeleteHostedZone",
      "route53:ChangeTagsForResource",
      "route53:ChangeResourceRecordSets"
    ]
    resources = ["*"]
  }

  # Elastic Load Balancing
  statement {
    effect = "Allow"
    actions = [
      "elasticloadbalancing:*"
    ]
    resources = ["*"]
  }

  # Global
  statement {
    effect = "Allow"
    actions = [
      "ssm:DescribeParameters",
      "lambda:GetFunctionCodeSigningConfig",
      "iam:CreatePolicyVersion",
      "iam:DeletePolicyVersion",
      "events:DescribeRule",
      "lambda:GetPolicy",
      "events:ListTargetsByRule"
    ]
    resources = ["*"]
  }

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
  policy   = data.aws_iam_policy_document.iam_policy_documents[each.key].json
}

# IAM Policies to Groups
resource "aws_iam_group_policy_attachment" "project_policy_attachment" {
  for_each   = var.departments
  group      = aws_iam_group.iam_groups[each.key].name
  policy_arn = aws_iam_policy.iam_policies[each.key].arn
}


