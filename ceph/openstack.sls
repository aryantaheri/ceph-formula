{% from "ceph/map.jinja" import ceph_settings with context %}
# Create OpenStack pools and users

include:
  - .repo

{% for service_name,service in ceph_settings.openstack.items() %}

{% for pool in service.get('pools', {}) %}

create_openstack_{{ service_name }}_pool_{{ pool.name }}:
  cmd.run:
    - name: |
        ceph osd pool create {{ pool.name }} \
        {{ pool.pool_pg_num }} \
        {{ pool.pool_pgp_num }}
    - unless: rados lspools | grep {{ pool.name }}

{% endfor %}

{% for user in service.get('users', {}) %}

create_openstack_{{ service_name }}_{{ user.name }}:
  cmd.run:
    - name: |
        ceph auth get-or-create --cluster {{ ceph_settings.cluster }} \
        {{ user.name }} \
        mon '{{ user.mon }}' \
        osd '{{ user.osd }}' > {{ ceph_settings.conf_dir }}{{ ceph_settings.cluster }}.{{ user.name }}.keyring

{% endfor %}

{% endfor %}