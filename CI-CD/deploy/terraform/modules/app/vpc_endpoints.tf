# Salida de las tareas sin NAT: solo los servicios AWS que usa Fargate.
# ecr.api/ecr.dkr + S3 = pull de imagen; logs = awslogs; ecs = agente.

# Solo las tareas hablan con los endpoints (HTTPS); las respuestas
# vuelven por la regla stateful del SG, no necesita egress.
resource "aws_security_group" "endpoints" {
  name   = "${local.name_prefix}-vpce-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs.id]
  }
}

resource "aws_vpc_endpoint" "interface" {
  for_each = toset(["ecr.api", "ecr.dkr", "logs", "ecs"])

  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.aws_region}.${each.value}"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.endpoints.id]
  private_dns_enabled = true
}

# S3 (gateway, gratuito): ECR entrega las capas de la imagen desde buckets de AWS.
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = aws_route_table.private[*].id

  # GetObject es lo único que necesita el pull; las capas viven en buckets
  # administrados por AWS, no referenciables por ARN.
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = "*"
      Action    = "s3:GetObject"
      Resource  = "*"
    }]
  })
}
