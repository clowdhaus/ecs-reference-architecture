output "run_task" {
  description = "AWS CLI command to execute task on cluster to test/validate"
  value       = "aws ecs run-task --cli-input-json file://config.json  --region ${local.region}"
}
