#!/bin/sh

statements=$(cat $1)
kubectl exec deployment/faf-db -- mysql --user=root --password= faf --execute="$statements"