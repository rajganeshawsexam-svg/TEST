resource "aws_db_subnet_group" "this" {
  name       = "payload-db-subnet"
  subnet_ids = var.subnet_ids
  tags       = merge(var.tags, { Name = "payload-db-subnet" })
}

resource "aws_security_group" "rds_sg" {
  name        = "payload-rds-sg"
  description = "Allow DB access from EKS nodes"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"] # adjust to your VPC CIDR
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { Name = "payload-rds-sg" })
}

resource "aws_db_instance" "postgres" {
  identifier              = "payload-db"
  engine                  = "postgres"
  engine_version          = "15"
  instance_class          = var.db_instance_class
  allocated_storage       = var.db_allocated_storage
  db_name                 = var.db_name
  username                = var.db_username
  password                = var.db_password
  db_subnet_group_name    = aws_db_subnet_group.this.name
  vpc_security_group_ids  = [aws_security_group.rds_sg.id]
  multi_az                = true
  storage_encrypted       = true
  skip_final_snapshot     = true
  publicly_accessible     = false

  tags = merge(var.tags, { Name = "payload-db" })
}
