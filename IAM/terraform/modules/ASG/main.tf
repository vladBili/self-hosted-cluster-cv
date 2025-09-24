data "aws_ami" "packer_ami" {
  most_recent = true

  filter {
    name   = "name"
    values = ["${var.asg_dict[each.key].ami_name}"]
  }

  owners = ["self"]
}

resource "aws_launch_template" "asg_template" {
  for_each      = var.asg_dict
  name_prefix   = "worker-"
  image_id      = data.aws_ami.packer_ami.id
  instance_type = var.asg_dict[each.key].instance_type
  key_name      = var.asg_dict[each.key].key_name
  user_data     = base64encode(file("${path.module}/kubernetes-workers/user_data.sh"))

  iam_instance_profile {
    name = var.asg_dict[each.key].instance_profile
  }

  network_interfaces {
    security_groups             = [var.asg_dict[each.key].security_groups]
    associate_public_ip_address = false
  }

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size           = 20
      delete_on_termination = true
    }
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      department                                             = terraform.workspace
      "kubernetes.io/cluster/${terraform.workspace}-cluster" = "owned"
    }
  }
}

resource "aws_autoscaling_group" "asg_group" {
  for_each            = var.asg_dict
  name                = "${each.key}-asg"
  desired_capacity    = 2
  max_size            = 4
  min_size            = 1
  vpc_zone_identifier = [keys(var.asg_dict[each.key].subnets)]

  launch_template {
    id      = aws_launch_template.asg_template.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "kubernetes-worker-asg"
    propagate_at_launch = true
  }
}
