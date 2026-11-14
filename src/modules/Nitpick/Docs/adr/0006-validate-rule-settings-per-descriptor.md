---
status: accepted
---

# Validate Rule Settings Per Descriptor

Project configuration keeps rule settings separate from compatibility policy and keys them by qualified rule ID. Each descriptor owns a strict integer schema with defaults and optional bounds; the coordinator validates all configured IDs and values once, against every known descriptor, before target processing, and later stages trust that result. It then supplies only that rule's effective settings in isolated context copies. Direct descriptor calls use `Context.RuleSettings`, while correction reanalysis uses an ID-keyed `-RuleSettings` map for multiple descriptors. Discovery validates settings for known excluded rules without turning an excluded callable conflict into an invocation failure unless settings for that ambiguous ID require a schema.
