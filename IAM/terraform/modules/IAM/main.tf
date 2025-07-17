data "aws_region" "main_region" {}
data "aws_caller_identity" "main_account" {}


# Roles
resource "aws_iam_role" "iam_ec2_role" {
  name = "iam_ec2_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })

  tags = {
    department = terraform.workspace
  }
}

resource "aws_iam_role" "iam_lambda_role" {
  name = "iam_lambda_role_1"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      },
    ]
  })
  tags = {
    department = terraform.workspace
  }
}

# Policy document
data "aws_iam_policy_document" "iam_ec2_role_document" {
  statement {
    effect = "Allow"
    actions = [
      "elasticloadbalancing:*",
      "ec2:*",
      "route53:*",
      "ecr:*",
      "ecr-public:*"
    ]
    resources = ["*"]
  }
}
data "aws_iam_policy_document" "iam_lambda_role_document" {
  statement {
    actions = [
      "ssm:GetParameter",
      "ssm:GetParameters",
      "ssm:PutParameter",
      "ssm:DeleteParameter",
      "ssm:DescribeParameters",
      "ssm:ListTagsForResource",
      "ssm:AddTagsToResource"
    ]
    resources = [
      "arn:aws:ssm:${data.aws_region.main_region.name}:${data.aws_caller_identity.main_account.account_id}:parameter/kubernetes/${terraform.workspace}/cluster_phase"
    ]
  }
  statement {
    actions = [
      "ec2:AssignPrivateIpAddresses",
      "ec2:UnassignPrivateIpAddresses",
      "ec2:CreateNetworkInterface",
      "ec2:DescribeNetworkInterfaces",
      "ec2:DeleteNetworkInterface",
      "ec2:DetachNetworkInterface",
      "route53:ChangeResourceRecordSets",
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = ["*"]
  }

}
# Policy
resource "aws_iam_policy" "iam_ec2_role_policy" {
  name   = "ec2_instance_profile_policy"
  policy = data.aws_iam_policy_document.iam_ec2_role_document.json
}

resource "aws_iam_policy" "iam_lambda_role_policy" {
  name   = "lambda_function_policy_1"
  policy = data.aws_iam_policy_document.iam_lambda_role_document.json
}

# Role-policy attachment
resource "aws_iam_role_policy_attachment" "iam_role_s3_full_access_attachment" {
  role       = aws_iam_role.iam_ec2_role.name
  policy_arn = aws_iam_policy.iam_ec2_role_policy.arn
}

resource "aws_iam_role_policy_attachment" "iam_role_lambda_ha_proxy_healthcheck_attachment" {
  role       = aws_iam_role.iam_lambda_role.name
  policy_arn = aws_iam_policy.iam_lambda_role_policy.arn
}

# Instance profile
resource "aws_iam_instance_profile" "iam_ec2_instance_profile" {
  name = "ec2_instance_profile"
  role = aws_iam_role.iam_ec2_role.name
  tags = {
    department = terraform.workspace
  }
}
