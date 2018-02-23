# Configure the AWS Provider
provider "aws" {
  region = "eu-west-1"
}

data "aws_availability_zones" "all" {}

resource "aws_launch_configuration" "web" {
  # AMI ID for Amazon Linux AMI 2016.03.0 (HVM) in eu-west-1
  image_id = "ami-1b791862"
  instance_type = "t2.micro" 
  security_groups = ["${aws_security_group.web_security_group.id}"]

  user_data = <<-EOF
              #!/bin/bash
              echo "Hello, World" > index.html
              nohup busybox httpd -f -p "${var.server_port}" &
              EOF
  
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group" "web_security_group" {
  name = "tf-web_security_group"
  ingress {
    from_port = "${var.server_port}"
    to_port = "${var.server_port}"
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags {
    Name = "tf-web_security_group"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "web" {
  launch_configuration = "${aws_launch_configuration.web.id}"
  availability_zones = ["${data.aws_availability_zones.all.names}"]
  min_size = 2
  max_size = 5

  load_balancers = ["${aws_elb.web.name}"]
  health_check_type = "ELB"

  tag {
    key = "Name"
    value = "tf-asg-web"
    propagate_at_launch = true
  }
}

resource "aws_elb" "web" {
  name = "tf-elb-asg-web"
  security_groups = ["${aws_security_group.elb_security_group.id}"]
  availability_zones = ["${data.aws_availability_zones.all.names}"]

  health_check {
    healthy_threshold = 2
    unhealthy_threshold = 2
    timeout = 3
    interval = 30
    target = "HTTP:${var.server_port}/"
  }

  listener {
    lb_port = 80
    lb_protocol = "http"
    instance_port = "${var.server_port}"
    instance_protocol = "http"
  }
}

resource "aws_security_group" "elb_security_group" {
  name = "tf-elb_security_group"
  
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

}

output "elb_dns_name" {
  value = "${aws_elb.web.dns_name}"
}