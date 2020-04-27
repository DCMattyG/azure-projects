# $IndexPage = @"
# <html>
# <head>
# <title>My DSC Page</title>
# </head>
# <body>
# <H1>Nginx DSC WebServer - (<?php echo gethostname(); ?>)</H1>
# </body>
# </html>
# "@

Configuration linuxconfig {
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

  # $mntPath="/mnt/nginx"
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

    # nxFile nginxphp_folder {
    #   DestinationPath = "/var/www/html"
    #   Type = "directory"
    #   Recurse = $true
    #   Force = $true
    # }

    nxFile nginxconfig_folder {
      DestinationPath = "/etc/nginx/sites-available"
      Type = "directory"
      Recurse = $true
      Force = $true
   }

    # nxFile nginxphp {
    #   DestinationPath = "/var/www/html/index.php"
    #   Type = "file"
    #   Contents = $IndexPage
    #   Force = $true
    #   DependsOn = "[nxFile]nginxphp_folder"
    # }

    nxFile nginxconfig {
       SourcePath = "https://raw.githubusercontent.com/DCMattyG/azure-projects/master/vmss-linux-dsc/config/default"
       DestinationPath = "/etc/nginx/sites-available/default"
       Mode = "644"
       Type = "file"
       Force = $true
       DependsOn = "[nxFile]nginxconfig_folder"
    }

    nxPackage php {
      Name = "php7.0-fpm"
      Ensure = "Present"
      PackageManager = "apt"
      DependsOn = "[nxFile]nginxconfig", "[nxScript]mountFileShare"#, "[nxFile]nginxphp"
    }

    nxPackage nginx {
      Name = "nginx"
      Ensure = "Present"
      PackageManager = "apt"
      Arguments = "-o Dpkg::Options::='--force-confold'"
      DependsOn = "[nxPackage]php"
    }

    nxService nginxsvcstart {
      Name = "nginx"
      State = "running"
      Enabled = $true
      Controller = "systemd"
      DependsOn = "[nxPackage]nginx"
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
