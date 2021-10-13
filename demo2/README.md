# Configuring leaf2 with Ansible

* Copy the ansible files on to the `oob-mgmt-server`

```
$ git clone <THIS REPO>
$ cd demo2
```

* Run the playbook

```
ansible-playbook nvue.yml
```

* Explore the input variables

```
  vars:
    ansible_python_interpreter: /usr/bin/python3
    bgp: 
      enabled: yes
      id: 10.10.10.2
      asn: 65102
      interfaces: 
      - swp2
    loopback: 10.10.10.2/32
```

* Expore the nvue template

Main file

```
- set:
    system:
      hostname: {{ inventory_hostname }}
{% if bgp is defined %}
{%   include './features/bgp.j2' %}
{% endif %}

    interface:
{% include './features/loopback.j2' %}

{% include './features/swp.j2' %}
```

BGP config

```
    router:
      bgp:
        enable: {{ 'on' if bgp.enabled else 'off' }}
        autonomous-system: {{ bgp.asn }}
        router-id: {{ bgp.id }}
    vrf:
      default:
        router:
          bgp:
            enable: on
            neighbor:
{% for neighbor in bgp.interfaces %}
              {{ neighbor }}:
                peer-group: UNDERLAY
                type: unnumbered
{% endfor %}{# bgp.interfaces #}
            peer-group:
              UNDERLAY:
                remote-as: external
```