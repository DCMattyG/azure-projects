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

  Import-DscResource -Module PSDesiredStateConfiguration
  Import-DscResource -Module nx
  # Import-DscResource -Module nxNetworking
  
  Node "TestLinuxfile" {
    nxFile ExampleFile {
      DestinationPath = "/tmp/example"
      Contents = "hello world `n"
      Ensure = "Present"
      Type = "File"
    }
  }

  Node "NginxWebServer" {
    nxPackage nginx {
      Name = "nginx"
      Ensure = "Present"
      PackageManager = "apt"
    }

    nxPackage php {
      Name = "php7.0-fpm"
      Ensure = "Present"
      PackageManager = "apt"
      DependsOn = "[nxPackage]nginx"
    }

    nxService nginxsvcstop {
      Name = "nginx"
      State = "stopped"
      Enabled = $true
      Controller = "systemd"
      DependsOn = "[nxPackage]php"
    }

    nxFile nginxconfig
    {
       SourcePath = "https://raw.githubusercontent.com/DCMattyG/azure-projects/master/vmss-linux-dsc/config/default"
       DestinationPath = "/etc/nginx/sites-available/default"
       Mode = "644"
       Type = "file"
       DependsOn = "[nxService]nginxsvcstop"
    }

    nxFile nginxphp {
      DestinationPath = "/var/www/html/index.php"
      Type = "file"
      Contents = $IndexPage
      Force = $true
      DependsOn = "[nxService]nginxsvcstop"
    }

    nxService nginxsvcstart {
      Name = "nginx"
      State = "running"
      Enabled = $true
      Controller = "systemd"
      DependsOn = "[nxFile]nginxconfig", "[nxFile]nginxphp"
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
