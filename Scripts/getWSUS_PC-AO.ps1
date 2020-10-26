[reflection.assembly]::LoadWithPartialName("Microsoft.UpdateServices.Administration")
$wsus = [Microsoft.UpdateServices.Administration.AdminProxy]::GetUpdateServer("vts01-piwsus-01", $false, "8530")
$WSUScomps = $wsus.GetComputerTargets()
$WSUSCompNames = $WSUScomps | ForEach { $_.FullDomainName.ToUpper() }
$WSUSCompNames >c:\wsus_pc01.txt