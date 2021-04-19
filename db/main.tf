provider "aws" {
  region = "us-east-1"
}

variable "username" {
  description = "The username for the DB master user"
  type        = string
}

variable "password" {
  description = "The password for the DB master user"
  type        = string
}

resource "aws_security_group" "shopaholic_rds_sg" {
  name        = "shopaholic_rds_sg"
  description = "Allow access from internal IP"
  vpc_id      = "vpc-2d594948"

  ingress {
    description = "Allow internal IP to access port 5432"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["72.80.175.88/32"]
  }

  tags = {
    Name = "Shopaholic"
  }
}

resource "aws_db_instance" "shopaholic" {
  identifier           = "shopaholic"
  allocated_storage    = 10
  engine               = "postgres"
  engine_version       = "11.10"
  instance_class       = "db.t3.micro"
  name                 = "shop_db" 
  # Set the secrets from variables
  username             = var.username
  password             = var.password
  skip_final_snapshot  = true
  publicly_accessible  = true
  multi_az             = false

  tags = {
    Name = "Shopaholic"
  }
}
