# ==============================================================================
# AWS RDS PostgreSQL Module - Production Grade
# Features: Multi-AZ High Availability, Automated Backups (PITR), Encryption
# ==============================================================================

variable "identifier" {
  type    = string
  default = "boutique-production-db"
}

variable "allocated_storage" {
  type    = number
  default = 50
}

variable "max_allocated_storage" {
  type    = number
  default = 200 # Autoscales storage under load
}

variable "instance_class" {
  type    = string
  default = "db.m6g.large"
}

variable "db_name" {
  type    = string
  default = "boutique_db"
}

variable "username" {
  type    = string
  default = "dbadmin"
}

variable "password" {
  type      = string
  sensitive = true
}

variable "subnet_ids" {
  type = list(string)
}

variable "vpc_security_group_ids" {
  type = list(string)
}

resource "aws_db_subnet_group" "rds" {
  name       = "${var.identifier}-subnet-group"
  subnet_ids = var.subnet_ids

  tags = {
    Name = "${var.identifier}-subnet-group"
  }
}

resource "aws_db_instance" "postgresql" {
  identifier             = var.identifier
  engine                 = "postgres"
  engine_version         = "15.7"
  instance_class         = var.instance_class
  allocated_storage      = var.allocated_storage
  max_allocated_storage  = var.max_allocated_storage
  storage_type           = "gp3"
  storage_encrypted      = true

  db_name  = var.db_name
  username = var.username
  password = var.password

  # High Availability & Disaster Recovery
  multi_az                = true
  backup_retention_period = 30 # 30 days of automated continuous PITR
  backup_window           = "03:00-04:00"
  maintenance_window      = "Sun:04:30-Sun:05:30"
  copy_tags_to_snapshot   = true
  deletion_protection     = true
  skip_final_snapshot     = false
  final_snapshot_identifier = "${var.identifier}-final-snapshot"

  db_subnet_group_name   = aws_db_subnet_group.rds.name
  vpc_security_group_ids = var.vpc_security_group_ids

  tags = {
    Environment = "production"
    Application = "boutique-microservices"
  }
}

output "endpoint" {
  value = aws_db_instance.postgresql.endpoint
}

output "address" {
  value = aws_db_instance.postgresql.address
}
