$ClusterName = "ikp-dev"
$ApiServer   = "https://<api.dev.example:6443>"
$IssuerUrl   = "https://<openunison-host>/auth/realms/<realm>"
$ClientId    = "kubectl"
$CaFile      = "$HOME\.kube\openunison-ca.pem"
$CacheDir    = "$HOME\.kube\oidc-cache"

kubectl config set-cluster $ClusterName `
  --server=$ApiServer `
  --certificate-authority=$CaFile `
  --embed-certs=false

kubectl config set-credentials "$ClusterName-user" `
  --exec-command="$PWD\kubelogin.exe" `
  --exec-api-version=client.authentication.k8s.io/v1beta1 `
  --exec-arg=get-token `
  --exec-arg=--oidc-issuer-url=$IssuerUrl `
  --exec-arg=--oidc-client-id=$ClientId `
  --exec-arg=--token-cache-dir=$CacheDir `
  --exec-arg=--certificate-authority=$CaFile

kubectl config set-context $ClusterName `
  --cluster=$ClusterName `
  --user="$ClusterName-user"

kubectl config use-context $ClusterName
