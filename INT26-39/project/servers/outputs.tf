output "web_ec2" {
  value = "ssh -i ${path.module}/keys/id_rsa ubuntu@${aws_instance.web.public_ip}"
}

output "private_ip_mongodb" {
  value = aws_instance.mongodb.private_ip
}