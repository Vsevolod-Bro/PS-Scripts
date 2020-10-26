#перед выполнением нужно запустить отдельно Set-ExecutionPolicy -ExecutionPolicy Unrestricted
cls

# Формируем название OU
$DateDel = (Get-Date).AddDays(+90) 
$NameDisOU="Удалить после "+$DateDel.ToUniversalTime().tostring('yyyy.MM.dd')

$NameDisOU

#Создаем OU
New-ADOrganizationalUnit -Name $NameDisOU -Path "OU=Disabled Objects,OU=AU,OU=AO,DC=oms,DC=tn,DC=corp"


$computers=get-adcomputer -properties lastLogonDate -filter * | where {$_.Enabled } | where {$_.name -like "WTS01-*"} | where { $_.lastLogonDate -lt (get-date).addmonths(-4) } 

# FT Name,LastLogonDate
$FQDN_NameOU="OU="+$NameDisOU + ",OU=Disabled Objects,OU=AU,OU=AO,DC=oms,DC=tn,DC=corp"
#$FQDN_NameOU

 ForEach( $computer in $computers){ 
 #$computer.Name
 #"s="+ $computers 
   Get-ADComputer $computer | Move-ADObject -TargetPath $FQDN_NameOU

   Get-ADComputer $computer | Disable-ADAccount
   
   
   #Get-ADComputer $computer | Move-ADObject -TargetPath "ou=Dropout,ou=Computers,ou=NRNU,ou=AO,dc=oms,dc=tn,dc=corp"

   }


