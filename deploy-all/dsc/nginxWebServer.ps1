﻿Configuration linuxconfig {
  param
  (
    [parameter(Mandatory)]
    [String]
    $storageAccountName,

    [parameter(Mandatory)]
    [String]
    $storageAccountKey,

    [parameter(Mandatory)]
    [String]
    $fileShareName
  )

  Import-DscResource -Module PSDesiredStateConfiguration
  Import-DscResource -Module nx
  # Import-DscResource -Module nxNetworking

  $smbPath="//$storageAccountName.file.core.windows.net/$fileShareName"
  $smbCredentialFile="/etc/smbcredentials/$storageAccountName.cred"

  Node "NginxWebServer" {
    nxPackage autofs {
      Name = "autofs"
      Ensure = "Present"
      PackageManager = "apt"
    }

    nxScript mountFileShare {
      GetScript = @"
#!/bin/bash
ls /fileshares/$fileShareName
"@
      SetScript = @"
#!/bin/bash
if [ ! -d "/etc/smbcredentials" ]; then
  sudo mkdir "/etc/smbcredentials"
fi

if [ ! -f $smbCredentialFile ]; then
    echo "username=$storageAccountName" | sudo tee $smbCredentialFile > /dev/null
    echo "password=$storageAccountKey" | sudo tee -a $smbCredentialFile > /dev/null
else 
    echo "The credential file $smbCredentialFile already exists, and was not modified."
fi

sudo chmod 600 $smbCredentialFile

if [ ! -d "/fileshares" ]; then
  sudo mkdir "/fileshares"
fi

if [ ! -f "/etc/auto.fileshares" ]; then
  sudo touch /etc/auto.fileshares
  echo "$fileShareName -fstype=cifs,credentials=$smbCredentialFile :$smbPath" | sudo tee /etc/auto.fileshares > /dev/null
fi

if ! grep -q "/fileshares" /etc/auto.master
then
  echo "/fileshares /etc/auto.fileshares --timeout=60" | sudo tee -a /etc/auto.master > /dev/null
fi

sudo service autofs restart
"@

      TestScript = @"
#!/bin/bash
if [ -d "/fileshares/$fileShareName" ]
then
    exit 0
else
    exit 1
fi
"@
      DependsOn = "[nxPackage]autofs"
    }

    nxPackage php {
      Name = "php7.0-fpm"
      Ensure = "Present"
      PackageManager = "apt"
      DependsOn = "[nxScript]mountFileShare"
    }

    nxPackage nginx {
      Name = "nginx"
      Ensure = "Present"
      PackageManager = "apt"
      # Arguments = "-o Dpkg::Options::='--force-confold'"
      DependsOn = "[nxPackage]php"
    }

    nxScript configureNginx {
      GetScript = @"
#!/bin/bash
cat /etc/nginx/sites-available/default
"@
      SetScript = @"
#!/bin/bash
update='
        location ~ \.php$ {
                include snippets/fastcgi-php.conf;      
                fastcgi_pass unix:/run/php/php7.0-fpm.sock;
        }'

perl -i.bak -spe 'BEGIN{undef $/;} s/(\t#location ~ \\\.php\$ \{[^\}]*(?=\})})/`$replace/smg' -- -replace="`$update" /etc/nginx/sites-available/default

old_sites='index index.html index.htm index.nginx-debian.html;'
new_sites='index index.php index.html index.htm index.nginx-debian.html;'

perl -i.bak -spe 'BEGIN{undef $/;} s/`$old/`$new/smg' -- -old="`$old_sites" -new="`$new_sites" /etc/nginx/sites-available/default

old_root='root /var/www/html;'
new_root='root /fileshares/$fileShareName;'

perl -i.bak -spe 'BEGIN{undef $/;} s/`$old/`$new/smg' -- -old="`$old_root" -new="`$new_root" /etc/nginx/sites-available/default

sudo service nginx restart
"@
      TestScript = @"
#!/bin/bash
if ! grep -q "index index.php index.html index.htm index.nginx-debian.html;" /etc/nginx/sites-available/default
then
  exit 1
else
  exit 0
fi
"@
      DependsOn = "[nxScript]mountFileShare", "[nxPackage]php", "[nxPackage]nginx"
    }

    # nxFirewall FWConfig {
    #   Name = "Allow Nginx HTTP"
    #   InterfaceName = "eth0" 
    #   FirewallType = "firewalld"
    #   Ensure = "Present"
    #   Access = "Allow"
    #   Direction = "Input"
    #   DestinationPort = "80"
    #   Position = "Before-End"
    # }
  }
}
