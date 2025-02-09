set -ex

DOES_SPOT_ROLE_EXIST=$(aws iam list-roles | grep -q 'spot.amazonaws.com')
if [[ ! -z $DOES_SPOT_ROLE_EXIST ]]; then
  aws iam create-service-linked-role --aws-service-name spot.amazonaws.com
fi

CLUSTER_NAME=nonprod

eksctl create cluster -f - <<EOF
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig

metadata:
  name: $CLUSTER_NAME
  region: us-east-1

autoModeConfig:
  enabled: true
  nodePools: []
EOF

NODE_ROLE_NAME=AmazonEKSNodeRole
aws iam create-role \
  --role-name $NODE_ROLE_NAME \
  --assume-role-policy-document "file://node_role_iam.json"
NODE_ROLE_ARN=$(aws iam get-role --role-name $NODE_ROLE_NAME --query 'Role.Arn' | tr -d '"')

aws iam attach-role-policy \
  --policy-arn arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy \
  --role-name $NODE_ROLE_NAME
aws iam attach-role-policy \
  --policy-arn arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPullOnly \
  --role-name $NODE_ROLE_NAME
aws iam attach-role-policy \
  --policy-arn arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy \
  --role-name $NODE_ROLE_NAME

sleep 5

aws eks create-access-entry \
  --cluster-name $CLUSTER_NAME \
  --principal-arn $NODE_ROLE_ARN \
  --type EC2
aws eks associate-access-policy \
  --cluster-name $CLUSTER_NAME \
  --principal-arn $NODE_ROLE_ARN \
  --policy-arn arn:aws:eks::aws:cluster-access-policy/AmazonEKSAutoNodePolicy \
  --access-scope type=cluster

kubectl apply -f - <<EOF
apiVersion: eks.amazonaws.com/v1
kind: NodeClass
metadata:
  name: private
spec:
  role: $NODE_ROLE_NAME
  subnetSelectorTerms:
    - tags:
        alpha.eksctl.io/cluster-name: $CLUSTER_NAME
        kubernetes.io/role/internal-elb: "1"
  securityGroupSelectorTerms:
    - tags:
        aws:cloudformation:logical-id: "ClusterSharedNodeSecurityGroup"
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
        name: private

      requirements:
        - key: "eks.amazonaws.com/instance-family"
          operator: In
          values: ["t3a", "t3", "t2"]
        - key: "eks.amazonaws.com/instance-size"
          operator: In
          values: ["medium"]
EOF

helm repo add crossplane-stable https://charts.crossplane.io/stable
helm repo update
helm install crossplane \
--create-namespace --namespace crossplane-system \
--set args='{"--enable-usages"}' \
crossplane-stable/crossplane

kubectl create secret generic aws-secret \
  -n crossplane-system \
  --from-file=creds=/root/.aws/credentials

STACK_OUTPUTS=$(aws cloudformation describe-stacks \
  --stack-name eksctl-$CLUSTER_NAME-cluster \
  --query "Stacks[0].Outputs")
VPC_ID=$(echo $STACK_OUTPUTS | jq -r '.[] | select(.OutputKey=="VPC") | .OutputValue')

kubectl wait --timeout=300s --for=create crds/providers.pkg.crossplane.io
kubectl wait --timeout=300s --for=create crds/providerrevisions.pkg.crossplane.io
kubectl wait --timeout=300s --for=create crds/environmentconfigs.apiextensions.crossplane.io

kubectl wait --timeout=300s --for=condition=Established crds/providers.pkg.crossplane.io
kubectl wait --timeout=300s --for=condition=Established crds/providerrevisions.pkg.crossplane.io
kubectl wait --timeout=300s --for=condition=Established crds/environmentconfigs.apiextensions.crossplane.io

kubectl apply -f - <<EOF
apiVersion: pkg.crossplane.io/v1
kind: Provider
metadata:
  name: provider-aws-s3
spec:
  package: xpkg.upbound.io/upbound/provider-aws-s3:v1.20.1
---
apiVersion: pkg.crossplane.io/v1
kind: Provider
metadata:
  name: provider-aws-elasticache
spec:
  package: xpkg.upbound.io/upbound/provider-aws-elasticache:v1.20.1
---
apiVersion: pkg.crossplane.io/v1
kind: Provider
metadata:
  name: provider-aws-rds
spec:
  package: xpkg.upbound.io/upbound/provider-aws-rds:v1.20.1
---
apiVersion: pkg.crossplane.io/v1
kind: Provider
metadata:
  name: provider-aws-cognitoidentity
spec:
  package: xpkg.upbound.io/upbound/provider-aws-cognitoidentity:v1.20.1
---
apiVersion: pkg.crossplane.io/v1
kind: Provider
metadata:
  name: provider-aws-ec2
spec:
  package: xpkg.upbound.io/upbound/provider-aws-ec2:v1.20.1
EOF
kubectl wait --timeout=300s --for=create crds/providerconfigs.aws.upbound.io
kubectl wait --timeout=300s --for=condition=Established crds/providerconfigs.aws.upbound.io
kubectl apply -f - <<EOF
apiVersion: aws.upbound.io/v1beta1
kind: ProviderConfig
metadata:
  name: default
spec:
  credentials:
    source: Secret
    secretRef:
      namespace: crossplane-system
      name: aws-secret
      key: creds
EOF

kubectl apply -f - <<EOF
apiVersion: pkg.crossplane.io/v1
kind: Function
metadata:
  name: function-patch-and-transform
spec:
  package: xpkg.upbound.io/crossplane-contrib/function-patch-and-transform:v0.1.4
---
apiVersion: pkg.crossplane.io/v1beta1
kind: Function
metadata:
  name: function-environment-configs
spec:
  package: xpkg.upbound.io/crossplane-contrib/function-environment-configs:v0.2.0
---
apiVersion: pkg.crossplane.io/v1beta1
kind: Function
metadata:
 name: function-kcl
spec:
 package: xpkg.upbound.io/crossplane-contrib/function-kcl:v0.2.0
EOF

helm install -n crossplane-system --set vpcID=$VPC_ID --set clusterName=$CLUSTER_NAME extras crossplane-extras/