Configuration domain
{
   Param (
    [Int]$RetryCount = 20,

    [Int]$RetryIntervalSec = 30,

    [Parameter(Mandatory=$true)]
    [String]$VMName,

    [Parameter(Mandatory=$true)]
    [String]$IPAddress,

    [Parameter(Mandatory=$true)]
    [String]$DNSForwarders
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

  Write-Output $DNSForwarders
  Write-Output $DNSForwarders.GetType()
  
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
      DatabasePath = "C:\NTDS" # "F:\NTDS"
      LogPath = "C:\NTDS" # "F:\NTDS"
      SysvolPath = "C:\SYSVOL" # "F:\SYSVOL"
      DependsOn = "[WindowsFeature]ADDSInstall" #, "[xDisk]ADDataDisk"
    }

    xDnsServerADZone AddReverseADZone
    {
      Name= $(Get-ReverseLookupZoneName -IPAddress $IPAddress)
      DynamicUpdate = 'Secure'
      ReplicationScope = 'Domain' # Forest
      Ensure = 'Present'
      DependsOn = "[xADDomain]FirstDS"
    }

    xDnsRecord TestPtrRecord
    {
      Name = $(Get-ReversePtrName -IPAddress $IPAddress)
      Target = "$VMName.$DomainName"
      Zone = $(Get-ReverseLookupZoneName -IPAddress $IPAddress)
      Type = 'PTR'
      Ensure = 'Present'
      DependsOn = "[xDnsServerADZone]AddReverseADZone"
    }
  }
}

Function Get-ReverseLookupZoneName {
  Param
  (
    [Parameter(Mandatory=$true)]
    [String]$IPAddress
  )

  $IPArray = $IPAddress.Split('.')

  [Array]::Reverse($IPArray)

  $IPArrayTrim = $IPArray[1..$IPArray.Length]
  $Addr = $IPArrayTrim -join '.'
  $ZoneName = $Addr + '.in-addr.arpa'

  Return $ZoneName
}

Function Get-ReversePtrName {
  Param
  (
    [Parameter(Mandatory=$true)]
    [String]$IPAddress
  )

  $PTRName = $IPAddress.Split('.')[3]

  Return $PTRName
}
