##

PS C:\Users\turkf\Pictures\mag2\RSO\Swappo\api-gateway\kong> kubectl get service -n kong kong-gateway-proxy -w
NAME                 TYPE           CLUSTER-IP       EXTERNAL-IP   PORT(S)                      AGE
kong-gateway-proxy   LoadBalancer   34.118.225.138   34.40.17.122   80:32518/TCP,443:32332/TCP   37s
