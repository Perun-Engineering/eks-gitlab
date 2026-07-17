locals {
  values     = yamldecode(var.values[0])
  app_config = local.values.global.appConfig
  global     = local.values.global

  omniauth_providers = {
    for k, v in local.values.global.appConfig.omniauth.providers :
    k => v.secret
  }

  buckets_app = {
    for k, v in local.app_config :
    k => v
    if k == "lfs" || k == "artifacts" || k == "packages" || k == "uploads" || k == "externalDiffs" || k == "terraformState" || k == "ciSecureFiles" || k == "dependencyProxy"
  }

  registry = {
    for k, v in local.values :
    k => v
    if k == "registry"
  }

  pages = {
    for k, v in local.global :
    k => v
    if k == "pages"
  }

  buckets_list = merge(
    {
      for k, v in local.buckets_app :
      k => v.bucket if v.enabled == true
    },
    {
      for k, v in local.registry :
      k => v.bucket if v.enabled == true
    },
    {
      for k, v in local.pages :
      k => v.objectStore.bucket if v.enabled == true
    },
    {
      backup : local.values.global.appConfig.backups.bucket
      backup_tmp : local.values.global.appConfig.backups.tmpBucket
    }
  )

  decoded_buckets_lifecycles = { for bucket, config in var.buckets_lifecycles :
    bucket => jsondecode(config)
  }

  # Filter only buckets with a non-empty lifecycle_rule
  filtered_buckets_lifecycles = {
    for bucket, config in local.decoded_buckets_lifecycles :
    bucket => config if length(try(config.lifecycle_rule, [])) > 0
  }

  # --- Lean backup CronJob ------------------------------------------------
  lean = var.lean_backup

  lean_name              = coalesce(local.lean.name, "${var.release_name}-toolbox-backup-lean")
  lean_service_account   = coalesce(local.lean.service_account_name, "${var.release_name}-toolbox")
  lean_rails_secret_name = coalesce(local.lean.rails_secret_name, try(local.values.global.railsSecrets.secret, "${var.release_name}-rails-secret"))

  # Container/init image tag is resolved automatically (no manual version to maintain), mirroring the
  # chart's `gitlab.versionTag` helper: take `global.gitlabVersion` if set, else the chart appVersion
  # exposed by the deployed helm_release, and prepend "v" when it is a plain semver (branch-name
  # versions are used verbatim). Repositories come from `values`; full `*_image` overrides win.
  lean_app_version = coalesce(try(local.values.global.gitlabVersion, null), try(helm_release.gitlab.metadata[0].app_version, ""))
  lean_image_tag   = can(regex("^\\d+\\.\\d+\\.\\d+(-rc\\d+)?(-pre)?$", local.lean_app_version)) ? "v${local.lean_app_version}" : local.lean_app_version

  lean_toolbox_image      = coalesce(local.lean.toolbox_image, "${try(local.values.gitlab.toolbox.image.repository, "")}:${local.lean_image_tag}")
  lean_certificates_image = coalesce(local.lean.certificates_image, "${try(local.values.global.certificates.image.repository, "")}:${local.lean_image_tag}")
  lean_configure_image    = coalesce(local.lean.configure_image, "${try(local.values.global.gitlabBase.image.repository, "")}:${local.lean_image_tag}")

  # s3 backend: the toolbox copies its rendered .s3cfg into $HOME before running backup-utility.
  lean_backup_command = "cp /etc/gitlab/.s3cfg $HOME/.s3cfg && backup-utility ${join(" ", [for s in local.lean.skip : "--skip ${s}"])}"

  # Drop null value/operator fields so the rendered tolerations stay clean.
  lean_tolerations = [for t in local.lean.tolerations : merge(
    { key = t.key, effect = t.effect },
    t.value != null ? { value = t.value } : {},
    t.operator != null ? { operator = t.operator } : {},
  )]

  # Baked pod annotations mirror the chart toolbox pod (logging + safe-to-evict); user-supplied
  # annotations (default: karpenter do-not-disrupt) merge on top.
  lean_pod_annotations = merge({
    "cluster-autoscaler.kubernetes.io/safe-to-evict" = "false"
    "logging/source"                                 = "service"
    "logging/stderr-parser"                          = "json"
    "logging/stdout-dt-field"                        = "time"
    "logging/stdout-dt-format"                       = "%Y-%m-%dT%H:%M:%SZ"
    "logging/stdout-parser"                          = "json"
    "logging/type"                                   = "gitlab"
  }, local.lean.pod_annotations)

  # Pre-indented YAML fragments injected into the CronJob template.
  lean_node_selector_yaml   = indent(12, trimspace(yamlencode(local.lean.node_selector)))
  lean_tolerations_yaml     = indent(12, trimspace(yamlencode(local.lean_tolerations)))
  lean_pod_annotations_yaml = indent(12, trimspace(yamlencode(local.lean_pod_annotations)))
  lean_resources_yaml       = indent(14, trimspace(yamlencode(local.lean.resources)))
}
