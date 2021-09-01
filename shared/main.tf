resource "aws_iam_policy" "policy_one" {
  name = "policy-618033"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = "*"
        Effect   = "Allow"
        Resource = "*"
      },
    ]
  })
}


resource "aws_iam_role" "duracloud" {

  name                  = "duracloud-role"
  force_detach_policies = true
  assume_role_policy  = jsonencode({
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
  managed_policy_arns = [aws_iam_policy.policy_one.arn]

  tags = {
    Name = "${var.stack_name}-role"
  }
}

resource "aws_iam_instance_profile" "duracloud" {

  name = "duracloud-instance-profile"
  role = aws_iam_role.duracloud.name

  tags = {
    Name = "${var.stack_name}-instance-profile"
  }
}

resource "aws_vpc" "duracloud" {
 cidr_block           = "10.0.0.0/16"
 enable_dns_hostnames =  true

 tags = {
    Name = "${var.stack_name}-vpc"
  }
}

resource "aws_subnet" "duracloud_public_subnet" {

 vpc_id            = aws_vpc.duracloud.id
 cidr_block        = "10.0.0.0/24"
 availability_zone = "${var.aws_region}a"

 tags = {
    Name = "${var.stack_name}-public-subnet"
  }
}

resource "aws_subnet" "duracloud_subnet_a" {

 vpc_id            = aws_vpc.duracloud.id
 cidr_block        = "10.0.1.0/24"
 availability_zone = "${var.aws_region}a"

 tags = { 
    Name = "${var.stack_name}-subnet-a"
  }
}

resource "aws_subnet" "duracloud_subnet_b" {

 vpc_id            = aws_vpc.duracloud.id
 cidr_block        = "10.0.2.0/24"
 availability_zone = "${var.aws_region}b"

 tags = {
    Name = "${var.stack_name}-subnet-b"
  }
}

resource "aws_route_table" "duracloud_nat" {

  vpc_id = aws_vpc.duracloud.id

  tags = {
    Name = "${var.stack_name}-nat-route-table"
  }
}

resource "aws_route_table" "duracloud" {

  vpc_id = aws_vpc.duracloud.id

  tags = { 
    Name = "${var.stack_name}-route-table"
  }
}

resource "aws_route_table_association" "duracloud_nat" {

  subnet_id      = aws_subnet.duracloud_public_subnet.id
  route_table_id = aws_route_table.duracloud_nat.id
}

resource "aws_route_table_association" "duracloud" {

  subnet_id      = aws_subnet.duracloud_subnet_a.id
  route_table_id = aws_route_table.duracloud.id
}

resource "aws_route" "route2igc" {

  route_table_id            = aws_route_table.duracloud_nat.id
  destination_cidr_block    = "0.0.0.0/0"
  gateway_id                = aws_internet_gateway.duracloud.id
}

resource "aws_route" "route2nat" {

  route_table_id            = aws_route_table.duracloud.id
  destination_cidr_block    = "0.0.0.0/0"
  gateway_id                = aws_nat_gateway.duracloud_nat.id
}



resource "aws_nat_gateway" "duracloud_nat" {
  allocation_id = aws_eip.duracloud_nat.id
  subnet_id     = aws_subnet.duracloud_public_subnet.id

  tags = {
    Name = "${var.stack_name}-nat-gateway" 
  }

  depends_on = [aws_internet_gateway.duracloud]
}


resource "aws_internet_gateway" "duracloud" {

  vpc_id = aws_vpc.duracloud.id

  tags = {
    Name = "${var.stack_name}-internet-gateway"
  }
}

resource "aws_eip" "duracloud_nat" {
  vpc      = true
}

resource "aws_db_subnet_group" "duracloud_db_subnet_group" {

  name       = "duracloud-${var.stack_name}-db-subnet-group"
  subnet_ids = [aws_subnet.duracloud_subnet_a.id, aws_subnet.duracloud_subnet_b.id]

  tags = {
    Name = "${var.stack_name}-db-subnet-group"
  }
}

resource "aws_security_group" "duracloud_database" {

  vpc_id = aws_vpc.duracloud.id
  name   = "duracloud-${var.stack_name}-db-sg"

  ingress {
    cidr_blocks = ["10.0.0.0/24"]
    from_port   = 3306 
    to_port     = 3306 
    protocol    = "tcp"
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name   = "duracloud-${var.stack_name}-db-sg"
  }
}

resource "aws_db_instance" "duracloud" {

  depends_on                = [aws_db_subnet_group.duracloud_db_subnet_group]
  name                      = "duracloud"
  identifier                = "${var.stack_name}-db-instance"
  allocated_storage         = 20
  storage_type              = "gp2"
  engine                    = "mysql" 
  engine_version            = "5.7"
  port                      = 3306 
  instance_class            = var.db_instance_class
  username                  = var.db_username
  password                  = var.db_password
  db_subnet_group_name      = aws_db_subnet_group.duracloud_db_subnet_group.name
  vpc_security_group_ids    =  [ aws_security_group.duracloud_database.id ]
  skip_final_snapshot       = "true"
  final_snapshot_identifier = "final-duracloud-${var.stack_name}"

  tags = {
    Name       = "${var.stack_name}-db-instance"
  }
}

resource "aws_security_group" "duracloud_bastion" {

  vpc_id = aws_vpc.duracloud.id

  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.stack_name}-bastion-sg"
  }
}

resource "aws_instance" "bastion" {
  ami                         = "ami-0dc2d3e4c0f9ebd18"
  instance_type               = "t3.micro"
  associate_public_ip_address = true
  security_groups             = [aws_security_group.duracloud_bastion.id]
  subnet_id                   = aws_subnet.duracloud_public_subnet.id
  key_name                    = var.ec2_keypair 
  tags = {
    Name       = "${var.stack_name}-bastion"
  }
}