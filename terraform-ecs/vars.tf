# ---------------------------------------------------------------------------------------------------------------------
# ENVIRONMENT VARIABLES
# Define these secrets as environment variables
# ---------------------------------------------------------------------------------------------------------------------

# AWS_ACCESS_KEY_ID
# AWS_SECRET_ACCESS_KEY

# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL MODULE PARAMETERS
# These variables have defaults, but may be overridden by the operator.
# ---------------------------------------------------------------------------------------------------------------------

variable "region" {
  description = "The region where to deploy this code (e.g. us-east-1)."
  default = "eu-west-1"
}

variable "key_pair_name" {
  description = "The name of the Key Pair that can be used to SSH to each EC2 instance in the ECS cluster. Leave blank to not include a Key Pair."
  default = ""
}

variable "backend_image" {
  description = "The name of the Docker image to deploy for the Sinatra backend (e.g. gruntwork/sinatra-backend)"
  default = "gruntwork/sinatra-backend"
}

variable "backend_version" {
  description = "The version (i.e. tag) of the Docker container to deploy for the Sinatra backend (e.g. latest, 12345)"
  default = "v2"
}

variable "backend_port" {
  description = "The port the Sinatra backend Docker container listens on for HTTP requests (e.g. 4567)"
  default = 4567
}