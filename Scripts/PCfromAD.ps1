$ADcomps = (new-object System.DirectoryServices.DirectorySearcher([ADSI]"LDAP://ou=NRNU, ou=AO,dc=oms, dc=tn,dc=corp","(&(objectCategory=computer)(!userAccountControl:1.2.840.113556.1.4.803:=2))")).findAll()
$ADCompNames = $ADcomps | ForEach {$_.GetDirectoryEntry().dNSHostName.ToString().ToUpper()}
$ADCompNames > C:\temp\AD-pc.txt