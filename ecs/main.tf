provider "aws" {
  region = "us-east-1"
}

resource "aws_ecs_cluster" "api_ecs_cluster" {
  name               = "api"
  capacity_providers = ["FARGATE", "FARGATE_SPOT"]
}

resource "aws_ecs_task_definition" "api_task_definition" {
  family                   = "api-service"
  requires_compatibilities = ["FARGATE"]
  container_definitions = jsonencode([
    {
      name      = "api-container"
      image     = "{account_id}.dkr.ecr.us-east-1.amazonaws.com/unionrealtime/api-service"
      essential = true
      portMappings = [
        {
          protocal      = "tcp"
          containerPort = 3000
          hostPort      = 3000
        }
      ]
      environment = [{
        name  = "NODE_ENV"
        value = "prod"
      }]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-region        = "us-east-1"
          awslogs-group         = "/ecs/api-service"
          awslogs-stream-prefix = "ecs"
        }
      }
    }
  ])
  execution_role_arn = "arn:aws:iam::{account_id}:role/ecsTaskExecutionRole"
  task_role_arn      = "arn:aws:iam::{account_id}:role/ecsTaskExecutionRole"
  network_mode       = "awsvpc"
  cpu                = 256
  memory             = 1024
}

resource "aws_lb_target_group" "api_tg" {
  name        = "ecs-api-service-tg"
  port        = 80
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = "vpc-"
  health_check {
    path = "/health"
    interval = 60
    timeout = 30
    unhealthy_threshold = 5
    healthy_threshold = 2
  }
}

resource "aws_security_group" "api_alb_sg" {
  name        = "api-alb-sg"
  description = "Allow access from internal IP"
  vpc_id      = "vpc-"

  ingress {
    description = "Internal IP"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["72.80.175.88/32"]
  }
  ingress {
    description = "Internal IP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["72.80.175.88/32"]
  }
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

resource "aws_security_group" "api_ecs_service_sg" {
  name        = "api-ecs-service-sg"
  description = "Allow access from api ALB"
  vpc_id      = "vpc-"

  ingress {
    description = "Allow access of port 80 from world"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description     = "Allow access from api ALB"
    from_port       = 0
    to_port         = 65535
    protocol        = "tcp"
    security_groups = [aws_security_group.api_alb_sg.id]
  }
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

resource "aws_lb" "api_alb" {
  name               = "api-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.api_alb_sg.id]
  subnets            = ["subnet-", "subnet-9e6111d5"]

  enable_deletion_protection = false
}

resource "aws_lb_listener" "api-listener-https" {
  load_balancer_arn = aws_lb.api_alb.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = "arn:aws:acm:us-east-1:{account_id}:certificate/{cert_id}"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.api_tg.arn
  }
}

resource "aws_lb_listener" "api-listener-http" {
  load_balancer_arn = aws_lb.api_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.api_tg.arn
  }
}

resource "aws_ecs_service" "api_service" {
  name             = "api-service"
  cluster          = aws_ecs_cluster.api_ecs_cluster.id
  task_definition  = aws_ecs_task_definition.api_task_definition.arn
  desired_count    = 1
  launch_type      = "FARGATE"
  platform_version = "1.3.0"
  health_check_grace_period_seconds = 30
  network_configuration {
    subnets          = ["subnet-", "subnet-"]
    security_groups  = [aws_security_group.api_ecs_service_sg.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.api_tg.arn
    container_name   = "api-container"
    container_port   = 3000
  }
}