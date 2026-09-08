variable "project" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
  default     = "us-central1"
}

variable "zones" {
  description = "List of zones within the region for instance distribution"
  type        = list(string)
  default     = ["us-central1-a", "us-central1-b", "us-central1-c"]
}

variable "stack_name" {
  description = "Name of the Elastic CI Stack"
  type        = string
  default     = "elastic-ci-stack"
}

# Networking module outputs (required)
variable "network_self_link" {
  description = "Self link of the VPC network (from networking module)"
  type        = string
}

variable "subnet_self_link" {
  description = "Self link of the subnet (from networking module)"
  type        = string
}

variable "instance_tag" {
  description = "Network tag for instances (from networking module)"
  type        = string
  default     = "elastic-ci-agent"
}

# IAM module outputs (required)
variable "agent_service_account_email" {
  description = "Email of the agent service account (from IAM module)"
  type        = string
}

# Instance configuration
variable "machine_type" {
  description = "GCP machine type for agent instances"
  type        = string
  default     = "n1-standard-2"
}

variable "image" {
  description = "Source image for boot disk"
  type        = string
  default     = "buildkite-gcp-stack/buildkite-ci-stack-x86-64-2026-09-08-0703-62-2781c81"
}

variable "root_disk_size_gb" {
  description = "Size of the root disk in GB"
  type        = number
  default     = 50
}

variable "root_disk_type" {
  description = "Type of root disk"
  type        = string
  default     = "pd-balanced"
}

# Buildkite configuration
variable "buildkite_organization_slug" {
  description = "Buildkite organization slug (from your Buildkite URL, e.g., 'my-org' from buildkite.com/my-org)"
  type        = string
}

variable "buildkite_agent_token" {
  description = "Buildkite agent registration token (leave empty if using buildkite_agent_token_secret)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "buildkite_agent_token_secret" {
  description = "GCP Secret Manager secret name containing Buildkite agent token (e.g. 'buildkite-agent-token')"
  type        = string
  default     = ""
}

variable "buildkite_agent_release" {
  description = "Buildkite agent release channel"
  type        = string
  default     = "stable"
}

variable "buildkite_queue" {
  description = "Buildkite queue name"
  type        = string
  default     = "default"
}

variable "buildkite_agent_tags" {
  description = "Additional tags for Buildkite agents"
  type        = string
  default     = ""
}

variable "buildkite_api_endpoint" {
  description = "Buildkite API endpoint URL"
  type        = string
  default     = "https://agent.buildkite.com/v3"
}

variable "agent_idle_timeout" {
  description = "Seconds an autoscaled agent must remain idle before disconnecting and removing its VM from the managed instance group. Set to 0 to disable idle-based scale-in; because the native autoscaler is scale-out-only, capacity will then remain at its high-water mark. Ignored when autoscaling is disabled."
  type        = number
  default     = 600

  validation {
    condition     = var.agent_idle_timeout >= 0 && floor(var.agent_idle_timeout) == var.agent_idle_timeout
    error_message = "Agent idle timeout must be a non-negative integer number of seconds."
  }
}

# Autoscaling configuration
variable "min_size" {
  description = "Minimum number of instances"
  type        = number
  default     = 0
}

variable "max_size" {
  description = "Maximum number of instances"
  type        = number
  default     = 10
}

variable "cooldown_period" {
  description = "Cooldown period in seconds between autoscaling actions"
  type        = number
  default     = 60
}

variable "autoscaling_jobs_per_instance" {
  description = "Number of unfinished Buildkite jobs assigned to each instance for autoscaling"
  type        = number
  default     = 1
}

variable "enable_autoscaling" {
  description = "Enable autoscaling based on custom Buildkite metrics (requires buildkite-agent-metrics function)"
  type        = bool
  default     = true
}

# Health check configuration
variable "enable_autohealing" {
  description = "Enable autohealing for unhealthy instances"
  type        = bool
  default     = true
}

variable "health_check_initial_delay_sec" {
  description = "Time to wait before starting autohealing"
  type        = number
  default     = 300
}

# Labels
variable "labels" {
  description = "Additional labels to apply to instances"
  type        = map(string)
  default     = {}
}
