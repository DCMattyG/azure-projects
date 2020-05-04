$phpPath = 'http://windows.php.net/downloads/releases/'
$phpZipFile = 'php-7.4.5-nts-Win32-vc15-x64.zip'
$vcRedistPath = 'https://aka.ms/vs/15/release/'
$vcRedistFile = 'VC_redist.x64.exe'
$phpIniPath = 'https://raw.githubusercontent.com/dsccommunity/xPhp/dev/Samples/PhpConfigTemplate.txt'
$siteName = 'Default Web Site'
$siteID = 1
$handlerName = "PHP"

Configuration windowsconfig
{
  Import-DscResource -Module xPSDesiredStateConfiguration
  Import-DscResource -Module xWebAdministration
  Import-DscResource -Module xPhp

  Node IISWebServer {

    WindowsFeature IIS {
      Ensure = 'Present'
      Name = 'Web-Server'
    }

    WindowsFeature IISConsole {
      Ensure = 'Present'
      Name = 'Web-Mgmt-Console'
      DependsOn = '[WindowsFeature]IIS'
    }

    WindowsFeature IISScriptingTools {
      Ensure = 'Present'
      Name = 'Web-Scripting-Tools'
      DependsOn = '[WindowsFeature]IIS'
    }

    # WindowsFeature AspNet
    # {
    #   Ensure = 'Present'
    #   Name = 'Web-Asp-Net45'
    #   DependsOn = @('[WindowsFeature]IIS')
    # }

    WindowsFeature CGI {
			#Enables CGI feature of IIS
			Ensure = "Present"
			Name = "Web-CGI"
		}

    # xWebsite DefaultSite
    # {
    #   Ensure = 'Present'
    #   Name = 'Default Web Site'
    #   State = 'Stopped'
    #   PhysicalPath = 'C:\inetpub\wwwroot'
    #   DependsOn = @('[WindowsFeature]IIS','[WindowsFeature]AspNet')
    # }

    # File demofolder
    # {
    #   Ensure = 'Present'
    #   Type = 'Directory'
    #   DestinationPath = "C:\inetpub\wwwroot\demo"
    # }

    # File Indexfile
    # {
    #   Ensure = 'Present'
    #   Type = 'file'
    #   DestinationPath = "C:\inetpub\wwwroot\demo\index.html"
    #   Contents = "<html>
    #   <header><title>This is Demo Website</title></header>
    #   <body>
    #   Welcome to DevopsGuru Channel
    #   </body>
    #   </html>"
    # }

    # xWebAppPool DemoWebAppPool
    # {
    #   Ensure = "Present"
    #   State = "Started"
    #   Name = "demo"
    # }

    # xWebsite DemoWebSite
    # {
    #   Ensure = 'Present'
    #   State = 'Started'
    #   Name = "Demo"
    #   PhysicalPath = "C:\inetpub\wwwroot\demo"
    # }

    # xWebApplication demoWebApplication
    # {
    #   Name = "demo"
    #   Website = "demo"
    #   WebAppPool = "demo"
    #   PhysicalPath = "C:\inetpub\wwwroot\demo"
    #   Ensure = 'Present'
    #   DependsOn = @('[xWebSite]DemoWebSite')
    # }

    File dscPath {
			Ensure = "Present"
			Type = "Directory"
			DestinationPath = "C:\dsc\"
    }

    xRemoteFile phpFile {
      DependsOn = "[File]dscPath"
      Uri = ($phpPath + $phpZipFile)
      DestinationPath = ("C:\dsc\" + $phpZipFile)
    }

    xRemoteFile vcRedistFile {
      DependsOn = "[File]dscPath"
      Uri = ($vcRedistPath + $vcRedistFile)
      DestinationPath = ("C:\dsc\" + $vcRedistFile)
    }
    
    Package VS2015-64 {
      DependsOn = "[xRemoteFile]vcRedistFile"
      Ensure = "Present"
      Name = "Microsoft Visual C++ 2017 Redistributable (x64) - 14.16.27033"
      Path = ("C:\dsc\" + $vcRedistFile)
      Arguments = "/install /quiet"
      ProductId = ""
    }
    
    Archive phpExtract {
      DependsOn = "[xRemoteFile]phpFile"
      Ensure = "Present"
      Path = ("C:\dsc\" + $phpZipFile)
      Destination = "C:\PHP"
    }

    File phpIni {
      DependsOn = "[Archive]phpExtract"
      Ensure = "Present"
      Type = "File"
      SourcePath = "C:\php\php.ini-production"
      DestinationPath = "C:\php\php.ini"
      Force = $true
    }

    xEnvironment phpPath {
      Name = "Path"
      Ensure = "Present"
      Path = $true
      Value = "C:\PHP"
    }

    # This module is waiting for a patch to fix this fucntionality
    # xIISModule phpModule {
    #   DependsOn = "[File]phpIni"
    #   Path = "C:\PHP\php-cgi.exe"
    #   Name = "PHP"
    #   RequestPath = "*.php"
    #   Verb = "*"
    #   SiteName = $siteName
    #   ModuleType = "FastCgiModule"
    #   Ensure = "Present"
    # }

    # Temporary method to add the PHP module to IIS
    Script phpModule {
      SetScript = {
        Add-WebConfiguration 'system.webServer/handlers' iis:\ -Value @{
          Name = $using:handlerName;
          Path = "*.php";
          Verb = "*";
          Modules = "FastCgiModule";
          scriptProcessor = "C:\php\php-cgi.exe";
          resourceType = "Either";
        }
      }
      TestScript = {
        $handler = Get-WebConfiguration 'system.webserver/handlers/add' | where-object { $_.Name -eq $using:handlerName }

        return $(If ($handler) { $true } Else { $false })
      }
      GetScript = {
        @{ Result = (Get-WebConfiguration 'system.webserver/handlers/add' | where-object { $_.Name -eq $using:handlerName }) }
      }
    }

    # Temporary method to add a FastCGI aaplication for PHP-CGI
    Script phpFastCgi
    {
      DependsOn = "[Script]phpModule"
      SetScript = {
        Add-WebConfiguration /system.webServer/fastCgi iis:\ -Value @{
          FullPath = "C:\PHP\php-cgi.exe"
        }
      }
      TestScript = {
        $fastcgi = Get-WebConfiguration "/system.webserver/fastcgi" -PSPath "IIS:\" | select -expandproperty collection | ?{$_.fullpath -eq "C:\PHP\php-cgi.exe"}

        return $(If ($fastcgi) { $true} Else { $false} )
      }
      GetScript = {
        @{ Result = (Get-WebConfiguration "/system.webserver/fastcgi" -PSPath "IIS:\" | select -expandproperty collection | ?{$_.fullpath -eq "C:\PHP\php-cgi.exe"}) }
      }
    }

    xWebSite indexPhpDefault
    {
      # DependsOn = '[xIISModule]phpModule'
      DependsOn = '[Script]phpFastCgi'
      Ensure = 'Present'
      Name = $siteName
      SiteId = $siteId
      State = 'Started'
      ServerAutoStart = $true
      DefaultPage = "index.php"
      # PhysicalPath = $DestinationPath
    }

    File indexPhp {
      DependsOn = "[xWebsite]indexPhpDefault"
      Ensure = "Present"
      Type = "File"
      Contents = "<?php phpinfo(); ?>"
      DestinationPath = "C:\inetpub\wwwroot\index.php"
      Force = $true
    }

    # This module doesn't work at all...
    # xPhpProvision php {
    #   InstallMySqlExt = $true
    #   PackageFolder =  'C:\package'
    #   # Update with the latest "VC11 x64 Non Thread Safe" from http://windows.php.net/download/
    #   DownloadURI = 'http://windows.php.net/downloads/releases/php-7.4.5-nts-Win32-vc15-x64.zip'
    #   DestinationPath = 'C:\php'
    #   ConfigurationPath = $phpIniPath
    #   Vc2012RedistDownloadUri = 'https://aka.ms/vs/15/release/VC_redist.x64.exe'
    #   # Removed because this dependency does not work in Windows Server 2012 R2 and below
    #   # This should work in WMF v5 and above
    #   # DependsOn = "[IisPreReqs_WordPress]Iis"
    # }
  }
}
