output "jenkins_ip" {
  value = aws_eip.jenkins.public_ip
}

output "jenkins_url" {
  description = "Jenkins UI, admin IP only. GitHub webhook URL is http://<ip>:8080/github-webhook/"
  value       = "http://${aws_eip.jenkins.public_ip}:8080"
}

output "ssh_command" {
  value = "ssh ubuntu@${aws_eip.jenkins.public_ip}"
}
