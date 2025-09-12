1 Add subnet: 10.0.4.0/27 tipo gateway



az resource update --resource-group rg-mpzsql --name mpzsqldeacr7p6gpzzcik3m --resource-type "Microsoft.ContainerRegistry/registries" --api-version "2021-06-01-preview" --set "properties.policies.exportPolicy.status=enabled" --set "properties.publicNetworkAccess=enabled"






openssl pkcs12 -in clientcert.pfx -nokeys -out clientcert_public.pem


openssl pkcs12 -in clientcert.pfx -nocerts -out clientcert_private_encrypted.pem -nodes                


openssl rsa -in clientcert_private_encrypted.pem -out clientcert_private.pem
