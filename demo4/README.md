# Python SDK example

> All commands are executed on `spine` switch. We'll be configuring BGP.

```
cp -au /usr/lib/python3/dist-packages/cue_cue_v1/openapi/ .
```

```
systemctl enable --now docker@mgmt.service
docker pull openapitools/openapi-generator-cli
```

OpenAPI code generators don't work well with relative imports [GH#1110](https://github.com/OpenAPITools/openapi-generator/issues/1110), so the best way is to manually merge the yaml files, e.g.

```python
#!/bin/python3
import yaml
import os

directory = './openapi'
spec_file = os.path.join(directory, "bgp.yaml")
files_to_merge = ['common.yaml', 'feature.yaml', 'ip-address.yaml', 'asn.yaml', 'bgp-address-family.yaml', 'bgp-peer.yaml']
out_path = os.path.join(directory, "out.yaml")

# we're only interested in schema definitions
merged = {
    'components': {
        'schemas': {}
    }
}
for fn in files_to_merge:
    path = os.path.join(directory, fn)
    with open(path, 'r') as f:
        yaml_raw = yaml.safe_load(f)
        if 'components' in yaml_raw:
            for k in merged['components']:
                if k in yaml_raw['components']:
                    print(f'Updating {k} from {fn}')
                    merged['components'][k].update(yaml_raw['components'][k])

# loading the main spec file
path = os.path.join(directory, 'bgp.yaml')
with open(spec_file, 'r') as f:
    bgp_yaml = yaml.safe_load(f)

# and merging the other schema definitions 
if 'components' in bgp_yaml:
    for k in merged['components']:
        if k in bgp_yaml['components']:
            bgp_yaml['components'][k].update(merged['components'][k])

# this is needed to force double quotes on all strings
def quoted_presenter(dumper, data):
    return dumper.represent_scalar('tag:yaml.org,2002:str', data, style='"')
yaml.add_representer(str, quoted_presenter)

# generating the final yaml file
yaml_raw = yaml.dump(bgp_yaml,  indent=4)

# and removing references to merged files
for fn in files_to_merge:
    yaml_raw = yaml_raw.replace(fn, '')

with open(out_path, 'w') as f:
    f.write(yaml_raw)
```

Run this script

```
./merge.py
```

The resulting `openapi/out.yaml` file can be loaded into swagger explorers, e.g.

```
docker run -p 80:8080 swaggerapi/swagger-editor
```

Generate bindings for revision API:

```
docker run --rm -v "${PWD}/openapi:/local" \
    openapitools/openapi-generator-cli \
    generate \
    -i /local/revision.yaml \
    -g python \
    -o /local/python  \
    --skip-validate-spec
```

Generate binding for BGP API

```
docker run --rm -v "${PWD}/openapi:/local" \
    openapitools/openapi-generator-cli \
    generate \
    -i /local/out.yaml \
    -g python \
    -o /local/python  \
    --skip-validate-spec
```


The generated code is in `./openapi/python/openapi_client`

```
$ ls openapi/python/openapi_client/
api  api_client.py  apis  configuration.py  exceptions.py  __init__.py  model  models  model_utils.py  rest.py
```

Let's first see how to use it to retrieve some data

```
cd openapi/python/
pip install ipython 
pip install -r requirements.txt
ipython
```

```python
import openapi_client
import yaml
remote_url = "https://localhost:8765"
username = "root"
password = "root"

conf = openapi_client.Configuration(remote_url, username=username, password=password)
conf.verify_ssl = False
api_client = openapi_client.ApiClient(configuration=conf, header_name="Authorization", header_value=conf.get_basic_auth_token())

path_params = {}
query_params = [('rev', 'applied')]
header_params = {}

api_client.call_api('/nvue_v1/interface', 'GET', path_params={}, query_params=query_params, header_params=header_params)

resp =  api_client.last_response
interfaces = yaml.safe_load(resp.data)
interfaces.get('lo')
{'ip': {'address': {'10.10.10.101/32': {}},
  'ipv4': {'forward': 'on'},
  'ipv6': {'enable': 'on', 'forward': 'on'},
  'vrf': 'default'},
 'lldp': {},
 'type': 'loopback'}

```

or just do:

```python
def pp(input):
    import yaml
    print('---')
    print(yaml.dump(yaml.safe_load(api_client.last_response.data), indent=4))
    print('---')

pp(api_client.last_response.data)
```

This is the interface we've configured before.

Now let's try to configure BGP

