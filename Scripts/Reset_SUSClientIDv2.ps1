cls

#Имена серверов WSUS (должны бать написаны в тоже регистре, что и в политике (если сервер один можно указать один и тот же, можно убрать в условии в программе)
$WUServer_1="http://VTS06-PIWSUS-01.oms.tn.corp:8530"
$WUServer_2="http://VTS09-PIWSUS-01.oms.tn.corp:8530"

$WUServer_1="http://vts01-piwsus-01.oms.tn.corp:8530"
$WUServer_2="http://vts01-piwsus-01.oms.tn.corp:8530"

#Рабочий каталог
$WorkDir="c:\temp\"

#Имя файла с комп., которые надо обоработать
$NamePCfile="NoWSUS_NRNU02.txt"
$NamePCfile="NoWSUS_AO01.txt"

#Файл в который выводятся Ошибки имени WSUS
$WrongNameWSUS="ErrNameWsus.txt"

#Файл в который выводятся запуска службы Доступа к удаленному реестру
$WrongServRemReg="ErrRemReg.txt"

#Файл в который выводятся Ошибки пинг
$WrongPing="ErrPing.txt"

#Файл в который выводятся Ошибки остановки службы WUAUserv
$WrongStopWUAU="ErrStopWUAU.txt"


#########################################################################################################################
#
#Функция возращает true, если заданный хост пингуется и false  - в противном случае (спасибо Xaerg'у)
function Test-Host ($Name)
{
    $ping = new-object System.Net.NetworkInformation.Ping
    trap {Write-Verbose "Ошибка пинга"; $False; continue}
    if ($ping.send($Name).Status -ne "Success" ) { "$Name нет пинга" >> ($WorkDir+$WrongPing) }
    if ($ping.send($Name).Status -eq "Success" ) { $True }
    else { $False }
}
#########################################################################################################################
# Начало скрипта
#########################################################################################################################

### Загружаем в переменную список компьютеров из файла c:\temp\NoWSUS_NRNU01.txt,
### попутно получая короткое имя компьютера из его FQDN###

$STR=$WorkDir + $NamePCfile
" $STR 'n"

