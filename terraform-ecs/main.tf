# Configure the AWS Provider
provider "aws" {
  region = "eu-west-1"
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE AN ECS CLUSTER
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_ecs_cluster" "web" {
  name = "web_aws_ecs_cluster"
}

# ---------------------------------------------------------------------------------------------------------------------
# DEPLOY AN AUTO SCALING GROUP (ASG)
# Each EC2 Instance in the ASG will register as an ECS Cluster Instance.
# ---------------------------------------------------------------------------------------------------------------------

# Auto-scaling-group
resource "aws_autoscaling_group" "ecs_cluster_instances" {
  name                 = "web_ecs_cluster_instance"
  min_size             = 3
  max_size             = 5
  launch_configuration = "${aws_launch_configuration.ecs_instance.name}"
  availability_zones   = ["${data.aws_availability_zones.all.names}"]

  vpc_zone_identifier = ["${data.aws_subnet.default.*.id}"]

  tag {
    key                 = "Name"
    value               = "web_ecs_cluster_instance"
    propagate_at_launch = true
  }
}

# Laucnch configuration
resource "aws_launch_configuration" "ecs_instance" {
  name_prefix          = "ecs-instance-"
  instance_type        = "t2.micro"
  iam_instance_profile = "${aws_iam_instance_profile.web.name}"
  security_groups      = ["${aws_security_group.web.id}"]
  image_id             = "${data.aws_ami.ecs.id}"

  user_data = <<EOF
#!/bin/bash
echo "ECS_CLUSTER=web_aws_ecs_cluster" >> /etc/ecs/ecs.config
EOF

  lifecycle {
    create_before_destroy = true
  }
}

# Security group
resource "aws_security_group" "web" {
  name        = "web_aws_security_group"
  description = "Security group for the EC2 instances in the ECS cluster"
  vpc_id      = "${data.aws_vpc.default.id}"

  # aws_launch_configuration.ecs_instance sets create_before_destroy to true, which means every resource it depends on,
  # including this one, must also set the create_before_destroy flag to true, or you'll get a cyclic dependency error.
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group_rule" "all_outbound_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = "${aws_security_group.web.id}"
}

resource "aws_security_group_rule" "all_inbound_ssh" {
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = "${aws_security_group.web.id}"
}

resource "aws_security_group_rule" "all_inbound_frontend" {
  type              = "ingress"
  from_port         = 3000
  to_port           = 3000
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = "${aws_security_group.web.id}"
}

resource "aws_security_group_rule" "all_inbound_backend" {
  type              = "ingress"
  from_port         = 4567
  to_port           = 4567
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = "${aws_security_group.web.id}"
}

resource "aws_iam_role" "web" {
  name               = "web_aws_iam_role"
  assume_role_policy = "${data.aws_iam_policy_document.ecs_instance.json}"

  # aws_iam_instance_profile.ecs_instance sets create_before_destroy to true, which means every resource it depends on,
  # including this one, must also set the create_before_destroy flag to true, or you'll get a cyclic dependency error.
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_iam_instance_profile" "web" {
  name = "web_aws_iam_instance_profile"
  role = "${aws_iam_role.web.name}"

  # aws_launch_configuration.ecs_instance sets create_before_destroy to true, which means every resource it depends on,
  # including this one, must also set the create_before_destroy flag to true, or you'll get a cyclic dependency error.
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_iam_role_policy" "web" {
  name   = "web_aws_iam_role_policy"
  role   = "${aws_iam_role.web.id}"
  policy = "${data.aws_iam_policy_document.ecs_cluster_permissions.json}"
}

# resource "aws_ecs_task_definition" "frontend" {
#   family = "frontend_aws_ecs_task_definition"

#   container_definitions = <<EOF
#   [{ 
#     "name": "rails-frontend", 
#     "image": "gruntwork/rails-frontend:v1", 
#     "cpu": 1024, 
#     "memory": 768, 
#     "essential": true, 
#     "portMappings": [{
#         "containerPort": 3000, 
#         "hostPort": 3000
#     }],
#     "environment": [{ 
#       "name": "SINATRA_BACKEND_PORT", 
#       "value": "tcp://${aws_elb.backend.dns_name}:4567" 
#     }]
#   }]EOF
# }

resource "aws_ecs_task_definition" "backend" {
  family = "backend_aws_ecs_task_definition"

  container_definitions = <<EOF
  [{ 
    "name": "sinatra-backend", 
    "image": "gruntwork/sinatra-backend:v1", 
    "cpu": 1024, 
    "memory": 768, 
    "essential": true, 
    "portMappings": 
      [{
        "containerPort": 4567, 
        "hostPort": 4567
      }] 
  }]EOF
}

# resource "aws_ecs_service" "frontend" {
#   name            = "frontend_aws_ecs_service"
#   cluster         = "${aws_ecs_cluster.web.id}"
#   task_definition = "${aws_ecs_task_definition.frontend.arn}"
#   desired_count   = 2

#   load_balancer {
#     elb_name       = "${aws_elb.frontend.name}"
#     container_name = "rails-frontend"
#     container_port = 3000
#   }
# }

resource "aws_ecs_service" "backend" {
  name            = "backend_aws_ecs_service"
  cluster         = "${aws_ecs_cluster.web.id}"
  task_definition = "${aws_ecs_task_definition.backend.arn}"
  desired_count   = 2

  load_balancer {
    elb_name       = "${module.elb_backend.elb_name}"
    container_name = "sinatra-backend"
    container_port = 4567
  }
}

# resource "aws_elb" "frontend" {
#   name               = "frontend-aws-elb"
#   availability_zones = ["${data.aws_availability_zones.all.names}"]

#   listener {
#     lb_port           = 80
#     lb_protocol       = "http"
#     instance_port     = 3000
#     instance_protocol = "http"
#   }
# }

# ---------------------------------------------------------------------------------------------------------------------
# ELB
# ---------------------------------------------------------------------------------------------------------------------

module "elb_backend" {
  source = "./elb"

  name = "ELB for backend"

  vpc_id     = "${data.aws_vpc.default.id}"
  subnet_ids = ["${data.aws_subnet.default.*.id}"]

  instance_port     = 4567
  health_check_path = "health"
}

# ---------------------------------------------------------------------------------------------------------------------
# Data from amazone
# ---------------------------------------------------------------------------------------------------------------------

data "aws_vpc" "default" {
  default = true
}

data "aws_availability_zones" "all" {}

# Look up the default subnets in the AZs available to this account (up to a max of 3)
data "aws_subnet" "default" {
  count             = "${min(length(data.aws_availability_zones.all.names), 3)}"
  default_for_az    = true
  vpc_id            = "${data.aws_vpc.default.id}"
  availability_zone = "${element(data.aws_availability_zones.all.names, count.index)}"
}

data "aws_ami" "ecs" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn-ami-*-amazon-ecs-optimized"]
  }
}

data "aws_iam_policy_document" "ecs_instance" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "ecs_cluster_permissions" {
  statement {
    effect    = "Allow"
    resources = ["*"]

    actions = [
      "ecs:CreateCluster",
      "ecs:DeregisterContainerInstance",
      "ecs:DiscoverPollEndpoint",
      "ecs:Poll",
      "ecs:RegisterContainerInstance",
      "ecs:StartTelemetrySession",
      "ecs:Submit*",
    ]
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# Output
# ---------------------------------------------------------------------------------------------------------------------

# output "elb_frontend_dns_name" {
#   value = "${aws_elb.frontend.dns_name}"
# }

output "elb_backend_dns_name" {
  value = "http://${module.elb_backend.elb_dns_name}"
}
