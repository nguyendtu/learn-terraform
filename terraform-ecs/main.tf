terraform {
  required_version = "> 0.9.0"
}

provider "aws" {
  region = "eu-west-1"
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE THE ECS CLUSTER
# ---------------------------------------------------------------------------------------------------------------------

module "ecs_cluster" {
  source = "./ecs-cluster"

  name = "ecs-cluster"
  size = 3
  instance_type = "t2.micro"
  key_pair_name = "${var.key_pair_name}"

  vpc_id = "${data.aws_vpc.default.id}"
  subnet_ids = ["${data.aws_subnet.default.*.id}"]

  # To keep the example simple to test, we allow SSH access from anywhere. In real-world use cases, you should lock 
  # this down just to trusted IP addresses.
  allow_ssh_from_cidr_blocks = ["0.0.0.0/0"]

  # Here, we allow the EC2 Instances in the ECS Cluster to recieve requests on the ports used by the rails-frontend
  # and sinatra-backend. To keep the example simple to test, we allow these requests from any IP, but in real-world
  # use cases, you should lock this down to just the IP addresses of the ELB and other trusted parties.
  allow_inbound_ports_and_cidr_blocks = "${map(
    var.backend_port, "0.0.0.0/0"
  )}"
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE THE BACKEND APP AND AN ELB FOR IT
# ---------------------------------------------------------------------------------------------------------------------

module "backend" {
  source = "./ecs-service"

  name = "backend"
  ecs_cluster_id = "${module.ecs_cluster.ecs_cluster_id}"
  
  image = "${var.backend_image}"
  image_version = "${var.backend_version}"
  cpu = 1024
  memory = 768
  desired_count = 3
  
  container_port = "${var.backend_port}"
  host_port = "${var.backend_port}"
  elb_name = "${module.backend_elb.elb_name}"

  num_env_vars = 1
  env_vars = "${map(
    "RACK_ENV", "production"
  )}"
}

module "backend_elb" {
  source = "./elb"

  name = "backend-elb"

  vpc_id = "${data.aws_vpc.default.id}"
  subnet_ids = ["${data.aws_subnet.default.*.id}"]

  instance_port = "${var.backend_port}"
  health_check_path = "health"
}

# ---------------------------------------------------------------------------------------------------------------------
# DEPLOY THIS EXAMPLE IN THE DEFAULT SUBNETS OF THE DEFAULT VPC
# To keep this example as easy to use as possible, we deploy into the default subnets of your default VPC. That means
# everything is accessible publicy, which is fine for learning/experimenting, but NOT a good practice for production.
# In real world use cases, you should run your code in the private subnets of a custom VPC.
#
# Note that if you do not have a default VPC (i.e. you have an older AWS account or you deleted the VPC), you will
# need to manually fill in the VPC and subnet IDs above.
# ---------------------------------------------------------------------------------------------------------------------

data "aws_vpc" "default" {
  default = true
}

data "aws_availability_zones" "available" {}

# Look up the default subnets in the AZs available to this account (up to a max of 3)
data "aws_subnet" "default" {
  count = "${min(length(data.aws_availability_zones.available.names), 3)}"
  default_for_az = true
  vpc_id = "${data.aws_vpc.default.id}"
  availability_zone = "${element(data.aws_availability_zones.available.names, count.index)}"
}