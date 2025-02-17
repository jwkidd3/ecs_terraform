terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = "us-east-1"
}

# 🔹 Lookup the Default VPC
data "aws_vpc" "default" {
  default = true
}

# 🔹 Lookup Default Subnets
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

data "aws_iam_role" "ecs_execution_role" {
  name = "ecsTaskExecutionRole"
}

# 🔹 Create an ECS Cluster
resource "aws_ecs_cluster" "main" {
  name = "user0-cluster"
}

# 🔹 Security Group for ALB
resource "aws_security_group" "alb_sg" {
  vpc_id = data.aws_vpc.default.id
  name = "user0_ALB"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# 🔹 Security Group for ECS Tasks
resource "aws_security_group" "ecs_sg" {
  vpc_id = data.aws_vpc.default.id
  name = "user0_ECS"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    security_groups = [aws_security_group.alb_sg.id] # Allow ALB traffic
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# 🔹 Create an Application Load Balancer
resource "aws_lb" "alb" {
  name               = "user0-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets           = data.aws_subnets.default.ids
}

# 🔹 Create a Target Group
resource "aws_lb_target_group" "tg" {
  name        = "user0-target-group"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = data.aws_vpc.default.id
  target_type = "ip"
}

# 🔹 Create a Listener for ALB
resource "aws_lb_listener" "listener" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg.arn
  }
}


# 🔹 Define ECS Task Definition
resource "aws_ecs_task_definition" "nginx" {
  family                   = "user0-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  execution_role_arn       = data.aws_iam_role.ecs_execution_role.arn
 # execution_role_arn       = aws_iam_role.ecs_execution_role.arn
  cpu                      = "256"
  memory                   = "512"

  container_definitions = jsonencode([
    {
      name  = "user0-container"
      image = "nginx:latest"
      cpu   = 256
      memory = 512
      essential = true

      portMappings = [
        {
          containerPort = 80
          protocol      = "tcp"
        }
      ]
    }
  ])
}

# 🔹 Create ECS Service
resource "aws_ecs_service" "nginx_service" {
  name            = "user0-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.nginx.arn
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = data.aws_subnets.default.ids
    security_groups  = [aws_security_group.ecs_sg.id]
    assign_public_ip = true
  }

  desired_count = 1

  load_balancer {
    target_group_arn = aws_lb_target_group.tg.arn
    container_name   = "user0-container"
    container_port   = 80
  }

  depends_on = [aws_lb_listener.listener]
}
