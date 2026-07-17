apiVersion: batch/v1
kind: CronJob
metadata:
  name: ${cronjob_name}
  namespace: ${namespace}
  labels:
    app: toolbox
    release: ${release_name}
    backup-tier: lean
spec:
  concurrencyPolicy: ${concurrency_policy}
  failedJobsHistoryLimit: ${failed_jobs_history_limit}
  successfulJobsHistoryLimit: ${successful_jobs_history_limit}
  schedule: "${schedule}"
  suspend: false
  jobTemplate:
    metadata: {}
    spec:
      backoffLimit: ${backoff_limit}
      activeDeadlineSeconds: ${active_deadline_seconds}
      ttlSecondsAfterFinished: ${ttl_seconds_after_finished}
      template:
        metadata:
          annotations:
            ${pod_annotations_yaml}
          labels:
            app: toolbox
            release: ${release_name}
            backup-tier: lean
        spec:
          restartPolicy: ${restart_policy}
          serviceAccountName: ${service_account}
          securityContext:
            fsGroup: 1000
            runAsGroup: 1000
            runAsUser: 1000
            seccompProfile:
              type: RuntimeDefault
          initContainers:
          - name: certificates
            image: ${certificates_image}
            imagePullPolicy: IfNotPresent
            env:
            - name: TZ
              value: UTC
            - name: GITLAB_LOG_LEVEL
              value: ERROR
            securityContext:
              allowPrivilegeEscalation: false
              capabilities:
                drop:
                - ALL
              runAsNonRoot: true
              runAsUser: 1000
            resources:
              requests:
                cpu: 50m
            volumeMounts:
            - mountPath: /etc/ssl/certs
              name: etc-ssl-certs
            - mountPath: /etc/pki/ca-trust/extracted/pem
              name: etc-pki-ca-trust-extracted-pem
          - name: configure
            command:
            - sh
            - /config/configure
            image: ${configure_image}
            imagePullPolicy: IfNotPresent
            env:
            - name: TZ
              value: UTC
            - name: GITLAB_LOG_LEVEL
              value: ERROR
            securityContext:
              allowPrivilegeEscalation: false
              capabilities:
                drop:
                - ALL
              runAsNonRoot: true
              runAsUser: 1000
            resources:
              requests:
                cpu: 50m
            volumeMounts:
            - mountPath: /config
              name: toolbox-config
              readOnly: true
            - mountPath: /init-config
              name: init-toolbox-secrets
              readOnly: true
            - mountPath: /init-secrets
              name: toolbox-secrets
          containers:
          - name: toolbox-backup
            args:
            - /bin/bash
            - -c
            - ${backup_command}
            image: ${toolbox_image}
            imagePullPolicy: IfNotPresent
            env:
            - name: ARTIFACTS_BUCKET_NAME
              value: ${bucket_prefix}-artifacts
            - name: REGISTRY_BUCKET_NAME
              value: ${bucket_prefix}-registry
            - name: LFS_BUCKET_NAME
              value: ${bucket_prefix}-lfs
            - name: UPLOADS_BUCKET_NAME
              value: ${bucket_prefix}-uploads
            - name: PACKAGES_BUCKET_NAME
              value: ${bucket_prefix}-packages
            - name: EXTERNAL_DIFFS_BUCKET_NAME
              value: ${bucket_prefix}-mr-diffs
            - name: TERRAFORM_STATE_BUCKET_NAME
              value: ${bucket_prefix}-terraform-state
            - name: CI_SECURE_FILES_BUCKET_NAME
              value: ${bucket_prefix}-ci-secure-files
            - name: AGENT_PLAN_CONTENT_BUCKET_NAME
              value: ${release_name}-agent-plan-content
            - name: BACKUP_BUCKET_NAME
              value: ${bucket_prefix}-backup-storage
            - name: BACKUP_BACKEND
              value: s3
            - name: TMP_BUCKET_NAME
              value: ${bucket_prefix}-backup-tmp-storage
            - name: PAGES_BUCKET_NAME
              value: ${bucket_prefix}-pages
            - name: CONFIG_TEMPLATE_DIRECTORY
              value: /var/opt/gitlab/templates
            - name: CONFIG_DIRECTORY
              value: /srv/gitlab/config
            - name: TZ
              value: UTC
            - name: GITLAB_LOG_LEVEL
              value: ERROR
            securityContext:
              allowPrivilegeEscalation: false
              capabilities:
                drop:
                - ALL
              runAsNonRoot: true
              runAsUser: 1000
            resources:
              ${resources_yaml}
            volumeMounts:
            - mountPath: /etc/gitlab/registry-db/
              name: registry-db-config
              readOnly: true
            - mountPath: /etc/gitlab/openbao-db/
              name: openbao-db-config
              readOnly: true
            - mountPath: /var/opt/gitlab/templates
              name: toolbox-config
            - mountPath: /etc/gitlab
              name: toolbox-secrets
              readOnly: true
            - mountPath: /srv/gitlab/config/secrets.yml
              name: toolbox-secrets
              subPath: rails-secrets/secrets.yml
            - mountPath: /srv/gitlab/tmp
              name: toolbox-tmp
            - mountPath: /etc/ssl/certs/
              name: etc-ssl-certs
              readOnly: true
            - mountPath: /etc/pki/ca-trust/extracted/pem
              name: etc-pki-ca-trust-extracted-pem
              readOnly: true
          volumes:
          - name: registry-db-config
            projected:
              defaultMode: 288
              sources:
              - configMap:
                  items:
                  - key: db-connection.env
                    path: connection.env
                  name: ${release_name}-registry-db-connection-config
                  optional: true
              - configMap:
                  items:
                  - key: backup-user
                    path: backup-user.env
                  - key: restore-user
                    path: restore-user.env
                  name: ${release_name}-toolbox-registry-db-backuprestore-users
                  optional: true
              - secret:
                  items:
                  - key: backupPassword
                    path: backup-pass
                  - key: restorePassword
                    path: restore-pass
                  name: ${release_name}-toolbox-registry-database-password
                  optional: true
          - name: openbao-db-config
            projected:
              defaultMode: 288
              sources:
              - configMap:
                  items:
                  - key: db-connection.env
                    path: connection.env
                  name: ${release_name}-toolbox-openbao-db-connection-config
                  optional: true
              - configMap:
                  items:
                  - key: backup-user
                    path: backup-user.env
                  - key: restore-user
                    path: restore-user.env
                  name: ${release_name}-toolbox-openbao-db-backuprestore-users
                  optional: true
              - secret:
                  items:
                  - key: backupPassword
                    path: backup-pass
                  - key: restorePassword
                    path: restore-pass
                  name: ${release_name}-toolbox-openbao-database-password
                  optional: true
          - name: toolbox-config
            projected:
              defaultMode: 420
              sources:
              - configMap:
                  name: ${release_name}-toolbox
          - name: toolbox-tmp
            ephemeral:
              volumeClaimTemplate:
                metadata:
                  labels:
                    app: toolbox
                    release: ${release_name}
                    backup-tier: lean
                spec:
                  accessModes:
                  - ReadWriteOnce
                  resources:
                    requests:
                      storage: ${tmp_storage_size}
                  volumeMode: Filesystem
          - name: init-toolbox-secrets
            projected:
              defaultMode: 256
              sources:
              - secret:
                  items:
                  - key: secrets.yml
                    path: rails-secrets/secrets.yml
                  name: ${rails_secret_name}
              - secret:
                  items:
                  - key: secret
                    path: shell/.gitlab_shell_secret
                  name: ${release_name}-gitlab-shell-secret
              - secret:
                  items:
                  - key: token
                    path: gitaly/gitaly_token
                  name: ${release_name}-gitaly-secret
              - secret:
                  items:
                  - key: secret
                    path: redis/redis-password
                  name: ${release_name}-redis-password
              - secret:
                  items:
                  - key: postgresql-password
                    path: postgres/psql-password-ci
                  name: ${release_name}-postgresql-password
              - secret:
                  items:
                  - key: postgresql-password
                    path: postgres/psql-password-main
                  name: ${release_name}-postgresql-password
              - secret:
                  items:
                  - key: registry-auth.key
                    path: registry/gitlab-registry.key
                  name: ${release_name}-registry-secret
              - secret:
                  items:
                  - key: secret
                    path: registry/notificationSecret
                  name: ${release_name}-registry-notification
              - secret:
                  items:
                  - key: config
                    path: objectstorage/.s3cfg
                  name: ${release_name}-rails-storage
              - secret:
                  items:
                  - key: shared_secret
                    path: pages/secret
                  name: ${release_name}-gitlab-pages-secret
              - secret:
                  items:
                  - key: connection
                    path: objectstorage/object_store
                  name: ${release_name}-rails-storage
              - secret:
                  items:
                  - key: connection
                    path: objectstorage/ci_secure_files
                  name: ${release_name}-rails-storage
              - secret:
                  items:
                  - key: provider
                    path: omniauth/gitlab-google-oauth2/provider
                  name: gitlab-google-oauth2
          - name: toolbox-secrets
            emptyDir:
              medium: Memory
          - name: etc-ssl-certs
            emptyDir:
              medium: Memory
          - name: etc-pki-ca-trust-extracted-pem
            emptyDir:
              medium: Memory
          nodeSelector:
            ${node_selector_yaml}
          tolerations:
            ${tolerations_yaml}
