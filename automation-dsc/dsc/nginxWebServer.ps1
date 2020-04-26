$IndexPage = @"
<html>
<head>
<title>My DSC Page</title>
</head>
<body>
<H1>Nginx DSC WebServer - (<?php echo gethostname(); ?>)</H1>
</body>
</html>
"@

Configuration linuxconfig {
  param
  (
    [parameter(Mandatory)]
    [String]
    $fileShareURL,

    [parameter(Mandatory)]
    [String]
    $fileShareKey
  )

  Import-DscResource -Module PSDesiredStateConfiguration
  Import-DscResource -Module nx
  # Import-DscResource -Module nxNetworking

  # Node "TestLinuxfile" {
  #   nxFile ExampleFile {
  #     DestinationPath = "/tmp/example"
  #     Contents = "hello world `n"
  #     Ensure = "Present"
  #     Type = "File"
  #   }
  # }

  Node "NginxWebServer" {
    nxFile ExampleFile {
      DestinationPath = "/tmp/example"
      Contents = "URL: $($fileShareURL)`nKey: $($fileShareKey)`n"
      Ensure = "Present"
      Type = "File"
    }

    nxFile nginxphp_folder {
      DestinationPath = "/var/www/html"
      Type = "directory"
      Recurse = $true
      Force = $true
    }

    nxFile nginxconfig_folder {
      DestinationPath = "/etc/nginx/sites-available"
      Type = "directory"
      Recurse = $true
      Force = $true
   }

    nxFile nginxphp {
      DestinationPath = "/var/www/html/index.php"
      Type = "file"
      Contents = $IndexPage
      Force = $true
      DependsOn = "[nxFile]nginxphp_folder"
    }

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
      DependsOn = "[nxFile]nginxphp", "[nxFile]nginxconfig"
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
