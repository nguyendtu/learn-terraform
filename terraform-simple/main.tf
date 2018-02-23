# Configure the AWS Provider
provider "aws" {
  region = "eu-west-1"
}

# Create an EC2 instance
resource "aws_instance" "web" {
  # AMI ID for Amazon Linux AMI 2016.03.0 (HVM) in eu-west-1
  ami = "ami-1b791862"
  instance_type = "t2.micro" 
  user_data = <<-EOF
              #!/bin/bash
              echo "Hello, World" > index.html
              nohup busybox httpd -f -p "${var.server_port}" &
              EOF
  vpc_security_group_ids = ["${aws_security_group.web_security_group.id}"]

  tags {
    Name = "TF-Web"
  }
}

resource "aws_security_group" "web_security_group" {
  name = "TF-web_security_group"
  ingress {
    from_port = "${var.server_port}"
    to_port = "${var.server_port}"
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags {
    Name = "TF-web_security_group"
  }
}


output "public_ip" {
  description = "List of public IP addresses assigned to the instances, if applicable"
  value       = ["${aws_instance.web.*.public_ip}"]
}