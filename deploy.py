# %%
with open("token.txt", "r") as file:
    token_txt = file.read()

with open("ssh_key.txt", "r") as file:
    ssh_key_text = file.read()


# %%
from hcloud import Client
client = Client(
    token=token_txt
)

# %%
ssh_key_name = "ramdyz@st.amu.edu.pl"

if(client.ssh_keys.get_by_name(ssh_key_name)):
    ssh_key = client.ssh_keys.get_by_name(ssh_key_name)
else:
    ssh_key = client.ssh_keys.create(name=ssh_key_name, public_key=ssh_key_text)


# %%
from hcloud.networks.domain import NetworkSubnet

network_name = "rd-network-test"

if(client.networks.get_by_name(network_name)):
    vnet = client.networks.get_by_name(network_name)
else:
    vnet = client.networks.create(
        name="rd-network-test", 
        ip_range="10.10.10.0/24", 
        subnets=[
            NetworkSubnet(ip_range="10.10.10.0/24", network_zone="eu-central", type="cloud")
        ]
    )
print(f"Utworzono sieć wirtualną {vnet.data_model.name} ({vnet.data_model.ip_range})")

# %%
volume_name = "rd-volume-test"

if(client.volumes.get_by_name(volume_name)):
    volume = client.volumes.get_by_name(volume_name)
else:
    volume = client.volumes.create(size=10, name=volume_name, location=Location('hel1'))


# %%
cloud_init_db = r'''#cloud-config

packages:
  - apt-transport-https
  - ca-certificates
  - curl
  - gnupg-agent
  - software-properties-common

write_files:
  - path: /root/docker-compose.yml
    content: |
        version: '3.9'

        services:
          db:
              image: mysql:5.7
              restart: always
              ports:
                - "10.10.10.2:3306:3306"
              environment:
                MYSQL_ROOT_PASSWORD: gitea
                MYSQL_DATABASE: gitea
                MYSQL_USER: gitea
                MYSQL_PASSWORD: gitea
              volumes:
                - db_data:/var/lib/mysql

          phpmyadmin:
              image: phpmyadmin
              restart: always
              ports:
                - "8080:80"
                
        volumes:
          db_data: {}

runcmd:
  - curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
  - add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
  - apt-get update -y
  - apt-get install -y docker-ce docker-ce-cli containerd.io
  - curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
  - chmod +x /usr/local/bin/docker-compose
  - systemctl start docker
  - systemctl enable docker
  - cd /root/ && docker-compose up -d
'''

# %%
from hcloud.locations.domain import Location
from hcloud.images.domain import Image
from hcloud.server_types.domain import ServerType

db_server_name = "rd-db-test"
if(client.servers.get_by_name(db_server_name)):
    db_server = client.servers.get_by_name(db_server_name)
else:
    db_server = client.servers.create(
        name=db_server_name, 
        server_type=ServerType("cpx11"), 
        image=Image(name="ubuntu-20.04"), 
        ssh_keys=[ssh_key], 
        networks=[vnet], 
        location=Location("hel1"), 
        user_data=cloud_init_db
    )


# %%
gitea_cloud_init = r'''#cloud-config

packages:
  - apt-transport-https
  - ca-certificates
  - curl
  - gnupg-agent
  - software-properties-common

write_files:
  - path: /root/docker-compose.yml
    content: |
        version: '3.9'
        
        services:
          server:
            image: gitea/gitea:1.15.6-rootless
            environment:
              GITEA__database__DB_TYPE: mysql
              GITEA__database__HOST: 10.10.10.2:3306    
              GITEA__database__NAME: gitea
              GITEA__database__USER: gitea
              GITEA__database__PASSWD: gitea
            restart: always
            volumes:
              - ./data:/root/gitea
              - ./config:/root/gitea/config
              - /etc/timezone:/etc/timezone:ro
              - /etc/localtime:/etc/localtime:ro
              - /mnt/volume:/data
            ports:
              - "3000:3000"
              - "222:22" 

runcmd:
  - curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
  - add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
  - apt-get update -y
  - apt-get install -y docker-ce docker-ce-cli containerd.io
  - curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
  - chmod +x /usr/local/bin/docker-compose
  - systemctl start docker
  - systemctl enable docker
  - cd /root/ && docker-compose up -d
  - chmod a+w /mnt/*
'''

# %%
from hcloud.locations.domain import Location
from hcloud.images.domain import Image
from hcloud.server_types.domain import ServerType
from hcloud.volumes.domain import Volume

db_server_name = "rd-gitea-test"
if(client.servers.get_by_name(db_server_name)):
    gitea_server = client.servers.get_by_name(db_server_name)
else:
    gitea_server = client.servers.create(
        name=db_server_name, 
        server_type=ServerType("cpx11"), 
        image=Image(name="ubuntu-20.04"), 
        ssh_keys=[ssh_key], 
        networks=[vnet], 
        location=Location("hel1"), 
        user_data=gitea_cloud_init,
        volumes=[volume.volume]
    )


# %%
# gitea_server.delete()
# db_server.delete()
# vnet.delete()
# volume.delete()
# ssh_key.delete()




