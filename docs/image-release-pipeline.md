# GCP image release pipeline

> **Maintainer documentation:** This describes Buildkite's pipeline for building
> and publishing the GCP Elastic CI Stack images. It is not required when using
> the Terraform module.

The
[`elastic-ci-stack-gcp-image-builder`](https://buildkite.com/buildkite/elastic-ci-stack-gcp-image-builder)
pipeline builds, tests, and publishes the VM images used by the GCP Elastic CI
Stack.

Images are not made public or added to an image family until a VM created from
the image has successfully run the validation suite. Automatic image lifecycle
builds run only on `main`; trusted maintainers can also validate a branch by
manually or API-triggering this private pipeline. Pull requests use the
repository's separate verification pipeline and do not receive the
image-builder credentials or validation-agent token.

## Release flow

The pipeline first runs the relevant Terraform, Packer, example, and shell
verification checks. It then runs separate x86-64 and ARM64 paths:

```text
Verification checks
        |
    Build image
        |
Clean Packer resources
        |
Launch validation VM
        |
     Run Goss
      /     \
Delete VM   Publish image on main
```

Publishing and validation-VM deletion are independent jobs after a successful
test.

The main pipeline definition is
[`.buildkite/build-agent-image.yml`](../.buildkite/build-agent-image.yml).

The stages are implemented by:

| Stage | File |
| --- | --- |
| Build | `.buildkite/scripts/build-image` |
| Launch | `.buildkite/scripts/launch-test-instance` |
| Test | `goss.yaml` |
| Publish | `.buildkite/scripts/publish-image` |
| Delete | `.buildkite/scripts/delete-test-instance` |

The architecture-specific image name is passed from the build job to downstream
jobs using a Buildkite artifact and build metadata.

### Image variants

| Variant | Debian source | Packer builder | Test VM | Published family |
| --- | --- | --- | --- | --- |
| x86-64 | `debian-13` | `e2-standard-4` | `e2-small` | `buildkite-ci-stack-x86-64` |
| ARM64 | `debian-13-arm64` | `t2a-standard-4` | `t2a-standard-1` | `buildkite-ci-stack-arm64` |

Packer does not assign an image family. The publish job makes the image
available to `allAuthenticatedUsers` and assigns its architecture-specific
family only after validation passes.

## Infrastructure and authentication

The pipeline uses the following resources:

| Resource | Purpose |
| --- | --- |
| GCP project `buildkite-gcp-stack` | Stores images and runs Packer and validation VMs |
| Buildkite queue `gcp` | Runs build, launch, publish, and delete jobs |
| Buildkite queue `gcp-image-test` | Runs validation jobs on the image under test |
| `gcp-image-builder-ci@buildkite-gcp-stack.iam.gserviceaccount.com` | Pipeline identity, accessed through Workload Identity Federation |
| Buildkite secret `GCP_AGENT_TEST_TOKEN` | Registers ephemeral validation agents |

The worker providing `queue=gcp` is managed separately from this repository.
There are three different kinds of VM involved:

1. The worker that runs jobs on `queue=gcp`.
2. Temporary Packer builder VMs used to construct images.
3. Ephemeral `bk-image-test-*` VMs created from images under test.

Validation VMs do not have a GCP service account or OAuth scopes. The Buildkite
agent token is supplied through instance metadata, and GCP Secret Manager SSH
key discovery is disabled because the validation job does not clone private
repositories.

## Validation and VM lifecycle

The validation suite in [`goss.yaml`](../goss.yaml) checks the installed tools,
Buildkite agent configuration, system services, file permissions, automatic
security upgrades, Docker, Compose, Buildx, binfmt/QEMU, and
cross-architecture container execution.

Each validation VM is named:

```text
bk-image-test-<architecture>-<build-number>
```

The test job includes the VM's exact `gcp-instance` agent tag. This prevents a
stale agent from accepting a job belonging to another build.

Validation agents are one-shot agents and disconnect after one job. The normal
delete step removes the VM after validation, including when Goss fails.

Each VM also has a GCE-enforced 30-minute lifetime:

```text
max-run-duration=30m
instance-termination-action=DELETE
```

This is the cleanup fallback for canceled builds or cases where the Buildkite
delete step cannot run.

Temporary Packer builder VMs also have a GCE-enforced one-hour lifetime. A
separate cleanup job runs after each image build and removes any Packer VM and
boot disk left behind if Packer could not run its normal teardown.

## Running and troubleshooting the pipeline

The image lifecycle runs only when image-related files change. This includes the
Packer configuration, image templates, Goss suite, lifecycle scripts, and the
image pipeline definition itself. Documentation-only and Terraform-only changes
skip the lifecycle.

A successful `main` release runs the relevant verification checks, builds both
images, cleans temporary Packer resources, launches validation VMs, runs Goss,
and then publishes the images and deletes the validation VMs. To validate a
branch before merging, a trusted maintainer can manually trigger the
image-builder pipeline for that branch; the candidate images are tested and the
validation VMs deleted, but publishing is skipped.

Do not retry a test job by itself after its validation VM has been deleted or
its one-shot agent has disconnected. Retry the launch and test sequence
together, or start a new build.

### ARM capacity errors

T2A capacity can occasionally be unavailable:

```text
The zone does not have enough resources available
state: STOCKOUT
```

First retry the build without changing the code. If stockouts become frequent,
consider adding automatic retries, using a smaller T2A builder, or adding a
fallback zone.

### Test job remains scheduled

The launch script waits for GCE to report that the VM is running, followed by a
fixed startup delay. It does not currently query Buildkite to confirm that the
agent registered.

If a test remains scheduled:

1. Check the validation VM's startup and serial-port logs.
2. Check for an agent with the expected `gcp-instance` tag.
3. Cancel the build if bootstrap failed.
4. Delete the VM manually if necessary; otherwise its 30-minute lifetime should
   remove it.

List validation VMs with:

```bash
gcloud compute instances list \
  --project=buildkite-gcp-stack \
  --filter='name~^bk-image-test-'
```

Inspect the current published image for an architecture with:

```bash
gcloud compute images describe-from-family \
  buildkite-ci-stack-arm64 \
  --project=buildkite-gcp-stack
```

## Known limitations

The following are intentionally deferred:

- Automatic retries or zone fallback for GCP capacity failures.
- Polling Buildkite to confirm that a validation agent registered.
- Additional validation of the image name before the publish step.
- Reconciliation of the separately managed `queue=gcp` worker infrastructure
  and its autoscaling configuration.
  