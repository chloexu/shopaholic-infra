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
      image     = "353948279170.dkr.ecr.us-east-1.amazonaws.com/unionrealtime/api-service"
      essential = true
      portMappings = [
        {
          containerPort = 3000
          hostPort      = 3000
        }
      ]
    }
  ])
  execution_role_arn = "arn:aws:iam::353948279170:role/ecsTaskExecutionRole"
  task_role_arn      = "arn:aws:iam::353948279170:role/ecsTaskExecutionRole"
  network_mode       = "awsvpc"
  cpu                = 256
  memory             = 1024
}

resource "aws_lb_target_group" "api_tg" {
  name        = "ecs-api-service-tg"
  port        = 80
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = "vpc-3466234c"
}

resource "aws_security_group" "api_alb_sg" {
  name        = "api-alb-sg"
  description = "Allow access from internal IP"
  vpc_id      = "vpc-2d594948"

  ingress {
    description = "Allow internal IP to access port 5432"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["72.80.175.88/32"]
  }
}

resource "aws_lb" "api_alb" {
  name               = "api-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.api_alb_sg.id]
  subnets            = ["subnet-7e71c451", "subnet-9e6111d5"]

  enable_deletion_protection = false
}

resource "aws_lb_listener" "api-listener" {
  load_balancer_arn = aws_lb.api_alb.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = "arn:aws:acm:us-east-1:353948279170:certificate/394b414b-0ff2-4559-9112-3ae2a7b427cc"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.api_tg.arn
  }
}

resource "aws_ecs_service" "api_service" {
  name            = "api-service"
  cluster         = aws_ecs_cluster.api_ecs_cluster.id
  task_definition = aws_ecs_task_definition.api_task_definition.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  load_balancer {
    target_group_arn = aws_lb_target_group.api_tg.arn
    container_name   = "api-container"
    container_port   = 3000
  }
}
