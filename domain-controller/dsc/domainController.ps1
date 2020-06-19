Configuration domain
{
   param (
    [Int]$RetryCount = 20,

    [Int]$RetryIntervalSec = 30
  )

  Import-DscResource -ModuleName xActiveDirectory
  # Import-DscResource -ModuleName xStorage
  Import-DSCResource -Module xSystemSecurity
  Import-DscResource -ModuleName xDnsServer
  Import-DSCResource -ModuleName NetworkingDsc
  Import-DscResource -ModuleName PSDesiredStateConfiguration

  $AdminCreds = Get-AutomationPSCredential -Name 'domainCreds'
  $DomainName = Get-AutomationVariable -Name 'domainName'
  [System.Management.Automation.PSCredential]$DomainCreds = New-Object System.Management.Automation.PSCredential ("${DomainName}\$($AdminCreds.UserName)", $AdminCreds.Password)

  $SafeModeCreds = Get-AutomationPSCredential -Name 'safeModePassword'
  [System.Management.Automation.PSCredential]$DomainSafeModePwd = New-Object System.Management.Automation.PSCredential ("NULL", $SafeModeCreds.Password)

  Node CreateADDC
  {
    NetAdapterBinding DisableIPv6
    {
      InterfaceAlias = "Ethernet*"
      ComponentId = "ms_tcpip6"
      State = "Disabled"
    }

    xIEEsc EnableIEEscAdmin {
      IsEnabled = $False
      UserRole  = "Administrators"
    }

    xIEEsc EnableIEEscUser {
      IsEnabled = $False
      UserRole  = "Users"
    }

    WindowsFeature DNS {
      Ensure = "Present"
      Name = "DNS"
    }

    WindowsFeature DNSTools {
      Ensure = "Present"
      Name = "RSAT-DNS-Server"
      DependsOn = "[WindowsFeature]DNS"
    }

    xDnsServerForwarder SetForwarders {
      IsSingleInstance = "Yes"
      IPAddresses = @("208.67.220.220", "208.67.222.222")
      UseRootHint = $false
      DependsOn = "[WindowsFeature]DNS"
    }

    # xWaitforDisk Disk2 {
    #   DiskNumber = 2
    #   RetryIntervalSec = $RetryIntervalSec
    #   RetryCount = $RetryCount
    # }

    # xDisk ADDataDisk {
    #   DiskNumber = 2
    #   DriveLetter = "F"
    #   DependsOn = "[xWaitForDisk]Disk2"
    # }

    WindowsFeature ADDSInstall {
      Ensure = "Present"
      Name = "AD-Domain-Services"
      DependsOn = "[WindowsFeature]DNS"
    }

    WindowsFeature ADDSTools {
      Ensure = "Present"
      Name = "RSAT-ADDS-Tools"
      DependsOn = "[WindowsFeature]ADDSInstall"
    }

    WindowsFeature ADAdminCenter {
      Ensure = "Present"
      Name = "RSAT-AD-AdminCenter"
      DependsOn = "[WindowsFeature]ADDSInstall"
    }

    xADDomain FirstDS {
      DomainName = $DomainName
      DomainAdministratorCredential = $DomainCreds
      SafemodeAdministratorPassword = $DomainSafeModePwd
      DatabasePath = "C:\NTDS" #"F:\NTDS"
      LogPath = "C:\NTDS" #"F:\NTDS"
      SysvolPath = "C:\SYSVOL" #"F:\SYSVOL"
      DependsOn = "[WindowsFeature]ADDSInstall"#, "[xDisk]ADDataDisk"
    }
  }
}
