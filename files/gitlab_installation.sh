#!/bin/bash

# Instalar dependencias

sudo yum install -y curl policycoreutils-python openssh-server cronie
sudo lokkit -s http -s ssh
sudo yum update -y

# Set hostname
sudo hostnamectl set-hostname gitlab.osiris.com
sudo echo "127.0.0.1    gitlab.osiris.com    gitlab" >> /etc/hosts

# Agregar repositorio GitLab
curl https://packages.gitlab.com/install/repositories/gitlab/gitlab-ce/script.rpm.sh | sudo bash
sudo EXTERNAL_URL="http://gitlab.osiris.com" yum -y install gitlab-ce

# SMTP Setting

sudo cat >> /etc/gitlab/gitlab.rb << EOF
gitlab_rails['smtp_enable'] = true
gitlab_rails['smtp_address'] = "smtp.gmail.com"
gitlab_rails['smtp_port'] = 587
gitlab_rails['smtp_user_name'] = "jontambi.business@gmail.com"
gitlab_rails['smtp_password'] = "j0hnc!t027"
gitlab_rails['smtp_domain'] = "smtp.gmail.com"
gitlab_rails['smtp_authentication'] = "login"
gitlab_rails['smtp_enable_starttls_auto'] = true
gitlab_rails['smtp_tls'] = false
gitlab_rails['smtp_openssl_verify_mode'] = 'peer' # Can be: 'none', 'peer', 'client_once', 'fail_if_no_peer_cert', see http://api.rubyonrails.org/classes/ActionMailer/Base.html
EOF

sudo gitlab-ctl reconfigure

# Restart server
sudo reboot
