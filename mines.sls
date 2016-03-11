# salt '*' saltutil.refresh_pillar
# salt '*' mine.update
# e.g. salt '*' mine.get '*' ip_map

mine_functions:
  ip_map:
    - mine_function: grains.get
    - ip_interfaces
  hostname:
    - mine_function: grains.get
    - host
