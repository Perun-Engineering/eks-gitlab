# The in-cluster part of GitLab (Helm release, namespace, secrets, lean backup CronJob) is no
# longer managed by this module: deploy it with a GitOps tool or Helm directly. These blocks
# drop the objects from Terraform state on the first apply without deleting them from the
# cluster. Each block covers every instance of a count/for_each resource.
#
# The helm, kubernetes and kubectl providers stay declared for this release so Terraform can
# process the forgotten state entries; they are dropped in a later release.

removed {
  from = helm_release.gitlab
  lifecycle {
    destroy = false
  }
}

removed {
  from = kubectl_manifest.lean_backup
  lifecycle {
    destroy = false
  }
}

removed {
  from = kubernetes_namespace_v1.gitlab
  lifecycle {
    destroy = false
  }
}

removed {
  from = kubernetes_secret_v1.postgres
  lifecycle {
    destroy = false
  }
}

removed {
  from = kubernetes_secret_v1.registry_postgres
  lifecycle {
    destroy = false
  }
}

removed {
  from = kubernetes_secret_v1.redis
  lifecycle {
    destroy = false
  }
}

removed {
  from = kubernetes_secret_v1.smtp
  lifecycle {
    destroy = false
  }
}

removed {
  from = kubernetes_secret_v1.gitlab_rails_storage
  lifecycle {
    destroy = false
  }
}

removed {
  from = kubernetes_secret_v1.gitlab_omniauth_providers
  lifecycle {
    destroy = false
  }
}

removed {
  from = kubernetes_secret_v1.ldap
  lifecycle {
    destroy = false
  }
}

removed {
  from = kubernetes_secret_v1.gitlab_registry_storage
  lifecycle {
    destroy = false
  }
}
