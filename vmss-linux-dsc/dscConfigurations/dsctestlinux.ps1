Configuration dsctestlinux{

  Import-DscResource -Module PSDesiredStateConfiguration
  Import-DscResource -Module nx
  
    Node  "TestDSCLinuxfile"{
    nxFile ExampleFile {
      DestinationPath = "/tmp/example"
      Contents = "hello world `n"
      Ensure = "Present"
      Type = "File"
    }
  }
  }
  