#!/bin/bash
function prep () {
    cp -au /usr/lib/python3/dist-packages/cue_cue_v1/openapi/ .
    systemctl enable --now docker@mgmt.service
    docker pull openapitools/openapi-generator-cli
    cat << EOF > merge.py
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
EOF
    chmod +x merge.py
    ./merge.py
    cat << EOF > demo4.py
import ipdb; ipdb.set_trace()
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
def pp(input):
    import yaml
    print('---')
    print(yaml.dump(yaml.safe_load(api_client.last_response.data), indent=4))
    print('---')

pp(api_client.last_response.data)
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

from openapi_client.model import revision
path_params = {}
query_params = []
header_params = {}
api_client.call_api('/nvue_v1/revision', 'POST', path_params={}, query_params=query_params, header_params=header_params)
new_rev = api_client.deserialize(api_client.last_response, (revision.Revision,), True)
type(new_rev)
EOF
    chmod +x demo4.py
}


function printAndRun () {
    read -p "root@spine:mgmt:~# $1"
    eval $1
    read -p ""
}


function reset () {
    echo 'Reset config for demo4'
}

function begin () {

docker run --rm -v "${PWD}/openapi:/local" openapitools/openapi-generator-cli generate -i /local/revision.yaml -g python -o /local/python --skip-validate-spec
docker run --rm -v "${PWD}/openapi:/local" openapitools/openapi-generator-cli generate -i /local/out.yaml -g python -o /local/python  --skip-validate-spec
ls openapi/python/openapi_client/
cp demo4.py openapi/python/
cd openapi/python/
pip install ipython 
pip install -r requirements.txt
cp demo4 openapi/python/openapi_client/
python3 -m pdb demo4.py
}