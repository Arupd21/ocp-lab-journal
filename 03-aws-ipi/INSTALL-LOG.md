# Day 4 — Full Install Log: OpenShift IPI on AWS

## Date: 2026-06-11
## Environment: WSL2 Ubuntu 24.04 on Windows 11

---

## Phase 1 — AWS CLI Setup

### Install AWS CLI v2
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip awscliv2.zip
    sudo ./aws/install
    aws --version
    # Output: aws-cli/2.34.64 Python/3.14.5 Linux/5.15.167.4-microsoft-standard-WSL2

### Configure AWS credentials
    aws configure
    # AWS Access Key ID: <redacted>
    # Secret Access Key: <redacted>
    # Default region: us-east-1
    # Default output: json

    aws sts get-caller-identity
    # UserId:  AIDAYEKP5GLW4WUHL3JBL
    # Account: 559050207981
    # Arn:     arn:aws:iam::559050207981:user/ad4you

### Verify IAM permissions
    aws iam list-attached-group-policies \
      --group-name $(aws iam list-groups-for-user \
      --user-name ad4you \
      --query 'Groups[0].GroupName' \
      --output text)
    # PolicyName: AdministratorAccess confirmed via group

---

## Phase 2 — Pre-Install Setup

### Download OpenShift installer
    mkdir -p ~/ocp-install/aws-ipi && cd ~/ocp-install/aws-ipi
    curl -L https://mirror.openshift.com/pub/openshift-v4/clients/ocp/stable/openshift-install-linux.tar.gz \
      -o openshift-install-linux.tar.gz
    tar xzf openshift-install-linux.tar.gz
    sudo mv openshift-install /usr/local/bin/
    openshift-install version
    # Output: openshift-install 4.22.0

### Generate SSH key
    ssh-keygen -t ed25519 -f ~/.ssh/ocp-aws-day4 -N "" -C "ocp-day4-lab"
    cat ~/.ssh/ocp-aws-day4.pub
    # ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICe1luHveQFteFW0pkK/kHy7ghZhN0CfaimAxxZV1lVf ocp-day4-lab

### Register domain aruplab.click
    # Done via AWS Console → Route53 → Register domain
    # Domain: aruplab.click | Price: $3/year | Auto-renew: OFF

    aws route53 list-hosted-zones --query 'HostedZones[*].Name'
    # Output: ["aruplab.click."]

### Create install-config.yaml
    # apiVersion: v1
    # baseDomain: aruplab.click
    # metadata:
    #   name: arup-day4
    # compute:
    # - hyperthreading: Enabled
    #   name: worker
    #   replicas: 2
    #   platform:
    #     aws:
    #       type: m5.xlarge
    #       zones:
    #       - us-east-1a
    # controlPlane:
    #   hyperthreading: Enabled
    #   name: master
    #   replicas: 3
    #   platform:
    #     aws:
    #       type: m5.xlarge
    #       zones:
    #       - us-east-1a
    # platform:
    #   aws:
    #     region: us-east-1
    # pullSecret: '<redacted>'
    # sshKey: 'ssh-ed25519 AAAAC3...'

    # Backup config before install
    cp install-config.yaml ~/ocp-install/install-config.yaml.bak

---

## Phase 3 — Cluster Install

### Launch IPI installer
    openshift-install create cluster \
      --dir ~/ocp-install/aws-ipi \
      --log-level=info

### Key milestones observed
    # INFO Credentials loaded from AWS config
    # INFO Creating infrastructure resources...
    # INFO Creating IAM roles for master and worker
    # INFO Network infrastructure is ready
    # INFO Creating Route53 records for control plane load balancer
    # INFO Created private Hosted Zone
    # INFO Control-plane machines are ready
    # INFO API v1.35.5 up — https://api.arup-day4.aruplab.click:6443
    # INFO Bootstrap etcd member has been removed
    # INFO Destroying bootstrap resources...
    # INFO All cluster operators have completed progressing
    # INFO Install complete!
    # INFO Time elapsed: 41m29s

### Cluster access details
    # API:       https://api.arup-day4.aruplab.click:6443
    # Console:   https://console-openshift-console.apps.arup-day4.aruplab.click
    # User:      kubeadmin
    # Kubeconfig: ~/ocp-install/aws-ipi/auth/kubeconfig
    # ClusterID: 6c770922-32a6-4af0-bed6-034ec76c4dd3

---

## Phase 4 — Cluster Verification

    export KUBECONFIG=/home/arupd/ocp-install/aws-ipi/auth/kubeconfig

    oc whoami
    # system:admin

    oc get nodes
    # ip-10-0-37-195.ec2.internal   Ready   control-plane,master   29m   v1.35.5
    # ip-10-0-43-232.ec2.internal   Ready   worker                 21m   v1.35.5
    # ip-10-0-54-230.ec2.internal   Ready   control-plane,master   29m   v1.35.5
    # ip-10-0-59-210.ec2.internal   Ready   control-plane,master   29m   v1.35.5
    # ip-10-0-63-150.ec2.internal   Ready   worker                 14m   v1.35.5

    oc get clusterversion
    # version   4.22.0   True   False   3m7s   Cluster version is 4.22.0

---

## Phase 5 — Lab 1: must-gather

    oc adm must-gather --dest-dir=/tmp/must-gather-day4

    # Summary:
    # ClusterID:        6c770922-32a6-4af0-bed6-034ec76c4dd3
    # ClusterVersion:   Stable at "4.22.0"
    # ClusterOperators: All healthy and stable

    # etcd endpoint health:
    # 10.0.37.195:2379  healthy  18ms
    # 10.0.59.210:2379  healthy  18ms
    # 10.0.54.230:2379  healthy  13ms

---

## Phase 6 — Lab 2: etcd Backup

    MASTER=$(oc get nodes -l node-role.kubernetes.io/master \
      -o jsonpath='{.items[0].metadata.name}')
    echo $MASTER
    # ip-10-0-37-195.ec2.internal

    oc debug node/$MASTER -- chroot /host \
      /usr/local/bin/cluster-backup.sh /home/core/assets/backup

    # Snapshot saved: snapshot_2026-06-11_160839.db
    # Size: 97MB | Keys: 11,518 | etcd: v3.6.0 | Revision: 39675

    # Verify files:
    oc debug node/$MASTER -- chroot /host ls -lh /home/core/assets/backup/
    # snapshot_2026-06-11_160839.db                    97M
    # static_kuberesources_2026-06-11_160839.tar.gz    82K

---

## Phase 7 — Lab 3: Cluster Operators

    oc get co
    # Result: 32/32 AVAILABLE=True, PROGRESSING=False, DEGRADED=False

---

## Phase 8 — Cluster Destroy

    openshift-install destroy cluster \
      --dir ~/ocp-install/aws-ipi \
      --log-level=info
    # INFO Uninstallation complete!
    # INFO Time elapsed: 5m6s

---

## Cost Summary
    # Cluster runtime:  ~1.5 hours
    # EC2 + networking: ~$1.60
    # Domain:           $3.00 (one-time, reusable for all future labs)
    # Total Day 4:      ~$4.60

---

## Lessons Learned
    # 1. IPI needs real Route53 hosted zone — devcluster.openshift.com is RH internal
    # 2. install-config.yaml is consumed by installer — always backup first
    # 3. must-gather "All healthy and stable" = clean cluster signal for GSS
    # 4. etcd backup = TWO files (snapshot .db + static_kuberesources.tar.gz)
    # 5. Bootstrap node auto-destroys after masters take over etcd
    # 6. oc debug node + chroot /host = standard way to access RHCOS filesystem
