output "security_gr_web" {
  value = aws_security_group.web.id
}

output "security_gr_mongodb" {
  value = aws_security_group.mongodb.id
}