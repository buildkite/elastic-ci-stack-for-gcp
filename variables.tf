# Root module variables for Elastic CI Stack for GCP

# Required Variables

variable "project_id" {
  description = "GCP project ID where the Elastic CI Stack will be deployed"
  type        = string

  validation {
    condition = (
      can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.project_id)) &&
      !can(regex("--", var.project_id)) &&
      !can(regex("(?i)google", var.project_id))
    )
    error_message = "Project ID must be 6-30 characters, start with a letter, contain only lowercase letters, numbers, and single hyphens, and cannot contain the word 'google'."
  }
}

variable "buildkite_agent_token" {
  description = "Buildkite agent registration token from your Buildkite organization. Get this from: Buildkite Dashboard → Agents → Reveal Agent Token. Leave empty if using buildkite_agent_token_secret."
  type        = string
  sensitive   = true
  default     = ""
}

# Stack Configuration

variable "stack_name" {
  description = "Name prefix for all resources in this stack. Used to identify and organize resources."
  type        = string
  default     = "buildkite"

  validation {
    condition     = can(regex("^[a-z][-a-z0-9]{0,61}[a-z0-9]$", var.stack_name))
    error_message = "Stack name must be a valid GCP resource name: lowercase letters, numbers, and hyphens only."
  }
}

variable "region" {
  description = "GCP region where resources will be deployed (e.g., 'us-central1', 'europe-west1')"
  type        = string
  default     = "us-central1"
}

variable "zones" {
  description = "List of availability zones within the region for high availability. If not specified, uses all zones in the region."
  type        = list(string)
  default     = null
}

# Buildkite Configuration

variable "buildkite_organization_slug" {
  description = "Buildkite organization slug (from your Buildkite URL: https://buildkite.com/<org-slug>). Used for metrics namespacing."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]*[a-z0-9]$", var.buildkite_organization_slug))
    error_message = "Organization slug must contain only lowercase letters, numbers, and hyphens."
  }
}

variable "buildkite_agent_token_secret" {
  description = "Alternative to buildkite_agent_token: GCP Secret Manager secret name containing the Buildkite agent token (e.g., 'projects/PROJECT_ID/secrets/buildkite-agent-token/versions/latest'). Recommended for production."
  type        = string
  default     = ""
}

variable "buildkite_queue" {
  description = "Buildkite queue name that agents will listen to. Agents in this stack will only pick up jobs targeting this queue."
  type        = string
  default     = "default"
}

variable "buildkite_agent_tags" {
  description = "Additional tags for Buildkite agents (comma-separated key=value pairs, e.g., 'docker=true,os=linux'). Use these to target specific agents in pipeline steps."
  type        = string
  default     = ""
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

variable "buildkite_agent_release" {
  description = "Buildkite agent release channel: 'stable' (recommended), 'beta', or 'edge'"
  type        = string
  default     = "stable"

  validation {
    condition     = contains(["stable", "beta", "edge"], var.buildkite_agent_release)
    error_message = "Buildkite agent release must be one of: stable, beta, edge."
  }
}

variable "buildkite_api_endpoint" {
  description = "Buildkite API endpoint URL. Only change if using a custom endpoint."
  type        = string
  default     = "https://agent.buildkite.com/v3"
}

# Instance Configuration

variable "machine_type" {
  description = "GCP machine type for agent instances (e.g., 'e2-standard-4', 'n1-standard-2', 'c2-standard-4'). See: https://cloud.google.com/compute/docs/machine-types"
  type        = string
  default     = "e2-standard-4"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]+$", var.machine_type))
    error_message = "Machine type must be a valid GCP machine type."
  }
}

variable "image" {
  description = "Source image for boot disk. Use a custom Packer-built image or a public Buildkite image."
  type        = string
  default     = "buildkite-gcp-stack/buildkite-ci-stack-x86-64-2026-09-08-0703-62-2781c81"
}

variable "root_disk_size_gb" {
  description = "Size of the root disk in GB. Increase for larger Docker images or build artifacts."
  type        = number
  default     = 50

  validation {
    condition     = var.root_disk_size_gb >= 10 && var.root_disk_size_gb <= 65536
    error_message = "Root disk size must be between 10 GB and 65536 GB."
  }
}

