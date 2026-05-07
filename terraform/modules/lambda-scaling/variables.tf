variable "environment" {
  description = "Environment name."
  type        = string
}

variable "name_prefix" {
  description = "Resource name prefix."
  type        = string
}

variable "cluster_name" {
  description = "EKS cluster name to scale."
  type        = string
}

variable "node_group_name" {
  description = "Managed node group name to scale (e.g. compute-ng)."
  type        = string
  default     = "compute-ng"
}

variable "tags" {
  description = "Common resource tags."
  type        = map(string)
  default     = {}
}

variable "scale_up_cron" {
  description = "EventBridge cron (UTC) to scale up. Default: 07:00 UTC weekdays (= 08:00 UTC+1)."
  type        = string
  default     = "cron(0 7 ? * MON-FRI *)"
}

variable "scale_down_cron" {
  description = "EventBridge cron (UTC) to scale down. Default: 17:00 UTC weekdays (= 18:00 UTC+1)."
  type        = string
  default     = "cron(0 17 ? * MON-FRI *)"
}

variable "scale_up_min_size" {
  description = "Minimum node count when scaled up."
  type        = number
  default     = 1
}

variable "scale_up_desired_size" {
  description = "Desired node count when scaled up."
  type        = number
  default     = 1
}

variable "scale_up_max_size" {
  description = "Maximum node count when scaled up."
  type        = number
  default     = 10
}

variable "schedule_enabled" {
  description = "Whether EventBridge schedules are enabled."
  type        = bool
  default     = true
}
