$IndexPage = @'
<html>
<head>
<title>My DSC Page</title>
</head>
<body>
<H1>Awesome DSC Test Page in the house!</H1>
</body>
</html>
'@

Configuration nginxwebserver {

  Import-DscResource -Module PSDesiredStateConfiguration
  Import-DscResource -Module nx
  # Import-DscResource -Module nxNetworking
  
  Node "TestDSCLinuxfile" {
    nxFile ExampleFile {
      DestinationPath = "/tmp/example"
      Contents = "hello world `n"
      Ensure = "Present"
      Type = "File"
    }
  }

  Node "dscwebserver" {
    nxPackage nginx {
      Name = "nginx"
      Ensure = "Present"
      PackageManager = "apt"
    }

    nxFile index_html {
      DestinationPath = "/var/www/html/index.html"
      Type = "file"
      Contents = $IndexPage
      DependsOn = "[nxPackage]nginx"
    }

    nxService nginxservice {
      Name = "nginx"
      State = "running"
      Enabled = $true
      Controller = "systemd"
      DependsOn = "[nxFile]index_html"
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
