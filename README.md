# Kubernetes Database Certificate Monitor
### Basics:
This project is essentially just a mix of kubectl, openssl, jq, and sed commands to monitor in-cluster database certificates from a json file. If the certificate will be expiring soon, the user should get an alert to a slack channel with details about the certificate in question.

It is designed for use with Bamboo, and assumes the build agent running the script has necessary access to the cluster and internet to be able to run the commands in the script.

### Possible improvements:
For smaller clusters with less to manage, this should work well with minor maintenance on the json file to ensure cluster/database information is up to date.

However, as clusters grow, there is a necessity for automating that maintenance. My recommendation would be creating a preliminary script to populate the json file dynamically, using kubectl and jq commands as we have done in `k8s-db-mon.sh`.