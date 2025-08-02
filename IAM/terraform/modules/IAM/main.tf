locals {
  instance_profile_enabled = terraform.workspace == "development" || var.oidc["oidc"].cluster_phase != "postinit" ? 1 : 0
  instance_profile_dict = {
    "aws_full_access"         = data.aws_iam_policy_document.iam_full_access_role_document.json
    "aws_controlplane_access" = data.aws_iam_policy_document.iam_controlplane_role_document.json
    "aws_worker_access"       = data.aws_iam_policy_document.iam_worker_role_document.json
  }
  irsa_enabled = var.enabled && var.oidc["oidc"].cluster_phase == "postinit"
  irsa_dict = {
    "aws-node" = {
      policy_document = try(data.aws_iam_policy_document.iam_irsa_aws_vpc_cni_role_document.json, "")
      namespace       = "kube-system"
    },
    "aws-secret-csi" = {
      policy_document = try(data.aws_iam_policy_document.iam_irsa_aws_csi_secret_role_document.json, "")
      namespace       = "kube-system"
    },
    "external-dns-public" = {
      policy_document = try(data.aws_iam_policy_document.iam_irsa_external_dns_role_document.json, "")
      namespace       = "kube-system"
    },
    "external-dns-private" = {
      policy_document = try(data.aws_iam_policy_document.iam_irsa_external_dns_role_document.json, "")
      namespace       = "kube-system"
    },
    "test-sa" = {
      policy_document = try(data.aws_iam_policy_document.iam_irsa_test_role_document.json, "")
      namespace       = "default"
    }
  }

}

data "aws_region" "main_region" {}
data "aws_caller_identity" "main_account" {}

data "aws_iam_policy_document" "iam_irsa_aws_vpc_cni_role_document" {
  statement {
    effect = "Allow"
    actions = [
      "ec2:AssignPrivateIpAddresses",
      "ec2:AttachNetworkInterface",
      "ec2:CreateNetworkInterface",
      "ec2:DeleteNetworkInterface",
      "ec2:DescribeInstances",
      "ec2:DescribeTags",
      "ec2:DescribeNetworkInterfaces",
      "ec2:DescribeInstanceTypes",
      "ec2:DescribeSubnets",
      "ec2:DetachNetworkInterface",
      "ec2:ModifyNetworkInterfaceAttribute",
      "ec2:UnassignPrivateIpAddresses"
    ]
    resources = ["*"]
  }
  statement {
    effect = "Allow"
    actions = [
      "ec2:CreateTags"
    ]
    resources = ["arn:aws:ec2:*:*:network-interface/*"]
  }
}

data "aws_iam_policy_document" "iam_irsa_external_dns_role_document" {
  statement {
    effect = "Allow"
    actions = [
      "route53:ChangeResourceRecordSets"
    ]
    resources = ["arn:aws:route53:::hostedzone/*"]
  }
  statement {
    effect = "Allow"
    actions = [
      "route53:ListHostedZones",
      "route53:ListResourceRecordSets",
      "route53:ListTagsForResources"
    ]
    resources = ["*"]
  }
}

data "aws_iam_policy_document" "iam_irsa_aws_csi_secret_role_document" {
  statement {
    effect = "Allow"
    actions = [
      "ssm:GetParameter",
      "ssm:GetParameters",
      "ssm:GetParameterHistory",
      "ssm:GetParametersByPath"
    ]
    resources = ["*"]
  }
}

data "aws_iam_policy_document" "iam_irsa_test_role_document" {
  statement {
    effect    = "Allow"
    actions   = ["s3:ListAllMyBuckets"]
    resources = ["*"]
  }

  statement {
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = ["arn:aws:s3:::*"]
  }
}

