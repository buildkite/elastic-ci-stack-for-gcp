# Agent scaling and instance updates

This behavior requires Terraform Google provider 7.33 or later because that release added
configurable autoscaler stabilization periods.

## Upgrading an existing stack

Applying this release will not automatically reconfigure existing VMs. Those VMs retain their old agent configuration and
cannot scale themselves in, so they can keep the fleet above `min_size`.

After applying the release, you will need to perform a one-time job-safe replacement:

1. Pause dispatch for the stack's Buildkite queue from the Buildkite cluster queue UI.
2. Wait for all running jobs on its agents to finish.
3. Replace the MIG's existing members so they start from the new template. For
   smaller fleets with sufficient quota for temporary replacement VMs, run:

   ```bash
   gcloud compute instance-groups managed update-instances \
     "$(terraform output -raw instance_group_manager_name)" \
     --project=PROJECT_ID \
     --region="$(terraform output -raw region)" \
     --all-instances \
     --minimal-action=replace \
     --most-disruptive-allowed-action=replace
   ```

   This can replace every member concurrently, so the fleet might briefly have
   no connected agents. For larger fleets, update named members in batches with
   `--instances` to limit disruption and stay within CPU and IP quota.
4. Resume dispatch after the replacement agents have connected.

Do not replace members until dispatch is paused and jobs have drained.

## Job-safe scale-in

The native GCP autoscaler assigns the queue's unfinished jobs across instances
and only scales out. When an agent has been idle for
`agent_idle_timeout` seconds (600 by default), it disconnects, and a systemd
lifecycle hook removes that VM from the regional managed instance group and
decrements the group's target size.
Set `agent_idle_timeout = 0` to disable idle agent scale-in.

The idle timeout is also the grace period for bursty workloads. If another job
arrives before the timeout expires, the idle agent accepts the job and resets its timer.
When autoscaling remains enabled, setting it to `0` keeps the scale-out-only
fleet at its high-water mark. When autoscaling is disabled, the module disables
idle disconnect and self-termination so the static MIG retains its configured
capacity.

When disabling autoscaling on an existing stack, you must pause dispatch, wait for jobs
to drain, disable autoscaling and apply, then replace the old members using the
process above. Existing members can still self-terminate on their old idle
timeout during this transition. Because Terraform intentionally ignores the
MIG's runtime target size, explicitly resize it to the desired static capacity
before resuming dispatch:

```bash
gcloud compute instance-groups managed resize \
  "$(terraform output -raw instance_group_manager_name)" \
  --project=PROJECT_ID \
  --region="$(terraform output -raw region)" \
  --size=STATIC_CAPACITY
```

The termination hook is installed by this Terraform module. It therefore
assumes the VM belongs to the regional MIG created by the module.

If an agent crashes, the same lifecycle attempts to remove the unusable VM. If the
removal request fails, the post-stop command fails, which triggers the service's
`Restart=on-failure` policy. Manually stopping or restarting the agent service
also recycles its VM; these agents are intended to be ephemeral.

An idle agent can remove itself while the group is at `min_size`. The
scale-out-only autoscaler then restores the minimum using the latest instance
template.

## Opportunistic template updates

The regional managed instance group uses an opportunistic update policy. When
the instance template changes, GCP records the new target template but does not
proactively replace existing agent VMs. Proactive instance redistribution is
also disabled so that the group does not delete a running agent merely to
rebalance instances between zones. New instances use the latest template when the group scales out or otherwise
creates a replacement.