variable "root_disk_type" {
  description = "Type of root disk: 'pd-standard' (cheaper, slower), 'pd-balanced' (recommended), 'pd-ssd' (fastest)"
  type        = string
  default     = "pd-balanced"

  validation {
    condition     = contains(["pd-standard", "pd-balanced", "pd-ssd"], var.root_disk_type)
    error_message = "Root disk type must be one of: pd-standard, pd-balanced, pd-ssd."
  }
}

# Scaling Configuration

variable "min_size" {
  description = "Minimum number of agent instances. Set to 0 to scale to zero when idle (cost-effective) or higher for always-available capacity."
  type        = number
  default     = 0

  validation {
    condition     = var.min_size >= 0
    error_message = "Minimum size must be greater than or equal to 0."
  }
}

variable "max_size" {
  description = "Maximum number of agent instances. Controls cost ceiling and maximum parallelization."
  type        = number
  default     = 10

  validation {
    condition     = var.max_size >= 1
    error_message = "Maximum size must be greater than or equal to 1."
  }
}

variable "enable_autoscaling" {
  description = "Enable autoscaling based on Buildkite job queue metrics. Requires buildkite-agent-metrics Cloud Function to be deployed."
  type        = bool
  default     = true
}

variable "cooldown_period" {
  description = "Cooldown period in seconds between autoscaling actions to prevent flapping"
  type        = number
  default     = 60

  validation {
    condition     = var.cooldown_period >= 30
    error_message = "Cooldown period must be at least 30 seconds."
  }
}

variable "autoscaling_jobs_per_instance" {
  description = "Number of unfinished Buildkite jobs assigned to each instance for autoscaling. Lower values provide more parallelism at higher cost."
  type        = number
  default     = 1

  validation {
    condition     = var.autoscaling_jobs_per_instance >= 1
    error_message = "Jobs per instance must be at least 1."
  }
}

# Networking Configuration

variable "network_name" {
  description = "Name of the VPC network to create. Defaults to '{stack_name}-network' if not specified."
  type        = string
  default     = null

  validation {
    condition     = var.network_name == null || can(regex("^[a-z][-a-z0-9]{0,61}[a-z0-9]$", var.network_name))
    error_message = "Network name must be a valid GCP resource name: lowercase letters, numbers, and hyphens only."
  }
}

variable "enable_ssh_access" {
  description = "Enable SSH access to instances via firewall rule. Set to false for additional security."
  type        = bool
  default     = true
}

variable "ssh_source_ranges" {
  description = "CIDR blocks allowed to SSH to instances. Restrict to your IP for security (e.g., ['203.0.113.0/24']). Only used if enable_ssh_access is true."
  type        = list(string)
  default     = ["0.0.0.0/0"]

  validation {
    condition = alltrue([
      for cidr in var.ssh_source_ranges : can(cidrhost(cidr, 0))
    ])
    error_message = "All SSH source ranges must be valid CIDR blocks."
  }
}

variable "instance_tag" {
  description = "Network tag applied to instances for firewall targeting. Defaults to '{stack_name}-agent' if not specified."
  type        = string
  default     = null

  validation {
    condition     = var.instance_tag == null || can(regex("^[a-z][-a-z0-9]{0,61}[a-z0-9]$", var.instance_tag))
    error_message = "Instance tag must be a valid GCP network tag."
  }
}

variable "enable_iap_access" {
  description = "Enable Identity-Aware Proxy (IAP) for secure SSH without external IPs or VPN"
  type        = bool
  default     = false
}

variable "enable_secondary_ranges" {
  description = "Enable secondary IP ranges for future GKE support"
  type        = bool
  default     = false
}

# IAM Configuration

variable "agent_service_account_id" {
  description = "ID for the Buildkite agent service account. Defaults to '{stack_name}-agent' if not specified."
  type        = string
  default     = null

  validation {
    condition     = var.agent_service_account_id == null || can(regex("^[a-z][-a-z0-9]{4,28}[a-z0-9]$", var.agent_service_account_id))
    error_message = "Service account ID must be 6-30 characters, lowercase letters, digits, and hyphens only."
  }
}

variable "metrics_service_account_id" {
  description = "ID for the metrics function service account. Defaults to '{stack_name}-metrics' if not specified."
  type        = string
  default     = null

  validation {
    condition     = var.metrics_service_account_id == null || can(regex("^[a-z][-a-z0-9]{4,28}[a-z0-9]$", var.metrics_service_account_id))
    error_message = "Service account ID must be 6-30 characters, lowercase letters, digits, and hyphens only."
  }
}

