$ADcomps = (new-object System.DirectoryServices.DirectorySearcher([ADSI]"LDAP://ou=Domain Controllers, dc=oms, dc=tn,dc=corp","(&(objectCategory=computer)(!userAccountControl:1.2.840.113556.1.4.803:=2))")).findAll()
$ADCompNames = $ADcomps | ForEach {$_.GetDirectoryEntry().dNSHostName.ToString().ToUpper()}
$ADCompNames > C:\temp\AD-pc-AO-DC.txt

$ADcomps = (new-object System.DirectoryServices.DirectorySearcher([ADSI]"LDAP://ou=Workstation,ou=AU,ou=AO, dc=oms, dc=tn,dc=corp","(&(objectCategory=computer)(!userAccountControl:1.2.840.113556.1.4.803:=2))")).findAll()
$ADCompNames = $ADcomps | ForEach {$_.GetDirectoryEntry().dNSHostName.ToString().ToUpper()}
$ADCompNames > C:\temp\AD-pc-AO-Wrks.txt

$ADcomps = (new-object System.DirectoryServices.DirectorySearcher([ADSI]"LDAP://ou=Core, dc=oms, dc=tn,dc=corp","(&(objectCategory=computer)(!userAccountControl:1.2.840.113556.1.4.803:=2))")).findAll()
$ADCompNames = $ADcomps | ForEach {$_.GetDirectoryEntry().dNSHostName.ToString().ToUpper()}
$ADCompNames > C:\temp\AD-pc-AO-Core.txt