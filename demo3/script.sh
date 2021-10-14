#!/bin/bash

function printAndRun () {
    read -p "root@spine:mgmt:~# $1"
    eval $1
    read -p ""
}

function prep () {
    apt install jq -y
    sudo systemctl start nvued
    echo 'root:root' | sudo chpasswd
    sed -i 's/cumulus/root/' /etc/nvue-auth.yaml
    systemctl restart nvued       
    cat << EOF > loopback.json
{
    "ip": {
      "address": {
        "10.10.10.101/32": {}
      }
    },
    "type": "loopback"
}
EOF
    cat << EOF > swp.json
{
  "swp1": {
    "type": "swp"
  },
  "swp2": {
    "type": "swp"
  }
}
EOF
}

function reset () {
    rm /etc/nginx/sites-enabled/nvue.conf
    nv config apply empty -y
}

function begin () {
    printAndRun "nv show interface"
    printAndRun "curl -s --unix-socket /run/nvue/nvue.sock localhost/nvue_v1/interface?rev=operational | jq '.swp1'"
    printAndRun "curl -s --unix-socket /run/nvue/nvue.sock localhost/nvue_v1/interface?rev=applied | jq '.lo'"
    printAndRun "sed -i 's/localhost/0.0.0.0/' /etc/nginx/sites-available/nvue.conf"
    printAndRun "cat /etc/nginx/sites-available/nvue.conf | grep proxy"
    printAndRun "ln -s /etc/nginx/sites-available/nvue.conf /etc/nginx/sites-enabled/nvue.conf"
    printAndRun "sudo systemctl restart nginx"
    printAndRun "netstat -an | grep 8765"
    printAndRun "curl -u 'root:root' --insecure https://localhost:8765/nvue_v1/interface?rev=applied"
    printAndRun "curl -u 'root:root' --insecure https://localhost:8765/nvue_v1/system?rev=applied"
    printAndRun "curl -u 'root:root' --insecure https://localhost:8765/env_v1/native/hostnamectl"
    printAndRun "curl -u 'root:root' --insecure https://localhost:8765/dns_v1/native/nameserver"
    printAndRun "cp -au /usr/lib/python3/dist-packages/cue_cue_v1/openapi/ ."
    printAndRun "less openapi/dns.yaml"
    printAndRun "# REVISION WORKFLOW"
    printAndRun "curl --insecure --request POST -u 'root:root' https://localhost:8765/nvue_v1/revision"
    printAndRun "curl --insecure -u 'root:root' https://localhost:8765/nvue_v1/revision"
    read -p "changeset=" changeset
    printAndRun "cat loopback.json"
    printAndRun "cat swp.json"
    printAndRun "curl --insecure --request PATCH -H 'Content-Type: application/json' -u 'root:root' -d @loopback.json https://localhost:8765/nvue_v1/interface/lo?rev=${changeset}"
    printAndRun "curl --insecure --request PATCH -H 'Content-Type: application/json' -u 'root:root' -d @swp.json https://localhost:8765/nvue_v1/interface?rev=${changeset}"
    printAndRun "curl --insecure -u 'root:root'  https://localhost:8765/nvue_v1/interface/lo?rev=${changeset}"
    printAndRun "date=$(echo $changeset | cut -d'/' -f3)"
    printAndRun "curl --insecure --request PATCH -H 'Content-Type: application/json' -u 'root:root' -d '{\"state\": \"apply\"}' https://localhost:8765/nvue_v1/revision/changeset%2Froot%2F${date}"
    printAndRun "curl --insecure -u 'root:root' https://localhost:8765/nvue_v1/revision/changeset%2Froot%2F${date}"
    printAndRun "curl --insecure --request PATCH -H 'Content-Type: application/json' -u 'root:root' -d '{\"state\": \"apply\", \"auto-prompt\": {\"ays\": \"ays_yes\"}}' https://localhost:8765/nvue_v1/revision/changeset%2Froot%2F${date}"
    printAndRun "curl --insecure -u 'root:root' https://localhost:8765/nvue_v1/revision/changeset%2Froot%2F${date}"
    printAndRun "curl --insecure -u 'root:root' https://localhost:8765/config_v1/rev/applied | jq '.interface.lo'"
}