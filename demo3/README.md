# REST API Demo

> all operations are performed on the `spine` switch

* enable nvue

```
sudo -i
apt install jq -y
sudo systemctl start nvued
```


* Retrieving state with NV CLI

```
nv show interface
```

* Retrieving operational state with REST API

```
curl -s --unix-socket /run/nvue/nvue.sock localhost/nvue_v1/interface?rev=operational | jq '.swp1'
{
  "ip": {
    "address": {}
  },
  "link": {
    "auto-negotiate": "off",
    "duplex": "full",
    "mac": "44:38:39:00:00:01",
    "mtu": 9216,
    "speed": "1G",
    "state": {
      "up": {}
    },
    "stats": {
      "carrier-transitions": 2,
      "in-bytes": 0,
      "in-drops": 0,
      "in-errors": 0,
      "in-pkts": 0,
      "out-bytes": 57456,
      "out-drops": 0,
      "out-errors": 0,
      "out-pkts": 192
    }
  },
  "type": "swp"
}
```

* Retrieving configuration state with REST API

```
curl -s --unix-socket /run/nvue/nvue.sock localhost/nvue_v1/interface?rev=applied | jq '.lo'
{
  "ip": {
    "address": {},
    "ipv4": {
      "forward": "on"
    },
    "ipv6": {
      "enable": "on",
      "forward": "on"
    },
    "vrf": "default"
  },
  "lldp": {},
  "type": "loopback"
}
```


* Enabling remote REST API

```
$ sed -i 's/localhost/0.0.0.0/' /etc/nginx/sites-available/nvue.conf
$ cat /etc/nginx/sites-available/nvue.conf | grep proxy
    proxy_pass http://unix:/run/nvue/nvue.sock;
$ ln -s /etc/nginx/sites-available/nvue.conf /etc/nginx/sites-enabled/nvue.conf
$ sudo systemctl restart nginx
```

* Allow root as a user 

```
passwd root
sed -i 's/cumulus/root/' /etc/nvue-auth.yaml
systemctl restart nvued                     
```

* Explore various API paths

```
curl  -u 'root:root' --insecure https://localhost:8765/nvue_v1/interface?rev=applied
curl  -u 'root:root' --insecure https://localhost:8765/nvue_v1/system?rev=applied
curl  -u 'root:root' --insecure https://localhost:8765/env_v1/native/hostnamectl
curl  -u 'root:root' --insecure https://localhost:8765/dns_v1/native/nameserver
```

* Download the openapi.json

```
curl -O  -u 'root:root' --insecure https://localhost:8765/nvue_v1/openapi.json
100  314M  100  314M    0     0  28.4M      0  0:00:11  0:00:11 --:--:-- 56.5M
```

or find it here
```
ls -lah /usr/lib/python3/dist-packages/cue_cue_v1/dist/openapi.json
```

but the json file is minified huge json file. An easier way is to look at the smaller YAML files


```
$ cp -au /usr/lib/python3/dist-packages/cue_cue_v1/openapi/ .
$ cat openapi/dns.yaml
```

* Let's see how to configure a loopback



Create a pending revision

```
curl --insecure --request POST -u 'root:root' https://localhost:8765/nvue_v1/revision
{
  "changeset/root/2021-10-11_15.48.54_CT6Q": {
    "state": "pending",
    "transition": {
      "issue": {},
      "progress": ""
    }
  }
}
```

Confirm that changes are in pending state

```
 curl --insecure -u 'root:root' https://localhost:8765/nvue_v1/revision
{
  "changeset/root/2021-10-11_15.48.54_CT6Q": {
    "state": "pending",
    "transition": {
      "issue": {},
      "progress": ""
    }
  },
  "empty": {
    "state": "inactive",
    "transition": {
      "issue": {},
      "progress": ""
    }
  },
  "startup": {
    "state": "inactive",
    "transition": {
      "issue": {},
      "progress": ""
    }
  }
}
```

Save the first (pending) revision name
```
changeset=$(curl -s --insecure -u 'root:root' https://localhost:8765/nvue_v1/revision | jq -r 'keys[0]')
```

Explore the data model (or look at the existing configs)

```
$ less openapi/interface.yaml
```

Create JSON payload 

```
cp /home/cumulus/gtc-nvue-A31079/demo3/*.json .
cat loopback.json
{
  "ip": {
    "address": {
      "10.10.10.101/32": {}
    }
  },
  "type": "loopback"
}
```

Apply the required changes

```
 curl --insecure \
 --request PATCH \
 -H 'Content-Type: application/json' \
 -u 'root:root' \
 -d @loopback.json \
 https://localhost:8765/nvue_v1/interface/lo?rev=${changeset}
```

```
 curl --insecure \
 --request PATCH \
 -H 'Content-Type: application/json' \
 -u 'root:root' \
 -d @swp.json \
 https://localhost:8765/nvue_v1/interface?rev=${changeset}
 ```

Check the pending changes

```
curl --insecure -u 'root:root'  https://localhost:8765/nvue_v1/interface/lo?rev=${changeset}
```

Now we can apply changes


```
date=$(echo $changeset | cut -d'/' -f3)

curl --insecure  \
 --request PATCH \
 -H 'Content-Type: application/json' \
 -u 'root:root' \
 -d '{"state": "apply"}' \
  https://localhost:8765/nvue_v1/revision/changeset%2Froot%2F${date}
```

Check the current state of the revision in case any of the changes need to be acknowledged:

```
curl --insecure -u 'root:root' https://localhost:8765/nvue_v1/revision/changeset%2Froot%2F${date}
```

Re-apply all changes and answer "yes" to all questions

```
curl --insecure \
 --request PATCH \
 -H 'Content-Type: application/json' \
 -u 'root:root' \
 -d '{"state": "apply", "auto-prompt": {"ays": "ays_yes"}}' \
  https://localhost:8765/nvue_v1/revision/changeset%2Froot%2F${date}
```

Confirm that the change has been applied

```
curl --insecure -u 'root:root' https://localhost:8765/nvue_v1/revision/changeset%2Froot%2F${date}
{
  "state": "applied",
  "transition": {
    "issue": {},
    "progress": ""
  }
}
```

Check that the configuration has been applied

```
curl --insecure -u 'root:root' https://localhost:8765/config_v1/rev/applied | jq '.interface.lo'
{
  "ip": {
    "address": {
      "10.10.10.101/32": {}
    },
    "ipv4": {
      "forward": "on"
    },
    "ipv6": {
      "enable": "on",
      "forward": "on"
    },
    "vrf": "default"
  },
  "lldp": {},
  "type": "loopback"
}
```