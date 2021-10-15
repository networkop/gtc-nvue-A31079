#!/bin/bash
function prep () {
    cp -au /usr/lib/python3/dist-packages/cue_cue_v1/openapi/ .
    systemctl enable --now docker@mgmt.service
    docker pull openapitools/openapi-generator-cli
    pip install ipdb ipython
    ipython profile create
    echo "c.InteractiveShell.colors = 'Linux'" >> /root/.ipython/profile_default/ipython_config.py
    sed -i '/\(link,lineno,call\)/s/^/#/g' /usr/local/lib/python3.7/dist-packages/IPython/core/debugger.py
    ### ret.append(u'%s(%s)%s\n' % (link,lineno,call)) /usr/local/lib/python3.7/dist-packages/IPython/core/debugger.py
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
import ipdb; ipdb.set_trace(context=1)
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

print(interfaces.get('lo'))

print(yaml.dump(yaml.safe_load(api_client.last_response.data), indent=4))

from openapi_client.model import bgp

api_client.call_api('/nvue_v1/router/bgp', 'GET', path_params={}, query_params=query_params, header_params=header_params)

resp = api_client.deserialize(api_client.last_response, (bgp.Bgp,), True)

print(resp)

print(type(resp))

bgp_model = bgp.Bgp()

print(bgp_model.openapi_types['autonomous_system'])

bgp_model.set_attribute('autonomous_system', 65100)
bgp_model.set_attribute('router_id', "10.10.10.101")

print(bgp_model.to_dict())

from openapi_client.model import revision

path_params = {}
query_params = []
header_params = {}

api_client.call_api('/nvue_v1/revision', 'POST', path_params={}, query_params=query_params, header_params=header_params)

new_rev = api_client.deserialize(api_client.last_response, (revision.Revision,), True)

print(new_rev)

changeset = next(iter(new_rev.to_dict()))
query_params = [('rev', changeset)]

api_client.call_api('/nvue_v1/router/bgp', 'PATCH', path_params={}, query_params=query_params, header_params=header_params, body=bgp_model)

path_params = {}
query_params = [('rev', changeset)]
header_params = {}
api_client.call_api('/nvue_v1/router/bgp', 'GET', path_params={}, query_params=query_params, header_params=header_params)
print(yaml.dump(yaml.safe_load(api_client.last_response.data), indent=4))

path_params = {"revID": changeset}
query_params = []
header_params = {}
api_client.call_api('/nvue_v1/revision/{revID}', 'GET', path_params=path_params, query_params=query_params, header_params=header_params)
print(yaml.dump(yaml.safe_load(api_client.last_response.data), indent=4))

from openapi_client.model import peer_config
try:
    peer_conf = peer_config.PeerConfig(**{'type': 'unnumberasded', 'peer_group': "UNDERLAY"})
except:
    pass
peer_conf = peer_config.PeerConfig(**{'type': 'unnumbered', 'peer_group': "UNDERLAY"})


from openapi_client.model import address_family1
from openapi_client.model.af_ipv4_unicast1 import AfIpv4Unicast1
try:
    af = address_family1.AddressFamily1(**{"ipv4_unicast": "AfIpv4Unicast"})
except:
    pass
af = address_family1.AddressFamily1(**{"ipv4_unicast": AfIpv4Unicast1()})



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
print(yaml.dump(yaml.safe_load(api_client.last_response.data), indent=4))

path_params = {}
query_params = [('rev', 'applied')]
header_params = {}

api_client.call_api('/nvue_v1/', 'GET', path_params={}, query_params=query_params, header_params=header_params)
print(yaml.dump(yaml.safe_load(api_client.last_response.data), indent=4))

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

    printAndRun "docker run --rm -v \"${PWD}/openapi:/local\" openapitools/openapi-generator-cli generate -i /local/revision.yaml -g python -o /local/python --skip-validate-spec"
    printAndRun "docker run --rm -v \"${PWD}/openapi:/local\" openapitools/openapi-generator-cli generate -i /local/out.yaml -g python -o /local/python  --skip-validate-spec"
    printAndRun "ls openapi/python/openapi_client/"
    printAndRun "cp demo4.py openapi/python/"
    printAndRun "cd openapi/python/"
    printAndRun "pip install -r requirements.txt"
    printAndRun "python3 -m ipdb demo4.py"
}