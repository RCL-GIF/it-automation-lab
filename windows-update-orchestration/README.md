# Windows Update Orchestration

## Overview

This project documents a sanitized automation pattern for coordinating Windows patching across distributed environments.

The original operational problem involved engineers manually initiating, monitoring, and validating patch activity across multiple regions.

The goal of the automation was to reduce time spent watching routine update jobs while preserving visibility into failures that required human investigation.

## Problem

Manual patching created several operational challenges:

- engineers spent significant time waiting for update jobs to complete
- success and failure states required manual verification
- distributed environments increased operational overhead
- troubleshooting effort was mixed together with routine monitoring

## Approach

The workflow separates routine execution from exception handling.

1. Target systems are grouped by environment or region.
2. Patch execution is initiated through a controlled workflow.
3. Systems perform the update process.
4. Results are collected.
5. Successful systems require no further intervention.
6. Failed systems are surfaced for technician review.

## Design Principles

- automation should reduce repetitive monitoring
- failures should remain visible
- systems should be grouped logically
- reporting should make follow-up obvious
- engineers should spend time investigating exceptions, not watching progress bars

## Security Considerations

A production implementation should include:

- least-privileged execution identities
- secure credential handling
- change control
- audit logging
- rollback planning
- separation between production and non-production environments

## Proof of Work

### PowerShell Patch Assessment

[`Invoke-PatchAssessment.ps1`](./Invoke-PatchAssessment.ps1)

This PowerShell artifact demonstrates a read-only pre-patching assessment workflow designed to support larger Windows update orchestration processes.

The script collects:

- Windows Update service state
- operating system and build information
- pending reboot indicators
- applicable Windows updates
- KB article numbers and update severity
- downloaded and reboot-required status

The assessment produces both JSON and CSV output so the results can be consumed by reporting, orchestration, monitoring, or downstream automation systems.

The published version intentionally does **not** install patches, restart services, reboot endpoints, or modify endpoint configuration.

This is a sanitized lab implementation designed to demonstrate the operational pattern without exposing proprietary production code, credentials, customer information, or internal infrastructure details.

## Usage

Run the assessment from PowerShell:

```powershell
.\Invoke-PatchAssessment.ps1