```python
from openapi_client.model import bgp

api_client.call_api('/nvue_v1/router/bgp', 'GET', path_params={}, query_params=query_params, header_params=header_params)
api_client.deserialize(api_client.last_response, (bgp.Bgp,), True)
Out[63]: {'enable': 'off'}

bgp_model = bgp.Bgp()
bgp_model.openapi_types
bgp_model.openapi_types['autonomous_system']

bgp_model.set_attribute('autonomous_system', 65100)
bgp_model.set_attribute('router_id', "10.10.10.101")

bgp_model.to_dict()
Out[54]: {'autonomous_system': 65100, 'router_id': '10.10.10.101'}


api_client.call_api('/nvue_v1/router/bgp', 'PATCH', path_params={}, query_params=query_params, header_params=header_params, body=bgp_model)

ApiException: (409)
Reason: CONFLICT
HTTP response headers: HTTPHeaderDict({'Server': 'nginx/1.14.2', 'Date': 'Wed, 13 Oct 2021 14:31:35 GMT', 'Content-Type': 'application/problem+json', 'Content-Length': '117', 'Connection': 'keep-alive'})
HTTP response body: {
  "detail": "'applied' is a read-only revision",
  "status": 409,
  "title": "Conflict",
  "type": "about:blank"
}
```

Create a new revisoin

```python

from openapi_client.model import revision
path_params = {}
query_params = []
header_params = {}
api_client.call_api('/nvue_v1/revision', 'POST', path_params={}, query_params=query_params, header_params=header_params)
new_rev = api_client.deserialize(api_client.last_response, (revision.Revision,), True)
type(new_rev)
Out[107]: openapi_client.model.revision.Revision
print(new_rev)
{'changeset/root/2021-10-12_15.04.56_0ACZ': {'state': 'pending',
                                             'transition': {'issue': {},
                                                            'progress': ''}}}

changeset = next(iter(new_rev.to_dict()))

query_params = [('rev', changeset)]
api_client.call_api('/nvue_v1/router/bgp', 'PATCH', path_params={}, query_params=query_params, header_params=header_params, body=bgp_model)

path_params = {}
query_params = [('rev', changeset)]
header_params = {}
api_client.call_api('/nvue_v1/router/bgp', 'GET', path_params={}, query_params=query_params, header_params=header_params)
pp(api_client.last_response.data)

path_params = {"revID": changeset}
query_params = []
header_params = {}
api_client.call_api('/nvue_v1/revision/{revID}', 'GET', path_params=path_params, query_params=query_params, header_params=header_params)
pp(api_client.last_response.data)


from openapi_client.model import peer_config
peer_conf = peer_config.PeerConfig(**{'type': 'unnumbered', 'peer_group': "UNDERLAY"})

from openapi_client.model import address_family1
from openapi_client.model.af_ipv4_unicast1 import AfIpv4Unicast1
af = address_family1.AddressFamily1(**{"ipv4_unicast": AfIpv4Unicast1()})
```

Example of validation
```
peer_conf = peer_config.PeerConfig(**{'type': 'unnumberasded', 'peer_group': "UNDERLAY"})
ApiValueError: Invalid value for `type` (unnumberasded), must be one of [None, 'numbered', 'unnumbered', 'null']

af = address_family.AddressFamily(**{"ipv4_unicast": "AfIpv4Unicast"})
ApiValueError: Invalid inputs given to generate an instance of 'AddressFamilyConfigChildren'. The input data was invalid for the allOf schema 'AddressFamilyConfigChildren' in the composed schema 'AddressFamily'. Error=Invalid type for variable 'ipv4_unicast'. Required value type is AfIpv4Unicast and passed type was str at ['ipv4_unicast']
```

Carrying on

```python
from openapi_client.model import peer_group
from openapi_client.model import peer_groups
pg = peer_group.PeerGroup(**{"remote-as": "external", "address_family": af})
pgs = peer_groups.PeerGroups(**{"UNDERLAY": pg})

from openapi_client.model import peer
from openapi_client.model import peers

p = peer.Peer(**{"peer_group": "UNDERLAY", "type": "unnumbered"})
ps = peers.Peers(**{"swp1": p, "swp2": p})

from openapi_client.model import ipv4_unicast_rr
policy = ipv4_unicast_rr.Ipv4UnicastRr(**{"connected": {}})
from openapi_client.model import af_ipv4_unicast
ipv4_model = af_ipv4_unicast.AfIpv4Unicast(**{"redistribute": policy})
from openapi_client.model import address_family
af = address_family.AddressFamily(**{"ipv4_unicast": ipv4_model})


from openapi_client.model import vrf_bgp
vrf_bgp_model = vrf_bgp.VrfBgp(**{'peer_group':pgs, 'neighbor': ps, 'address_family': af})

query_params = [('rev', changeset)]
api_client.call_api('/nvue_v1/vrf/default/router/bgp', 'PATCH', path_params={}, query_params=query_params, header_params=header_params, body=vrf_bgp_model)




path_params = {"revID": changeset}
query_params = []
header_params = {}
api_client.call_api('/nvue_v1/revision/{revID}', 'PATCH', path_params=path_params, query_params=query_params, header_params=header_params, body={"state": "apply", "auto-prompt": {"ays": "ays_yes"}})
pp(api_client.last_response.data)
```

Confirm that changes have been applied

```python
path_params = {}
query_params = [('rev', 'applied')]
header_params = {}
api_client.call_api('/nvue_v1/', 'GET', path_params={}, query_params=query_params, header_params=header_params)
pp(api_client.last_response.data)
```
