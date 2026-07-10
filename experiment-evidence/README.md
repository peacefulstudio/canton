# Experiment evidence

Burden-of-evidence artefacts for the PR `experiment: google.api.http annotations on CommandService`.

**This directory is internal to the Peaceful Studio fork.** Delete it before submitting any upstream PR to `digital-asset/canton` — these files are review aids, not part of the contribution.

## Contents

| Subdirectory | Purpose |
|---|---|
| [`go-package-harmlessness/`](go-package-harmlessness/) | Empirical proof that adding `option go_package = "..."` to the v2 protos does not affect any existing C# / Java / Scala codegen consumer. |
| [`openapi-generation/`](openapi-generation/) | The actual OpenAPI document generated from the annotated `command_service.proto`, plus the `buf.gen.yaml` used to produce it. The 1,372-line JSON is the "after" side of the SwaggerHub comparison linked from the PR description. |

## How to verify everything from scratch

The PR description (top of #1) has the full reproducible flow: install buf, drop the three google.api / google.rpc protos into `community/lib/google-common-protos-scala/target/protobuf_external/`, run `buf build` and `buf generate`. Every artefact in this directory is regeneratable from that flow.
