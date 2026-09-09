# Elastic CI Stack for GCP

[![Build status](https://badge.buildkite.com/3215529db5b0c43976ce30bd625724ae0f71af146ef8ac0007.svg)](https://buildkite.com/buildkite/elastic-ci-stack-for-gcp?branch=main)

Terraform modules for running autoscaling [Buildkite](https://buildkite.com/) agents on Google Cloud Platform.

## Documentation

Full documentation is available at <https://buildkite.com/docs/agent/v3/gcp/elastic-ci-stack/elastic-ci-stack>.

Repository documentation:

- [Agent scaling and instance updates](docs/instance-updates.md) — describes
  job-safe scale-in, idle-agent removal, and opportunistic template rollout
- [GCP image release pipeline](docs/image-release-pipeline.md)

## Getting Started

The module ships with a set of default values which can be overridden as needed, but should be sufficient for most use cases.

```hcl
module "elastic-ci-stack-for-gcp" {
  source  = "buildkite/elastic-ci-stack-for-gcp/buildkite"
  version = "~> 0.5.0"

  # Required
  project_id                  = "your-gcp-project"
  buildkite_organization_slug = "your-org-slug"
  buildkite_agent_token       = "YOUR_AGENT_TOKEN"
}
```

## Contributing

See [Contributing Guidelines](CONTRIBUTING.md).

## License

MIT
