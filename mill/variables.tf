variable "aws_profile" {
  description = "name of the aws profile"
}

variable "aws_region" {
  description = "The aws region"
  default     = "us-east-1"
}

variable "mill_docker_container" {
  description = "The docker container of DuraCloud Mill"
  default     = "dbernstein/mill"
}

variable "mill_version" {
  description = "The docker version of DuraCloud Mill"
  default     = "latest"
}

variable "mill_s3_config_location" {
  description = "An S3 path to a directory containing your mill config files e.g. yourbucket/optional/path"
}

variable "sentinel_instance_class" {
  description = "The sentinel's ec2 instance class"
  default     = "t3.small"
}

variable "worker_instance_class" {
  description = "The instance size of worker ec2 instance class"
  default     = "m5.large"
}

variable "worker_spot_price" {
  description = "The max spot price for work instances"
  default     = ".05"
}

variable "ec2_keypair" {
  description = "The EC2 keypair to use in case you want to access the instance."
}

variable "stack_name" {
  description = "The name of the duracloud stack."
}
