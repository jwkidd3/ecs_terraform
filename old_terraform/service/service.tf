resource "aws_ecs_task_definition" "app_task" {
  family                   = "my-app"
  container_definitions    = jsonencode([
    {
      name      = "my-app-container"
      image     = "nginx:latest"  # replace with your image
      cpu       = 256
      memory    = 512
      essential = true
      portMappings = [
        {
          containerPort = 80
          hostPort      = 80
        }
      ]
    }
  ])
  requires_compatibilities = ["FARGATE"]  # or EC2, depending on your setup
  network_mode             = "awsvpc"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn
  cpu                      = "256"
  memory                   = "512"
}

resource "aws_ecs_service" "app_service" {
  name            = "my-app-service"
  cluster         = "your-cluster-name"  # Use your existing ECS cluster name
  task_definition = aws_ecs_task_definition.app_task.arn
  desired_count   = 2  # Number of tasks to run
  launch_type     = "FARGATE"  # or EC2, depending on your cluster type

  network_configuration {
    subnets         = ["subnet-xxx", "subnet-yyy"]  # Replace with your subnet IDs
    security_groups = [aws_security_group.sg.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.app_target_group.arn
    container_name   = "my-app-container"
    container_port   = 80
  }
}

resource "aws_lb" "app_lb" {
  name               = "app-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.lb_sg.id]
  subnets            = ["subnet-xxx", "subnet-yyy"]
}

resource "aws_lb_target_group" "app_target_group" {
  name        = "app-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = "vpc-xxx"  # Replace with your VPC ID
  target_type = "ip"
}

resource "aws_lb_listener" "app_listener" {
  load_balancer_arn = aws_lb.app_lb.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_target_group.arn
  }
}
resource "aws_security_group" "lb_sg" {
  name        = "lb-sg"
  vpc_id      = "vpc-xxx"
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

resource "aws_security_group" "sg" {
  name        = "app-sg"
  vpc_id      = "vpc-xxx"
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
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "ecsTaskExecutionRole"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      },
      Effect = "Allow",
      Sid = ""
    }]
  })

  managed_policy_arns = [
    "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
  ]
}
