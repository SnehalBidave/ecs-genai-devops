resource "aws_ecs_cluster" "cluster" {
  name = "genai-cluster"
}

resource "aws_iam_role" "ecs_task_execution" {
  name = "ecsTaskExecutionRole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
    }]
  })

  managed_policy_arns = [
    "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
  ]
}

resource "aws_ecs_task_definition" "task" {
  family                   = "genai-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn

  container_definitions = jsonencode([
    {
      name      = "genai-app"
      image     = "<aws_account_id>.dkr.ecr.ap-south-1.amazonaws.com/ecs-genai-devops:latest"
      essential = true
      portMappings = [{ containerPort = 80 }]
      environment = [
        { name = "OPENAI_API_KEY", value = "<your_openai_api_key>" }
      ]
    }
  ])
}

resource "aws_ecs_service" "service" {
  name            = "genai-service"
  cluster         = aws_ecs_cluster.cluster.id
  task_definition = aws_ecs_task_definition.task.arn
  desired_count   = 1
  launch_type     = "FARGATE"
  network_configuration {
    subnets         = [aws_subnet.public.id]
    security_groups = [aws_security_group.ecs_sg.id]
    assign_public_ip = true
  }
  load_balancer {
    target_group_arn = aws_lb_target_group.web_tg.arn
    container_name   = "genai-app"
    container_port   = 80
  }
  depends_on = [aws_lb_listener.web_listener]
}