variable "agent_custom_role_id" {
  description = "ID for the custom IAM role for agent instance management. Defaults to '{stack_name}AgentInstanceMgmt' if not specified."
  type        = string
  default     = null

  validation {
    condition     = var.agent_custom_role_id == null || can(regex("^[a-zA-Z0-9_\\.]{3,64}$", var.agent_custom_role_id))
    error_message = "Custom role ID must be 3-64 characters, letters, numbers, underscores, and periods only."
  }
}

variable "metrics_custom_role_id" {
  description = "ID for the custom IAM role for metrics autoscaling. Defaults to '{stack_name}MetricsAutoscaler' if not specified."
  type        = string
  default     = null

  validation {
    condition     = var.metrics_custom_role_id == null || can(regex("^[a-zA-Z0-9_\\.]{3,64}$", var.metrics_custom_role_id))
    error_message = "Custom role ID must be 3-64 characters, letters, numbers, underscores, and periods only."
  }
}

variable "enable_secret_access" {
  description = "Grant agents access to Secret Manager. Enable if your builds need to access secrets."
  type        = bool
  default     = true
}

variable "enable_storage_access" {
  description = "Grant agents access to Cloud Storage. Enable if your builds need to upload/download artifacts."
  type        = bool
  default     = false
}

# Health Check Configuration

variable "enable_autohealing" {
  description = "Enable automatic replacement of unhealthy instances"
  type        = bool
  default     = true
}

variable "health_check_port" {
  description = "Port for health checks (22 for SSH, or custom port if running health endpoint)"
  type        = number
  default     = 22

  validation {
    condition     = var.health_check_port > 0 && var.health_check_port <= 65535
    error_message = "Health check port must be between 1 and 65535."
  }
}

variable "health_check_interval_sec" {
  description = "How often (in seconds) to perform health checks"
  type        = number
  default     = 30

  validation {
    condition     = var.health_check_interval_sec >= 1
    error_message = "Health check interval must be at least 1 second."
  }
}

variable "health_check_timeout_sec" {
  description = "How long (in seconds) to wait for health check response before marking as failed"
  type        = number
  default     = 10

  validation {
    condition     = var.health_check_timeout_sec >= 1
    error_message = "Health check timeout must be at least 1 second."
  }
}

variable "health_check_healthy_threshold" {
  description = "Number of consecutive successful health checks before marking instance healthy"
  type        = number
  default     = 2

  validation {
    condition     = var.health_check_healthy_threshold >= 1
    error_message = "Healthy threshold must be at least 1."
  }
}

variable "health_check_unhealthy_threshold" {
  description = "Number of consecutive failed health checks before marking instance unhealthy"
  type        = number
  default     = 3

  validation {
    condition     = var.health_check_unhealthy_threshold >= 1
    error_message = "Unhealthy threshold must be at least 1."
  }
}

variable "health_check_initial_delay_sec" {
  description = "Time (in seconds) to wait after instance start before beginning health checks"
  type        = number
  default     = 300

  validation {
    condition     = var.health_check_initial_delay_sec >= 0
    error_message = "Initial delay must be greater than or equal to 0."
  }
}

# Update Policy Configuration

variable "max_surge" {
  description = "Maximum number of instances stored in the MIG update policy above target size. Pass this value explicitly with --max-surge when starting a gcloud rolling update; template changes are not rolled out proactively."
  type        = number
  default     = 3

  validation {
    condition     = var.max_surge >= 0
    error_message = "Max surge must be greater than or equal to 0."
  }
}

variable "max_unavailable" {
  description = "Maximum number of unavailable instances stored in the MIG update policy. Pass this value explicitly with --max-unavailable when starting a gcloud rolling update; template changes are not rolled out proactively."
  type        = number
  default     = 0

  validation {
    condition     = var.max_unavailable >= 0
    error_message = "Max unavailable must be greater than or equal to 0."
  }
}

# Security Configuration

variable "enable_secure_boot" {
  description = "Enable Secure Boot for shielded VM instances (additional security, slight performance overhead)"
  type        = bool
  default     = false
}

variable "enable_vtpm" {
  description = "Enable virtual Trusted Platform Module for shielded VM instances (recommended)"
  type        = bool
  default     = true
}

variable "enable_integrity_monitoring" {
  description = "Enable integrity monitoring for shielded VM instances (recommended)"
  type        = bool
  default     = true
}

# Additional Configuration

variable "labels" {
  description = "Additional labels to apply to all resources for organization and billing"
  type        = map(string)
  default     = {}
}
