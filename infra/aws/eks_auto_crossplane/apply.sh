eksctl create cluster -f - <<EOF
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig

metadata:
  name: nonprod
  region: us-east-1

autoModeConfig:
  enabled: true
  nodePools: []
EOF

kubectl apply -f - <<EOF
apiVersion: eks.amazonaws.com/v1
kind: NodeClass
metadata:
  name: default
spec:
  ephemeralStorage:
    size: "60Gi"
EOF

kubectl apply -f - <<EOF
apiVersion: karpenter.sh/v1
kind: NodePool
metadata:
  name: system
spec:
  template:
    metadata:
      labels:
        purpose: system
    spec:
      nodeClassRef:
        group: eks.amazonaws.com
        kind: NodeClass
        name: default

      requirements:
        - key: "eks.amazonaws.com/instance-family"
          operator: In
          values: ["t3a"]
        - key: "eks.amazonaws.com/instance-size"
          operator: In
          values: ["small"]
        - key: "topology.kubernetes.io/zone"
          operator: In
          values: ["us-east-1a", "us-east-1b"]
EOF

helm install crossplane \
--namespace crossplane-system \
--set args='{"--enable-usages"}' \
--create-namespace crossplane-stable/crossplane