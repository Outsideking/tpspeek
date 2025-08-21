output "alb_http_url"            { value = "http://${aws_lb.app.dns_name}" }
output "api_gateway_invoke_url"  { value = aws_apigatewayv2_api.http.api_endpoint }
output "ecr_repo"                { value = aws_ecr_repository.tpspeek.repository_url }
output "log_group"               { value = aws_cloudwatch_log_group.app.name }
