
function OOBE
{

$TypeDef = @"
 
    using System;
    using System.Text;
    using System.Collections.Generic;
    using System.Runtime.InteropServices;
 
    namespace Api
    {
        public class Kernel32
        {
            [DllImport("kernel32.dll", CharSet = CharSet.Auto, SetLastError = true)]
            public static extern int OOBEComplete(ref int bIsOOBEComplete);
        }
    }
"@
 
    Add-Type -TypeDefinition $TypeDef -Language CSharp
 
    $IsOOBEComplete = $false
    $hr = [Api.Kernel32]::OOBEComplete([ref] $IsOOBEComplete)
 
    Return $IsOOBEComplete   
}

$IsOOBEComplete = OOBE

if ($IsOOBEComplete -eq 1)
{
    write-host "WinBase"
}
else
{
    write-host "OOBE"
}
