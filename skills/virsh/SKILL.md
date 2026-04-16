---
name: virsh
description: Use when working with virsh, libvirt, QEMU, KVM, storage pools, qcow2 images, or VM definitions. Use this skill when users ask where VMs are stored, how to inspect domains, or how to find the backing disk image.
---

# virsh

Use this skill for libvirt inspection and VM storage discovery.

## Connection basics

`virsh` may talk to either the session or system libvirt daemon depending on the host setup.
Do not assume which one contains the VM the user cares about.

Check both when needed:

```bash
virsh uri
virsh -c qemu:///system list --all
virsh -c qemu:///session list --all
```

Use whichever connection actually contains the domain.

## Fast path

If the user asks where a VM is stored, use these commands in order:

```bash
virsh uri
virsh -c qemu:///system list --all
virsh -c qemu:///session list --all
virsh -c <uri> domblklist <domain> --details
```

Replace `<uri>` with the connection that contains the domain.

`domblklist` is usually the most direct answer.

## Common commands

### List VMs

```bash
virsh -c qemu:///system list --all
virsh -c qemu:///session list --all
```

### Show where a VM disk lives

```bash
virsh -c <uri> domblklist <domain> --details
```

Look for the `Source` path for each `disk` row.

### Show storage pool directories

```bash
virsh -c <uri> pool-list --all
virsh -c <uri> pool-dumpxml <pool>
```

Read the `<target><path>...` value to get the pool directory.

### Show VM metadata

```bash
virsh -c <uri> dominfo <domain>
virsh -c <uri> dumpxml <domain>
```

Use `dumpxml` when the user needs NICs, disks, firmware, CPU, memory, or other configuration details.

## Storage lookup workflow

When the user asks for VM storage, answer in this order:

1. Identify whether the domain is under `qemu:///system` or `qemu:///session`
2. Run `virsh -c <uri> domblklist <domain> --details`
3. If they want the pool directory instead of the exact image, run `virsh -c <uri> pool-dumpxml <pool>`
4. If the domain has multiple disks, list all of them

## Interpretation rules

- Prefer the exact disk image path over a guessed directory
- Report the pool directory only when it helps answer the question
- If a domain uses multiple disks, list each source path clearly
- If permissions block direct file reads under libvirt config directories, use `domblklist`, `dominfo`, `dumpxml`, and `pool-dumpxml` instead of guessing

## Response style

Keep replies short:

- exact disk path first
- pool directory second if relevant
- mention whether the VM was found under `qemu:///system` or `qemu:///session`
