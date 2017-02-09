{% from "ceph/map.jinja" import global_settings as gs with context %}
{% from "ceph/map.jinja" import mon_settings as ms with context %}
{% from "ceph/macros.sls" import auth_get_or_create with context %}

{% for name, user in ms.users.iteritems() -%}

{%- if user.get('action', '') == 'create' %}
{{ auth_get_or_create(name, user) }}

cp.push {{ user.keyring_file }}:
  module.wait:
    - name: cp.push
    - path: {{ user.keyring_file }}
    - watch:
      - cmd: get_or_create_{{ name }}_keyring_{{ user.keyring_file }}
{%- endif %}


{%- if user.get('action', '') == 'update' %}
{%- endif %}

{% endfor -%}