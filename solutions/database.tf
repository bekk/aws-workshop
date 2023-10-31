resource "random_password" "postgres_password" {
  length  = 24
  special = false
}

resource "aws_security_group" "db-allow-all" {
  name   = "security-group-todo-public-${local.id}"
  vpc_id = data.aws_vpc.default.id
}

resource "aws_vpc_security_group_ingress_rule" "db-allow-all" {
  security_group_id = aws_security_group.db-allow-all.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 5432
  to_port           = 5432
  ip_protocol       = "tcp"
}

resource "aws_db_instance" "todo" {
  # The name of the instance
  identifier = "db-todo-${local.id}"
  # The name of the database
  db_name = "todo"

  # Credentials
  username = "todoadmin"
  password = random_password.postgres_password.result

  # Tier and scale configuration
  allocated_storage = 10
  instance_class    = "db.t3.micro"

  # Database type & version
  engine         = "postgres"
  engine_version = "15.3"

  # Make database accessible from the internet
  publicly_accessible    = true
  vpc_security_group_ids = [aws_security_group.db-allow-all.id]

  # Necessary to easily destroy after workshop, we don't want a backup snapshot when destroying
  skip_final_snapshot = true
}

output "db_password" {
  sensitive = true
  value     = random_password.postgres_password.result
}

output "db_host" {
  value = aws_db_instance.todo.endpoint
}