$noInWSUS = gc ($WorkDir + $NamePCfile) | foreach{($_ -replace " ") -replace "\..+$"}
#Обработаем полученный список
$noInWSUS| where{Test-Host $_}|foreach{`
    $CompName = $_
    Write-Host "`n`n$CompName"
       
    [System.Reflection.Assembly]::LoadWithPartialName('system.serviceprocess')

    #Запускаем службу доступа к удаленному реестру
    $remRegserv=new-Object System.ServiceProcess.ServiceController('RemoteRegistry',$CompName)
     #Если служба не запущена, то запускаем ее
    $Start=$True
    if ($remRegserv.Status -ne "Start") {
    #Переводим в Автомат
    Set-Service  RemoteRegistry -ComputerName $CompName -StartupType Automatic
       
        try {
            #Стартуем службу
            $remRegserv.Start()
            #Ожидаем запуска службы в течении заданного таймаута
            $remRegserv.WaitForStatus('Start',(new-timespan -seconds 20))
        }
        catch {
            # если в течение отведенного таймаута служба не остановилась, то сообщим об этом...
            "На $CompName службу RemoteRegistry запустить не удалось...`n" >> ($WorkDir+$WrongServRemReg)
            # ...и установим флаг успешного запуска службы в состояние $false
            $Start=$false
        }
    }
    
    if($Start){
    # Проверяем, что параметры WSUS сервера прописаны в рееcтре и они верные
        $type = [Microsoft.Win32.RegistryHive]::LocalMachine
        $reg = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey($type, $CompName)

        $regKey_WUAU= $reg.OpenSubKey("SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate", $true)
        If(!$regKey_WUAU) { 
         # если ключа реестра нет, то выводим сообщение
            "На $CompName нет ключа реестра WUAU...`n"  >> ($WorkDir+$WrongNameWSUS)
            }
            else 
            {
            $WUServer=$regKey_WUAU.GetValue("WUServer")
            If (($WUServer -ne $WUServer_1) -Or ($WUServer -ne $WUServer_2)) {

            "На $CompName указан неверный WSUS сервер $WUServer `n" >> ($WorkDir+$WrongNameWSUS)
            }
            }
    }

    #Подлкючаемся к службе Автоматического обновления (wuauserv) на удаленной машине
    $wuauserv=new-Object System.ServiceProcess.ServiceController('wuauserv',$CompName)
    
    #Инициализация флага успешной остановки службы
    $Stopped=$true
    #Если служба не остановлена, то остановливаем ее
    if ($wuauserv.Status -ne "Stopped") {
        try {
            #Останавливаем службу
            $wuauserv.Stop()
            #Ожидаем остановки службы в течении заданного таймаута
            $wuauserv.WaitForStatus('Stopped',(new-timespan -seconds 20))
        }
        catch {
            # если в течение отведенного таймаута служба не остановилась, то сообщим об этом...
            "На $CompName службу wuauserv остановить не удалось...`n" >> ($WorkDir+$WrongStopWUAU)
            # ...и установим флаг успешной остановки службы в состояние $false
            $Stopped=$false
        }
    }
    # если WuauServ была успешно остановлена и RemReg запущена, то
    # сбрасываем SUSClientID
    if ( $Stopped -And $Start) {
        #
        #Удаляем ключи реестра

        $type = [Microsoft.Win32.RegistryHive]::LocalMachine
        $reg = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey($type, $CompName)

        $regKey= $reg.OpenSubKey("SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate",$true)
        $regKey.DeleteValue("SusClientId")
        $regKey.DeleteValue("SusClientIdValidation")
        $regKey.DeleteValue("PingID")
        $regKey.DeleteValue("AccountDomainSid")
        $RemoteProcess6=([wmiclass]"\\$CompName\root\cimv2:Win32_Process").create("cmd /c attrib -R -A -S -H  %WinDir%\SoftwareDistribution\* /S /D")
        $RemoteProcess7=([wmiclass]"\\$CompName\root\cimv2:Win32_Process").create("cmd /c rmdir /S /Q %WinDir%\SoftwareDistribution")
        $RemoteProcess8=([wmiclass]"\\$CompName\root\cimv2:Win32_Process").create("cmd /c ren %WinDir%\WindowsUpdate.log WindowsUpdate.bak")
        #Инициализация флага успешного запуска службы Автоматического обновления (wuauserv)
        $Started=$true
        #
        try {
            #Запускаем службу Автообновления
            $wuauserv.Start()
            #Ожидаем запуска службы в течении заданного таймаута
            $wuauserv.WaitForStatus('Running',(new-timespan -seconds 10))
        }
        catch {
            # если в течение отведенного таймаута служба не стартовала, то сообщим об этом...
            "На $CompName службу wuauserv запустить не удалось...`n"
            # ...и установим флаг успешного запуска службы в состояние $false
            $Started=$false
        }
        # если служба Автоматического обновления была успешно запущенна, то
        # регистрируемся на WSUS и запускаем обновление
        if ($Started) {
            #Ждем 5 секунд
            Start-Sleep -Seconds 5
            #принудительное применение политики (на всякий случай, лучше перебдеть)
            "Запускаем принудительное обновление политики..."
            $RemoteProcess=([wmiclass]"\\$CompName\root\cimv2:Win32_Process").create("cmd /c gpupdate /force")
            "...код возврата запуска - $($RemoteProcess.ReturnValue), ID запущеного процесса - $($RemoteProcess.ProcessId)`n"
            #Ждем 30 секунд
            Start-Sleep -Seconds 30
            "Выполняем wuauclt /resetauthorization /detectnow"
            #выполняем wuauclt /resetauthorization /detectnow, согласно http://support.microsoft.com/kb/903262
            $RemoteProcess=([wmiclass]"\\$CompName\root\cimv2:Win32_Process").create("cmd /c wuauclt /resetauthorization /reportnow")
            "...код возврата запуска - $($RemoteProcess.ReturnValue), ID запущеного процесса - $($RemoteProcess.ProcessId)`n"
            $RemoteProcess1=([wmiclass]"\\$CompName\root\cimv2:Win32_Process").create("cmd /c wuauclt /detectnow")
            $RemoteProcess2=([wmiclass]"\\$CompName\root\cimv2:Win32_Process").create("cmd /c wuauclt /detectnow")
            $RemoteProcess3=([wmiclass]"\\$CompName\root\cimv2:Win32_Process").create("cmd /c wuauclt /detectnow")
        }
    }
}