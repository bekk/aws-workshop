resource "random_password" "postgres_password" {
  length  = 24
  special = false
}

resource "aws_security_group" "db-allow-all" {
  name        = "db-allow-all"
  vpc_id      = data.aws_vpc.default.id
}

resource "aws_vpc_security_group_ingress_rule" "db-allow-all" {
  security_group_id = aws_security_group.db-allow-all.id
  cidr_ipv4            = "0.0.0.0/0"
  from_port             = 5432
  to_port               = 5432
  ip_protocol           = "tcp"
}

resource "aws_db_instance" "todo" {
  # TODO: identifier = random
  allocated_storage = 10
  db_name           = "todo"
  engine            = "postgres"
  engine_version    = "15.3"
  instance_class    = "db.t3.micro"
  username          = "todoadmin"
  password          = random_password.postgres_password.result
  publicly_accessible = true
  vpc_security_group_ids = [aws_security_group.db-allow-all.id]
}

output "db_password" {
  sensitive = true
  value = random_password.postgres_password.result
}