# Roles
resource "aws_iam_role" "iam_ec2_role" {
  for_each = local.instance_profile_dict
  name     = "${each.key}-role"
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
      }
    ]
  })
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
data "aws_iam_policy_document" "iam_full_access_role_document" {
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

data "aws_iam_policy_document" "iam_controlplane_role_document" {
  statement {
    effect = "Allow"
    actions = [
      "autoscaling:DescribeAutoScalingGroups",
      "autoscaling:DescribeLaunchConfigurations",
      "autoscaling:DescribeTags",
      "ec2:DescribeInstances",
      "ec2:DescribeRegions",
      "ec2:DescribeRouteTables",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeSubnets",
      "ec2:DescribeVolumes",
      "ec2:DescribeAvailabilityZones",
      "ec2:CreateSecurityGroup",
      "ec2:CreateTags",
      "ec2:CreateVolume",
      "ec2:ModifyInstanceAttribute",
      "ec2:ModifyVolume",
      "ec2:AttachVolume",
      "ec2:AuthorizeSecurityGroupIngress",
      "ec2:CreateRoute",
      "ec2:DeleteRoute",
      "ec2:DeleteSecurityGroup",
      "ec2:DeleteVolume",
      "ec2:DetachVolume",
      "ec2:RevokeSecurityGroupIngress",
      "ec2:DescribeVpcs",
      "ec2:DescribeInstanceTopology",
      "elasticloadbalancing:AddTags",
      "elasticloadbalancing:AttachLoadBalancerToSubnets",
      "elasticloadbalancing:ApplySecurityGroupsToLoadBalancer",
      "elasticloadbalancing:CreateLoadBalancer",
      "elasticloadbalancing:CreateLoadBalancerPolicy",
      "elasticloadbalancing:CreateLoadBalancerListeners",
      "elasticloadbalancing:ConfigureHealthCheck",
      "elasticloadbalancing:DeleteLoadBalancer",
      "elasticloadbalancing:DeleteLoadBalancerListeners",
      "elasticloadbalancing:DescribeLoadBalancers",
      "elasticloadbalancing:DescribeLoadBalancerAttributes",
      "elasticloadbalancing:DetachLoadBalancerFromSubnets",
      "elasticloadbalancing:DeregisterInstancesFromLoadBalancer",
      "elasticloadbalancing:ModifyLoadBalancerAttributes",
      "elasticloadbalancing:RegisterInstancesWithLoadBalancer",
      "elasticloadbalancing:SetLoadBalancerPoliciesForBackendServer",
      "elasticloadbalancing:AddTags",
      "elasticloadbalancing:CreateListener",
      "elasticloadbalancing:CreateTargetGroup",
      "elasticloadbalancing:DeleteListener",
      "elasticloadbalancing:DeleteTargetGroup",
      "elasticloadbalancing:DescribeListeners",
      "elasticloadbalancing:DescribeLoadBalancerPolicies",
      "elasticloadbalancing:DescribeTargetGroups",
      "elasticloadbalancing:DescribeTargetHealth",
      "elasticloadbalancing:ModifyListener",
      "elasticloadbalancing:ModifyTargetGroup",
      "elasticloadbalancing:RegisterTargets",
      "elasticloadbalancing:DeregisterTargets",
      "elasticloadbalancing:SetLoadBalancerPoliciesOfListener",
      "iam:CreateServiceLinkedRole",
      "kms:DescribeKey"
    ]
    resources = ["*"]
  }
}

data "aws_iam_policy_document" "iam_worker_role_document" {
  statement {
    effect = "Allow"
    actions = [
      "ec2:DescribeInstances",
      "ec2:DescribeRegions",
      "ecr:GetAuthorizationToken",
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:GetRepositoryPolicy",
      "ecr:DescribeRepositories",
      "ecr:ListImages",
      "ecr:BatchGetImage"
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
  for_each = local.instance_profile_dict
  name     = "${each.key}-policy"
  policy   = each.value
}

resource "aws_iam_policy" "iam_lambda_role_policy" {
  name   = "lambda_function_policy_1"
  policy = data.aws_iam_policy_document.iam_lambda_role_document.json
}

# Role-policy attachment
resource "aws_iam_role_policy_attachment" "iam_role_ec2_full_access_attachment" {
  for_each   = local.instance_profile_dict
  role       = aws_iam_role.iam_ec2_role[each.key].name
  policy_arn = aws_iam_policy.iam_ec2_role_policy[each.key].arn
}

resource "aws_iam_role_policy_attachment" "iam_role_lambda_ha_proxy_healthcheck_attachment" {
  role       = aws_iam_role.iam_lambda_role.name
  policy_arn = aws_iam_policy.iam_lambda_role_policy.arn
}

# Instance profile
resource "aws_iam_instance_profile" "iam_ec2_instance_profile" {
  for_each = local.instance_profile_dict
  name     = "${each.key}_instance_profile"
  role     = aws_iam_role.iam_ec2_role[each.key].name
  tags = {
    department = terraform.workspace
  }
}

#OIDC
resource "aws_iam_openid_connect_provider" "oidc_provider" {
  count = local.irsa_enabled ? 1 : 0
  url   = "https://oidc.${var.oidc["oidc"].domain_name}"

  client_id_list = ["sts.amazonaws.com"]

  thumbprint_list = [var.oidc["oidc"].thumbprint]
}

resource "aws_iam_role" "iam_irsa_role" {
  for_each = local.irsa_enabled ? local.irsa_dict : {}
  name     = "${each.key}-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity",
        Effect = "Allow",
        Principal = {
          Federated = aws_iam_openid_connect_provider.oidc_provider[0].arn
        },
        Condition = {
          StringEquals = {
            "oidc.${var.oidc["oidc"].domain_name}:sub" = "system:serviceaccount:${each.value.namespace}:${each.key}"
          }
        }
      }
    ]
  })

  tags = {
    department = terraform.workspace
  }
}

resource "aws_iam_policy" "iam_irsa_role_policy" {
  for_each = local.irsa_enabled ? local.irsa_dict : {}
  name     = "${each.key}-irsa-policy"
  policy   = each.value.policy_document
}

resource "aws_iam_role_policy_attachment" "iam_irsa_role_policy_attachment" {
  for_each   = local.irsa_enabled ? local.irsa_dict : {}
  role       = aws_iam_role.iam_irsa_role[each.key].name
  policy_arn = aws_iam_policy.iam_irsa_role_policy[each.key].arn
}

resource "local_file" "templates" {
  count = local.irsa_enabled ? 1 : 0
  content = try(templatefile("${path.module}/../Templates/env/${terraform.workspace}/kubernetes_irsa.tftpl",
  { irsa_dict = local.irsa_dict, irsa_role = aws_iam_role.iam_irsa_role }), "")
  filename = abspath("${path.root}/../kubernetes/overlays/${terraform.workspace}/irsa/sa.yaml")
}
