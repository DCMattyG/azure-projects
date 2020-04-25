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
    nxFile nginxphp {
      DestinationPath = "/var/www/html/index.php"
      Type = "file"
      Contents = $IndexPage
      Force = $true
    }

    nxFile nginxconfig
    {
       SourcePath = "https://raw.githubusercontent.com/DCMattyG/azure-projects/master/vmss-linux-dsc/config/default"
       DestinationPath = "/etc/nginx/sites-available/default"
       Mode = "644"
       Type = "file"
       Force = $true
       DependsOn = "[nxFile]nginxphp"
    }

    nxPackage php {
      Name = "php7.0-fpm"
      Ensure = "Present"
      PackageManager = "apt"
      Arguments = "-o Dpkg::Options::='--force-confold'"
      DependsOn = "[nxFile]nginxconfig"
    }

    nxPackage nginx {
      Name = "nginx"
      Ensure = "Present"
      PackageManager = "apt"
      DependsOn = "[nxPackage]php"
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
