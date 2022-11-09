<# : Archetype Counter 2.0.1 for PokeMMO
@echo off
Setlocal
cd %~dp0
powershell -NoLogo -Noprofile -Executionpolicy Bypass -WindowStyle Hidden -Command "Invoke-Expression $([System.IO.File]::ReadAllText('%~f0'))"
Endlocal
goto:eof
#>

# Sets the error action for the entire script to 'SilentlyContinue'
$ErrorActionPreference = 'SilentlyContinue'

# Clears PowerShell console history file (Help with performance)
Remove-Item "$env:APPDATA\Microsoft\Windows\PowerShell\PSReadLine\*" -Recurse -Force

# Removes dummy file from folder (File is needed for Github upload)
Remove-Item "Counter Functions\ScreenCapture\DEBUG MODE\dummy.txt" -Force
Remove-Item "Counter Config Files\Counter Config Backup\dummy.txt" -Force

# Globals varaibles for counter form dragging
$global:dragging = $false; $global:mouseDragX = 0; $global:mouseDragY = 0

# Starts up the NoTrayOprhans.exe AHK script (Clears out Archetype icons that are left in the system tray)
Start-Process "$PWD\Counter Functions\NoTrayOprhans\NoTrayOrphans.exe"

# Closes any other PowerShell instance down (Just in case the counter has been launched more than once)
Get-Process "Powershell"  | Where-Object { $_.ID -ne $PID } | Stop-Process -Force

# Removes file "ArchetypeCounterExecute" as the Archetype Counter is running in memory (To prevent seeing main counter script)
Remove-item "$PWD\ArchetypeCounterExecute.bat" -Force

# Loads hunt string from external source (CurrentProfileState.txt file)
$SetProfileConfig = "$PWD\Counter Config Files\CurrentProfileState.txt"
$GetProfileConfig = Get-Content $SetProfileConfig
$GetProfile = $GetProfileConfig[7] -replace 'Current_Hunt_Profile=', ''
$CheckProfile1 = $GetProfileConfig[8] -replace 'Hunt_Profile_Name_1=', ''
$CheckProfile2 = $GetProfileConfig[9] -replace 'Hunt_Profile_Name_2=', ''
$CheckProfile3 = $GetProfileConfig[10] -replace 'Hunt_Profile_Name_3=', ''
$CheckProfile4 = $GetProfileConfig[11] -replace 'Hunt_Profile_Name_4=', ''
$CheckProfile5 = $GetProfileConfig[12] -replace 'Hunt_Profile_Name_5=', ''
if ($GetProfile -match $CheckProfile1) { $GetProfile = 'Profile1' } elseif ($GetProfile -match $CheckProfile2) { $GetProfile = 'Profile2' } elseif ($GetProfile -match $CheckProfile3) { $GetProfile = 'Profile3' } elseif ($GetProfile -match $CheckProfile4) { $GetProfile = 'Profile4' } elseif ($GetProfile -match $CheckProfile5) { $GetProfile = 'Profile5' }

# Checks if counter config backup current day folder is set (Creates a backup of the current day the counter is ran each day)
$TodaysDate = (Get-Date).ToString('MM_dd_yyyy'); if (!(Test-Path -Path "$PWD\Counter Config Files\Counter Config Backup\$TodaysDate\CounterConfig_$GetProfile.txt")) { New-Item -Path "$PWD\Counter Config Files\Counter Config Backup" -Type Directory -Name $TodaysDate; Copy-Item "$PWD\Counter Config Files\CounterConfig_$GetProfile.txt" -Destination "$PWD\Counter Config Files\Counter Config Backup\$TodaysDate" -Recurse; Copy-Item "$PWD\Counter Config Files\CurrentProfileState.txt" -Destination "$PWD\Counter Config Files\Counter Config Backup\$TodaysDate" -Recurse }

# Loads user32.dll (To get GetSpecificWin/ForceActiveWin/MouseDownDrag that are improrted into PowerShell)
$GrabForWinformCode = @'

    using System;
    using System.Runtime.InteropServices;
    using System.Text;

    public class GetSpecificWin {

        [DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = true)]
        public static extern int GetWindowText(IntPtr hwnd,StringBuilder lpString, int cch);

        [DllImport("user32.dll", SetLastError=true, CharSet=CharSet.Auto)]
        public static extern IntPtr GetForegroundWindow();

        [DllImport("user32.dll", SetLastError=true, CharSet=CharSet.Auto)]
        public static extern Int32 GetWindowThreadProcessId(IntPtr hWnd,out Int32 lpdwProcessId);

        [DllImport("user32.dll", SetLastError=true, CharSet=CharSet.Auto)]
        public static extern Int32 GetWindowTextLength(IntPtr hWnd);

    }

    public class ForceActiveWin {

        [DllImport("user32.dll")]
        [return: MarshalAs(UnmanagedType.Bool)]
        public static extern bool SetForegroundWindow(IntPtr hWnd);

        [DllImport("user32.dll")]
        [return: MarshalAs(UnmanagedType.Bool)]
        public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow); 
        
    }

    public static class MouseDownDrag {

        [DllImportAttribute("user32.dll")]
        public static extern int SendMessage(IntPtr hWnd, int Msg, int wParam, int lParam);

        [DllImportAttribute("user32.dll")]
        public static extern bool ReleaseCapture();

    }

'@

# Loads C# that will create a separate taskbar icon per process (But ultimately allows a custom Taskbar Icon)
$TaskbarIconReplace = @'
using System;
using System.Runtime.InteropServices;
using System.Runtime.InteropServices.ComTypes;

public class PSAppID
{
    // https://emoacht.wordpress.com/2012/11/14/csharp-appusermodelid/
    // IPropertyStore Interface
    [ComImport,
        InterfaceType(ComInterfaceType.InterfaceIsIUnknown),
        Guid("886D8EEB-8CF2-4446-8D02-CDBA1DBDCF99")]
    private interface IPropertyStore
    {
        uint GetCount([Out] out uint cProps);
        uint GetAt([In] uint iProp, out PropertyKey pkey);
        uint GetValue([In] ref PropertyKey key, [Out] PropVariant pv);
        uint SetValue([In] ref PropertyKey key, [In] PropVariant pv);
        uint Commit();
    }


    // PropertyKey Structure
    [StructLayout(LayoutKind.Sequential, Pack = 4)]
    public struct PropertyKey
    {
        private Guid formatId;    // Unique GUID for property
        private Int32 propertyId; // Property identifier (PID)

        public Guid FormatId
        {
            get
            {
                return formatId;
            }
        }

        public Int32 PropertyId
        {
            get
            {
                return propertyId;
            }
        }

        public PropertyKey(Guid formatId, Int32 propertyId)
        {
            this.formatId = formatId;
            this.propertyId = propertyId;
        }

        public PropertyKey(string formatId, Int32 propertyId)
        {
            this.formatId = new Guid(formatId);
            this.propertyId = propertyId;
        }

    }


    // PropVariant Class (only for string value)
    [StructLayout(LayoutKind.Explicit)]
    public class PropVariant : IDisposable
    {
        [FieldOffset(0)]
        ushort valueType;     // Value type

        // [FieldOffset(2)]
        // ushort wReserved1; // Reserved field
        // [FieldOffset(4)]
        // ushort wReserved2; // Reserved field
        // [FieldOffset(6)]
        // ushort wReserved3; // Reserved field

        [FieldOffset(8)]
        IntPtr ptr;           // Value


        // Value type (System.Runtime.InteropServices.VarEnum)
        public VarEnum VarType
        {
            get { return (VarEnum)valueType; }
            set { valueType = (ushort)value; }
        }

        public bool IsNullOrEmpty
        {
            get
            {
                return (valueType == (ushort)VarEnum.VT_EMPTY ||
                        valueType == (ushort)VarEnum.VT_NULL);
            }
        }

        // Value (only for string value)
        public string Value
        {
            get
            {
                return Marshal.PtrToStringUni(ptr);
            }
        }


        public PropVariant()
        { }

        public PropVariant(string value)
        {
            if (value == null)
                throw new ArgumentException("Failed to set value.");

            valueType = (ushort)VarEnum.VT_LPWSTR;
            ptr = Marshal.StringToCoTaskMemUni(value);
        }

        ~PropVariant()
        {
            Dispose();
        }

        public void Dispose()
        {
            PropVariantClear(this);
            GC.SuppressFinalize(this);
        }

    }

    [DllImport("Ole32.dll", PreserveSig = false)]
    private extern static void PropVariantClear([In, Out] PropVariant pvar);


    [DllImport("shell32.dll")]
    private static extern int SHGetPropertyStoreForWindow(
        IntPtr hwnd,
        ref Guid iid /*IID_IPropertyStore*/,
        [Out(), MarshalAs(UnmanagedType.Interface)] out IPropertyStore propertyStore);

    public static void SetAppIdForWindow(int handle, string AppId)
    {
        Guid iid = new Guid("886D8EEB-8CF2-4446-8D02-CDBA1DBDCF99");
        IPropertyStore prop;
        int result1 = SHGetPropertyStoreForWindow((IntPtr)handle, ref iid, out prop);

        // Name = System.AppUserModel.ID
        // ShellPKey = PKEY_AppUserModel_ID
        // FormatID = 9F4C2855-9F79-4B39-A8D0-E1D42DE1D5F3
        // PropID = 5
        // Type = String (VT_LPWSTR)
        PropertyKey AppUserModelIDKey = new PropertyKey("{9F4C2855-9F79-4B39-A8D0-E1D42DE1D5F3}", 5);
    
        PropVariant pv = new PropVariant(AppId);
        
        uint result2 = prop.SetValue(ref AppUserModelIDKey, pv);
        
        Marshal.ReleaseComObject(prop);
    }
}
'@

# Loads all required assembiles for the Winform
Add-Type -AssemblyName System.Windows.Forms; Add-Type -AssemblyName System.Drawing; Add-Type -AssemblyName PresentationCore; Add-Type -AssemblyName Presentationframework; Add-Type -AssemblyName Microsoft.VisualBasic; Add-Type -AssemblyName WindowsFormsIntegration; Add-Type $GrabForWinformCode; Add-Type -TypeDefinition $TaskbarIconReplace

# Loads values from external sources (Config file)
$SetConfig = "$PWD\Counter Config Files\CounterConfig_$GetProfile.txt"
$GetConfig = Get-Content $SetConfig
$TotalCount = $GetConfig[7] -replace 'Total_Count=', ''
$PokemonA = $GetConfig[8] -replace 'Pokemon_A=', ''
$PokemonCountA = $GetConfig[9] -replace 'Pokemon_A_Count=', ''
$PokemonAHover = $GetConfig[10] -replace 'Pokemon_A_Hover=', ''
$PokemonB = $GetConfig[11] -replace 'Pokemon_B=', ''
$PokemonCountB = $GetConfig[12] -replace 'Pokemon_B_Count=', ''
$PokemonBHover = $GetConfig[13] -replace 'Pokemon_B_Hover=', ''
$PokemonC = $GetConfig[14] -replace 'Pokemon_C=', ''
$PokemonCountC = $GetConfig[15] -replace 'Pokemon_C_Count=', ''
$PokemonCHover = $GetConfig[16] -replace 'Pokemon_C_Hover=', ''
$DetectionCount = $GetConfig[17] -replace 'Detection_Count=', ''
$ArchetypeX = $GetConfig[18] -replace 'Archetype_X=',''
$ArchetypeY = $GetConfig[19] -replace 'Archetype_Y=',''
$EggCount = $GetConfig[20] -replace 'Egg_Count=',''
$ShinyCount = $GetConfig[21] -replace 'Shiny_Count=',''
$ThemeType = $GetConfig[22] -replace 'Theme_Type=', ''
$SpriteType = $GetConfig[25] -replace 'Sprite_Type=', ''
$SetLanguage = $GetConfig[23] -replace 'Set_Language=', ''
$PokeMMOLaunch = $GetConfig[24] -replace 'PokeMMO_Launch=', ''
$AutoRestartCounter = $GetConfig[33] -replace 'Auto_Restart_Counter=', ''
$CounterActive = $GetConfig[34] -replace 'Counter_Active=', ''
$DebugMode = $GetConfig[35] -replace 'Debug_Mode=', ''
$CounterMode = $GetConfig[36] -replace 'Counter_Mode=', ''
$AlwaysOnTop = $GetConfig[37] -replace 'Always_On_Top=', ''
$TotalCount = [int]$PokemonCountA + [int]$PokemonCountB + [int]$PokemonCountC + [int]$EggCount
$TotalCountNoEgg = [int]$PokemonCountA + [int]$PokemonCountB + [int]$PokemonCountC
$TotalPokeSeenCount = $GetConfig[38] -replace 'Pokemon_Seen_Count=',''
$ScreenMode = $GetConfig[39] -replace 'Screen_Mode=', ''
$IgnoreSystemLang = $GetConfig[41] -replace 'Ignore_System_Language=', ''

# Resets all values back into the config file (Ensures the values are set on winform launch)
$GetConfig | Set-Content -Path $SetConfig

# Removes all screenshot(s) from folder (To ensure counter does not grab a previous screenshot)
if ($DebugMode -match "False") { Remove-Item "$PWD\Counter Functions\ScreenCapture\*.*" | Where { ! $_.PSIsContainer }; Remove-Item "$PWD\Counter Functions\ScreenCapture\DEBUG MODE\*.*" | Where { ! $_.PSIsContainer } }

# Loads values from external sources for winform (Config file)
$SetColorConfig = "$PWD\GUI Form Images\$ThemeType\FormBackgroundColors.txt"
$GetColorConfig = Get-Content $SetColorConfig
$PokeSlot1BGColor = $GetColorConfig[7] -replace 'PokemonBG_1=', ''
$PokeSlot1CountBGColor = $GetColorConfig[8] -replace 'PokemonCountBGLabel_1=', ''
$PokeSlot2BGColor = $GetColorConfig[9] -replace 'PokemonBG_2=', ''
$PokeSlot2CountBGColor = $GetColorConfig[10] -replace 'PokemonCountBGLabel_2=', ''
$PokeSlot3BGColor = $GetColorConfig[11] -replace 'PokemonBG_3=', ''
$PokeSlot3CountBGColor = $GetColorConfig[12] -replace 'PokemonCountBGLabel_3=', ''
$EggCountBGColor = $GetColorConfig[13] -replace 'EggCountBGLabel=', ''
$CollapsedCountBGColor = $GetColorConfig[14] -replace 'CollapsedCountBGLabel=', ''

# Takes Base64 string and converts from Base64 into a variable (For Archetype Icon)
$ThemeIconBase64 = "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AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAPT09AU1NTQNPT08GT09PC1BQUBRRUVEgUFBQME9PT0NQUFBZUFBQcFNTU4hRUVGdQ0NDrVVVVcKXl5be4NzV+/v59v/8+fX/+/Xv//r07f/69u//+/bw//r28P/69vD/+vbw//r28P/69vD/+vbw//r28P/69u//+vbv//r27//69O3/+vTt//r17v/69u//+vbw//r28P/79/H/+/fy//v38v/79/H/+vbw//r27//69u//+vXu//r07f/69e7/+vbv//r27//69vD/+/bw//r28P/69vD/+vbw//r28P/69vD/+vbw//r28P/69O3/+vTt//v38v/9+/j/+PPt/87GuvR3d3bSRkZGuElJSaZUVFSUUVFRflBQUGZQUFBQT09PO09PTylQUFAbUlJSEFVVVQhFRUUETk5OAg4ODgEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAICAgAUlJSQJYWFgDTExMB09PTw9QUFAYUFBQJ09PTzlQUFBOUFBQZlFRUX5VVVWVRkZGp0pKSruTk5Pb5ODa+vv59v/8+fX/+vXu//r07f/79vD/+/bw//r28P/69vD/+/bw//v28P/79vD/+/bw//r27//69O3/+vTt//v38f/8+fT//Pr2//78+v///v7//fr4//z49P/79/L/+vXv//rz7P/58+v/+fPr//r07f/79vD//Pjz//z59f/+/fz//v79//37+f/8+fX/+/fy//r27//69O3/+vXu//r27//79vD/+/bw//v28P/79vD/+/bw//r28P/79vD/+vbv//r07f/79/H//fv4//j18P/PyL30bW1ty0FBQbFOTk6hVFRU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//v38f/79/H/+/fv//z59f/r4M73Tk5OgVBQUGlRUVFNUFBQMVJSUhxRUVENUVFRBS4uLgEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAERERAU1NTQROTk4KUVFRF09PTyxRUVFHVFRUZD4+PnbSz8rY/fr3//v27v/79/H/+/fx//v38f/79u7//v38/+bMo//LlUD/zpxO/86bS//Om0v/zptL/86bS//Om0v/zptL/86bS//Om0v/zptL/86bS//Om0v/zptL/86bS//Om0v/zptL/86bS//Om0v/zptL/86aS//Om0v/zptL/86bS//Om0v/zptL/86bS//Om0v/zptL/86bS//Om0v/zptL/86bS//Om0v/zptL/86bS//Om0v/zptL/86cTf/OnE3/zpxN/8+bTP/Omkr/zZpJ/86aSv/Om0v/zptL/86cTv/OnE7/zptM/86bS//Om0v/zppL/86bS//Om0v/zppL/86bS//Omkv/zptL/86bS//Om0v/zptL/86bS//Om0v/zptL/86bS//Om0v/zptL/86bS//Om0v/zptL/86bS//Om0v/zptL/86bS//Om0v/zptL/86bS//Om0v/zptL/86bS//Om0v/zppL/86bS//Om0v/zptM/82aSf/QoFT/9+3f//369v/79/D/+/fx//v38f/79/H/+/fx//v38f+Ti36rQUFBbVVVVVhPT086UVFRIlJSUhFXV1cHQEBAAgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABHR0cBTExMBVFRUQ5PT08dUVFRM1JSUlBJSUloampqi/Pv6vv8+PL/+/fw//v38f/79/H/+/fw//z48//58uj/06Zf/82YR//Pm0z/zptL/86bTP/Om0z/zptL/86bS//Om0v/zptL/86bS//Om0v/zptL/86bTP/Om0v/zptL/86bS//Om0z/zptL/86bS//Om0v/zptL/86bTP/Om0v/zptL/86bS//Om0v/zptL/86bS//Om0v/zptL/86bS//Om0v/zptL/86bS//Om0v/zpxM/8+dT//Om0v/zZhG/8uUPv/MlkH/zZlI/86bTf/QnlH/z51Q/86aSf/NmEX/y5U//8yWQv/Omkn/z5xN/8+cTv/Om0v/zptM/86bTP/Om0v/zptL/86bS//Om0v/zptL/86bS//Om0v/zptL/86bS//Om0v/zptL/86bS//Om0v/zptL/86bTP/Om0v/zptM/86bS//Om0z/zptL/86bS//Om0z/zptM/86bS//Om0v/zptL/86bS//Om0v/zptL/86bS//Om0v/z51O/8yWQf/kx5v//v37//v27//79/H/+/fx//v38f/79u7//fr2/9TErOQ5OTlxVVVVYVBQUENQUFApUVFRFlRUVAlZWVkDBAQEAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAE1NTQJRUVEIT09PEk5OTiNPT087V1dXWTU1NWmsrKyy/Pr4//v37//79/H/+/fx//v38f/79u7//v37/+vWtf/MlkL/0J1O/8+cTP/PnEz/zpxM/86cTP/Pm0z/z5xM/8+cTP/OnEz/z5xM/8+cTP/PnEz/zptL/8+bTP/Pm0z/z5xM/86cS//Om0z/zptM/86cTP/OnEz/z5xL/86cTP/PnEz/z5tM/8+bTP/OnEz/zpxM/86cTP/PnEz/z5xM/86cTP/OnEz/zpxM/8+dT//Pm0r/zJZB/86aSv/Wqmb/48WX/+zYuP/w4cj/9erY//nz6f/48OP/8+bR/+7dwv/p0q7/3bmB/9KhVv/NmET/zJdD/8+dTf/QnU3/z5xM/86cTP/Om0z/zptM/8+cS//PnEv/zptL/86cTP/PnEz/z5xM/86cTP/PnEz/zpxM/8+cTP/OnEz/z5xM/8+cTP/Pm0z/z5xM/8+bTP/OnEz/z5tM/86cTP/OnEz/zpxM/8+cTP/PnEz/z5xL/8+cTP/OnEz/zpxM/86cTP/PnU3/zppH/9SmX//58+r//Pjz//v38P/79/H/+/fx//v37//8+fT/8una/VlZWYJNTU1mUVFRS1FRUTFNTU0bUlJSDEpKSgUoKCgBAAAAAAAAAAAAAAAAAAAAAAAAAAAwMDABTU1NBFFRUQlRUVEWUFBQKlJSUkRRUVFfR0dHdN7b1eT9+vb/+/fv//v38f/7+PH/+/jx//v38P/9+vb/3Ld8/86YRP/Qnk7/z51M/8+dTP/PnE3/z51N/9CdTf/PnU3/0J1M/8+dTP/QnU3/z51N/9CdTf/PnEz/z5xN/8+dTf/PnE3/0J1N/8+dTf/PnUz/z5xM/8+cTP/QnE3/z51M/9CdTP/PnUz/z5xM/8+dTf/PnUz/z5xM/8+cTf/PnUz/z51M/9CeT//QnEv/zJZA/9KiVv/lyZ3/9enX//79+v//////////////////////////////////////////////////////+/bv/+7dwf/duH7/zZlG/86YRf/Qnk//z51O/8+dTf/PnU3/0J1M/8+dTP/PnUz/0J1M/8+dTP/PnU3/z5xM/9CdTf/PnEz/0J1M/8+cTP/PnEz/z51M/8+dTf/PnUz/z51N/9CdTP/QnU3/z51M/8+dTP/PnEz/z51N/9CdTP/QnUz/0J1M/8+dTf/PnU3/z51M/9CdTP/PnU3/zppH/+7cv//+/Pr/+/fv//v48f/7+PH/+/jx//v48P/8+fP/qp+NtTo6OmdVVVVUUFBQN05OTiBPT08QTExMBkRERAIAAAAAAAAAAAAAAAAAAAAAAAAAACsrKwFHR0cEUlJSDU9PTxtSUlIwVFRUS0ZGRmJxcXGI9fPu/fz48v/8+PH//Pjx//z48f/79/D//fr2//br2v/RoVL/0J1M/9CeTv/QnU3/z51N/9CeTf/Qnk3/z55N/9CeTf/Qnk3/0J5N/9CeTf/QnU3/0J1N/9CdTf/Qnk3/0J5N/9CdTv/Qnk3/0J5N/9CdTf/QnU3/0J1N/9CeTf/QnU3/0J5N/9CdTf/PnU3/0J1N/9CeTf/QnU3/0J1N/9CdTf/Rn1D/zppH/9CdTv/jxJT/+fPp//////////7////////+/f/+/vz//v78//7+/P///v3///79//7+/P/+/vz//v78/////v/////////////////x4sr/2rBw/86ZRP/PnU3/0J1O/9CeTf/QnU3/0J5N/9CdTf/Qnk3/0J5N/9CeTf/Qnk3/0J1O/9CdTf/Qnk3/0J1N/9CdTf/Qnk3/0J5N/9CeTf/Qnk3/0J1N/8+eTf/QnU3/0J1N/9CeTv/Qnk3/0J5N/9CeTf/Qnk3/0J1N/9CdTf/QnU3/0J1N/9GfUP/NmEP/37yH//38+f/79+///Pjx//z48f/7+PH/+/bu//369v/ZyrPlOzs7bFVVVVxPT08/UFBQJlJSUhNSUlIINzc3AwAAAAAAAAAAAAAAAAAAAAAAAAAAS0tLAVZWVgZSUlIPUVFRH1BQUDZYWFhSNTU1YqioqKn7+fb/+/fv//z48f/8+PH//Pjx//v27//+/vz/6M6m/82YRP/Qn0//0J5N/9CeTf/Rnk7/0Z5O/9GeTv/Rnk3/0J5O/9GeTv/Qnk7/0Z5O/9GeTv/Qnk3/0Z5O/9CeTf/Rnk7/0Z5O/9CeTf/Rnk7/0J5O/9GeTf/Rnk7/0Z5N/9CeTv/Qnk7/0J5N/9GeTf/Qnk7/0J5N/9CeTv/Qnk7/0Z9Q/86ZQ//YrWn/9uzc//////////7///79///+/f////7//v78//7+/P///////////////////////////////v/+/fv///79/////v/+/vz////+/////////v3/6tKu/9CcSf/PnEr/0Z9P/9CeTv/Rnk3/0Z5O/9GeTv/Rnk3/0Z5N/9CeTv/Qnk7/0J5O/9GeTf/Rnk7/0J5N/9CeTv/Rnk3/0Z5O/9GeTv/Rnk3/0Z5O/9CeTf/Rnk7/0Z5O/9GeTf/Rnk7/0Z5O/9GeTv/Rnk7/0J5O/9CeTv/Rnk3/0J5O/9CdS//TpFj/+O/i//z69f/79/D//Pjx//z48f/79+///Pn0//Dk0/pSUlJ4TU1NX1BQUEZPT08sTU1NGExMTAtTU1MEDAwMAQAAAAAAAAAAAAAAAAAAAAAxMTEDVVVVCFJSUhJQUFAkT09PO1dXV1g3NzdnzMnDy/379//79u7//Pjx//z48f/8+PH//Pjx//z58//bs3P/0JtG/9GfUP/Rnk7/0Z9O/9GfTv/Rnk7/0Z9O/9GeTv/Rn07/0Z9O/9GeTv/Rnk7/0Z5O/9GfTv/Rnk7/0Z9O/9GeTv/Rn07/0Z9O/9GeTv/Rn07/0Z5O/9GfTv/Rnk7/0Z9O/9GfTv/Rn07/0Z9O/9GfTv/Rn07/0Z5O/9GgUP/OmkT/37qB//z48v////////79///+/f////7//v78/////////////////////v/9/Pn//fr1//369v/+/fr////////////////////+///+/f////7//v78///+/f//////8ePK/9SjV//QnEn/0Z9P/9GeTv/Rn07/0Z5O/9GeTv/Rn07/0Z5O/9GeTv/Rnk7/0Z5O/9GeTv/Rnk7/0Z9O/9GfTv/Rnk7/0Z9O/9GeTv/Rnk7/0Z5O/9GeTv/Rnk7/0Z9O/9GeTv/Rn07/0Z5O/9GfTv/Rnk7/0Z5O/9GfTv/Rn07/0aBQ/8+bRf/r17T//v78//v27//8+PH//Pjx//z48f/8+PL/+vbt/4qBc5dERERhVFRUS1BQUDFQUFAbUFBQDUpKSgUpKSkBAAAAAAAAAAAAAAAAKCgoAUZGRgRISEgJT09PFlBQUChSUlJBTk5OW1JSUnLq5d7v/Pn0//v38P/8+PH//Pjx//v38f/9+vX/9+/g/9OjVv/Rnk3/0qBP/9GfTv/Rn07/0Z9O/9GfTv/RoE7/0Z9O/9GgTv/RoE7/0aBO/9GfTv/Rn07/0Z9O/9GgTv/Rn07/0aBO/9GgTv/Rn07/0aBO/9GgTv/Rn07/0aBO/9GfTv/Rn07/0Z9O/9GgTv/RoE7/0aBO/9GfTv/SoVH/z5pE/+TFlf/////////+///+/f////////79/////v///////fv4/+/fw//iwo//16pj/9OiU//QnUr/0Z5N/9SlWP/bs3P/582k//ft3P////7////////+/f////7///////7+/P//////9+7g/9apYP/QnEn/0qFQ/9GfTv/RoE7/0Z9O/9GfTv/RoE7/0aBO/9GfTv/RoE7/0aBO/9GfTv/RoE7/0Z9O/9GgTv/RoE7/0Z9O/9GgTv/RoE7/0Z9O/9GfTv/RoE7/0aBO/9GgTv/Rn07/0Z9O/9GfTv/RoE7/0Z9O/9GgTv/SoVH/z5lD/+LCjv/+/Pr/+/fw//z48f/8+PH//Pjx//v38P/8+fT/wbCXyDQ0NGBYWFhSUFBQNlBQUB9PT08PU1NTBkdHRwIAAAAAAAAAAAAAAAAICAgBUlJSBFJSUgtRUVEZUFBQLVNTU0dERERceHh4hPf07/38+PH//Pjx//z48f/8+PH/+/fw//79+//t27v/0Z5K/9KhT//SoE//0aBP/9GhTv/RoE7/0aFO/9KhT//RoE//0qFO/9KgT//SoE//0qFO/9KgT//SoE//0qBP/9KgT//SoE//0aFP/9KhT//SoE//0qBP/9KgTv/SoU//0qFO/9KhT//SoU//0qBO/9GgT//SoE//0qFS/8+bQ//gvIP//////////v////7///////7+/P///////fv4/+jPp//TolH/y5M2/8qPMP/Mkjb/zZQ4/82UOf/NlDj/zJQ4/8uRM//KkDD/zZY9/9qwbv/059L////////+/f////7///////79+///////9urY/9OhUv/Rnkz/0qFQ/9GgTv/SoE//0qFP/9GhTv/RoU//0qFP/9KgTv/RoE//0aFO/9KgTv/SoE//0qBO/9KhTv/SoE7/0aBP/9KgT//SoE//0qFP/9KhTv/SoU7/0qFP/9KgTv/RoE//0qBO/9KgTv/SoE7/0qFP/9KgUP/Rnkv/2K1o//v27//8+PL//Pjx//z48f/8+PH/+/bv//369v/dzrXoOzs7ZVVVVVZQUFA7UFBQJFFRURJUVFQHRUVFAwAAAAAAAAAAAAAAAE1NTQFLS0sFTk5ODlFRURtPT08xV1dXTDIyMlmvr6+m+/n2//z38P/8+PL//Pjy//z48v/79u///v37/+XHl//PmkT/1KJS/9KhUP/SoU//0qFQ/9KhUP/SoVD/06FQ/9OhT//SoU//06FP/9OhT//ToU//0qFQ/9OhT//SoVD/0qFP/9OhT//SoU//06FP/9KhT//SoU//0qFP/9OhUP/SoU//0qFP/9KhT//SoU//0qFP/9OiUf/RnUn/2bBr//z48f////////79///////+/vz///////Tm0P/Vplf/y5Aw/82VOf/PmT//zplB/86YP//OmD7/zpg+/8+YP//PmD7/z5lA/8+ZQf/Olz3/zJI0/8yVOP/hvYX//fv3/////////v3///////7+/P//////7t2+/9GeSv/SoVD/0qFP/9OhT//SoU//0qFP/9KhUP/SoU//06FQ/9OhT//SoU//0qFP/9OhT//ToU//0qFP/9OhT//SoU//06FP/9KhUP/SoVD/0qFP/9KhT//SoU//06FQ/9OhT//ToVD/0qFP/9KhT//SoU//06FP/9KhT//TolH/9enW//379//79/H//Pjx//z48v/79/D//Pn0//Dn1fpVVVVwTk5OV1FRUT9PT08nU1NTFFBQUAlLS0sDAAAAAAAAAAAAAAAATU1NAkNDQwZQUFAPUFBQH09PTzVZWVlQKysrWsLCwLf9+/j/+/bu//z48v/8+PL//Pjy//z48v/89/H/3LRy/9GfSf/TolL/06JQ/9OiUP/ToVD/06FQ/9OhUP/ToVD/06FQ/9ShUP/TolD/1KFQ/9OiUP/ToVD/06JQ/9OiUP/Uok//06FQ/9OiUP/ToVD/06FQ/9OhUP/ToVD/06FQ/9OhUP/ToVD/1KFQ/9OhUP/TolH/06JP/9OjUf/269n///////7+/P///////v78///////t2bf/zpg9/82UNv/PmkL/z5lA/8+YPv/PmD7/z5g+/8+YPv/PmD7/z5g+/8+YPv/PmT7/z5g+/8+YPv/PmUD/z5g//8uQMP/YrWb/+vPp/////////v3///////7+/P//////5ceY/9GcRf/Uo1P/06JQ/9OhUP/ToVD/06FQ/9OhUP/TolD/06FQ/9OhUP/ToVD/06FQ/9ShUP/ToVD/1KFQ/9OhUP/ToVD/06FQ/9OhUP/ToVD/06FQ/9OhUP/ToVD/06FQ/9OhUP/TolD/06FQ/9OhUP/UolD/06NS/9GeR//r1K////79//v27//8+PL//Pjy//z48f/8+PL/+vPo/25taH1ISEhZU1NTQ1BQUCpPT08XVVVVCk9PTwQNDQ0BAAAAAAAAAAE3NzcCV1dXB0xMTBFQUFAhUFBQN1VVVVE8PDxg2NPL1P369v/89u///Pjy//z48v/89/H//Pn0//nx5f/Wplj/06JO/9SjUv/Uo1H/1KJR/9SiUf/UolH/06NR/9SiUP/Uo1H/06NR/9SjUf/Uo1H/1KJR/9OiUf/UolH/1KJQ/9SiUf/Uo1H/1KJR/9SjUP/Uo1H/1KJR/9OjUf/Uo1D/1KJR/9SiUf/To1D/1KJQ/9SkU//RnUb/5caV/////////v3////////+/f//////7di2/82UNP/PmD3/0JpB/8+ZP//PmT7/z5k//8+ZPv/PmT7/z5k//8+ZP//PmT7/z5o+/8+ZP//PmT//z5o//8+aP//PmT//0JtC/82TM//VqFr/+/bt//////////7////+///////69Or/1qhc/9OiTf/Uo1L/06JR/9SiUP/Uo1H/1KJQ/9OiUf/UolH/1KJR/9SiUP/Uo1H/1KJQ/9SiUP/UolH/1KNR/9SiUf/UolH/1KJQ/9OiUf/UolH/1KJR/9SiUf/Uo1H/1KJR/9SiUP/UolD/1KNR/9SiUf/UpFP/0Z1F/+TFkv/+/fv/+/fw//z48v/8+PL//Pjy//z48v/8+PH/o5aAoD8/P1hVVVVHUVFRLVFRURlTU1MMV1dXBCoqKgEAAAAAAAAAAFVVVQNQUFAIT09PE1FRUSNSUlI6TU1NUlVVVWjq5dzt/Pn0//z48P/8+PL//Pjy//v38P/9+/j/9OfR/9WjUv/To1D/1KNR/9SjUf/UpFH/1KRR/9SjUf/Uo1H/1KNR/9SjUf/Uo1H/1KNR/9SjUf/Uo1H/1KNR/9SjUf/Uo1H/1KNR/9SkUf/Uo1H/1KNR/9SjUf/UpFH/1KNR/9SjUf/UpFH/1KNR/9SjUf/Vo1L/1KJO/9eoWv/58uf//////////v///v3///////Tn0f/QmT7/z5k9/9GbQf/QmkD/z5o//9CbQP/Pmj//0Jo//9CaP//PmkD/0JpA/8+aP//Qmz//z5o//8+aP//Pmz//z5o//8+aP//Pmz//0ZxD/82UM//dtHL///79/////////////v78///////q0an/0Z5H/9SlUv/Uo1H/1KNR/9SjUf/UpFH/1KNR/9SjUf/Uo1H/1KNR/9SjUf/Uo1H/1KNR/9SjUf/Uo1H/1KRR/9SjUf/Uo1H/1KNR/9SjUf/UpFH/1KNR/9SjUf/Uo1H/1KNR/9SkUf/Uo1H/1KRR/9WkUv/Tn0n/37p9//z58//8+PL//Pjy//z48v/8+PL//Pjx//z58//CsJLCNDQ0VlhYWElQUFAwT09PHExMTA1NTU0FWFhYAQAAAAAAAAAAT09PA0VFRQlOTk4UUFBQJVJSUj1KSkpSYGBgbPPv6fj8+fP//Pjx//z48v/8+PL/+/fw//79+//u27r/06FM/9WkUv/UpVH/1aRR/9SlUf/UpFH/1KRR/9WkUf/UpFH/1KRR/9SkUf/UpFH/1KVR/9SkUf/UpFH/1KVR/9SlUf/UpFH/1KVR/9WkUf/UpFH/1KRR/9WkUf/VpFH/1KRR/9WlUf/UpVH/1KRR/9alVP/Snkf/6Myg///////+/vz////+///////+/Pn/1qlZ/9CXOP/RnEL/0ZtA/9CbQP/Qm0D/0JtA/9GbQP/Qm0D/0JtA/9GbQP/Qm0D/0JtA/9CbQP/Qm0D/0JtA/9CbQP/Rm0D/0JtA/9CbQP/Qm0D/0ZxD/82SMP/pzaL///////7+/P////7///////z48f/YrWL/1KJO/9WlUv/VpVH/1KRR/9WlUf/UpFH/1KRR/9SkUf/UpFH/1KRR/9SkUf/UpFH/1KRR/9SlUf/UpFH/1KRR/9SlUf/UpVH/1KRR/9WkUf/UpFH/1aVR/9SkUf/UpVH/1KRR/9SkUf/UpFH/1aRS/9SiTf/ar2j/+/bt//z58//8+PH//Pjy//z48v/89+///fr2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/9SfQf/Tn0L/055C/9OeQf/TnkL/055C/9OeQv/TnkL/059C/9OeQv/UnkL/055B/9OeQv/TnkH/055B/9OeQv/TnkL/055B/9OdQf/TnkP/9uvX/////////v3////////////8+PH/+/bt//v27v/79u3/+/bt//v27f/79u3/+/Xs//v16//69ev/+vXq//r16v/69On/+vTp//r06P/69On/+vPo//rz6P/68+j/+fPn//ny5v/58ub/+fLm//ny5f/58uX/+fLl//nx5P/58eT/+fHj//nw4v/79ev//Pnz//z48v/8+PL//Pjy//z48P/8+fT/8ubQ+1RUVGBNTU1LUlJSN1BQUCFWVlYRVFRUB19fXwIgICABVFRUAV1dXQRMTEwLUFBQGFJSUipbW1tCKioqSb29vaH9+/f//Pfv//z48v/8+PL//Pjy//z48v/8+PL//fr0//369f/9+vX//fv2//379//9+/f//fv3//37+P/+/Pn//vz5//78+v/+/Pr//v37//79+//+/fv//v37//7+/P/+/vz///79///+/f////7////+//////////////////////////////////////////////////////////////////79+//csWb/0ps8/9SgRP/Un0P/1J9D/9SfQv/Un0P/1J9C/9SfQv/Un0L/1J9C/9SfQv/UoEP/1J9C/9OfQv/Un0L/1J9C/9SfQ//Un0L/1J9C/9SfQv/Un0L/1KBD/9SfQv/UoEL/1KBG/9GZOP/s1K3///////7++//////////////////////////////////////////////////////////+/////v////7///79///+/f/+/vz//v78//79/P/+/fz//v37//79+//+/Pr//vz6//78+f/9+/j//fv4//37+P/9+/f//fv2//379v/9+vX//fr1//z58//8+PL//Pjy//z48v/8+PL//Pjx//359P/16df9WlpaYUxMTEpSUlI2UFBQIVRUVBJOTk4IVFRUAwAAAABTU1MBXFxcBExMTAtQUFAYU1NTKltbW0EjIyNHwsLCpf379//89+///Pjy//z48v/8+PL//Pjy//z48v/8+PL//Pjy//z58//8+fP//fn0//359P/9+fT//fr1//369f/9+vX//fv2//379v/9+/f//fv3//37+P/9+/j//vz5//78+f/+/Pr//vz6//79+//+/fv//v38//79/P/+/vz///79///+/f///v3////+/////v///////////////v///////fv5/9mpWP/TnT//1KBE/9SgQ//VoEP/1KBD/9SgQ//VoEP/1aBD/9WgQ//VoEP/1KBD/9WgRP/VoEP/1aBD/9SgQ//VoEP/1aBD/9SgQ//VoEP/1aBD/9WgQ//VoEP/1aBD/9SgQ//UoUb/0Zg1/+vQpP///////v38///////////////+/////v////7///79///+/f/+/vz//v78//79/P/+/fv//v37//79+//+/Pr//vz6//78+f/9+/j//fv4//379//9+/f//fv3//379v/9+/b//fr1//369f/9+vX//fr1//359P/8+fP//Pnz//z48v/8+PL//Pjy//z48v/8+PL//Pjy//z48v/8+PH//Pnz//fu3/5gYGBhS0tLSFRUVDZQUFAhVFRUEk9PTwhTU1MDAAAAAFJSUgFcXFwETExMC1FRURhRUVEpW1tbQCAgIETHx8eo/fv3//v37//8+PL//Pjy//z48v/8+PL//Pjy//z58//8+fP//fn0//359P/9+vX//fr1//369f/9+vX//fv2//379v/9+/f//fv3//38+P/9/Pj//vz5//78+f/+/Pr//vz6//79+//+/fv//v38//79/P/+/vz//v78///+/f////7////+/////v/////////////////////////+///////9+/X/2KZP/9SfQP/WoUX/1aBE/9WgRP/VoUT/1aBE/9WgRP/VoEP/1aFE/9WgQ//VoET/1aBE/9WgRP/VoEP/1aBE/9WgRP/VoET/1aBE/9WgRP/VoET/1aBE/9WgRP/VoET/1aBE/9aiR//RmDX/6c6e///////+/fz///////////////////////////////7////+///+/f///v3//v78//79/P/+/fz//v38//79+//+/fv//vz6//78+v/+/Pn//vz4//38+P/9+/f//fv3//379//9+/b//fv2//369f/9+vX//fr1//359P/9+fT//Pnz//z58//8+PL//Pjy//z48v/8+PL//Pjy//z48f/8+fP/+fPm/2VlZWFHR0dHU1NTNlFRUSFUVFQRT09PCFNTUwMAAAAAW1tbAV1dXQROTk4LUFBQF09PTyhbW1s/ICAgQ8fHx6b9+/f/+/fv//z58v/8+fL//Pny//z58v/8+fL//Pnz//z58//9+fT//fn0//369f/9+vX//fr1//369f/9+/b//fv2//379//9+/f//vz4//78+P/+/Pn//vz5//78+v/+/Pr//v37//79+//+/fz//v38//7+/P/+/vz///79/////v////7////+//////////////////////////7///////369v/ZqFL/1aBA/9aiRf/VoUX/1aJE/9WhRf/VoUX/1aFE/9WhRP/VoUX/1aJE/9aiRf/WokX/1qJF/9aiRv/WokX/1qNF/9WiRP/VoUT/1aFE/9WhRf/VoUX/1aFE/9WiRP/VoUX/1qNI/9KZNv/q0KH///////79/P///////////////////////////////v////7///79///+/f/+/vz//v38//79/P/+/fz//v37//79+//+/Pr//vz6//78+f/+/Pj//vz4//379//9+/f//fv3//379v/9+/b//fr1//369f/9+vX//fn0//359P/8+fP//Pnz//z58v/8+fL//Pny//z58v/8+fL//Pnx//z58//58eT/ZGRkX0lJSUVTU1M0UFBQIFJSUhFUVFQHUVFRAwAAAAAlJSUBYWFhBFVVVQpQUFAWUFBQJ1tbWz0hISFAxMTEoPz79v/89+///Pny//z58v/8+fL//Pny//z58v/8+PH//Pjw//z48f/8+PH//Pjx//z48f/8+PH//Pny//z58//8+fP//fn0//359P/9+vX//fr1//369f/9+vX//fv2//379v/9+/f//fv3//78+P/+/Pj//vz5//78+f/+/Pr//v37//79+//+/fv//v38//79/P///v3//////////v///////v36/9quXf/UoED/1qNG/9aiRf/WokX/1qJF/9aiRf/Wo0X/1qJF/9ajRv/Xo0b/16NH/9ekSP/XpEj/16RI/9ekSP/Xo0f/1qNG/9WiRf/VokX/1qNF/9ajRf/Wo0X/1qJF/9aiRf/Xo0f/1Js4/+vTp////////v78/////////////v78//79/P/+/fz//v37//79+//+/Pr//vz6//78+f/+/Pj//vz4//379//9+/f//fv3//379v/9+/b//fr1//369f/9+vX//fr1//359P/9+fT//Pnz//z58//8+fL//Pny//z48f/8+PH//Pjx//z48P/8+PD//Pjx//z58v/8+fL//Pny//z58v/8+fH//fn0//fs2/5eXl5aSkpKRFJSUjJOTk4fTk5OEFRUVAdiYmICISEhAQAAAAFbW1sEWVlZClNTUxVQUFAlWlpaOyMjIz/AwMCY/Pv2//z37//8+fL//Pny//z58v/8+fL//Pny//79/P///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////v/+/fz/4rx3/9SdPP/XpEj/16NG/9ekRv/Xo0b/1qNG/9ajRv/Wo0b/2KVJ/9ilSv/YpUv/16ZM/9imTP/Ypkz/2KZL/9ilS//YpUn/1qNG/9ajRv/Xo0b/1qNG/9ejRf/Xo0b/1qNG/9ekR//Vnj3/8N66///////+/vv////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////9+/b//Pjx//z58v/8+fL//Pny//z58f/9+fT/9enU/VhYWFVLS0tBUlJSMVJSUh5SUlIPXl5eB2BgYAIZGRkBFxcXAT4+PgROTk4KT09PFFFRUSNaWlo4JiYmPbq6uo/8+vb//Pjw//z58v/8+fL//Pny//z58v/9+vP/79y4/+rOnf/r0aL/69Gi/+zRov/r0aL/7NGi/+vRov/r0aL/7NGi/+zRpP/s0qP/7NGj/+zRpP/s0qT/7NKk/+zSpf/s0qT/7NKl/+zTpf/s06b/7NOm/+zTpv/s06b/7NOn/+zTp//s06f/7dOo/+3Uqv/r0KH/9+rV/////////v3//v38///////s06f/1Zw5/9ilSf/XpEb/16RG/9elRv/XpEb/16RH/9ilSv/Zpkv/2KdM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AQAAAAAAAAABNzc3Ak5OTgZOTk4NT09PGVNTUypJSUk4Y2NjTfTw6PT9+fP//fnx//358v/9+fL//Pjx//79+//y4cH/2aVF/9qmSP/apkj/2qZI/9qmSf/apkj/2qZJ/9qnSf/apkj/2qZI/9qmSf/apkj/2qZI/9qmSP/apkn/2qZI/9qmSf/apkj/2qZI/9qmSP/apkj/2qZI/9qmSP/apkj/2qZI/9qmSP/apkj/2qZI/9qoS//YokD/4796//////////7////+/////v//////58aJ/9egO//aqUv/2qdJ/9qpS//bqk7/26tR/9ysU//crVX/3a9X/92wWP/dr1n/3bBa/92vWP/dr1f/3K1U/9usUv/bq1D/26pN/9uoS//ap0n/2qZJ/9mkRf/16M7////////+/f///v3///////fr1f/ap0n/2qZJ/9qmSf/apkn/2qZI/9qmSP/apkj/2qZI/9qmSP/apkj/2qZI/9qmSP/apkn/2qZI/9qmSP/apkj/2qZJ/9qnSf/apkj/2qZI/9qmSf/apkj/2qZI/9qmSP/apkn/2qZI/9qnSP/apkj/2qhK/9ijQv/gt2r//Pjx//358//9+fL//fny//358v/8+O///fr1/9rEnskXFxc1XFxcNU9PTyJSUlIUU1NTCk1NTQQxMTEBAAAAAAAAAABUVFQBTExMBU9PTwxOTk4XUVFRJk9PTzVNTU1D7efb4v369f/8+O///fny//358v/8+fH//vv3//jt2f/bqkz/2qdI/9unSv/ap0n/2qdJ/9qnSf/ap0n/2qdJ/9qnSf/ap0j/2qdJ/9qnSf/ap0n/2qdJ/9qnSf/ap0n/2qdJ/9qnSf/ap0n/2qdJ/9qnSf/ap0n/2qdJ/9qnSP/ap0n/2qdI/9qnSf/ap0n/2qdJ/9uoS//ZpEL/8+TG/////////vz////+///////9+/b/4blt/9iiPv/cq0//2qpN/9ysUP/crFL/3a5V/92vV//esFr/3rFc/96xXP/esVz/3bBb/92wWf/drlb/3K1T/9ysUf/cq0//26pN/9upS//Yoj3/79iu/////////v3//////////v//////5cF+/9miP//bqUv/2qdJ/9qoSf/ap0n/2qdJ/9qnSf/ap0n/2qdJ/9qnSf/ap0n/2qdJ/9qnSf/aqEj/2qdJ/9qnSf/ap0n/2qdJ/9qnSf/ap0j/2qhJ/9qnSf/ap0j/2qhJ/9qnSf/ap0n/2qdJ/9qnSf/bqUv/2aI//+bDgv/+/Pj//Pnx//358v/9+fL//fny//358f/9+fP/yrWNqioqKjVaWloxUFBQH1NTUxFISEgJREREBBsbGwEAAAAAAAAAACcnJwFVVVUET09PC05OThRRUVEjXFxcNBkZGTTf2s68/fv3//z48P/9+fL//fny//z58f/9+vT/+/bs/96xWv/apkb/26hK/9uoSf/aqUr/26hK/9uoSf/aqEr/26hJ/9uoSf/aqEn/26hJ/9uoSv/aqEn/26hK/9qoSf/bqEr/26hJ/9uoSv/bqEr/26hK/9uoSv/aqEr/26hJ/9qoSf/bqEn/26hK/9qoSf/aqEr/3KlL/9mkQf/hum7////+/////v////////79///////69Ob/4LVi/9qjQP/crVL/3a1R/9yuU//dr1b/3rBZ/9+yW//fsl7/37Nf/9+zXv/fsl3/3rFb/92wWP/drlX/3a1S/9ytUv/cq03/2aM//+vOmv////////79/////////vz///////Tmyv/apUT/26hK/9uoSf/bqEn/26hJ/9uoSf/bqEr/26hJ/9qoSf/bqEn/26hJ/9uoSv/bqEr/26hJ/9qoSf/bqEr/2qhJ/9uoSv/aqEn/26hJ/9qoSv/bqEr/26hJ/9uoSf/aqEr/26hJ/9uoSf/bqEr/26hJ/9ypS//Zojz/68+a/////v/8+PD//fny//358v/9+fH//fny//v47/+qmnp7Ojo6NFdXVyxPT08cTk5OD1ZWVgdZWVkDAAAAAAAAAAAAAAAABgYGAURERANJSUkJUVFRElFRUR5gYGAxAgICLdPS0Jz9+/f//fjw//358v/9+fL//fny//z58v/9+/f/5cN+/9qkQP/cqkz/3KlK/9upS//bqUr/3KpK/9ypS//cqUr/3KlK/9upSv/bqUr/3KlK/9ypSv/bqUr/3KlK/9upSv/cqUr/3KlL/9upSv/bqUr/3KlK/9upSv/bqUr/26lK/9upSv/cqUr/26lK/9upSv/bqUv/3KlL/9qlQf/v1qr////////+/P////////79///////8+PD/5MB6/9mkQP/crFD/3rBX/96wWP/eslv/37Jd/+C0YP/gtWH/4LVh/+CzXv/fslz/3rFZ/96wWP/dr1b/3KhI/9uoSv/w2rH////////+/f/////////+///////9+vX/4rlr/9umQ//cqUz/3KlL/9ypSv/bqUr/26lK/9upS//cqUr/3KlK/9upSv/cqUv/26lL/9ypSv/cqUr/3KlK/9upSv/bqUr/3KlK/9ypSv/cqUv/3KlL/9ypSv/bqUr/3KlK/9upSv/bqUr/3KlK/9ypSv/cqUv/3KlL/9qmRf/y4L7//v38//z48P/9+fL//fny//358f/9+vP/+fLj/nFsZU5FRUUzU1NTKFJSUhhOTk4NSUlJBjg4OAIAAAABAAAAAAAAAAAAAAAAV1dXA1JSUgdPT08PT09PG1paWiwfHx8turq6efv69//9+fH//fny//358v/9+fL//Pjw/////v/t1KT/2qRA/92rTf/cqkv/3KpK/9yqS//cqkr/3apL/9yqS//cqkv/3apL/9yqS//cqkv/3KpL/9yqS//cqkv/3KpL/9yqS//cqkv/3KpL/92qS//cqkv/3KpL/9yqS//cqkv/3KpK/9yqS//cqkr/3KpL/9yqS//cqkv/3KlK/9yoR//05sj///////79/P/////////+///////+/Pn/7tap/9+zXP/cqEj/3q5T/9+yW//gtGD/4bZj/+G3Zv/ht2T/4LVi/+CzXv/fsVj/3atO/9ypSv/kvnX/9urT/////////v3//////////v///v3//////+jGhv/apED/3atN/9yqSv/cqkv/3KpL/9yqS//cqkv/3KpL/9yqS//dqkv/3KpL/9yqS//cqkv/3KpL/9yqS//cqkv/3KpL/9yqS//cqkv/3KpK/9yqS//cqkv/3KpL/9yqS//cqkr/3KpL/92qS//cqkv/3KpL/9yqS//cqEj/369V//ry4//9+/b//fny//358v/9+fL//fjw//369P/x4sf1SEhIPFBQUDFSUlIkUFBQFlBQUAtPT08FSEhIAgAAAAAAAAAAAAAAAAAAAAE0NDQCRkZGBlJSUg1QUFAXVFRUJkFBQTB0dHRJ+PXu+f358v/9+fH//fny//358v/8+PH//vz5//XozP/dqkv/3KpL/92qS//dqkv/3apL/92qS//cqkv/3apL/9yqS//dqkv/3KpL/9yqS//dqkv/3apL/92qS//dqkv/3apL/92qS//cqkv/3apL/92qS//cqkv/3apL/92qS//dqkv/3apL/92qS//dqkv/3apL/92qS//dq03/3KhH/9+wVf/58N////////79/P/////////+///+/f//////+/br/+7Vpv/jvXH/4LNb/92vUv/er1P/37BV/9+wVf/er1P/37BV/+G1YP/oxYP/8+PE///+/P////////79//////////7///78///////t06H/26VB/92sTf/dqkv/3apL/92qS//dqkv/3apL/9yqS//dqkv/3apL/92qS//dqkv/3KpL/92qS//cqkv/3apL/92qS//dqkv/3apL/9yqS//dqkv/3apL/92qS//dqkv/3apL/92qS//dqkv/3apL/92qS//cqkv/3atN/9ynRP/lv3b//fr1//358v/9+fL//fny//358v/9+PD//fr1/+PQqtcPDw8sXl5eME9PTx9NTU0TUFBQClJSUgQuLi4BAAAAAAAAAAAAAAAAAAAAADo6OgJXV1cFVFRUC1FRURRSUlIhUlJSLkZGRjfu59vd/fr1//348P/9+fL//fnz//358v/9+vX//Pbr/+C0XP/dqkn/3axM/96rS//eq0z/3qtM/92rS//eq0v/3qtM/92rS//eq0v/3qtM/92rS//dq0v/3atL/92rS//eq0v/3atL/92rS//dq0z/3atL/96rS//eq0z/3atL/92rS//eq0v/3qtM/96rS//dqkz/3qtL/96rS//erE7/3KlG/+G0Xf/47dj////////+/f///v3////+///+/f/////////////+/f/5793/8d21//DasP/w2a3/8Nmv//Dbsv/z4sH//Pjw///////////////+///+/f////////78/////v//////7dOh/92oRv/drEz/3atM/92rS//eq0z/3atL/96rS//dq0v/3atM/96qS//eq0v/3atL/92rS//eqkz/3atL/96rS//dq0v/3qtL/92rS//eq0v/3qtL/96rS//dq0z/3atL/92rS//eq0v/3atM/96rS//dq0z/3qtL/96rS//erE7/3KZA/+3RnP////7//Pjw//358v/9+fP//fny//358v/9+fL/zbeMoyAgICtbW1srUFBQG05OThBPT08ISUlJAxcXFwEAAAAAAAAAAAAAAAAAAAAAEhISAVVVVQNKSkoITk5OEFJSUhxhYWEtAAAAJdzXz6T++/f//fjw//358//9+fP//fnz//358f/+/Pn/6ceG/9yoQv/frU//3qxM/9+sTP/frEz/36xM/9+sTP/erEz/3qxL/9+sTP/erEz/36xM/96sTP/erEz/3qxM/96sS//frEz/3qtM/9+sTP/erEv/36xM/9+sTP/erEz/36xM/96sTP/erEz/36xM/96sTP/frEz/3qxM/96sTP/frE//3apH/96tT//z4b///////////v///v3////+///+/f///v3////////////////////////////////////////////////////+///+/f////7///79///+/f///////fv2/+nIh//cp0H/3qxN/96sTf/erEz/3qxL/96sTP/erEz/3qxM/9+sTP/erEz/3qxM/96sTP/eq0z/36xM/96rTP/frEz/3qxM/96sTP/erEz/3qxM/96sS//erEz/3qxM/9+sTP/erEz/3qxM/9+sTP/erEz/36xM/9+sTP/erEz/3qxM/96sTf/dq0r/9ObI//79+//9+fH//fnz//358//9+fL//frz//rz5f+Wh2pbQUFBLVRUVCVQUFAXUVFRDVdXVwY0NDQDAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABQEBAA1FRUQdRUVEOUVFRGF1dXScYGBgnu7u7b/z69//9+fL//fnz//358//9+fP//Pjw///+/f/z4b7/3qpG/9+tT//frUz/361N/9+tTP/frUz/361N/9+tTP/frUz/361M/9+tTf/frU3/361N/9+tTP/frU3/361M/9+sTP/frE3/361M/9+tTf/frU3/3q1M/9+tTf/frU3/361M/9+tTP/frUz/361N/9+tTf/frUz/361M/9+tTf/frk//3qxL/96rSP/sz5f//Pft//////////7///79///+/f///v3///79//7+/P/+/vz//v78//7+/P/+/vz//v78///+/f///v3///79/////v////////////bq0P/kvG3/3adB/9+uT//frUz/361M/9+tTf/frUz/361M/9+tTP/frU3/361N/9+sTf/frU3/361M/9+tTP/frU3/361N/9+tTP/frUz/361M/9+sTf/frUz/36xM/9+tTf/frUz/361N/9+tTf/frU3/361M/9+tTf/frUz/36xN/9+tTf/frk//3apG/+O7af/8+PD//frz//358//9+fP//fnz//348f/9+vT/8eLF9D8/PzJTU1MsUlJSH09PTxNSUlIKUlJSBT09PQIAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABCQkICUFBQBU9PTwtQUFAUVFRUIEFBQSlxcXE99/Tt9v368//9+fL//fnz//358//9+fL//fr0//z26//juGH/3qxJ/9+uTv/frk7/365N/9+uTf/frk3/365N/9+uTf/frk3/361N/9+uTf/frk3/365N/9+uTv/frk3/365N/9+uTf/frk7/365O/9+uTf/frk3/365N/9+uTf/frk3/365N/9+uTf/frk3/365N/9+uTf/frU3/361N/9+uTf/grk7/4K5O/96pQv/htFn/8Neo//358//////////+///////////////+///+/f/+/vz///79///+/f////7///////////////7///////nu2v/oxoH/36pH/9+qR//gr1D/361N/9+uTf/frk3/365N/9+uTf/frU3/365N/9+tTf/frk7/365N/9+uTf/frk3/365N/9+tTf/frk3/361N/9+uTf/frk3/365N/9+uTf/frk3/365N/9+uTf/frk3/365O/9+uTf/frk3/365N/9+uTf/frk7/365O/+CvUP/eqUP/7tOf///+/f/9+PD//fnz//358//9+fP//fjx//369P/jz6jMAQEBI2BgYClQUFAaT09PEFFRUQhOTk4DExMTAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAADIyMgFPT08ESkpKCVBQUBBTU1MbW1tbKBcXFybp49i+/fv2//348P/9+vP//frz//368//9+PD///79/+zPlv/fqkP/4LBQ/9+vTv/fr07/369O/9+vTv/fr07/4K5O/9+vTf/gr07/369O/9+vTv/grk7/369O/+CvTv/fr07/4K9O/9+vTv/fr07/369O/9+vTv/grk3/369O/+CvTv/fr07/369O/9+vTf/gr07/365O/9+vTv/gr07/365O/9+vTf/grk//4LBQ/9+sS//eqkP/4rZe/+vNkP/048H//fjw/////////////////////////////////////////v3/+vHf//Darf/ow3r/369O/9+qRP/gr0//4K9Q/9+vTv/fr03/369O/9+vTv/fr07/4K9O/9+vTv/frk7/369O/9+uTf/fr07/4K9O/+CvTv/gr07/369O/9+vTv/gr03/369O/+CvTv/gr07/365O/9+vTv/gr07/369O/+CuTv/gr07/369O/9+uTv/fr07/4K9O/+CuTv/frk7/365N/+CvUP/37NX//vz4//358f/9+fP//frz//368v/9+vP//Pjv/7ungHUtLS0lWlpaI0xMTBZRUVENW1tbBk5OTgIAAAABAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAEBAQAVVVVQNNTU0HUVFRDk9PTxZgYGAkBgYGIMDAwGn9+/j//fnx//368//9+vP//frz//358f/+/fr/9unO/+CuS//gr0//4K9O/+CvTv/gr07/4K9O/+CvT//gr07/4K9P/+CvT//gr07/4K9O/+CvT//gr07/4K9O/+CvTv/gr0//4K9P/+CvTv/gr07/4a9O/+CvTv/gr07/4K9O/+CvT//gr07/4K9P/+CvT//gr0//4K9P/+CvT//gr0//4K9P/+CvTv/gr0//4LBP/+GxUf/grkz/3qpC/9+sR//itVr/58J1/+rJh//t0Jf/8Nen/+/VoP/szZD/6MaA/+W8a//hr1D/3qpC/9+rRv/gr07/4rFR/+CvTv/gr0//4K9O/+CvT//gr0//4K9O/+CvTv/gr07/4K9O/+CvTv/gr07/4K9O/+CvTv/gr07/4K9O/+CvT//gr07/4a9O/+CvTv/gr0//4K9O/+CvTv/gr0//4K9O/+CvTv/gr07/4K9O/+CvT//gr07/4K9P/+CvTv/gr07/4K9O/+GwUP/frEf/58F3//779v/9+fL//frz//368//9+vP//fnx//369P/z5MX2OTk5K1RUVChTU1McUFBQEktLSwpTU1MFREREAgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAASkpKAU5OTgVUVFQLT09PElJSUhxKSkolYWFhMvXx5+/9+vT//fry//368//9+vP//frz//358v/++/f/6MV7/9+sR//hsFD/4bBP/+CvT//hsE//4LBQ/+CwT//hr0//4a9P/+GvT//hsE//4a9P/+CvT//hsE//4a9P/+GvT//hsE//4bBP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BVFRUQpRUVEPVlZWFlxcXBwkJCQa9O3fz/789v/++fD//vrz//768//++vP//vrz//768//9+vL///79//fmw//qvVz/6bxX/+q/Xf/qvlv/6b1c/+q+XP/qvlz/6r5c/+q+Xf/qvl3/675d/+u+Xf/rv1//679f/+q/X//rv1//679f/+u/YP/qv2D/679g/+q/YP/rwGH/68Bg/+rAYP/rwGH/6sBg/+vAYf/rwGH/68Bh/+rAYv/rwGL/6sBi/+vBYf/rwGH/68Bi/+vAYf/qwGH/68Bi/+rAYf/rwGH/68Bg/+vAYf/rwGH/6sBh/+u/YP/qv2D/6r9g/+u/YP/qv2D/679f/+u/YP/rv1//679f/+u+Xf/rvl3/6r5e/+q+XP/qvl3/6r9c/+q9W//qvVz/6r1b/+m9W//qv1z/6LpQ/+7Mfv/99+r//vz4//358f/++vP//vrz//768//++vP//vry//768//++vL/3MeXiwAAABJpaWkcUVFRElNTUw1TU1MISkpKBFtbWwIAAAABAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAATc3NwFJSUkEUVFRB1FRUQtOTk4QXFxcGD8/Pxl7e3sk9vDh5P779v/++fH//vrz//768//++vP//vrz//768//9+vH///79//jrzv/swWL/6rxV/+u/X//qvlz/6r5c/+q/Xf/qv13/679e/+u/X//rv1//679e/+vAYP/rwGD/68Bg/+zAYP/swGD/68Bg/+vAYf/rwGH/68Bh/+vBYv/swWL/68Fh/+vBY//rwGP/68Fj/+vBYv/rwGP/68Fj/+vBY//rwWP/7MFj/+vBY//rwGP/68Fj/+zBY//rwWP/68Fj/+vBY//rwWP/68Fi/+vBYv/rwWL/68Fh/+vAYf/rwGH/7MBh/+vAYP/rwGD/68Bg/+vAYP/rv2D/679f/+u/X//rv1//679e/+q/Xf/qv13/679d/+q+XP/qv13/6r9d/+q6UP/v0In//fnw//789//9+vH//vrz//768//++vP//vrz//768v/++vL//vv1/+fSnrQAAAARZmZmHVNTUxRQUFAOUlJS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AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAR0dHAlRUVANLS0sFVlZWCVBQUA1RUVESYGBgGU9PTxkNDQ0U49vGiv369f3++/X//vrw//778v/++/P//vv0//778//++/P//vvz//768//++vH//vz3///+/P/89eP/9t+q//DNef/uxGP/7sNf/+7FZ//vx2r/78ds/+/Hav/vx2v/78dq/+/HbP/vx2z/8Mdt/+/HbP/vyG3/78ht/+/Jbv/vyG3/78hu/+/Ibf/vyG7/78hu/+/Ibv/vyG3/78ht/+/Ibf/vx2z/78dt/+/Ha//vx2v/78dr/+/Ha//vx2v/78dr/+/Gav/uxWT/7sNg/+7GaP/y04v/+OnE//778////vz//vv0//768f/++/P//vvz//778//++/T//vv0//778//++vP//vnx//789v/46sr0xK99UwAAABFiYmIdV1dXFU9PTxBZWVkMSkpKCElJSQVvb28CNzc3AQAAAAEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALS0tAVRUVANPT08GUlJSCVRUVAxPT08RXFxcF2NjYx0AAAAPxcC0Tvny4+3+/Pf//vnx//768v/++/T//vv0//779P/++/T//vv0//779P/++vL//vry//789////vz//vju//nqx//12Zr/8Mpz/+7EY//uxGH/78Zn/+/Hav/wyG3/8Mlu//DJbv/wyG3/78ht//DJbv/vyW7/8Mlu//DJb//wyG//78lv//DIb//wyW//8Mlv//DJbf/vyW7/8Mlu/+/Ibf/vyG3/78lu//DJbv/wyGz/78dp/+7EZP/uxGD/7sZn//HQgf/34K3/+/Ha//789v///vv//vv0//768f/++/T//vv0//779P/++/T//vv0//779P/++/P//vrx//779P/++/T/8N2y0W1fPCMpKSkXaWlpHExMTBRRUVEPTU1NC09PTwdPT08EVFRUAjExMQEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABLy8vAVxcXANOTk4FVlZWCFJSUgxOTk4QWVlZFWtraxwUFBQUa2trJPHp1b39+/f//vv1//768f/++vP//vv0//779P/++/T//vv0//779P/++/T//vry//768f/++/X///77///++v/99ub/+OfA//XboP/x0IH/8Mls/+/FZP/vxGP/78Zm/+/Haf/wyGz/8Mht//DKb//wyXD/8Mpx//DLc//wynP/8Mt0//DKcf/wyXH/8Mlw/+/Jbv/wyG3/78hs/+/GaP/vxmT/78Rj/+/HZ//vy3P/89WM//fgrf/67tH//vry///+/P/+/Pj//vv0//768f/++/T//vv0//779P/++/T//vv0//779P/++/T//vrx//768v/+/Pb/+vLe+9/LnIwAAAARWVlZHGJiYhlRUVESS0tLDlNTUwpVVVUHU1NTBFJSUgIMDAwBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABOzs7AVZWVgNLS0sEVVVVB09PTwpXV1cOUFBQE2NjYxtOTk4aAAAAEc7HuVv48eDr/v34//778//++vH//vvz//779P/++/T//vv0//779P/++/T//vv0//779P/++vH//vry//789v///vz///36//768f/78tr/+Oa7//bdpP/z1pD/8dCA//DLdP/wyW7/78hr/+/Iaf/vxmj/8Mdn/+/GZf/vxmb/78dn/+/Haf/vyGn/8Mls//DKb//xzHj/8tKG//TZl//34K3/+OrI//335v/+/PX///37///9+v/++/T//vrx//778//++/T//vv0//779P/++/T//vv0//779P/++/T//vry//768v/++/X//fnv//DestGYiWczDAwME2RkZBxYWFgWUVFREVNTUw1OTk4JSUlJBkpKSgNXV1cCBQUFAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAFBQUBDw8PAVhYWAJWVlYDSEhIBlFRUQlSUlINUFBQEVtbWxdiYmIdEBAQE0hISB3n3seX+/ju+/789//++/P//vrx//778//++/T//vv0//779P/++/T//vv0//779P/++/T//vvz//768f/++vH//vv0//789////vz///37//789P/++vD//fbl//vu0f/568f/+OjB//jmvf/45Lf/9+Oz//jjtf/45bj/+Oe+//jow//568n//PHZ//347f/++vH///z3/////f///fr//vz2//778//++vH//vry//779P/++/T//vv0//779P/++/T//vv0//779P/++/T//vrx//768v/++/X//vz2//fqyvDQvIppAAAAEE1NTRpkZGQbU1NTE1FRUQ9OTk4LUVFRCEtLSwVaWloCKCgoAgEBAQEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAADg4OAWBgYAJVVVUDUFBQBlBQUAhOTk4LVFRUD1NTUxNpaWkZU1NTGwAAAA+npqQ38OfPvvz58P3+/Pf//vvz//768f/++vP//vv0//779P/++/T//vv0//779P/++/T//vv0//779P/++/P//vvz//768v/++vH//vry//779P/+/Pb//vz3//79+f///fr///77///+/f////7////+///+/f///fr///36//79+f/+/Pf//vz2//779P/++vL//vrx//768v/++/P//vv0//779P/++/T//vv0//779P/++/T//vv0//779P/++/P//vrx//778v/++/X//vz3//nv1Pfk0aKYPTs1GR0dHRRmZmYdWlpaF09PTxJSUlINT09PClFRUQdKSkoEWVlZAzk5OQIAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAT4+PgJdXV0CTExMBFNTUwdUVFQJVVVVDFVVVRBWVlYVaWlpHDQ0NBYAAAAQqKagOfDkyLv8+O38/vz3//779P/++/L//vrx//778//++/T//vv0//779P/++/T//vv0//779P/++/T//vv0//779P/++/T//vvz//778//++/L//vrx//768f/++vL//vrx//768f/++vH//vry//768f/++vH//vvy//778//++/P//vv0//779P/++/T//vv0//779P/++/T//vv0//779P/++/T//vv0//779P/++vP//vrx//779P/++/X//vz2//nu0fXl0J6aVFFHHgAAABFaWlobYmJiGFJSUhNWVlYPTk5ODFFRUQhOTk4FUlJSA1hYWAINDQ0BAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAQEBAREREQFWVlYCV1dXA0hISAVUVFQIVlZWClVVVQ1PT08RXl5eF2hoaBsvLy8WAAAAEJqZljTs4sms+vXn9v79+P/+/Pb//vv0//768f/++vH//vvz//778//++/T//vv0//779P/++/T//vv0//779P/++/T//vv0//779P/++/T//vv0//779P/++/T//vv0//779P/++/T//vv0//779P/++/T//vv0//779P/++/T//vv0//779P/++/T//vv0//779P/++/T//vvz//768//++vH//vvy//779P/+/Pf//vrx//fqzOvhzqGJPz44GwAAABFTU1MaaWlpGlJSUhRRUVEQUVFRDFRUVAlMTEwGRUVFBVlZWQNWVlYBCAgIAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA5OTkCXV1dAlJSUgNSUlIGTk5OCVBQUAtPT08OUlJSEmFhYRZsbGwbLy8vFwEBARBvb28k2tG5cvTozNT89+38/vz3//789v/++/T//vvz//768P/++vL//vvz//778//++/T//vv0//779P/++/T//vv0//779P/++/T//vv0//779P/++/T//vv0//779P/++/T//vv0//779P/++/T//vv0//779P/++/T//vvz//778//++/P//vrw//768v/++/T//vv0//789v/++/X/+u/W+O/csMHEtI9UJiYmFgMDAxJVVVUbampq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AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAD////////+AAB/////////////////wAAAA////////////////AAAAAAf/////////////+AAAAAAB/////////////4AAAAAAAD////////////4AAAAAAAAH///////////4AAAAAAAAAf//////////8AAAAAAAAAB//////////4AAAAAAAAAAP/////////8AAAAAAAAAAA/////////8AAAAAAAAAAAH////////+AAAAAAAAAAAAf///////+AAAAAAAAAAAAD////////AAAAAAAAAAAAAP///////AAAAAAAAAAAAAB///////gAAAAAAAAAAAAAP//////wAAAAAAAAAAAAAB//////wAAAAAAAAAAAAAAH/////4AAAAAAAAAAAAAAA/////+AAAAAAAAAAAAAAAH/////gAAAAAAAAAAAAAAB/////gAAAAAAAAAAAAAAAP////wAAAAAAAAAAAAAAAB////8AAAAAAAAAAAAAAAAP///+AAAAAAAAAAAAAAAAB////gAAAAAAAAAAAAAAAAf///gAAAAAAAAAAAAAAAAD///4AAAAAAAAAAAAAAAAA///8AAAAAAAAAAAAAAAAAH///AAAAAAAAAAAAAAAAAA///gAAAAAAAAAAAAAAAAAH//wAAAAAAAAAAAAAAAAAB//8AAAAAAAAAAAAAAAAAAP//AAAAAAAAAAAAAAAAAAD//gAAAAAAAAAAAAAAAAAAf/wAAAAAAAAAAAAAAAAAAH/8AAAAAAAAAAAAAAAAAAB/+AAAAAAAAAAAAAAAAAAAP/gAAAAAAAAAAAAAAAAAAB/4AAAAAAAAAAAAAAAAAAAf8AAAAAAAAAAAAAAAAAAAH/AAAAAAAAAAAAAAAAAAAB/wAAAAAAAAAAAAAAAAAAAP4AAAAAAAAAAAAAAAAAAAD+AAAAAAAAAAAAAAAAAAAAfgAAAAAAAAAAAAAAAAAAAHwAAAAAAAAAAAAAAAAAAAB8AAAAAAAAAAAAAAAAAAAAfAAAAAAAAAAAAAAAAAAAADwAAAAAAAAAAAAAAAAAAAA4AAAAAAAAAAAAAAAAAAAAOAAAAAAAAAAAAAAAAAAAADgAAAAAAAAAAAAAAAAAAAA4AAAAAAAAAAAAAAAAAAAAEAAAAAAAAAAAAAAAAAAAABgAAAAAAAAAAAAAAAAAAAAYAAAAAAAAAAAAAAAAAAAAEAAAAAAAAAAAAAAAAAAAABAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAQAAAAAAAAAAAAAAAAAAAAEAAAAAAAAAAAAAAAAAAAABAAAAAAAAAAAAAAAAAAAAAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAGAAAAAAAAAAAAAAAAAAAABAAAAAAAAAAAAAAAAAAAAAQAAAAAAAAAAAAAAAAAAAAGAAAAAAAAAAAAAAAAAAAABgAAAAAAAAAAAAAAAAAAAA4AAAAAAAAAAAAAAAAAAAAHAAAAAAAAAAAAAAAAAAAADgAAAAAAAAAAAAAAAAAAAA8AAAAAAAAAAAAAAAAAAAAPAAAAAAAAAAAAAAAAAAAAHwAAAAAAAAAAAAAAAAAAAB+AAAAAAAAAAAAAAAAAAAAfgAAAAAAAAAAAAAAAAAAAH4AAAAAAAAAAAAAAAAAAAD/AAAAAAAAAAAAAAAAAAAA/wAAAAAAAAAAAAAAAAAAAP8AAAAAAAAAAAAAAAAAAAH/gAAAAAAAAAAAAAAAAAAB/4AAAAAAAAAAAAAAAAAAA//AAAAAAAAAAAAAAAAAAAP/wAAAAAAAAAAAAAAAAAAH/+AAAAAAAAAAAAAAAAAAB//gAAAAAAAAAAAAAAAAAA//8AAAAAAAAAAAAAAAAAAP//AAAAAAAAAAAAAAAAAAH//4AAAAAAAAAAAAAAAAAB///AAAAAAAAAAAAAAAAAA///wAAAAAAAAAAAAAAAAAf//+AAAAAAAAAAAAAAAAAH///gAAAAAAAAAAAAAAAAD///8AAAAAAAAAAAAAAAAA////AAAAAAAAAAAAAAAAAf///4AAAAAAAAAAAAAAAAH////AAAAAAAAAAAAAAAAH////wAAAAAAAAAAAAAAAB/////AAAAAAAAAAAAAAAA/////wAAAAAAAAAAAAAAAf////+AAAAAAAAAAAAAAAP/////wAAAAAAAAAAAAAAD//////AAAAAAAAAAAAAAB//////4AAAAAAAAAAAAAB//////+AAAAAAAAAAAAAA///////wAAAAAAAAAAAAAf//////+AAAAAAAAAAAAAP///////4AAAAAAAAAAAAP////////AAAAAAAAAAAAH////////4AAAAAAAAAAAD/////////wAAAAAAAAAAD/////////+AAAAAAAAAAD//////////4AAAAAAAAAB///////////gAAAAAAAAB///////////+AAAAAAAAB////////////4AAAAAAAB/////////////gAAAAAAD/////////////+AAAAAAD//////////////+AAAAAH///////////////+AAAAf/////////////////wAf//////////////////////////////ygAAABAAAAAgAAAAAEAIAAAAAAAAEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAARUVFAVFRUQJOTk4DVFRUBFBQUAVHR0cGS0tLB0tLSwdKSkoGUFBQBVFRUQRKSkoCPz8/Aj09PQEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA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AU1NTQNRUVERVVVVNX9/f3D7+PP//Pjy//z48f/x3sD/1qZS/9enVf/Xp1X/16dV/9enVf/Xp1X/16dV/9enVv/Xp1b/16dW/9enVv/Xp1X/16dV/9eoVv/bsWn///79/////v/lx5L/0p1A/9KdQf/SnUH/0p1B/9KdQf/SnUH/0p1B/9KdQf/SnUH/0p1B/9KdQf/Rmz3/8N29/////f/79uz/16hW/9enVv/Xp1X/16dV/9enVf/Xp1X/16dV/9enVf/XqFX/16dV/9enVf/Xp1X/16dV/9enVf/Xp1X/+O/g//z48f/8+PH/9e3e+k5OTlVRUVErUlJSDExMTAJbW1sDT09PEldXVzaMjIx0/Pnz//z48v/8+PL//Pfw//v17P/79u3/+/fu//v37//89/D//Pjx//z48v/8+fL//Pnz//369P/9+vX//fr2//379v/9+/f//vz5/////////v3/2apa/9SfRP/Un0L/1J9C/9SfQv/Un0L/1J9C/9OfQv/Un0L/1J9C/9SfQv/Un0L/1J9D/+K+gP////7///////379//9+/b//fv2//369v/9+vX//fr0//z58//8+fL//Pjy//z48f/89/D/+/fv//v37v/79u3/+/Xs//z48f/8+PL//Pjx//jw5P5SUlJWUVFRLFRUVA1PT08CWlpaA09PTxJXV1c1lZWVdvz58//8+PL//Pjy//z48v/8+fP//fn0//369f/9+vX//fv2//379//9/Pj//vz5//78+v/+/fv//v38//7+/P////7////+/////////////v37/9ajSv/VoET/1aBE/9WgRP/VoEP/1aBD/9WgRP/VoEP/1aBE/9WgRP/VoET/1aBE/9WhRf/etGv///7+///////////////+///+/f/+/vz//v38//79+//+/Pr//vz5//38+P/9+/f//fv2//369f/9+vX//fn0//z58//8+PL//Pjy//z48v/69ev/WFhYVFJSUixSUlINU1NTAllZWQNQUFARV1dXM5aWlnL8+fP//Pny//z58v/8+fL//Pny//358//9+fP//fr0//369f/9+/b//vv3//77+P/+/Pn//vz6//79+v/+/fv///79///+/f///v7///////79/P/Xpkz/1qJF/9aiRf/WokX/1qJF/9ajRv/Xo0f/16NH/9ajRv/VokX/1qJF/9aiRf/Wokb/37Zu///+/v////////7+///+/f///vz//v37//79+v/+/Pn//vz5//77+P/++/f//fr2//369f/9+vT//fnz//358//8+fL//Pny//z58v/8+fL/+vTq/1dXV1FRUVEpUVFRDE9PTwJAQEADUlJSD1ZWVi+QkJBp/Pnz//z58v/8+fL/+vPm//Xnz//16NH/9ejR//Xo0f/26NH/9ujR//bo0v/26dL/9unS//bp0v/26dP/9unT//bp0//26dT/+O7d/////////v3/3rJl/9ekR//XpEb/16RG/9ilSf/Ypkv/2adN/9mnTf/Ypkv/16VH/9ekRv/XpEb/16RG/+fHjf////7////+//bq1v/26dP/9unT//bp0//26dP/9unS//bp0v/26dL/9ujS//bo0f/16NH/9ejR//Xo0f/16NH/9ejQ//v37f/8+fL//Pnx//jw4v1SUlJJUVFRJlVVVQs3NzcCSEhIAk9PTw1VVVUqhISEXfv58//8+fL//Pnx//Lgvv/WoD3/16JC/9eiQv/XokL/16JC/9eiQv/XokL/16JC/9ejQf/XokL/16JC/9eiQf/XokL/2KND/9qqUP/+/fr////+/+zTpf/YpEX/2aVH/9mmSf/ZqE3/2qpQ/9qrUv/bq1L/2qlQ/9moTP/Ypkj/2aVH/9ijRP/05sz///79//nw4f/XoUD/16JC/9eiQv/XokH/16JC/9eiQv/XokH/16JB/9eiQv/XokH/16JC/9eiQf/XokH/16JC/9eiQf/58OH//Pnx//z48f/17d35TExMQlFRUSJNTU0JSUlJATU1NQJSUlILUlJSJF5eXkb69u/8/fny//z58f/37dn/2aVF/9qmSP/apkj/2qZJ/9qmSP/apkj/2qZI/9qmSP/apkj/2qZI/9qmSP/apkj/2qZI/9qmSP/ZpUX/9efN/////f/9+fP/3KxU/9qnSf/aqUz/26tR/9ytVf/cr1f/3a9Y/9ytVf/bq1D/2qlL/9qnSf/iunD//////////v/t06X/2aVH/9qmSP/apkj/2qZI/9qmSP/apkj/2qZI/9qmSP/apkj/2qZI/9qmSP/apkj/2qZI/9qnSf/bq1H//Pjx//358v/8+PH/7+XS6jw8PDhRUVEdU1NTCEJCQgE+Pj4BT09PCFBQUB1FRUU48+/n5/358f/9+fL//Pbs/9uqTf/bqEr/2qhK/9qoSf/bqEn/2qhJ/9qoSf/aqEn/26hJ/9uoSv/bqEr/2qhJ/9qoSf/aqEn/26hK/+K6bv////7////+//bq0v/cqUz/3KxQ/92uVP/esFn/37Jd/96yXf/dsFn/3a1T/9yrT//er1j/+/Xq/////v/8+fL/3axT/9uoSv/bqEn/26hJ/9qoSf/bqEn/26hJ/9qoSf/aqEn/2qhJ/9qoSf/bqEn/2qhJ/9uoSf/bqEr/4bZm//379v/9+fL//fny/+XcyslEREQyUFBQF05OTgYbGxsABgYGAE1NTQZQUFAXNzc3Lurp5sX9+fH//fny//379v/iuGn/3KpM/9yqS//cqkv/3KpL/9yqS//cqkv/3KpL/9yqS//cqkv/3KpL/9yqS//cqkr/3KpK/9yqS//cqEj/8Nmu///+/v////7/9+3Z/+G2Zf/erlP/37Nd/+G2Y//gtWH/37Jb/92tUv/kvnf/+/br/////v////7/6MeK/9ypSv/cqkv/3KpL/9yqS//cqkv/3KpL/9yqS//cqkv/3KpL/9yqS//cqkv/3KpK/9yqS//cqkv/3KlK/+nKj//9+vX//fny//358v/Vy7qfTk5OLFBQUBJJSUkEAAAAAAAAAABISEgEUVFREU5OTinU0MmW/fny//358v/9+vT/7M+Y/92rS//eq0v/3atL/92rS//dq0v/3atL/92rS//dq0v/3atL/92rS//dq0v/3atL/96rS//dqkv/3qtM/92rTP/05MX///7+/////v/+/fr/9OTF/+rMkP/nxYH/58WC/+zQmv/26tH////+/////v////7/7tOi/92qSv/dq0v/3atL/92rS//eqkv/3atL/92qS//dq0v/3atL/92rS//dq0v/3atL/92rS//dq0v/3atL/92pSP/04sH//fny//358v/9+fL/taWEdFdXVyVOTk4NREREAgAAAAAAAAAAOjo6Ak9PTwtaWloipaKfWP369P/9+fP//fny//bpz//eq0r/361M/9+tTP/frUz/361M/9+tTf/frUz/361M/9+sTP/frUz/361M/9+tTf/frUz/361M/9+tTP/frU3/3qxM/+/Xp//+/fr////+///+/v////7////+/////v////7///79/////v/9+vP/6sqL/96sSv/frU3/361M/9+tTP/frE3/361M/9+sTP/frEz/361M/9+sTP/frEz/361M/9+tTf/frUz/36xM/9+tTf/fr1L/+/Xq//358//9+fL/+fLl/GZgVDpSUlIcU1NTCTg4OAEAAAAAAAAAAD09PQFOTk4HUlJSGE5OTi339O3t/fny//368//9+vP/47dh/9+vT//fr07/369O/9+uTf/frk7/365O/9+vTv/fr07/369O/9+vTv/frk3/369O/9+vTf/frk7/365O/9+uTv/grUz/5Lhk//LfuP/89uz//////////v////7////+//ry4v/w2Kj/4rJX/+CuTf/frk3/369O/9+uTv/frk7/365O/+CvTv/frk7/365N/9+vTv/frk7/369O/9+uTv/fr07/365O/+CuTv/frk7/6caC//779v/9+fP//fny/+3jz9A7OzslT09PE1NTUwUKCgoBAAAAAAAAAAAQEBAAT09PBFBQUBBBQUEh5OLdov368//9+vP//fr0/+/Wo//gr03/4K9P/+CwT//gr0//4a9P/+GvT//gr0//4a9P/+GwT//hr0//4LBP/+CvT//hr0//4a9P/+GvT//gr0//4bBP/+GwUP/gr0z/4bBP/+S5Yv/nv3H/5r5u/+O3X//grkz/4K9N/+GwUP/hr0//4K9P/+CwT//gsE//4a9P/+CvT//hsE//4LBP/+GwT//hr0//4LBP/+CwT//gsE//4K9P/+GwT//gr0//4K9M//bnyv/9+vL//frz//368//Pv5+AV1dXIE5OTg1JSUkDAAAAAAAAAAAAAAAAAAAAAEBAQAJRUVEKWlpaG6+sp039+fP//frz//368//89ur/47RX/+KyUP/isVD/4rFQ/+KxUP/isVD/4rJQ/+KxUP/isVD/4rFQ/+KxUP/isVD/4rFQ/+KxUP/isVD/4rFQ/+KyUP/isVD/4rFQ/+KxUP/islD/47JR/+KyUf/islH/4rFQ/+KxUP/isVD/4rFQ/+KxUP/isVD/4rFQ/+KxUP/isVD/4rFQ/+KxUP/isVD/4rFQ/+KxUP/islD/4rFQ/+KxUP/isVD/4rJQ/+e/bv/++/X//frz//368v/58uP6b2ZWL1JSUhdRUVEHPT09AQAAAAAAAAAAAAAAAAAAAAA2NjYBUFBQ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/+7FaP/uxmj/7sRj//HPgP/568v//vv2//778//++/P//vvz//768//58uLit6iFPVpaWhdSUlIMTExMBURERAEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAASUlJAlJSUgZSUlINV1dXF6ullzP38+rO/vvz//778//++/T//vv0//779P/++vL/+enD//PTif/vx2r/78Zo/+/Ha//wyG3/8Mht/+/Jbv/wyW7/78hu//DIb//wyW7/78lu/+/Ibf/vyG3/78dr/+/GZ//vyG7/9NeU//ru0P/+/PX//vvz//779P/++/T//vvz//768//x5sy6hXpeJldXVxVRUVEMTExMBVJSUgEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABAQEACUlJSBVBQUAtdXV0VUlJSG+nl2or9+fD6/vvz//779P/++/T//vv0//779P///Pb//fbm//npw//12pn/8s9///DLcv/wyW3/8Mht//DJbf/wyW3/8Mht//DJbv/wy3X/8tGD//Xdov/67Mr//fjs//789v/++/P//vv0//779P/++/T//vvz//v05fTd0bRzTExMGFdXVxJNTU0KU1NTBC0tLQEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABQUFADMzMwFRUVEEUVFRCVRUVBFQUFAXsaubOPPv5Lz++/P//vvz//779P/++/T//vv0//778//++/P//vz2//779f/++vD//PXi//zy3f/78dn//PHa//zy3f/89eX//vry///89v/+/PX//vvz//779P/++/T//vv0//778//++/P//fjt/e7lzKiViWorV1dXGFJSUg5PT08ITk5OAxsbGwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA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/9SiUf/UolH/1KJR/9SjUf/Zrmb//Pn0//z48v/k3dLdSUlJR1BQUBRKSkoBT09PBFFRUR9jY2Nc+vbx/vz48v/269n/1KNP/9WlUf/VpFL/1aRR/9WlUf/VpVH/1aVR/9WkUv/VpVL/1aVR/9WlUv/w3sD///79/+G/g//Rm0D/0ZtA/9GbQP/Rm0D/0ZtA/9GbQP/Rm0D/0Zs//+nOof////7/6dCl/9WlUf/VpVH/1aRS/9WkUf/VpVH/1aVS/9WlUf/VpVH/1aVR/9WkUv/WplX/+/bs//z48f/z6931SEhIS1BQUBlQUFACUVFRBVNTUyJ+fn5m/Pnz//z48v/37d3/6M2e/+nOoP/pzqH/6c+h/+nPov/pz6P/6dCj/+nQpP/q0KT/6tCl/+rSqP/89/D/+vTp/9WkTf/TnkL/055B/9OeQf/TnkH/055B/9OeQf/TnkH/055C/9mrXf/9+/f/+fLl/+rRpf/q0KX/6tCk/+nQo//p0KP/6c+i/+nPov/pz6H/6c6h/+nOoP/pzZ//+vTq//z48v/48eX9UVFRTlJSUhpRUVEDUlJSBVNTUyKKiopp/Pnz//z48v/8+PL//Pn0//369f/9+vb//fv3//38+P/+/Pr//v37//79/P/+/v3////+////////////9ejT/9WgRf/VoEP/1aBD/9WgQ//VoEP/1aBD/9WgQ//VoEP/1aBD/9akS//68+f//////////////v7//v79//79/P/+/fv//vz5//38+P/9+/f//fr2//369f/8+fP//Pjy//z48v/69ev/VlZWTVJSUhtQUFADVFRUBFNTUyCMjIxk/Pnz//z58v/8+fP//fr1//369v/9+/f//fv4//78+f/+/Pn//v36//79+//+/vz///79///+/v//////9urV/9ajR//WokX/1qJF/9ajRv/XpEj/16RI/9ajRv/WokX/1qJF/9imTv/69Oj////////+/v///v3//v38//79+//+/fr//vz5//78+P/9+/j//fv3//369v/9+vX//Pny//z58v/69er/VVVVSFFRURlTU1MDSEhIBFNTUxyDg4NY/Pnz//z58v/269X/4715/+O+e//jvnv/4758/+O+fP/jvnz/4798/+O/ff/jv33/4799/+XBgf/69Oj/+/fu/9urVf/YpUb/2KVI/9mnTP/aqU//2alP/9mnTP/YpUf/2KVH/9+0Z//+/fr/9+vW/+S/fv/jv33/4799/+S/ff/jvnz/4758/+O+fP/jvnz/4757/+O+e//jvnv/+vPn//z58v/48eT8UFBQP1FRURZISEgCSkpKA1FRURdkZGRD+/fw/fz58v/47tz/2aVG/9mmSf/Zpkn/2qZI/9qmSP/Zpkn/2aZI/9mmSP/Zpkj/2qZJ/9mnSP/v2rP////+/+rMl//Zpkf/2qlM/9urUv/crlb/3K1W/9urUv/aqUz/2aZI//DatP////7/6cuV/9mmSf/apkn/2qZI/9qmSP/apkj/2qZI/9qmSP/Zpkn/2aZI/9qnSP/aqU7//Pfv//z58v/069vyQkJCNVFRURFOTk4CRkZGAU9PTxFEREQx9fHq6P358v/8+O//3KtQ/9uoSv/bqEr/26hJ/9uoSf/bqEn/26hK/9uoSv/bqEn/26hJ/9qoSv/fsl7//vv2//369f/lwXz/3KxP/92wV//fsl3/3rJd/92vVv/cq0//6cuS//79+v/79Oj/3KpP/9uoSf/bqEn/26hJ/9uoSv/bqEn/26hJ/9uoSf/bqEn/26hJ/9uoSv/gtWT//fr1//358v/q49XQR0dHK09PTww8PDwBNzc3AU9PTwtEREQn6ufiwv358v/9+vX/5L1y/92qS//dqkv/3apL/9yqS//cqkv/3apL/9yqS//cqkv/3KpL/92qS//cqkv/6sqP//78+P/9+/f/7tep/+O8cf/iuGf/4rhn/+W+dv/x3bj//v36//358v/lwHn/3apL/9yqS//cqkv/3apL/9yqS//dqkv/3KpL/92qS//dqkv/3apL/9yqS//qy5D//fnz//358v/c08GoU1NTJE9PTwg0NDQAHR0dAE5OTgdXV1cf1dLNi/358//9+fL/7tWk/96sTP/frEz/3qxM/9+sTP/erEz/3qxM/96sTP/erEz/3qxM/96sTP/erEz/3q1N/+rKjP/9+fL///7+//78+P/79er/+/br//79+/////7/+/Xp/+fBef/erEz/3qxM/96sTP/erEz/3qxM/96sTP/erEz/3qxM/96sTP/erEz/36xM/96sTf/z4b///fny//z48P7Bt6VyU1NTGU1NTQUXFxcAAAAAAEtLSwNRUVETqqejT/v48ff9+vP/+e/b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/+3Faf/txWn/7cVo/+3EZ//uxGb/7cRl/+3DZP/ux23/9uKz//768P/++/P//vvz//v26u7TyK1aVVVVE01NTQc8PDwBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAHBwcAE9PTwJSUlIIVVVVFNbSx1n79+/j/vvz//778//++/P/+/Lc//Tanv/wynL/7sZp/+/Gav/vx2v/78ds/+/Ibf/vyG3/78dt/+/Ibf/vx2z/78dr/+/Gav/vxmn/8Mt2//XeqP/89eP//vvz//778//++/P/+PHi2srAp0pVVVUTT09PB0dHRwIODg4AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABISEgBEREQCUlJSCFZWVhKsqaAy9fDnu/768/7++/T//vv0//779P/99+j/+ejC//Xanf/yz37/8Mpw//DJbf/wyG3/8Mht//DJbf/wynH/8tCB//Xdov/568j//fjs//779P/++/T//vv0//358P3w6NSsnJJ7KlNTUxBQUFAGPj4+ATExMQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAFBQUAQUFBAU9PTwVUVFQNUFBQFtrWymD49OnR/vvz//778//++/T//vvz//779P/++/X//vnu//z15P/88+D//PTg//z15f/++vD//vz1//779P/++/P//vv0//778//++vD+9u/fx8/EqVJSUlIVUVFRC05OTgQxMTEBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC8vLwFOTk4DVFRUCFRUVBCDf3ce2tbKYvXw5L38+PDx/vvz//778//++/T//vv0//779P/++/T//vv0//779P/++/T//vv0//778//++vL//Pfs7vPs27XUy7RYdnBiG1RUVA9RUVEHT09PAjAwMAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA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0fz48v/dt3r/0Z9O/9GfTv/Rn07/0Z9O/9GfTv/Rn07/0Z9O/9y2eP/8+PL/9u3d/+jOpf/p0Kf/+PHk//r06v/Zr2z/0Z9O/9GfTv/Rn07/0Z9O/9GfTv/Rn07/0Z9O/+HBjf/8+PH/0czDw1JSUitMTEwCTU1NBkpKSkHz7+rx+/fw/9WlVv/TolD/06JQ/9OiUP/TolD/06JQ/9OiUP/XqV7//Pjy/+nQp//PmT//z5k//8+ZP//QmkH/7tq6//ny5//UpVX/06JQ/9OiUP/UolD/06JQ/9OiUP/TolD/2a1k//z58//q5dzkTExMOE9PTwRPT08JZmZmTvv38v737t7/1qVS/9amVP/WplP/1qZT/9amVP/WplT/1qZU/+nQpP/37t3/0pxB/9GcQP/RnED/0ZxA/9GcQP/TnkX/+/bs/+XHk//WplT/1qZU/9amU//WplT/1qZT/9amU//WplX/+/Xs//fw5fpMTEw/UVFRBlBQUAp+fn5V/Pnz//z48v/89/D//Pjy//z59P/9+vX//fv3//78+f/+/fr///79/+vSp//UoEP/1J9D/9SfQ//Un0P/1J9D/9SgQ//v27n///79//79+v/+/Pn//fv3//369f/8+fP//Pjy//z38P/8+PL/+/Xs/1RUVEBTU1MHUFBQCYCAgE/8+fL/+/fv//nw4f/58eL/+fHj//ry5P/68ub/+vPn//r06P/9+/b/7NWq/9ajRv/Wo0b/16VJ/9elSf/Wo0b/1qNG//Hevf/9+vT/+vPo//rz5//68uX/+vLk//nx4//58eL/+fDh//z48f/79ez/U1NTOlFRUQZOTk4HaWlpPPv48f74797/2KND/9ikRf/YpEX/2KRF/9ikRf/YpEX/2aRF/+nMl//68uX/2qdK/9qpTf/brFT/26xU/9qoTP/bqlH//Pnx/+XCg//YpEX/2KRE/9ikRf/ZpEX/2KRF/9ikRf/ZpUf/+/bt//fx5PhJSUkuT09PBU1NTQRFRUUm9vPs6v358f/drVP/26lK/9upSv/bqUr/26lK/9upSv/bqUr/3a1T//v16v/y4L3/3q9X/9+zXf/fslz/3rFa//Xmy//5797/3KpM/9upSv/bqUr/26lK/9upSv/bqUr/26lK/+C0Yv/9+vT/8Ore2ktLSyFJSUkDQEBAAlJSUhrq5+G7/fnz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"
$ArchetypeThemeIcon = [System.IO.MemoryStream][System.Convert]::FromBase64String("$ThemeIconBase64")

# Grabs current working directory/location
$PWD_Reset = $PWD

# Resets working directory to the PokeMMO main root directory
Set-Location ..\..; Set-Location ..\..

# Adds in changed PokeMMO path into variable
$PWD_PokeMMOPath = $PWD

# Steathly inserts changes for OCR in the PokeMMO default theme + Egg Text Delay + pokeball encounter issue
$GetDefaultBattleXML = Get-Content "$PWD\data\themes\default\ui\battle.xml"; $GetDefaultFontsXML = Get-Content "$PWD\data\themes\default\fonts.xml"
$GetCounterStrings = Get-ChildItem -Path "$PWD\data\strings" -Recurse -Filter "*zzz_*"
if ($GetDefaultFontsXML[22] -match "battle-name" -and $GetDefaultBattleXML[65] -match "battle-name" -and ($GetCounterStrings).Count -match "21") { } else { 

    # Checks if PokeMMO is running - Will close down to allow the insert of .xml files to happen
    $PokeMMOProcess = Get-Process | where {$_.mainWindowTItle } | where {$_.Name -like "javaw" }
    if ($PokeMMOProcess -eq $null) { $PokeMMOIsActive = $false } else { $PokeMMOIsActive = $true ; Stop-Process -Name "PokeMMO" -Force; Stop-Process -Name "javaw" -Force }

    # Specific line changes to insert back into the original .xml files
    $GetDefaultBattleXML[65] = '		<param name="font"><font>battle-name</font></param>'; $GetDefaultBattleXML[66] = '		<param name="border"><border>0,0,7,0</border></param>'; $GetDefaultBattleXML | Set-Content -Path "$PWD\data\themes\default\ui\battle.xml"; $GetDefaultFontsXML[22] = '	<fontDef name="battle-name" filename="res/fonts/NotoSansCJK-Medium.ttc" color="#FFFFFF" border_width="1.1" border_color="#A6000000" shadow_offset_x="1" shadow_offset_y="1" shadow_color="#A6000000" size="19" hinting="Full" offsetY="-3"/>'; $GetDefaultFontsXML | Set-Content -Path "$PWD\data\themes\default\fonts.xml" 

    # Copies counter string files into PokeMMO strings folder for Egg Delay & encounter "appeared" when using pokeball
    Copy-Item "$PWD_Reset\Counter Sring Files\*" -Destination "$PWD\data\strings\" -Recurse -Force

    # Removes "Eng" Unova Egg/Encounter Delay if language is NOT English (To avoid string confliction)
    #if ($SetLanguage -notmatch "English") { Remove-Item "$PWD\data\strings\a_placeholder_for_enabling_unova_edits.xml" }

    # Resetting counter language back to "English" when files are missing
    $SetConfig = "$PWD_Reset\Counter Config Files\CounterConfig_$GetProfile.txt"
    $GetConfig = Get-Content $SetConfig
    $GetConfig[23] = 'Set_Language=English'
    $GetConfig | Set-Content -Path $SetConfig

    # Waits & Restarts PokeMMO
    if ($PokeMMOIsActive -eq $true) { Start-Sleep -Milliseconds 500; Start-Process "$PWD\PokeMMO.exe" }

    # Displays Dialog box - Indicating change in default theme font and battle xml + String delays
    [System.Windows.MessageBox]::Show("Values in the Default PokeMMO interface will be modified so it can support OCR detection.`n`nThese are slight adjustments to the font used for monster names in battle. The amount they are changed is almost unnoticeable to the eye. You may revert these modifications at any time by repairing your client.`n`nIn order to accurately track receiving Eggs, the Counter will add several XML files to the strings directory that will automatically load (PokeMMO\data\strings).`n`nTechnical mumbo-jumbo: OCR detection will not trigger without a readable font def and inset because letters such as; g, j, p, y, etc. hang over the HP bars.`n`nConversation where user receives an Egg from the Daycare man is now unskippable to ensure enough time to log count. Failed catch dialog also has been modified in several languages to ensure false-positive count results do not occur.","  Archetype Counter","OK","Warning")

    # Displays Dialog box - Indicating counter language has been reset 
    [System.Windows.MessageBox]::Show("Counter language has been reset to 'English'.`n`nPlease change the counter language to your specific language.","  Archetype Counter","OK","Information")

}

# Leverages reset directory for the Noto font on the counter
$NonInstalledFont = New-Object System.Drawing.Font("$PWD\themes\default\res\fonts\NotoSansCJK-Medium.ttc", 7.5)
 
# Checks if PokeMMO is already open (If not - Launch with counter if set to "True" by user)
$PokeMMOProcess = Get-Process | where {$_.mainWindowTItle } | where {$_.Name -like "javaw" }
if ("$PokeMMOLaunch" -match "True") { if ($PokeMMOProcess -ne $null) { } else { Stop-Process -Name "PokeMMO" -Force; Stop-Process -Name "javaw" -Force; Start-Process "$PWD\PokeMMO.exe" } }

# Sets back the working directory/location to main mods folder for counter
Set-Location -Path $PWD_Reset

# Enabled 3D Visual Styles for Counter Winform
[System.Windows.Forms.Application]::EnableVisualStyles()

# Creates the Main Counter GUI Form
$ArchetypeForm = New-Object system.Windows.Forms.Form
$ArchetypeForm.Text = "Archetype Counter"
$ArchetypeFormIcon = New-Object System.Drawing.Icon ("$PWD\GUI Form Images\Icons\Icon\Archetype.ico")
$ArchetypeForm.Icon = $ArchetypeFormIcon
if ($ArchetypeX -match "-123" -and $ArchetypeY -match "-123") { $ArchetypeForm.StartPosition = "CenterScreen" } else { $ArchetypeForm.StartPosition = "Manual" }
$ArchetypeForm.Location = "$ArchetypeX, $ArchetypeY"
if ($DetectionCount -match "3") { $ArchetypeForm.ClientSize = "94, 400" } elseif ($DetectionCount -match "2") { $ArchetypeForm.ClientSize = "94, 343" } elseif ($DetectionCount -match "1") { $ArchetypeForm.ClientSize = "94, 286" }
$ArchetypeForm.AllowTransparency = $true
$ArchetypeForm.TransparencyKey = $ArchetypeForm.BackColor
$ArchetypeForm.FormBorderStyle = "None"
if ($AlwaysOnTop -match "True") { $ArchetypeForm.Topmost = $true }
$ArchetypeForm.Add_Load({   

    # Application Variable - Name
    $ApplicationName = "javaw"

    # Finds application process
    $Process = Get-Process | where {$_.mainWindowTItle } | where {$_.Name -like "$ApplicationName"}

    # Puts $Process.MainWindowHandle into a variable
    $hwnd = $Process.MainWindowHandle
 
    # Performs force active window process
    [void][ForceActiveWin]::SetForegroundWindow($hwnd)

    # Checks if Auto Restart Counter is set to "True"
    if ($AutoRestartCounter -match "True") { PlayAction } else { $GetConfig[34] = 'Counter_Active=False' }

    # Sets the flag for the counter to not Auto Start on "Stop"
    $GetConfig[33] = "Auto_Restart_Counter=False" 

    # Sets all changes back into the Config file
    $GetConfig | Set-Content -Path $SetConfig

    # Sets up Winform from C# (So it can have its own Taskbar Icon)
    [PSAppID]::SetAppIdForWindow($ArchetypeForm.Handle, "Archetype Counter")

})
$ArchetypeForm.Add_Closing({

    # Grabs the config file in its "current" state
    $SetConfig = "$PWD\Counter Config Files\CounterConfig_$GetProfile.txt"
    $GetConfig = Get-Content $SetConfig

    # Gets the current X and Y coordinates of the form
    $ArchetypeReplaceX = $ArchetypeForm.Bounds.Left
    $ArchetypeReplaceY = $ArchetypeForm.Bounds.Top

    # Replaces and Sets the starting position on the counter form start
    $GetConfig[18] = "Archetype_X=$ArchetypeReplaceX"
    $GetConfig[19] = "Archetype_Y=$ArchetypeReplaceY"

    # Sets all changes back into the Config file
    $GetConfig | Set-Content -Path $SetConfig

    # This exits the application (Winform) properly
    [System.Windows.Forms.Application]::Exit(); Stop-Process $PID -Force
    
})

# Creates the top main image that indicates the counter is "ON"
$ArchetypeMainOnFile = [System.Drawing.Image]::Fromfile("$PWD\GUI Form Images\$ThemeType\Main_On.png")
$ArchetypeMainOnImage = New-Object system.windows.Forms.PictureBox
$ArchetypeMainOnImage.Visible = $false
$ArchetypeMainOnImage.Image = $ArchetypeMainOnFile
$ArchetypeMainOnImage.Width = 88
$ArchetypeMainOnImage.Height = 35
$ArchetypeMainOnImage.location = New-object system.drawing.point(3,32)
$ArchetypeForm.controls.Add($ArchetypeMainOnImage)

# Creates the top main image that indicates the counter is "OFF"
$ArchetypeMainOffFile = [System.Drawing.Image]::Fromfile("$PWD\GUI Form Images\$ThemeType\Main_Off.png")
$ArchetypeMainOffImage = New-Object system.windows.Forms.PictureBox
$ArchetypeMainOffImage.Image = $ArchetypeMainOffFile
$ArchetypeMainOffImage.Width = 88
$ArchetypeMainOffImage.Height = 35
$ArchetypeMainOffImage.location = New-object system.drawing.point(3,32)
$ArchetypeForm.controls.Add($ArchetypeMainOffImage)

# Creates the middle egg image that indicates the egg count versus pokemon seen
$ArchetypeEggOnFile = [System.Drawing.Image]::Fromfile("$PWD\GUI Form Images\$ThemeType\Main_Egg.png")
$ArchetypeMainEggImage = New-Object system.windows.Forms.PictureBox
$ArchetypeMainEggImage.Visible = $true
$ArchetypeMainEggImage.Image = $ArchetypeEggOnFile
$ArchetypeMainEggImage.Width = 88
$ArchetypeMainEggImage.Height = 35
if ($DetectionCount -match "3") { $ArchetypeMainEggImage.location = New-object system.drawing.point(3,245) } elseif ($DetectionCount -match "2") { $ArchetypeMainEggImage.location = New-object system.drawing.point(3,189) } elseif ($DetectionCount -match "1") { $ArchetypeMainEggImage.location = New-object system.drawing.point(3,130) }
$ArchetypeMainEggImage.Add_Click({

    # Checks Left Mouse Click & if Poke Counter Slot is blank - If so, gives ability to manually increase count
    if ($_.Button -eq [System.Windows.Forms.MouseButtons]::Left) {

        # Grabs the config file in its "current" state
        $SetConfig = "$PWD\Counter Config Files\CounterConfig_$GetProfile.txt"
        $GetConfig = Get-Content $SetConfig

        # Gets the current X and Y coordinates of the form
        $ArchetypeReplaceX = $ArchetypeForm.Bounds.Left
        $ArchetypeReplaceY = $ArchetypeForm.Bounds.Top

        # Replaces and Sets the starting position on the counter form start
        $GetConfig[18] = "Archetype_X=$ArchetypeReplaceX"
        $GetConfig[19] = "Archetype_Y=$ArchetypeReplaceY"

        # Grabs Pokemon egg slot and increases the count
        $EggCount = $GetConfig[20] -replace 'Egg_Count=',''
        $EggCount = [int]$EggCount + 1

        # Changes the Pokemon egg count
        $GetConfig[20] = "Egg_Count=$EggCount"

        # Gets the current X and Y coordinates of the form
        $ArchetypeReplaceX = $ArchetypeForm.Bounds.Left
        $ArchetypeReplaceY = $ArchetypeForm.Bounds.Top

        # Replaces and Sets the starting position on the counter form start
        $GetConfig[18] = "Archetype_X=$ArchetypeReplaceX"
        $GetConfig[19] = "Archetype_Y=$ArchetypeReplaceY"

        # Sets all changes back into the Config file
        $GetConfig | Set-Content -Path $SetConfig

        # Refreshes Form and Poke count label
        $ArchetypeEggLabelCount.update()
        $ArchetypeEggLabelCount.refresh()
        $ArchetypeForm.update()
        $ArchetypeForm.refresh()
        $ArchetypeEggLabelCount.Text = $EggCount

    }

    # Checks Left Mouse Click & if Poke Counter Slot is blank - If so, gives ability to manually decrease count
    if ($_.Button -eq [System.Windows.Forms.MouseButtons]::Right) {

        # Grabs the config file in its "current" state
        $SetConfig = "$PWD\Counter Config Files\CounterConfig_$GetProfile.txt"
        $GetConfig = Get-Content $SetConfig

        # Gets the current X and Y coordinates of the form
        $ArchetypeReplaceX = $ArchetypeForm.Bounds.Left
        $ArchetypeReplaceY = $ArchetypeForm.Bounds.Top

        # Replaces and Sets the starting position on the counter form start
        $GetConfig[18] = "Archetype_X=$ArchetypeReplaceX"
        $GetConfig[19] = "Archetype_Y=$ArchetypeReplaceY"

        # Grabs Pokemon egg slot and increases the count
        $EggCount = $GetConfig[20] -replace 'Egg_Count=',''
        if ($EggCount -eq "0") { $EggCount = 0 } else { $EggCount = [int]$EggCount - 1 }

        # Changes the Pokemon egg count
        $GetConfig[20] = "Egg_Count=$EggCount"

        # Sets all changes back into the Config file
        $GetConfig | Set-Content -Path $SetConfig

        # Refreshes Form and Poke count label
        $ArchetypeEggLabelCount.update()
        $ArchetypeEggLabelCount.refresh()
        $ArchetypeForm.update()
        $ArchetypeForm.refresh()
        $ArchetypeEggLabelCount.Text = $EggCount

    }

})
$ArchetypeForm.controls.Add($ArchetypeMainEggImage)

# Creates the label count for the egg slot
$ArchetypeEggLabelCount = New-Object System.Windows.Forms.label
$ArchetypeEggLabelCount.Visible = $true
if ($DetectionCount -match "3") { $ArchetypeEggLabelCount.Location = New-object system.drawing.point(25,289) } elseif ($DetectionCount -match "2") { $ArchetypeEggLabelCount.Location = New-object system.drawing.point(25,233) } elseif ($DetectionCount -match "1") { $ArchetypeEggLabelCount.Location = New-object system.drawing.point(25,175) }
if ($CounterMode -match "Collapsed_Egg") { $ArchetypeEggLabelCount.Location = New-object system.drawing.point(51,12) }
$ArchetypeEggLabelCount.BackColor = [System.Drawing.ColorTranslator]::FromHtml($EggCountBGColor)
$ArchetypeEggLabelCount.Width = 45
$ArchetypeEggLabelCount.Height = 13
$ArchetypeEggLabelCount.TextAlign = "MiddleCenter"
$ArchetypeEggLabelCount.ForeColor = "White"
$ArchetypeEggLabelCount.Text = $EggCount
$ArchetypeEggLabelCount.Font = $NonInstalledFont
$ArchetypeEggLabelCount.Add_Click({

    # Checks Left Mouse Click & if Poke Counter Slot is blank - If so, gives ability to manually increase count
    if ($_.Button -eq [System.Windows.Forms.MouseButtons]::Left) {

        # Grabs the config file in its "current" state
        $SetConfig = "$PWD\Counter Config Files\CounterConfig_$GetProfile.txt"
        $GetConfig = Get-Content $SetConfig

        # Gets the current X and Y coordinates of the form
        $ArchetypeReplaceX = $ArchetypeForm.Bounds.Left
        $ArchetypeReplaceY = $ArchetypeForm.Bounds.Top

        # Replaces and Sets the starting position on the counter form start
        $GetConfig[18] = "Archetype_X=$ArchetypeReplaceX"
        $GetConfig[19] = "Archetype_Y=$ArchetypeReplaceY"

        # Grabs Pokemon egg slot and increases the count
        $EggCount = $GetConfig[20] -replace 'Egg_Count=',''
        $EggCount = [int]$EggCount + 1

        # Changes the Pokemon egg count
        $GetConfig[20] = "Egg_Count=$EggCount"

        # Sets all changes back into the Config file
        $GetConfig | Set-Content -Path $SetConfig

        # Refreshes Form and Poke count label
        $ArchetypeEggLabelCount.update()
        $ArchetypeEggLabelCount.refresh()
        $ArchetypeForm.update()
        $ArchetypeForm.refresh()
        $ArchetypeEggLabelCount.Text = $EggCount

    }

    # Checks Left Mouse Click & if Poke Counter Slot is blank - If so, gives ability to manually decrease count
    if ($_.Button -eq [System.Windows.Forms.MouseButtons]::Right) {

        # Grabs the config file in its "current" state
        $SetConfig = "$PWD\Counter Config Files\CounterConfig_$GetProfile.txt"
        $GetConfig = Get-Content $SetConfig

        # Gets the current X and Y coordinates of the form
        $ArchetypeReplaceX = $ArchetypeForm.Bounds.Left
        $ArchetypeReplaceY = $ArchetypeForm.Bounds.Top

        # Replaces and Sets the starting position on the counter form start
        $GetConfig[18] = "Archetype_X=$ArchetypeReplaceX"
        $GetConfig[19] = "Archetype_Y=$ArchetypeReplaceY"

        # Grabs Pokemon egg slot and increases the count
        $EggCount = $GetConfig[20] -replace 'Egg_Count=',''
        if ($EggCount -eq "0") { $EggCount = 0 } else { $EggCount = [int]$EggCount - 1 }

        # Changes the Pokemon egg count
        $GetConfig[20] = "Egg_Count=$EggCount"

        # Sets all changes back into the Config file
        $GetConfig | Set-Content -Path $SetConfig

        # Refreshes Form and Poke count label
        $ArchetypeEggLabelCount.update()
        $ArchetypeEggLabelCount.refresh()
        $ArchetypeForm.update()
        $ArchetypeForm.refresh()
        $ArchetypeEggLabelCount.Text = $EggCount

    }

})
$ArchetypeForm.Controls.Add($ArchetypeEggLabelCount)

# Creates the label for the collapsed count slot
$ArchetypeCollapsedCount = New-Object System.Windows.Forms.label
if ($DetectionCount -match "3") { $ArchetypeCollapsedCount.Location = New-object system.drawing.point(25,347) } elseif ($DetectionCount -match "2") { $ArchetypeCollapsedCount.Location = New-object system.drawing.point(25,290) } elseif ($DetectionCount -match "1") { $ArchetypeCollapsedCount.Location = New-object system.drawing.point(25,233) }
if ($CounterMode -match "Collapsed_Encounter") { $ArchetypeCollapsedCount.Location = New-object system.drawing.point(51,12) }
$ArchetypeCollapsedCount.BackColor = [System.Drawing.ColorTranslator]::FromHtml($CollapsedCountBGColor)
$ArchetypeCollapsedCount.Width = 45
$ArchetypeCollapsedCount.Height = 13
$ArchetypeCollapsedCount.TextAlign = "MiddleCenter"
$ArchetypeCollapsedCount.ForeColor = "White"
$ArchetypeCollapsedCount.Text = $TotalPokeSeenCount
$ArchetypeCollapsedCount.Font = $NonInstalledFont
$ArchetypeCollapsedCount.Add_Click({

    # Checks Left Mouse Click & if Poke Counter Slot is blank - If so, gives ability to manually increase count
    if ($_.Button -eq [System.Windows.Forms.MouseButtons]::Left) {

        # Grabs the config file in its "current" state
        $SetConfig = "$PWD\Counter Config Files\CounterConfig_$GetProfile.txt"
        $GetConfig = Get-Content $SetConfig

        # Gets the current X and Y coordinates of the form
        $ArchetypeReplaceX = $ArchetypeForm.Bounds.Left
        $ArchetypeReplaceY = $ArchetypeForm.Bounds.Top

        # Replaces and Sets the starting position on the counter form start
        $GetConfig[18] = "Archetype_X=$ArchetypeReplaceX"
        $GetConfig[19] = "Archetype_Y=$ArchetypeReplaceY"

        # Grabs Pokemon and increases the "seen" count
        $TotalPokeSeenCount = $GetConfig[38] -replace 'Pokemon_Seen_Count=',''
        $TotalPokeSeenCount = [int]$TotalPokeSeenCount + 1

        # Changes the Pokemon count for "seen"
        $GetConfig[38] = "Pokemon_Seen_Count=$TotalPokeSeenCount"

        # Sets all changes back into the Config file
        $GetConfig | Set-Content -Path $SetConfig

        # Refreshes Form and Poke count label
        $ArchetypeCollapsedCount.update()
        $ArchetypeCollapsedCount.refresh()
        $ArchetypeForm.update()
        $ArchetypeForm.refresh()
        $ArchetypeCollapsedCount.Text = $TotalPokeSeenCount

    }

    # Checks Left Mouse Click & if Poke Counter Slot is blank - If so, gives ability to manually decrease count
    if ($_.Button -eq [System.Windows.Forms.MouseButtons]::Right) {

        # Grabs the config file in its "current" state
        $SetConfig = "$PWD\Counter Config Files\CounterConfig_$GetProfile.txt"
        $GetConfig = Get-Content $SetConfig

        # Gets the current X and Y coordinates of the form
        $ArchetypeReplaceX = $ArchetypeForm.Bounds.Left
        $ArchetypeReplaceY = $ArchetypeForm.Bounds.Top

        # Replaces and Sets the starting position on the counter form start
        $GetConfig[18] = "Archetype_X=$ArchetypeReplaceX"
        $GetConfig[19] = "Archetype_Y=$ArchetypeReplaceY"

        # Grabs Pokemon and decreases the "seen" count
        $TotalPokeSeenCount = $GetConfig[38] -replace 'Pokemon_Seen_Count=', ''
        if ($TotalPokeSeenCount -eq "0") { $TotalPokeSeenCount = 0 } else { $TotalPokeSeenCount = [int]$TotalPokeSeenCount - 1 }

        # Changes the Pokemon count for "seen"
        $GetConfig[38] = "Pokemon_Seen_Count=$TotalPokeSeenCount"

        # Sets all changes back into the Config file
        $GetConfig | Set-Content -Path $SetConfig

        # Refreshes Form and Poke count label
        $ArchetypeCollapsedCount.update()
        $ArchetypeCollapsedCount.refresh()
        $ArchetypeForm.update()
        $ArchetypeForm.refresh()
        $ArchetypeCollapsedCount.Text = $TotalPokeSeenCount

    }

})
$ArchetypeForm.Controls.Add($ArchetypeCollapsedCount)

# Creates the Pokemon image for Slot 1 on the form
$ArchetypePokeAFile = [System.Drawing.Image]::Fromfile("$PWD\Pokemon Icon Sprites\$SpriteType\$PokemonA.png")
$ArchetypePokeAImage = New-Object system.windows.Forms.PictureBox
$ArchetypePokeAImage.Image = $ArchetypePokeAFile
$ArchetypePokeAImage.Width = 36
$ArchetypePokeAImage.Height = 32
$ArchetypePokeAImage.BackColor = [System.Drawing.ColorTranslator]::FromHtml($PokeSlot1BGColor)
$ArchetypePokeAImage.location = New-object system.drawing.point(30,75)
$ArchetypePokeAImage.Add_Click({

    # Checks Right Mouse Click & if Poke Counter Slot is blank - To manually add Pokemon in slot
    if (($_.Button -eq [System.Windows.Forms.MouseButtons]::Right) -and ($PokemonA -match "Blank")) {

        # Allows manual pre-load of the Pokemon in counter slot (Without having to find pokemon in the wild)
        $PokemonDexInput = [Microsoft.VisualBasic.Interaction]::InputBox("Enter Pokemon Dex Number for Slot:`n(Dex Number Example: 33)", ' Archetype Counter')
        $SetPokeConfig = "$PWD\Counter Config Files\PokemonNamesWithID_$SetLanguage.txt" 
        $GetPokeConfig = Get-Content $SetPokeConfig
        $PokemonDexInput = $PokemonDexInput.trimstart('0')
        $GetPokemonWithIDFromFile = $GetPokeConfig | Where-Object { $_ -match "$PokemonDexInput" } | Select -First 1
        $GetPokemonID = $GetPokemonWithIDFromFile -Replace '[^0-9]','' -Replace ' ', ''
        $GetPokemonName = $GetPokemonWithIDFromFile -Replace '[0-9]','' -Replace ' ', ''
        if ($PokemonDexInput) { if ($GetPokemonID | Where-Object { $_ -match "\b$PokemonDexInput\b" }) { $SetConfig = "$PWD\Counter Config Files\CounterConfig_$GetProfile.txt"; $GetConfig = Get-Content $SetConfig; $GetConfig[8] = "Pokemon_A=$GetPokemonID"; $GetConfig[10] = "Pokemon_A_Hover=$GetPokemonName #$GetPokemonID"; $GetConfig | Set-Content -Path $SetConfig; Start-Process "$PWD\ArchetypeCounter.bat" -NoNewWindow } else { [System.Windows.MessageBox]::Show("No match found for the Pokemon Dex Number. Please ensure you input a correct number value for the specific Pokemon.","Archetype Counter","OK","Asterisk") } }
    
    }

    # Checks Left Mouse Click & if Poke Counter Slot is blank - If so, gives ability to manually increase count
    if (($_.Button -eq [System.Windows.Forms.MouseButtons]::Left) -and ($PokemonA -notmatch "Blank")) {

        # Grabs the config file in its "current" state
        $SetConfig = "$PWD\Counter Config Files\CounterConfig_$GetProfile.txt"
        $GetConfig = Get-Content $SetConfig

        # Gets the current X and Y coordinates of the form
        $ArchetypeReplaceX = $ArchetypeForm.Bounds.Left
        $ArchetypeReplaceY = $ArchetypeForm.Bounds.Top

        # Replaces and Sets the starting position on the counter form start
        $GetConfig[18] = "Archetype_X=$ArchetypeReplaceX"
        $GetConfig[19] = "Archetype_Y=$ArchetypeReplaceY"

        # Changes the total Pokemon seen count
        $TotalPokeSeenCount = $GetConfig[38] -replace 'Pokemon_Seen_Count=',''
        $TotalPokeSeenCount = [int]$TotalPokeSeenCount + 1
        $GetConfig[38] = "Pokemon_Seen_Count=$TotalPokeSeenCount"

        # Grabs Pokemon from slot 1 and increases the "seen" count
        $PokemonCountA = $GetConfig[9] -replace 'Pokemon_A_Count=', ''
        $PokemonCountA = [int]$PokemonCountA + 1

        # Changes the Pokemon count for "seen"
        $GetConfig[9] = "Pokemon_A_Count=$PokemonCountA"

        # Sets all changes back into the Config file
        $GetConfig | Set-Content -Path $SetConfig

        # Refreshes Form and Poke count label
        $ArchetypeCollapsedCount.update()
        $ArchetypeCollapsedCount.refresh()
        $ArchetypePokeALabelCount.update()
        $ArchetypePokeALabelCount.refresh()
        $ArchetypeForm.update()
        $ArchetypeForm.refresh()
        $ArchetypePokeALabelCount.Text = $PokemonCountA
        $ArchetypeCollapsedCount.Text = $TotalPokeSeenCount

    }

    # Checks Left Mouse Click & if Poke Counter Slot is blank - If so, gives ability to manually decrease count
    if (($_.Button -eq [System.Windows.Forms.MouseButtons]::Right) -and ($PokemonA -notmatch "Blank")) {

        # Grabs the config file in its "current" state
        $SetConfig = "$PWD\Counter Config Files\CounterConfig_$GetProfile.txt"
        $GetConfig = Get-Content $SetConfig

        # Gets the current X and Y coordinates of the form
        $ArchetypeReplaceX = $ArchetypeForm.Bounds.Left
        $ArchetypeReplaceY = $ArchetypeForm.Bounds.Top

        # Replaces and Sets the starting position on the counter form start
        $GetConfig[18] = "Archetype_X=$ArchetypeReplaceX"
        $GetConfig[19] = "Archetype_Y=$ArchetypeReplaceY"

        # Changes the Pokemon count for "seen"
        $TotalPokeSeenCount = $GetConfig[38] -replace 'Pokemon_Seen_Count=', ''
        if ($TotalPokeSeenCount -eq "0") { $TotalPokeSeenCount = 0 } else { $TotalPokeSeenCount = [int]$TotalPokeSeenCount - 1 }
        $GetConfig[38] = "Pokemon_Seen_Count=$TotalPokeSeenCount"

        # Grabs Pokemon from slot 1 and decreases the "seen" count
        $PokemonCountA = $GetConfig[9] -replace 'Pokemon_A_Count=', ''
        if ($PokemonCountA -eq "0") { $PokemonCountA = 0 } else { $PokemonCountA = [int]$PokemonCountA - 1 }

        # Changes the Pokemon count for "seen"
        $GetConfig[9] = "Pokemon_A_Count=$PokemonCountA"

        # Sets all changes back into the Config file
        $GetConfig | Set-Content -Path $SetConfig

        # Refreshes Form and Poke count label
        $ArchetypeCollapsedCount.update()
        $ArchetypeCollapsedCount.refresh()
        $ArchetypePokeBLabelCount.update()
        $ArchetypePokeBLabelCount.refresh()
        $ArchetypeForm.update()
        $ArchetypeForm.refresh()
        $ArchetypePokeALabelCount.Text = $PokemonCountA
        $ArchetypeCollapsedCount.Text = $TotalPokeSeenCount

    }

})
$PokeATooltip = New-Object System.Windows.Forms.ToolTip
$PokeATooltipText = "$PokemonAHover"
$PokeATooltip.SetToolTip($ArchetypePokeAImage, $PokeATooltipText)
$ArchetypeForm.controls.Add($ArchetypePokeAImage)

# Creates the label count for the slot 1 pokemon
$ArchetypePokeALabelCount = New-Object System.Windows.Forms.label
$ArchetypePokeALabelCount.Location = New-object system.drawing.point(25,107)
$ArchetypePokeALabelCount.BackColor = [System.Drawing.ColorTranslator]::FromHtml($PokeSlot1CountBGColor)
$ArchetypePokeALabelCount.Width = 45
$ArchetypePokeALabelCount.Height = 13
$ArchetypePokeALabelCount.TextAlign = "MiddleCenter"
$ArchetypePokeALabelCount.ForeColor = "White"
$ArchetypePokeALabelCount.Text = $PokemonCountA
$ArchetypePokeALabelCount.Font = $NonInstalledFont
$ArchetypePokeALabelCount.Add_Click({

    # Checks Left Mouse Click & if Poke Counter Slot is blank - If so, gives ability to manually increase count
    if (($_.Button -eq [System.Windows.Forms.MouseButtons]::Left) -and ($PokemonA -notmatch "Blank")) {

        # Grabs the config file in its "current" state
        $SetConfig = "$PWD\Counter Config Files\CounterConfig_$GetProfile.txt"
        $GetConfig = Get-Content $SetConfig

        # Gets the current X and Y coordinates of the form
        $ArchetypeReplaceX = $ArchetypeForm.Bounds.Left
        $ArchetypeReplaceY = $ArchetypeForm.Bounds.Top

        # Replaces and Sets the starting position on the counter form start
        $GetConfig[18] = "Archetype_X=$ArchetypeReplaceX"
        $GetConfig[19] = "Archetype_Y=$ArchetypeReplaceY"

        # Changes the total Pokemon seen count
        $TotalPokeSeenCount = $GetConfig[38] -replace 'Pokemon_Seen_Count=',''
        $TotalPokeSeenCount = [int]$TotalPokeSeenCount + 1
        $GetConfig[38] = "Pokemon_Seen_Count=$TotalPokeSeenCount"

        # Grabs Pokemon from slot 1 and increases the "seen" count
        $PokemonCountA = $GetConfig[9] -replace 'Pokemon_A_Count=', ''
        $PokemonCountA = [int]$PokemonCountA + 1

        # Changes the Pokemon count for "seen"
        $GetConfig[9] = "Pokemon_A_Count=$PokemonCountA"

        # Sets all changes back into the Config file
        $GetConfig | Set-Content -Path $SetConfig

        # Refreshes Form and Poke count label
        $ArchetypeCollapsedCount.update()
        $ArchetypeCollapsedCount.refresh()
        $ArchetypePokeALabelCount.update()
        $ArchetypePokeALabelCount.refresh()
        $ArchetypeForm.update()
        $ArchetypeForm.refresh()
        $ArchetypePokeALabelCount.Text = $PokemonCountA
        $ArchetypeCollapsedCount.Text = $TotalPokeSeenCount

    }

    # Checks Left Mouse Click & if Poke Counter Slot is blank - If so, gives ability to manually decrease count
    if (($_.Button -eq [System.Windows.Forms.MouseButtons]::Right) -and ($PokemonA -notmatch "Blank")) {

        # Grabs the config file in its "current" state
        $SetConfig = "$PWD\Counter Config Files\CounterConfig_$GetProfile.txt"
        $GetConfig = Get-Content $SetConfig

        # Gets the current X and Y coordinates of the form
        $ArchetypeReplaceX = $ArchetypeForm.Bounds.Left
        $ArchetypeReplaceY = $ArchetypeForm.Bounds.Top

        # Replaces and Sets the starting position on the counter form start
        $GetConfig[18] = "Archetype_X=$ArchetypeReplaceX"
        $GetConfig[19] = "Archetype_Y=$ArchetypeReplaceY"

        # Changes the Pokemon count for "seen"
        $TotalPokeSeenCount = $GetConfig[38] -replace 'Pokemon_Seen_Count=', ''
        if ($TotalPokeSeenCount -eq "0") { $TotalPokeSeenCount = 0 } else { $TotalPokeSeenCount = [int]$TotalPokeSeenCount - 1 }
        $GetConfig[38] = "Pokemon_Seen_Count=$TotalPokeSeenCount"

        # Grabs Pokemon from slot 1 and decreases the "seen" count
        $PokemonCountA = $GetConfig[9] -replace 'Pokemon_A_Count=', ''
        if ($PokemonCountA -eq "0") { $PokemonCountA = 0 } else { $PokemonCountA = [int]$PokemonCountA - 1 }

        # Changes the Pokemon count for "seen"
        $GetConfig[9] = "Pokemon_A_Count=$PokemonCountA"

        # Sets all changes back into the Config file
        $GetConfig | Set-Content -Path $SetConfig

        # Refreshes Form and Poke count label
        $ArchetypeCollapsedCount.update()
        $ArchetypeCollapsedCount.refresh()
        $ArchetypePokeBLabelCount.update()
        $ArchetypePokeBLabelCount.refresh()
        $ArchetypeForm.update()
        $ArchetypeForm.refresh()
        $ArchetypePokeALabelCount.Text = $PokemonCountA
        $ArchetypeCollapsedCount.Text = $TotalPokeSeenCount

    }

})
$ArchetypeForm.Controls.Add($ArchetypePokeALabelCount)

# Creates the Pokemon image for Slot 2 on the form
$ArchetypePokeBFile = [System.Drawing.Image]::Fromfile("$PWD\Pokemon Icon Sprites\$SpriteType\$PokemonB.png")
$ArchetypePokeBImage = New-Object system.windows.Forms.PictureBox
$ArchetypePokeBImage.Image = $ArchetypePokeBFile
$ArchetypePokeBImage.Width = 36
$ArchetypePokeBImage.Height = 32
$ArchetypePokeBImage.BackColor = [System.Drawing.ColorTranslator]::FromHtml($PokeSlot2BGColor)
$ArchetypePokeBImage.location = New-object system.drawing.point(30,132)
if ($DetectionCount -match "3") { $ArchetypePokeBImage.Visible = $true } elseif ($DetectionCount -match "2") { $ArchetypePokeBImage.Visible = $true } elseif ($DetectionCount -match "1") { $ArchetypePokeBImage.Visible = $false; $GetConfig[11] = "Pokemon_B=Blank"; $GetConfig[12] = "Pokemon_B_Count=0"; $GetConfig | Set-Content -Path $SetConfig }
$ArchetypePokeBImage.Add_Click({

    # Checks Right Mouse Click & if Poke Counter Slot is blank - To manually add Pokemon in slot
    if (($_.Button -eq [System.Windows.Forms.MouseButtons]::Right) -and ($PokemonB -match "Blank")) {

        # Allows manual pre-load of the Pokemon in counter slot (Without having to find pokemon in the wild)
        $PokemonDexInput = [Microsoft.VisualBasic.Interaction]::InputBox("Enter Pokemon Dex Number for Slot:`n(Dex Number Example: 33)", ' Archetype Counter')
        $SetPokeConfig = "$PWD\Counter Config Files\PokemonNamesWithID_$SetLanguage.txt" 
        $GetPokeConfig = Get-Content $SetPokeConfig
        $PokemonDexInput = $PokemonDexInput.trimstart('0')
        $GetPokemonWithIDFromFile = $GetPokeConfig | Where-Object { $_ -match "$PokemonDexInput" } | Select -First 1
        $GetPokemonID = $GetPokemonWithIDFromFile -Replace '[^0-9]','' -Replace ' ', ''
        $GetPokemonName = $GetPokemonWithIDFromFile -Replace '[0-9]','' -Replace ' ', ''
        if ($PokemonDexInput) { if ($GetPokemonID | Where-Object { $_ -match "\b$PokemonDexInput\b" }) { $SetConfig = "$PWD\Counter Config Files\CounterConfig_$GetProfile.txt"; $GetConfig = Get-Content $SetConfig; $GetConfig[11] = "Pokemon_B=$GetPokemonID"; $GetConfig[13] = "Pokemon_B_Hover=$GetPokemonName #$GetPokemonID"; $GetConfig | Set-Content -Path $SetConfig; Start-Process "$PWD\ArchetypeCounter.bat" -NoNewWindow } else { [System.Windows.MessageBox]::Show("No match found for the Pokemon Dex Number. Please ensure you input a correct number value for the specific Pokemon.","Archetype Counter","OK","Asterisk") } }

    }

    # Checks Left Mouse Click & if Poke Counter Slot is blank - If so, gives ability to manually increase count
    if (($_.Button -eq [System.Windows.Forms.MouseButtons]::Left) -and ($PokemonB -notmatch "Blank")) {

        # Grabs the config file in its "current" state
        $SetConfig = "$PWD\Counter Config Files\CounterConfig_$GetProfile.txt"
        $GetConfig = Get-Content $SetConfig

        # Gets the current X and Y coordinates of the form
        $ArchetypeReplaceX = $ArchetypeForm.Bounds.Left
        $ArchetypeReplaceY = $ArchetypeForm.Bounds.Top

        # Replaces and Sets the starting position on the counter form start
        $GetConfig[18] = "Archetype_X=$ArchetypeReplaceX"
        $GetConfig[19] = "Archetype_Y=$ArchetypeReplaceY"

        # Changes the total Pokemon seen count
        $TotalPokeSeenCount = $GetConfig[38] -replace 'Pokemon_Seen_Count=',''
        $TotalPokeSeenCount = [int]$TotalPokeSeenCount + 1
        $GetConfig[38] = "Pokemon_Seen_Count=$TotalPokeSeenCount"

        # Grabs Pokemon from slot 1 and increases the "seen" count
        $PokemonCountB = $GetConfig[12] -replace 'Pokemon_B_Count=', ''
        $PokemonCountB = [int]$PokemonCountB + 1

        # Changes the Pokemon count for "seen"
        $GetConfig[12] = "Pokemon_B_Count=$PokemonCountB"

        # Sets all changes back into the Config file
        $GetConfig | Set-Content -Path $SetConfig

        # Refreshes Form and Poke count label
        $ArchetypeCollapsedCount.update()
        $ArchetypeCollapsedCount.refresh()
        $ArchetypePokeBLabelCount.update()
        $ArchetypePokeBLabelCount.refresh()
        $ArchetypeForm.update()
        $ArchetypeForm.refresh()
        $ArchetypePokeBLabelCount.Text = $PokemonCountB
        $ArchetypeCollapsedCount.Text = $TotalPokeSeenCount

    }

    # Checks Left Mouse Click & if Poke Counter Slot is blank - If so, gives ability to manually decrease count
    if (($_.Button -eq [System.Windows.Forms.MouseButtons]::Right) -and ($PokemonB -notmatch "Blank")) {

        # Grabs the config file in its "current" state
        $SetConfig = "$PWD\Counter Config Files\CounterConfig_$GetProfile.txt"
        $GetConfig = Get-Content $SetConfig

        # Gets the current X and Y coordinates of the form
        $ArchetypeReplaceX = $ArchetypeForm.Bounds.Left
        $ArchetypeReplaceY = $ArchetypeForm.Bounds.Top

        # Replaces and Sets the starting position on the counter form start
        $GetConfig[18] = "Archetype_X=$ArchetypeReplaceX"
        $GetConfig[19] = "Archetype_Y=$ArchetypeReplaceY"

        # Changes the Pokemon count for "seen"
        $TotalPokeSeenCount = $GetConfig[38] -replace 'Pokemon_Seen_Count=', ''
        if ($TotalPokeSeenCount -eq "0") { $TotalPokeSeenCount = 0 } else { $TotalPokeSeenCount = [int]$TotalPokeSeenCount - 1 }
        $GetConfig[38] = "Pokemon_Seen_Count=$TotalPokeSeenCount"

        # Grabs Pokemon from slot 1 and decreases the "seen" count
        $PokemonCountB = $GetConfig[12] -replace 'Pokemon_B_Count=', ''
        if ($PokemonCountB -eq "0") { $PokemonCountB = 0 } else { $PokemonCountB = [int]$PokemonCountB - 1 }

        # Changes the Pokemon count for "seen"
        $GetConfig[12] = "Pokemon_B_Count=$PokemonCountB"

        # Sets all changes back into the Config file
        $GetConfig | Set-Content -Path $SetConfig

        # Refreshes Form and Poke count label
        $ArchetypeCollapsedCount.update()
        $ArchetypeCollapsedCount.refresh()
        $ArchetypePokeBLabelCount.update()
        $ArchetypePokeBLabelCount.refresh()
        $ArchetypeForm.update()
        $ArchetypeForm.refresh()
        $ArchetypePokeBLabelCount.Text = $PokemonCountB
        $ArchetypeCollapsedCount.Text = $TotalPokeSeenCount

    }

})
$PokeBTooltip = New-Object System.Windows.Forms.ToolTip
$PokeBTooltipText = "$PokemonBHover"
$PokeBTooltip.SetToolTip($ArchetypePokeBImage, $PokeBTooltipText)
$ArchetypeForm.controls.Add($ArchetypePokeBImage)

# Creates the label count for the slot 2 pokemon
$ArchetypePokeBLabelCount = New-Object System.Windows.Forms.label
$ArchetypePokeBLabelCount.Location = New-object system.drawing.point(25,164)
if ($DetectionCount -match "3") { $ArchetypePokeBLabelCount.Visible = $true } elseif ($DetectionCount -match "2") { $ArchetypePokeBLabelCount.Visible = $true } elseif ($DetectionCount -match "1") { $ArchetypePokeBLabelCount.Visible = $false }
$ArchetypePokeBLabelCount.BackColor = [System.Drawing.ColorTranslator]::FromHtml($PokeSlot2CountBGColor)
$ArchetypePokeBLabelCount.Width = 45
$ArchetypePokeBLabelCount.Height = 13
$ArchetypePokeBLabelCount.TextAlign = "MiddleCenter"
$ArchetypePokeBLabelCount.ForeColor = "White"
$ArchetypePokeBLabelCount.Text = $PokemonCountB
$ArchetypePokeBLabelCount.Font = $NonInstalledFont
$ArchetypePokeBLabelCount.Add_Click({

    # Checks Left Mouse Click & if Poke Counter Slot is blank - If so, gives ability to manually increase count
    if (($_.Button -eq [System.Windows.Forms.MouseButtons]::Left) -and ($PokemonB -notmatch "Blank")) {

        # Grabs the config file in its "current" state
        $SetConfig = "$PWD\Counter Config Files\CounterConfig_$GetProfile.txt"
        $GetConfig = Get-Content $SetConfig

        # Gets the current X and Y coordinates of the form
        $ArchetypeReplaceX = $ArchetypeForm.Bounds.Left
        $ArchetypeReplaceY = $ArchetypeForm.Bounds.Top

        # Replaces and Sets the starting position on the counter form start
        $GetConfig[18] = "Archetype_X=$ArchetypeReplaceX"
        $GetConfig[19] = "Archetype_Y=$ArchetypeReplaceY"

        # Changes the total Pokemon seen count
        $TotalPokeSeenCount = $GetConfig[38] -replace 'Pokemon_Seen_Count=',''
        $TotalPokeSeenCount = [int]$TotalPokeSeenCount + 1
        $GetConfig[38] = "Pokemon_Seen_Count=$TotalPokeSeenCount"

        # Grabs Pokemon from slot 1 and increases the "seen" count
        $PokemonCountB = $GetConfig[12] -replace 'Pokemon_B_Count=', ''
        $PokemonCountB = [int]$PokemonCountB + 1

        # Changes the Pokemon count for "seen"
        $GetConfig[12] = "Pokemon_B_Count=$PokemonCountB"

        # Sets all changes back into the Config file
        $GetConfig | Set-Content -Path $SetConfig

        # Refreshes Form and Poke count label
        $ArchetypeCollapsedCount.update()
        $ArchetypeCollapsedCount.refresh()
        $ArchetypePokeBLabelCount.update()
        $ArchetypePokeBLabelCount.refresh()
        $ArchetypeForm.update()
        $ArchetypeForm.refresh()
        $ArchetypePokeBLabelCount.Text = $PokemonCountB
        $ArchetypeCollapsedCount.Text = $TotalPokeSeenCount

    }

    # Checks Left Mouse Click & if Poke Counter Slot is blank - If so, gives ability to manually decrease count
    if (($_.Button -eq [System.Windows.Forms.MouseButtons]::Right) -and ($PokemonB -notmatch "Blank")) {

        # Grabs the config file in its "current" state
        $SetConfig = "$PWD\Counter Config Files\CounterConfig_$GetProfile.txt"
        $GetConfig = Get-Content $SetConfig

        # Gets the current X and Y coordinates of the form
        $ArchetypeReplaceX = $ArchetypeForm.Bounds.Left
        $ArchetypeReplaceY = $ArchetypeForm.Bounds.Top

        # Replaces and Sets the starting position on the counter form start
        $GetConfig[18] = "Archetype_X=$ArchetypeReplaceX"
        $GetConfig[19] = "Archetype_Y=$ArchetypeReplaceY"

        # Changes the Pokemon count for "seen"
        $TotalPokeSeenCount = $GetConfig[38] -replace 'Pokemon_Seen_Count=', ''
        if ($TotalPokeSeenCount -eq "0") { $TotalPokeSeenCount = 0 } else { $TotalPokeSeenCount = [int]$TotalPokeSeenCount - 1 }
        $GetConfig[38] = "Pokemon_Seen_Count=$TotalPokeSeenCount"

        # Grabs Pokemon from slot 1 and decreases the "seen" count
        $PokemonCountB = $GetConfig[12] -replace 'Pokemon_B_Count=', ''
        if ($PokemonCountB -eq "0") { $PokemonCountB = 0 } else { $PokemonCountB = [int]$PokemonCountB - 1 }

        # Changes the Pokemon count for "seen"
        $GetConfig[12] = "Pokemon_B_Count=$PokemonCountB"

        # Sets all changes back into the Config file
        $GetConfig | Set-Content -Path $SetConfig

        # Refreshes Form and Poke count label
        $ArchetypeCollapsedCount.update()
        $ArchetypeCollapsedCount.refresh()
        $ArchetypePokeBLabelCount.update()
        $ArchetypePokeBLabelCount.refresh()
        $ArchetypeForm.update()
        $ArchetypeForm.refresh()
        $ArchetypePokeBLabelCount.Text = $PokemonCountB
        $ArchetypeCollapsedCount.Text = $TotalPokeSeenCount

    }

})
$ArchetypeForm.Controls.Add($ArchetypePokeBLabelCount)

# Creates the Pokemon image for Slot 3 on the form
$ArchetypePokeCFile = [System.Drawing.Image]::Fromfile("$PWD\Pokemon Icon Sprites\$SpriteType\$PokemonC.png")
$ArchetypePokeCImage = New-Object system.windows.Forms.PictureBox
$ArchetypePokeCImage.Image = $ArchetypePokeCFile
$ArchetypePokeCImage.Width = 36
$ArchetypePokeCImage.Height = 32
$ArchetypePokeCImage.BackColor = [System.Drawing.ColorTranslator]::FromHtml($PokeSlot3BGColor)
$ArchetypePokeCImage.location = New-object system.drawing.point(30,189)
if ($DetectionCount -match "3") { $ArchetypePokeCImage.Visible = $true } elseif ($DetectionCount -match "2") { $ArchetypePokeCCImage.Visible = $false; $GetConfig[14] = "Pokemon_C=Blank"; $GetConfig[15] = "Pokemon_C_Count=0"; $GetConfig | Set-Content -Path $SetConfig } elseif ($DetectionCount -match "1") { $ArchetypePokeCImage.Visible = $false; $GetConfig[14] = "Pokemon_C=Blank"; $GetConfig[15] = "Pokemon_C_Count=0"; $GetConfig | Set-Content -Path $SetConfig }
$ArchetypePokeCImage.Add_Click({

    # Checks Right Mouse Click & if Poke Counter Slot is blank - To manually add Pokemon in slot
    if (($_.Button -eq [System.Windows.Forms.MouseButtons]::Right) -and ($PokemonC -match "Blank")) {

        # Allows manual pre-load of the Pokemon in counter slot (Without having to find pokemon in the wild)
        $PokemonDexInput = [Microsoft.VisualBasic.Interaction]::InputBox("Enter Pokemon Dex Number for Slot:`n(Dex Number Example: 33)", ' Archetype Counter')
        $SetPokeConfig = "$PWD\Counter Config Files\PokemonNamesWithID_$SetLanguage.txt" 
        $GetPokeConfig = Get-Content $SetPokeConfig
        $PokemonDexInput = $PokemonDexInput.trimstart('0')
        $GetPokemonWithIDFromFile = $GetPokeConfig | Where-Object { $_ -match "$PokemonDexInput" } | Select -First 1
        $GetPokemonID = $GetPokemonWithIDFromFile -Replace '[^0-9]','' -Replace ' ', ''
        $GetPokemonName = $GetPokemonWithIDFromFile -Replace '[0-9]','' -Replace ' ', ''
        if ($PokemonDexInput) { if ($GetPokemonID | Where-Object { $_ -match "\b$PokemonDexInput\b" }) { $SetConfig = "$PWD\Counter Config Files\CounterConfig_$GetProfile.txt"; $GetConfig = Get-Content $SetConfig; $GetConfig[14] = "Pokemon_C=$GetPokemonID"; $GetConfig[16] = "Pokemon_C_Hover=$GetPokemonName #$GetPokemonID"; $GetConfig | Set-Content -Path $SetConfig; Start-Process "$PWD\ArchetypeCounter.bat" -NoNewWindow } else { [System.Windows.MessageBox]::Show("No match found for the Pokemon Dex Number. Please ensure you input a correct number value for the specific Pokemon.","Archetype Counter","OK","Asterisk") } }

    }

    # Checks Left Mouse Click & if Poke Counter Slot is blank - If so, gives ability to manually increase count
    if (($_.Button -eq [System.Windows.Forms.MouseButtons]::Left) -and ($PokemonC -notmatch "Blank")) {

        # Grabs the config file in its "current" state
        $SetConfig = "$PWD\Counter Config Files\CounterConfig_$GetProfile.txt"
        $GetConfig = Get-Content $SetConfig

        # Gets the current X and Y coordinates of the form
        $ArchetypeReplaceX = $ArchetypeForm.Bounds.Left
        $ArchetypeReplaceY = $ArchetypeForm.Bounds.Top

        # Replaces and Sets the starting position on the counter form start
        $GetConfig[18] = "Archetype_X=$ArchetypeReplaceX"
        $GetConfig[19] = "Archetype_Y=$ArchetypeReplaceY"

        # Changes the total Pokemon seen count
        $TotalPokeSeenCount = $GetConfig[38] -replace 'Pokemon_Seen_Count=',''
        $TotalPokeSeenCount = [int]$TotalPokeSeenCount + 1
        $GetConfig[38] = "Pokemon_Seen_Count=$TotalPokeSeenCount"

        # Grabs Pokemon from slot 1 and increases the "seen" count
        $PokemonCountC = $GetConfig[15] -replace 'Pokemon_C_Count=', ''
        $PokemonCountC = [int]$PokemonCountC + 1

        # Changes the Pokemon count for "seen"
        $GetConfig[15] = "Pokemon_C_Count=$PokemonCountC"

        # Sets all changes back into the Config file
        $GetConfig | Set-Content -Path $SetConfig

        # Refreshes Form and Poke count label
        $ArchetypeCollapsedCount.update()
        $ArchetypeCollapsedCount.refresh()
        $ArchetypePokeCLabelCount.update()
        $ArchetypePokeCLabelCount.refresh()
        $ArchetypeForm.update()
        $ArchetypeForm.refresh()
        $ArchetypePokeCLabelCount.Text = $PokemonCountC
        $ArchetypeCollapsedCount.Text = $TotalPokeSeenCount

    }

    # Checks Left Mouse Click & if Poke Counter Slot is blank - If so, gives ability to manually decrease count
    if (($_.Button -eq [System.Windows.Forms.MouseButtons]::Right) -and ($PokemonC -notmatch "Blank")) {

        # Grabs the config file in its "current" state
        $SetConfig = "$PWD\Counter Config Files\CounterConfig_$GetProfile.txt"
        $GetConfig = Get-Content $SetConfig

        # Gets the current X and Y coordinates of the form
        $ArchetypeReplaceX = $ArchetypeForm.Bounds.Left
        $ArchetypeReplaceY = $ArchetypeForm.Bounds.Top

        # Replaces and Sets the starting position on the counter form start
        $GetConfig[18] = "Archetype_X=$ArchetypeReplaceX"
        $GetConfig[19] = "Archetype_Y=$ArchetypeReplaceY"

        # Changes the Pokemon count for "seen"
        $TotalPokeSeenCount = $GetConfig[38] -replace 'Pokemon_Seen_Count=', ''
        if ($TotalPokeSeenCount -eq "0") { $TotalPokeSeenCount = 0 } else { $TotalPokeSeenCount = [int]$TotalPokeSeenCount - 1 }
        $GetConfig[38] = "Pokemon_Seen_Count=$TotalPokeSeenCount"

        # Grabs Pokemon from slot 1 and decreases the "seen" count
        $PokemonCountC = $GetConfig[15] -replace 'Pokemon_C_Count=', ''
        if ($PokemonCountC -eq "0") { $PokemonCountC = 0 } else { $PokemonCountC = [int]$PokemonCountC - 1 }

        # Changes the Pokemon count for "seen"
        $GetConfig[15] = "Pokemon_C_Count=$PokemonCountC"

        # Sets all changes back into the Config file
        $GetConfig | Set-Content -Path $SetConfig

        # Refreshes Form and Poke count label
        $ArchetypeCollapsedCount.update()
        $ArchetypeCollapsedCount.refresh()
        $ArchetypePokeCLabelCount.update()
        $ArchetypePokeCLabelCount.refresh()
        $ArchetypeForm.update()
        $ArchetypeForm.refresh()
        $ArchetypePokeCLabelCount.Text = $PokemonCountC
        $ArchetypeCollapsedCount.Text = $TotalPokeSeenCount

    }

})
$PokeCTooltip = New-Object System.Windows.Forms.ToolTip
$PokeCTooltipText = "$PokemonCHover"
$PokeCTooltip.SetToolTip($ArchetypePokeCImage, $PokeCTooltipText)
$ArchetypeForm.controls.Add($ArchetypePokeCImage)

# Creates the label count for the slot 2 pokemon
$ArchetypePokeCLabelCount = New-Object System.Windows.Forms.label
$ArchetypePokeCLabelCount.Location = New-object system.drawing.point(25,221)
if ($DetectionCount -match "3") { $ArchetypePokeCLabelCount.Visible = $true } elseif ($DetectionCount -match "2") { $ArchetypePokeCLabelCount.Visible = $false } elseif ($DetectionCount -match "1") { $ArchetypePokeCLabelCount.Visible = $false }
$ArchetypePokeCLabelCount.BackColor = [System.Drawing.ColorTranslator]::FromHtml($PokeSlot3CountBGColor)
$ArchetypePokeCLabelCount.Width = 45
$ArchetypePokeCLabelCount.Height = 13
$ArchetypePokeCLabelCount.TextAlign = "MiddleCenter"
$ArchetypePokeCLabelCount.ForeColor = "White"
$ArchetypePokeCLabelCount.Text = $PokemonCountC
$ArchetypePokeCLabelCount.Font = $NonInstalledFont
$ArchetypePokeCLabelCount.Add_Click({

    # Checks Left Mouse Click & if Poke Counter Slot is blank - If so, gives ability to manually increase count
    if (($_.Button -eq [System.Windows.Forms.MouseButtons]::Left) -and ($PokemonC -notmatch "Blank")) {

        # Grabs the config file in its "current" state
        $SetConfig = "$PWD\Counter Config Files\CounterConfig_$GetProfile.txt"
        $GetConfig = Get-Content $SetConfig

        # Gets the current X and Y coordinates of the form
        $ArchetypeReplaceX = $ArchetypeForm.Bounds.Left
        $ArchetypeReplaceY = $ArchetypeForm.Bounds.Top

        # Replaces and Sets the starting position on the counter form start
        $GetConfig[18] = "Archetype_X=$ArchetypeReplaceX"
        $GetConfig[19] = "Archetype_Y=$ArchetypeReplaceY"

        # Changes the total Pokemon seen count
        $TotalPokeSeenCount = $GetConfig[38] -replace 'Pokemon_Seen_Count=',''
        $TotalPokeSeenCount = [int]$TotalPokeSeenCount + 1
        $GetConfig[38] = "Pokemon_Seen_Count=$TotalPokeSeenCount"

        # Grabs Pokemon from slot 1 and increases the "seen" count
        $PokemonCountC = $GetConfig[15] -replace 'Pokemon_C_Count=', ''
        $PokemonCountC = [int]$PokemonCountC + 1

        # Changes the Pokemon count for "seen"
        $GetConfig[15] = "Pokemon_C_Count=$PokemonCountC"

        # Sets all changes back into the Config file
        $GetConfig | Set-Content -Path $SetConfig

        # Refreshes Form and Poke count label
        $ArchetypeCollapsedCount.update()
        $ArchetypeCollapsedCount.refresh()
        $ArchetypePokeCLabelCount.update()
        $ArchetypePokeCLabelCount.refresh()
        $ArchetypeForm.update()
        $ArchetypeForm.refresh()
        $ArchetypePokeCLabelCount.Text = $PokemonCountC
        $ArchetypeCollapsedCount.Text = $TotalPokeSeenCount

    }

    # Checks Left Mouse Click & if Poke Counter Slot is blank - If so, gives ability to manually decrease count
    if (($_.Button -eq [System.Windows.Forms.MouseButtons]::Right) -and ($PokemonC -notmatch "Blank")) {

        # Grabs the config file in its "current" state
        $SetConfig = "$PWD\Counter Config Files\CounterConfig_$GetProfile.txt"
        $GetConfig = Get-Content $SetConfig

        # Gets the current X and Y coordinates of the form
        $ArchetypeReplaceX = $ArchetypeForm.Bounds.Left
        $ArchetypeReplaceY = $ArchetypeForm.Bounds.Top

        # Replaces and Sets the starting position on the counter form start
        $GetConfig[18] = "Archetype_X=$ArchetypeReplaceX"
        $GetConfig[19] = "Archetype_Y=$ArchetypeReplaceY"

        # Changes the Pokemon count for "seen"
        $TotalPokeSeenCount = $GetConfig[38] -replace 'Pokemon_Seen_Count=', ''
        if ($TotalPokeSeenCount -eq "0") { $TotalPokeSeenCount = 0 } else { $TotalPokeSeenCount = [int]$TotalPokeSeenCount - 1 }
        $GetConfig[38] = "Pokemon_Seen_Count=$TotalPokeSeenCount"

        # Grabs Pokemon from slot 1 and decreases the "seen" count
        $PokemonCountC = $GetConfig[15] -replace 'Pokemon_C_Count=', ''
        if ($PokemonCountC -eq "0") { $PokemonCountC = 0 } else { $PokemonCountC = [int]$PokemonCountC - 1 }

        # Changes the Pokemon count for "seen"
        $GetConfig[15] = "Pokemon_C_Count=$PokemonCountC"

        # Sets all changes back into the Config file
        $GetConfig | Set-Content -Path $SetConfig

        # Refreshes Form and Poke count label
        $ArchetypeCollapsedCount.update()
        $ArchetypeCollapsedCount.refresh()
        $ArchetypePokeCLabelCount.update()
        $ArchetypePokeCLabelCount.refresh()
        $ArchetypeForm.update()
        $ArchetypeForm.refresh()
        $ArchetypePokeCLabelCount.Text = $PokemonCountC
        $ArchetypeCollapsedCount.Text = $TotalPokeSeenCount

    }

})
$ArchetypeForm.Controls.Add($ArchetypePokeCLabelCount)

# Adds the Stop image button on the form
$ArchetypeStopFile = [System.Drawing.Image]::Fromfile("$PWD\GUI Form Images\$ThemeType\Stop.png")
$ArchetypeStopImage = New-Object system.windows.Forms.PictureBox
$ArchetypeStopImage.Visible = $false
$ArchetypeStopImage.Image = $ArchetypeStopFile
$ArchetypeStopImage.Width = 64
$ArchetypeStopImage.Height = 19
if ($DetectionCount -match "3") { $ArchetypeStopImage.location = New-object system.drawing.point(15,319) } elseif ($DetectionCount -match "2") { $ArchetypeStopImage.location = New-object system.drawing.point(15,262) } elseif ($DetectionCount -match "1") { $ArchetypeStopImage.location = New-object system.drawing.point(15,205) }
$ArchetypeStopImage.Add_Click({

    # Displays Message Dialog Box - If the user wants to start the pokemon encounter count 
    $StopResult = [System.Windows.MessageBox]::Show("Do you want to STOP the counter?","Archetype Counter","YesNo","Question")

    # Checks if Message Dialog Box "Yes" has been selected
    if ($StopResult -match "Yes") { 

        # Grabs the config file in its "current" state
        $SetConfig = "$PWD\Counter Config Files\CounterConfig_$GetProfile.txt"
        $GetConfig = Get-Content $SetConfig

        # Gets the current X and Y coordinates of the form
        $ArchetypeReplaceX = $ArchetypeForm.Bounds.Left
        $ArchetypeReplaceY = $ArchetypeForm.Bounds.Top

        # Replaces and Sets the starting position on the counter form start
        $GetConfig[18] = "Archetype_X=$ArchetypeReplaceX"
        $GetConfig[19] = "Archetype_Y=$ArchetypeReplaceY"

        # Sets the flag for the counter to not Auto Start on "Stop"
        $GetConfig[33] = "Auto_Restart_Counter=False"

        # Sets all changes back into the Config file
        $GetConfig | Set-Content -Path $SetConfig

        # Removes all screenshot(s) from folder (To ensure counter does not grab a previous screenshot)
        if ($DebugMode -match "False") { Remove-Item "$PWD\Counter Functions\ScreenCapture\*.*" | Where { ! $_.PSIsContainer }; Remove-Item "$PWD\Counter Functions\ScreenCapture\DEBUG MODE\*.*" | Where { ! $_.PSIsContainer } }

        # Starts up Archetype Counter
        Start-Process "$PWD\ArchetypeCounter.bat" -NoNewWindow

    }

})
$ArchetypeForm.controls.Add($ArchetypeStopImage)

# Adds the Play image button on the form
$ArchetypePlayFile = [System.Drawing.Image]::Fromfile("$PWD\GUI Form Images\$ThemeType\Play.png")
$ArchetypePlayImage = New-Object system.windows.Forms.PictureBox
$ArchetypePlayImage.Image = $ArchetypePlayFile
$ArchetypePlayImage.Width = 64
$ArchetypePlayImage.Height = 19
if ($DetectionCount -match "3") { $ArchetypePlayImage.location = New-object system.drawing.point(15,319) } elseif ($DetectionCount -match "2") { $ArchetypePlayImage.location = New-object system.drawing.point(15,262) } elseif ($DetectionCount -match "1") { $ArchetypePlayImage.location = New-object system.drawing.point(15,205) }
$ArchetypePlayImage.Add_Click({

    # Grabs the config file in its "current" state
    $SetConfig = "$PWD\Counter Config Files\CounterConfig_$GetProfile.txt"
    $GetConfig = Get-Content $SetConfig

    # Gets the current X and Y coordinates of the form
    $ArchetypeReplaceX = $ArchetypeForm.Bounds.Left
    $ArchetypeReplaceY = $ArchetypeForm.Bounds.Top

    # Replaces and Sets the starting position on the counter form start
    $GetConfig[18] = "Archetype_X=$ArchetypeReplaceX"
    $GetConfig[19] = "Archetype_Y=$ArchetypeReplaceY"

    # Sets Counter Active to "True" (To make menu options available disabled)
    $GetConfig[34] = 'Counter_Active=True'

    # Sets all changes back into the Config file
    $GetConfig | Set-Content -Path $SetConfig

    # Starts the play/record action upon pokemon added or seen count
    PlayAction

})
$ArchetypeForm.controls.Add($ArchetypePlayImage)

# Adds the Close image button on the form
$ArchetypeCloseFile = [System.Drawing.Image]::Fromfile("$PWD\GUI Form Images\$ThemeType\Close.png")
$ArchetypeCloseImage = New-Object system.windows.Forms.PictureBox
$ArchetypeCloseImage.Image = $ArchetypeCloseFile
$ArchetypeCloseImage.Width = 64
$ArchetypeCloseImage.Height = 19
if ($DetectionCount -match "3") { $ArchetypeCloseImage.location = New-object system.drawing.point(15,370) } elseif ($DetectionCount -match "2") { $ArchetypeCloseImage.location = New-object system.drawing.point(15,313) } elseif ($DetectionCount -match "1") { $ArchetypeCloseImage.location = New-object system.drawing.point(15,256) }
$ArchetypeCloseImage.Add_Click({

    # Displays Message Dialog Box - If the user wants to exit or not
    $CloseLeftResult = [System.Windows.MessageBox]::Show("Do you want to EXIT the counter?","Archetype Counter","YesNo","Question")

    # Checks if Message Dialog Box "Yes" has been selected
    if ($CloseLeftResult -match "Yes") { 

        # Grabs the config file in its "current" state
        $SetConfig = "$PWD\Counter Config Files\CounterConfig_$GetProfile.txt"
        $GetConfig = Get-Content $SetConfig

        # Gets the current X and Y coordinates of the form
        $ArchetypeReplaceX = $ArchetypeForm.Bounds.Left
        $ArchetypeReplaceY = $ArchetypeForm.Bounds.Top

        # Replaces and Sets the starting position on the counter form start
        $GetConfig[18] = "Archetype_X=$ArchetypeReplaceX"
        $GetConfig[19] = "Archetype_Y=$ArchetypeReplaceY"

        # Resets Counter Active to "False" (To make menu options available again)
        $GetConfig[34] = 'Counter_Active=False'

        # Sets all changes back into the Config file
        $GetConfig | Set-Content -Path $SetConfig

        # Removes all screenshot(s) from folder (To ensure counter does not grab a previous screenshot)
        if ($DebugMode -match "False") { Remove-Item "$PWD\Counter Functions\ScreenCapture\*.*" | Where { ! $_.PSIsContainer }; Remove-Item "$PWD\Counter Functions\ScreenCapture\DEBUG MODE\*.*" | Where { ! $_.PSIsContainer } }

        # This exits the application (Winform) properly 
        [System.Windows.Forms.Application]::Exit(); Stop-Process $PID -Force 

    }

})
$ArchetypeForm.controls.Add($ArchetypeCloseImage)

# Adds the main base image on the form
$ArchetypeBaseFileCollapsedEncounter = [System.Drawing.Image]::Fromfile("$PWD\GUI Form Images\$ThemeType\CollapsedEncounter.png")
$ArchetypeBaseFileCollapsedEgg = [System.Drawing.Image]::Fromfile("$PWD\GUI Form Images\$ThemeType\CollapsedEgg.png")
$ArchetypeBaseFile3 = [System.Drawing.Image]::Fromfile("$PWD\GUI Form Images\$ThemeType\3.png")
$ArchetypeBaseFile2 = [System.Drawing.Image]::Fromfile("$PWD\GUI Form Images\$ThemeType\2.png")
$ArchetypeBaseFile1 = [System.Drawing.Image]::Fromfile("$PWD\GUI Form Images\$ThemeType\1.png")
$ArchetypeImage = New-Object system.windows.Forms.PictureBox
$ArchetypeImage.Width = 94
$ArchetypeImage.Height = 400
if ($DetectionCount -match "3") { $ArchetypeImage.Image = $ArchetypeBaseFile3 } elseif ($DetectionCount -match "2") { $ArchetypeImage.Image = $ArchetypeBaseFile2 } elseif ($DetectionCount -match "1") { $ArchetypeImage.Image = $ArchetypeBaseFile1 }
if ($CounterMode -match "Collapsed_Encounter") { $ArchetypeImage.Width = 115; $ArchetypeImage.Height = 38; $ArchetypeImage.Image = $ArchetypeBaseFileCollapsedEncounter; $ArchetypeMainOnImage.Visible = $false; $ArchetypeMainOffImage.Visible = $false; $ArchetypeMainEggImage.Visible = $false; $ArchetypeEggLabelCount.Visible = $false; $ArchetypePokeAImage.Visible = $false; $ArchetypePokeALabelCount.Visible = $false; $ArchetypePokeBImage.Visible = $false; $ArchetypePokeBLabelCount.Visible = $false; $ArchetypePokeCImage.Visible = $false; $ArchetypePokeCLabelCount.Visible = $false; $ArchetypePlayImage.Visible = $false; $ArchetypeStopImage.Visible = $false; $ArchetypeResetImage.Visible = $false; $ArchetypeCloseImage.Visible = $false }
if ($CounterMode -match "Collapsed_Egg") { $ArchetypeImage.Width = 115; $ArchetypeImage.Height = 38; $ArchetypeImage.Image = $ArchetypeBaseFileCollapsedEgg; $ArchetypeMainOnImage.Visible = $false; $ArchetypeMainOffImage.Visible = $false; $ArchetypeMainEggImage.Visible = $false; $ArchetypePokeAImage.Visible = $false; $ArchetypePokeALabelCount.Visible = $false; $ArchetypePokeBImage.Visible = $false; $ArchetypePokeBLabelCount.Visible = $false; $ArchetypePokeCImage.Visible = $false; $ArchetypePokeCLabelCount.Visible = $false; $ArchetypePlayImage.Visible = $false; $ArchetypeStopImage.Visible = $false; $ArchetypeResetImage.Visible = $false; $ArchetypeCloseImage.Visible = $false }
$ArchetypeImage.location = New-object system.drawing.point(0,0)
$ArchetypeImage.Add_MouseDown({ if ($_.Button -eq [System.Windows.Forms.MouseButtons]::Left) { $global:dragging = $true; $global:mouseDragX = [System.Windows.Forms.Cursor]::Position.X - $ArchetypeForm.Left; $global:mouseDragY = [System.Windows.Forms.Cursor]::Position.Y - $ArchetypeForm.Top } })
$ArchetypeImage.Add_MouseMove({ if ($_.Button -eq [System.Windows.Forms.MouseButtons]::Left) { if($global:dragging) { $screen = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea; $currentX = [System.Windows.Forms.Cursor]::Position.X; $currentY = [System.Windows.Forms.Cursor]::Position.Y; [int]$newX = [Math]::Min($currentX - $global:mouseDragX, $screen.Right - $ArchetypeForm.Width); [int]$newY = [Math]::Min($currentY - $global:mouseDragY, $screen.Bottom - $ArchetypeForm.Height); $ArchetypeForm.Location = New-Object System.Drawing.Point($newX, $newY) } }})
$ArchetypeImage.Add_MouseUp({ if ($_.Button -eq [System.Windows.Forms.MouseButtons]::Left) { $global:dragging = $false } })
$ArchetypeImage.Add_MouseDown({

    # Checks if right click mouse button has been selected
    if ($_.Button -eq [System.Windows.Forms.MouseButtons]::Right) {

    # Loads Config file and specifically grabs Counter Active line
    $SetConfig = "$PWD\Counter Config Files\CounterConfig_$GetProfile.txt"
    $GetConfig = Get-Content $SetConfig
    $CounterActive = $GetConfig[34] -replace 'Counter_Active=', ''
    $PokemonCountA = $GetConfig[9] -replace 'Pokemon_A_Count=', ''
    $PokemonCountB = $GetConfig[12] -replace 'Pokemon_B_Count=', ''
    $PokemonCountC = $GetConfig[15] -replace 'Pokemon_C_Count=', ''
    $EggCount = $GetConfig[20] -replace 'Egg_Count=',''
    $ShinyCount = $GetConfig[21] -replace 'Shiny_Count=',''
    $SetLanguage = $GetConfig[23] -replace 'Set_Language=', ''
    $TotalPokeSeenCount = $GetConfig[38] -replace 'Pokemon_Seen_Count=',''
    $TotalCount = [int]$PokemonCountA + [int]$PokemonCountB + [int]$PokemonCountC + [int]$EggCount
    $TotalCountNoEgg = [int]$PokemonCountA + [int]$PokemonCountB + [int]$PokemonCountC
    $DebugMode = $GetConfig[35] -replace 'Debug_Mode=', ''
    $ScreenMode = $GetConfig[39] -replace 'Screen_Mode=', ''
    $AlphaCount = $GetConfig[40] -replace 'Alpha_Count=', ''
    $IgnoreSystemLang = $GetConfig[41] -replace 'Ignore_System_Language=', ''

    # Adds all icons into variables for counter menu
    $ArchetypeMenuStrip = New-Object System.Windows.Forms.ContextMenuStrip
    $ArchetypeMenuStripMenu = [System.Drawing.Bitmap]::FromFile("$PWD\GUI Form Images\Icons\Menu.png")
    $ArchetypeMenuStripMain = [System.Drawing.Bitmap]::FromFile("$PWD\GUI Form Images\Icons\Archetype.png")
    $ArchetypeMenuStripPokeMMO = [System.Drawing.Bitmap]::FromFile("$PWD\GUI Form Images\Icons\PokeMMO.png")
    $ArchetypeMenuStripCustom = [System.Drawing.Bitmap]::FromFile("$PWD\GUI Form Images\Icons\Custom.png")
    $ArchetypeMenuStripToolNumber1 = [System.Drawing.Bitmap]::FromFile("$PWD\GUI Form Images\Icons\Number1.png")
    $ArchetypeMenuStripToolNumber2 = [System.Drawing.Bitmap]::FromFile("$PWD\GUI Form Images\Icons\Number2.png")
    $ArchetypeMenuStripToolNumber3 = [System.Drawing.Bitmap]::FromFile("$PWD\GUI Form Images\Icons\Number3.png")
    $ArchetypeMenuStripToolNumber4 = [System.Drawing.Bitmap]::FromFile("$PWD\GUI Form Images\Icons\Number4.png")
    $ArchetypeMenuStripToolNumber5 = [System.Drawing.Bitmap]::FromFile("$PWD\GUI Form Images\Icons\Number5.png")
    $ArchetypeMenuStripToolLanguage = [System.Drawing.Bitmap]::FromFile("$PWD\GUI Form Images\Icons\Language.png")
    $ArchetypeMenuStripToolSystemLanguage = [System.Drawing.Bitmap]::FromFile("$PWD\GUI Form Images\Icons\SystemLanguage.png")
    $ArchetypeMenuStripToolTheme = [System.Drawing.Bitmap]::FromFile("$PWD\GUI Form Images\Icons\Theme.png")
    $ArchetypeMenuStripToolSprite = [System.Drawing.Bitmap]::FromFile("$PWD\GUI Form Images\Icons\Sprite.png")
    $ArchetypeMenuStripToolDefault = [System.Drawing.Bitmap]::FromFile("$PWD\GUI Form Images\Icons\Default.png")
    $ArchetypeMenuStripTool3DS = [System.Drawing.Bitmap]::FromFile("$PWD\GUI Form Images\Icons\3DS.png")
    $ArchetypeMenuStripToolGen8 = [System.Drawing.Bitmap]::FromFile("$PWD\GUI Form Images\Icons\Gen8.png")
    $ArchetypeMenuStripToolShuffle = [System.Drawing.Bitmap]::FromFile("$PWD\GUI Form Images\Icons\Shuffle.png")
    $ArchetypeMenuStripToolDetection = [System.Drawing.Bitmap]::FromFile("$PWD\GUI Form Images\Icons\Detection.png")
    $ArchetypeMenuStripToolBackup = [System.Drawing.Bitmap]::FromFile("$PWD\GUI Form Images\Icons\Backup.png")
    $ArchetypeMenuStripToolDaily = [System.Drawing.Bitmap]::FromFile("$PWD\GUI Form Images\Icons\Daily.png")
    $ArchetypeMenuStripToolSave = [System.Drawing.Bitmap]::FromFile("$PWD\GUI Form Images\Icons\Save.png")
    $ArchetypeMenuStripToolSupport = [System.Drawing.Bitmap]::FromFile("$PWD\GUI Form Images\Icons\Support.png")
    $ArchetypeMenuStripEnglish = [System.Drawing.Bitmap]::FromFile("$PWD\GUI Form Images\Icons\English.png")
    $ArchetypeMenuStripDebug = [System.Drawing.Bitmap]::FromFile("$PWD\GUI Form Images\Icons\Debug.png")
    $ArchetypeMenuStripDebug2 = [System.Drawing.Bitmap]::FromFile("$PWD\GUI Form Images\Icons\Debug2.png")
    $ArchetypeMenuStripFrench = [System.Drawing.Bitmap]::FromFile("$PWD\GUI Form Images\Icons\French.png")
    $ArchetypeMenuStripGerman = [System.Drawing.Bitmap]::FromFile("$PWD\GUI Form Images\Icons\German.png")
    $ArchetypeMenuStripSpanish = [System.Drawing.Bitmap]::FromFile("$PWD\GUI Form Images\Icons\Spanish.png")
    $ArchetypeMenuStripBrazilianPortuguese = [System.Drawing.Bitmap]::FromFile("$PWD\GUI Form Images\Icons\BrazilianPortuguese.png")
    $ArchetypeMenuStripItalian = [System.Drawing.Bitmap]::FromFile("$PWD\GUI Form Images\Icons\Italian.png")
    $ArchetypeMenuStripPolish = [System.Drawing.Bitmap]::FromFile("$PWD\GUI Form Images\Icons\Polish.png")
    $ArchetypeMenuStripGithub = [System.Drawing.Bitmap]::FromFile("$PWD\GUI Form Images\Icons\Github.png")
    $ArchetypeMenuStripDiscord = [System.Drawing.Bitmap]::FromFile("$PWD\GUI Form Images\Icons\Discord.png")
    $ArchetypeMenuStripPowerShell = [System.Drawing.Bitmap]::FromFile("$PWD\GUI Form Images\Icons\PowerShell.png")
    $ArchetypeMenuStripWindows = [System.Drawing.Bitmap]::FromFile("$PWD\GUI Form Images\Icons\Windows.png")
    $ArchetypeMenuStripStart = [System.Drawing.Bitmap]::FromFile("$PWD\GUI Form Images\Icons\Start.png")
    $ArchetypeMenuStripStop = [System.Drawing.Bitmap]::FromFile("$PWD\GUI Form Images\Icons\Stop.png")
    $ArchetypeMenuStripReset = [System.Drawing.Bitmap]::FromFile("$PWD\GUI Form Images\Icons\Reset.png")
    $ArchetypeMenuStripExit = [System.Drawing.Bitmap]::FromFile("$PWD\GUI Form Images\Icons\Exit.png")
    $ArchetypeMenuStripToolEgg = [System.Drawing.Bitmap]::FromFile("$PWD\GUI Form Images\Icons\Egg.png")
    $ArchetypeMenuStripToolCollapsed = [System.Drawing.Bitmap]::FromFile("$PWD\GUI Form Images\Icons\Collapsed.png")
    $ArchetypeMenuStripToolCollapsed2 = [System.Drawing.Bitmap]::FromFile("$PWD\GUI Form Images\Icons\Collapsed2.png")
    $ArchetypeMenuStripToolClear = [System.Drawing.Bitmap]::FromFile("$PWD\GUI Form Images\Icons\Clear.png")
    $ArchetypeMenuStripToolProfiles = [System.Drawing.Bitmap]::FromFile("$PWD\GUI Form Images\Icons\Profiles.png")
    $ArchetypeMenuStripToolProfile1 = [System.Drawing.Bitmap]::FromFile("$PWD\GUI Form Images\Icons\Profile1.png")
    $ArchetypeMenuStripToolProfile2 = [System.Drawing.Bitmap]::FromFile("$PWD\GUI Form Images\Icons\Profile2.png")
    $ArchetypeMenuStripToolProfile3 = [System.Drawing.Bitmap]::FromFile("$PWD\GUI Form Images\Icons\Profile3.png")
    $ArchetypeMenuStripToolProfile4 = [System.Drawing.Bitmap]::FromFile("$PWD\GUI Form Images\Icons\Profile4.png")
    $ArchetypeMenuStripToolProfile5 = [System.Drawing.Bitmap]::FromFile("$PWD\GUI Form Images\Icons\Profile5.png")
    $ArchetypeMenuStripToolAlwaysOnTop = [System.Drawing.Bitmap]::FromFile("$PWD\GUI Form Images\Icons\AlwaysOnTop.png")
    $ArchetypeMenuStripToolSettings = [System.Drawing.Bitmap]::FromFile("$PWD\GUI Form Images\Icons\Settings.png")
    $ArchetypeMenuStripToolExpanded = [System.Drawing.Bitmap]::FromFile("$PWD\GUI Form Images\Icons\Expanded.png")
    $ArchetypeMenuStripToolCounterMode = [System.Drawing.Bitmap]::FromFile("$PWD\GUI Form Images\Icons\CounterMode.png")
    $ArchetypeMenuStripToolScreenMode = [System.Drawing.Bitmap]::FromFile("$PWD\GUI Form Images\Icons\ScreenMode.png")
    $ArchetypeMenuStripTool720 = [System.Drawing.Bitmap]::FromFile("$PWD\GUI Form Images\Icons\720.png")
    $ArchetypeMenuStripToolHD = [System.Drawing.Bitmap]::FromFile("$PWD\GUI Form Images\Icons\HD.png")
    $ArchetypeMenuStripTool4K = [System.Drawing.Bitmap]::FromFile("$PWD\GUI Form Images\Icons\4K.png")
    $ArchetypeMenuStripFolder = [System.Drawing.Bitmap]::FromFile("$PWD\GUI Form Images\Icons\Folder.png")
    $ArchetypeMenuStripEdit = [System.Drawing.Bitmap]::FromFile("$PWD\GUI Form Images\Icons\Edit.png")

    # Adds Counter Menu - Header
    $ArchetypeMenuStrip.Items.Add("-")
    $ArchetypeMenuStrip.Items.Add("COUNTER MENU:", $ArchetypeMenuStripMenu).Enabled = $false
    $ArchetypeMenuStrip.Items.Add("-")

    # Adds Language - Selection
    $ArchetypeMenuStripTool1 = New-Object System.Windows.Forms.ToolStripMenuItem
    $ArchetypeMenuStripTool1.Text = 'Language'
    $ArchetypeMenuStripTool1.Image = $ArchetypeMenuStripToolLanguage
    $ArchetypeMenuStrip.Items.Add($ArchetypeMenuStripTool1)
    if ($CounterActive -match "True") { $ArchetypeMenuStripTool1.Enabled = $false } else { $ArchetypeMenuStripTool1.Enabled = $true }
    
    # Checks if sub selection needs to be enabled or disabled
    if ($SetLanguage -match "English") { $ArchetypeMenuStripTool1.DropDownItems.Add("English", $ArchetypeMenuStripEnglish).Enabled = $false } else {

        # Adds click to "English" selection  
        $ArchetypeMenuStripTool1.DropDownItems.Add("English", $ArchetypeMenuStripEnglish).add_Click({ 

            # Grabs PokeMMO process
            $PokeMMOProcess = Get-Process | where {$_.mainWindowTItle } | where {$_.Name -like "javaw" }

            # Copies counter string files into PokeMMO strings folder for Egg Delay & encounter "appeared" when using pokeball
            Copy-Item "$PWD\Counter Sring Files\*" -Destination "$PWD_PokeMMOPath\data\strings\" -Recurse -Force

            # Grabs the config file in its "current" state
            $SetConfig = "$PWD\Counter Config Files\CounterConfig_$GetProfile.txt"
            $GetConfig = Get-Content $SetConfig

            # Gets the current X and Y coordinates of the form
            $ArchetypeReplaceX = $ArchetypeForm.Bounds.Left
            $ArchetypeReplaceY = $ArchetypeForm.Bounds.Top

            # Replaces and Sets the starting position on the counter form start
            $GetConfig[18] = "Archetype_X=$ArchetypeReplaceX"
            $GetConfig[19] = "Archetype_Y=$ArchetypeReplaceY"

            # Sets the Language to English
            $GetConfig[23] = 'Set_Language=English'

            # Sets all changes back into the Config file
            $GetConfig | Set-Content -Path $SetConfig
    
            # If PokeMMO is opened - exit out and re-open
            if ($PokeMMOProcess -eq $null) { $PokeMMOIsActive = $false } else { $PokeMMOIsActive = $true ; Stop-Process -Name "PokeMMO" -Force; Stop-Process -Name "javaw" -Force }
            if ($PokeMMOIsActive -eq $true) { Start-Sleep -Milliseconds 500; Start-Process "$PWD_PokeMMOPath\PokeMMO.exe" }

            # Restarts counter to update form
            Start-Process "$PWD\ArchetypeCounter.bat" -NoNewWindow 

        }) 
        
    }
    
    # Checks if sub selection needs to be enabled or disabled
    if ($SetLanguage -match "French") { $ArchetypeMenuStripTool1.DropDownItems.Add("Français (French)", $ArchetypeMenuStripFrench).Enabled = $false } else {

        # Adds click to "French" selection 
        $ArchetypeMenuStripTool1.DropDownItems.Add("Français (French)", $ArchetypeMenuStripFrench).add_Click({ 

            # Grabs PokeMMO process
            $PokeMMOProcess = Get-Process | where {$_.mainWindowTItle } | where {$_.Name -like "javaw" }

            # Copies counter string files into PokeMMO strings folder for Egg Delay & encounter "appeared" when using pokeball
            Copy-Item "$PWD\Counter Sring Files\*" -Destination "$PWD_PokeMMOPath\data\strings\" -Recurse -Force

            # Removes "Eng" Unova Egg/Encounter Delay (To avoid string confliction)
            Remove-Item "$PWD_PokeMMOPath\data\strings\a_placeholder_for_enabling_unova_edits.xml"

            # Grabs the config file in its "current" state
            $SetConfig = "$PWD\Counter Config Files\CounterConfig_$GetProfile.txt"
            $GetConfig = Get-Content $SetConfig

            # Gets the current X and Y coordinates of the form
            $ArchetypeReplaceX = $ArchetypeForm.Bounds.Left
            $ArchetypeReplaceY = $ArchetypeForm.Bounds.Top

            # Replaces and Sets the starting position on the counter form start
            $GetConfig[18] = "Archetype_X=$ArchetypeReplaceX"
            $GetConfig[19] = "Archetype_Y=$ArchetypeReplaceY"

            # Sets the Language to French
            $GetConfig[23] = 'Set_Language=French'

            # Sets all changes back into the Config file
            $GetConfig | Set-Content -Path $SetConfig

            # If PokeMMO is opened - exit out and re-open
            if ($PokeMMOProcess -eq $null) { $PokeMMOIsActive = $false } else { $PokeMMOIsActive = $true ; Stop-Process -Name "PokeMMO" -Force; Stop-Process -Name "javaw" -Force }
            if ($PokeMMOIsActive -eq $true) { Start-Sleep -Milliseconds 500; Start-Process "$PWD_PokeMMOPath\PokeMMO.exe" }

            # Restarts counter to update form
            Start-Process "$PWD\ArchetypeCounter.bat" -NoNewWindow 

        }) 
        
    }
    
    # Checks if sub selection needs to be enabled or disabled
    if ($SetLanguage -match "German") { $ArchetypeMenuStripTool1.DropDownItems.Add("Deutsch (German)", $ArchetypeMenuStripGerman).Enabled = $false } else {

        # Adds click to "German" selection 
        $ArchetypeMenuStripTool1.DropDownItems.Add("Deutsch (German)", $ArchetypeMenuStripGerman).add_Click({ 

            # Grabs PokeMMO process
            $PokeMMOProcess = Get-Process | where {$_.mainWindowTItle } | where {$_.Name -like "javaw" }
            
            # Copies counter string files into PokeMMO strings folder for Egg Delay & encounter "appeared" when using pokeball
            Copy-Item "$PWD\Counter Sring Files\*" -Destination "$PWD_PokeMMOPath\data\strings\" -Recurse -Force

            # Removes "Eng" Unova Egg/Encounter Delay (To avoid string confliction)
            Remove-Item "$PWD_PokeMMOPath\data\strings\a_placeholder_for_enabling_unova_edits.xml"

            # Grabs the config file in its "current" state
            $SetConfig = "$PWD\Counter Config Files\CounterConfig_$GetProfile.txt"
            $GetConfig = Get-Content $SetConfig

            # Gets the current X and Y coordinates of the form
            $ArchetypeReplaceX = $ArchetypeForm.Bounds.Left
            $ArchetypeReplaceY = $ArchetypeForm.Bounds.Top

            # Replaces and Sets the starting position on the counter form start
            $GetConfig[18] = "Archetype_X=$ArchetypeReplaceX"
            $GetConfig[19] = "Archetype_Y=$ArchetypeReplaceY"

            # Sets the Language to German
            $GetConfig[23] = 'Set_Language=German'

            # Sets all changes back into the Config file
            $GetConfig | Set-Content -Path $SetConfig

            # If PokeMMO is opened - exit out and re-open
            if ($PokeMMOProcess -eq $null) { $PokeMMOIsActive = $false } else { $PokeMMOIsActive = $true ; Stop-Process -Name "PokeMMO" -Force; Stop-Process -Name "javaw" -Force }
            if ($PokeMMOIsActive -eq $true) { Start-Sleep -Milliseconds 500; Start-Process "$PWD_PokeMMOPath\PokeMMO.exe" }

            # Restarts counter to update form
            Start-Process "$PWD\ArchetypeCounter.bat" -NoNewWindow 

        }) 
        
    }
    
    # Checks if sub selection needs to be enabled or disabled
    if ($SetLanguage -match "Spanish") { $ArchetypeMenuStripTool1.DropDownItems.Add("Español (Spanish)", $ArchetypeMenuStripSpanish).Enabled = $false } else {

        # Adds click to "Spanish" selection 
        $ArchetypeMenuStripTool1.DropDownItems.Add("Español (Spanish)", $ArchetypeMenuStripSpanish).add_Click({ 

            # Grabs PokeMMO process
            $PokeMMOProcess = Get-Process | where {$_.mainWindowTItle } | where {$_.Name -like "javaw" }

            # Copies counter string files into PokeMMO strings folder for Egg Delay & encounter "appeared" when using pokeball
            Copy-Item "$PWD\Counter Sring Files\*" -Destination "$PWD_PokeMMOPath\data\strings\" -Recurse -Force

            # Removes "Eng" Unova Egg/Encounter Delay (To avoid string confliction)
            Remove-Item "$PWD_PokeMMOPath\data\strings\a_placeholder_for_enabling_unova_edits.xml"

            # Grabs the config file in its "current" state
            $SetConfig = "$PWD\Counter Config Files\CounterConfig_$GetProfile.txt"
            $GetConfig = Get-Content $SetConfig

            # Gets the current X and Y coordinates of the form
            $ArchetypeReplaceX = $ArchetypeForm.Bounds.Left
            $ArchetypeReplaceY = $ArchetypeForm.Bounds.Top

            # Replaces and Sets the starting position on the counter form start
            $GetConfig[18] = "Archetype_X=$ArchetypeReplaceX"
            $GetConfig[19] = "Archetype_Y=$ArchetypeReplaceY"

            # Sets the Language to Spanish
            $GetConfig[23] = 'Set_Language=Spanish'

            # Sets all changes back into the Config file
            $GetConfig | Set-Content -Path $SetConfig

            # If PokeMMO is opened - exit out and re-open
            if ($PokeMMOProcess -eq $null) { $PokeMMOIsActive = $false } else { $PokeMMOIsActive = $true ; Stop-Process -Name "PokeMMO" -Force; Stop-Process -Name "javaw" -Force }
            if ($PokeMMOIsActive -eq $true) { Start-Sleep -Milliseconds 500; Start-Process "$PWD_PokeMMOPath\PokeMMO.exe" }

            # Restarts counter to update form
            Start-Process "$PWD\ArchetypeCounter.bat" -NoNewWindow 

        }) 
        
    }

    # Checks if sub selection needs to be enabled or disabled
    if ($SetLanguage -match "Brazilian_Portuguese") { $ArchetypeMenuStripTool1.DropDownItems.Add("Português Brasileiro (Brazilian Portuguese)", $ArchetypeMenuStripBrazilianPortuguese).Enabled = $false } else {

        # Adds click to "Brazilian Portuguese" selection
        $ArchetypeMenuStripTool1.DropDownItems.Add("Português Brasileiro (Brazilian Portuguese)", $ArchetypeMenuStripBrazilianPortuguese).add_Click({ 

            # Grabs PokeMMO process
            $PokeMMOProcess = Get-Process | where {$_.mainWindowTItle } | where {$_.Name -like "javaw" }

            # Copies counter string files into PokeMMO strings folder for Egg Delay & encounter "appeared" when using pokeball
            Copy-Item "$PWD\Counter Sring Files\*" -Destination "$PWD_PokeMMOPath\data\strings\" -Recurse -Force

            # Removes "Eng" Unova Egg/Encounter Delay (To avoid string confliction)
            Remove-Item "$PWD_PokeMMOPath\data\strings\a_placeholder_for_enabling_unova_edits.xml"
            
            # Grabs the config file in its "current" state
            $SetConfig = "$PWD\Counter Config Files\CounterConfig_$GetProfile.txt"
            $GetConfig = Get-Content $SetConfig

            # Gets the current X and Y coordinates of the form
            $ArchetypeReplaceX = $ArchetypeForm.Bounds.Left
            $ArchetypeReplaceY = $ArchetypeForm.Bounds.Top

            # Replaces and Sets the starting position on the counter form start
            $GetConfig[18] = "Archetype_X=$ArchetypeReplaceX"
            $GetConfig[19] = "Archetype_Y=$ArchetypeReplaceY"

            # Sets the Language to Brazilian Portuguese
            $GetConfig[23] = 'Set_Language=Brazilian_Portuguese'

            # Sets all changes back into the Config file
            $GetConfig | Set-Content -Path $SetConfig

            # If PokeMMO is opened - exit out and re-open
            if ($PokeMMOProcess -eq $null) { $PokeMMOIsActive = $false } else { $PokeMMOIsActive = $true ; Stop-Process -Name "PokeMMO" -Force; Stop-Process -Name "javaw" -Force }
            if ($PokeMMOIsActive -eq $true) { Start-Sleep -Milliseconds 500; Start-Process "$PWD_PokeMMOPath\PokeMMO.exe" }

            # Restarts counter to update form
            Start-Process "$PWD\ArchetypeCounter.bat" -NoNewWindow 

        }) 
        
    }
    
    # Checks if sub selection needs to be enabled or disabled
    if ($SetLanguage -match "Italian") { $ArchetypeMenuStripTool1.DropDownItems.Add("Italiano (Italian)", $ArchetypeMenuStripItalian).Enabled = $false } else {

        # Adds click to "Italian" selection
        $ArchetypeMenuStripTool1.DropDownItems.Add("Italiano (Italian)", $ArchetypeMenuStripItalian).add_Click({ 

            # Grabs PokeMMO process
            $PokeMMOProcess = Get-Process | where {$_.mainWindowTItle } | where {$_.Name -like "javaw" }

            # Copies counter string files into PokeMMO strings folder for Egg Delay & encounter "appeared" when using pokeball
            Copy-Item "$PWD\Counter Sring Files\*" -Destination "$PWD_PokeMMOPath\data\strings\" -Recurse -Force

            # Removes "Eng" Unova Egg/Encounter Delay (To avoid string confliction)
            Remove-Item "$PWD_PokeMMOPath\data\strings\a_placeholder_for_enabling_unova_edits.xml"

            # Grabs the config file in its "current" state
            $SetConfig = "$PWD\Counter Config Files\CounterConfig_$GetProfile.txt"
            $GetConfig = Get-Content $SetConfig

            # Gets the current X and Y coordinates of the form
            $ArchetypeReplaceX = $ArchetypeForm.Bounds.Left
            $ArchetypeReplaceY = $ArchetypeForm.Bounds.Top

            # Replaces and Sets the starting position on the counter form start
            $GetConfig[18] = "Archetype_X=$ArchetypeReplaceX"
            $GetConfig[19] = "Archetype_Y=$ArchetypeReplaceY"

            # Sets the Language to Italian
            $GetConfig[23] = 'Set_Language=Italian'

            # Sets all changes back into the Config file
            $GetConfig | Set-Content -Path $SetConfig

            # If PokeMMO is opened - exit out and re-open
            if ($PokeMMOProcess -eq $null) { $PokeMMOIsActive = $false } else { $PokeMMOIsActive = $true ; Stop-Process -Name "PokeMMO" -Force; Stop-Process -Name "javaw" -Force }
            if ($PokeMMOIsActive -eq $true) { Start-Sleep -Milliseconds 500; Start-Process "$PWD_PokeMMOPath\PokeMMO.exe" }

            # Restarts counter to update form
            Start-Process "$PWD\ArchetypeCounter.bat" -NoNewWindow 

        }) 
    
    }

    # Checks if sub selection needs to be enabled or disabled
    if ($SetLanguage -match "Polish") { $ArchetypeMenuStripTool1.DropDownItems.Add("Polski (Polish)", $ArchetypeMenuStripPolish).Enabled = $false } else {

        # Adds click to "Italian" selection
        $ArchetypeMenuStripTool1.DropDownItems.Add("Polski (Polish)", $ArchetypeMenuStripPolish).add_Click({ 

            # Grabs PokeMMO process
            $PokeMMOProcess = Get-Process | where {$_.mainWindowTItle } | where {$_.Name -like "javaw" }

            # Copies counter string files into PokeMMO strings folder for Egg Delay & encounter "appeared" when using pokeball
            Copy-Item "$PWD\Counter Sring Files\*" -Destination "$PWD_PokeMMOPath\data\strings\" -Recurse -Force

            # Removes "Eng" Unova Egg/Encounter Delay (To avoid string confliction)
            Remove-Item "$PWD_PokeMMOPath\data\strings\a_placeholder_for_enabling_unova_edits.xml"

            # Grabs the config file in its "current" state
            $SetConfig = "$PWD\Counter Config Files\CounterConfig_$GetProfile.txt"
            $GetConfig = Get-Content $SetConfig

            # Gets the current X and Y coordinates of the form
            $ArchetypeReplaceX = $ArchetypeForm.Bounds.Left
            $ArchetypeReplaceY = $ArchetypeForm.Bounds.Top

            # Replaces and Sets the starting position on the counter form start
            $GetConfig[18] = "Archetype_X=$ArchetypeReplaceX"
            $GetConfig[19] = "Archetype_Y=$ArchetypeReplaceY"

            # Sets the Language to Italian
            $GetConfig[23] = 'Set_Language=Polish'

            # Sets all changes back into the Config file
            $GetConfig | Set-Content -Path $SetConfig

            # If PokeMMO is opened - exit out and re-open
            if ($PokeMMOProcess -eq $null) { $PokeMMOIsActive = $false } else { $PokeMMOIsActive = $true ; Stop-Process -Name "PokeMMO" -Force; Stop-Process -Name "javaw" -Force }
            if ($PokeMMOIsActive -eq $true) { Start-Sleep -Milliseconds 500; Start-Process "$PWD_PokeMMOPath\PokeMMO.exe" }

            # Restarts counter to update form
            Start-Process "$PWD\ArchetypeCounter.bat" -NoNewWindow 

        }) 
    
    }

    # Adds Theme - Selection (With Archetype/Default/Custom Sub selections)
    $ArchetypeMenuStripTool2 = New-Object System.Windows.Forms.ToolStripMenuItem
    $ArchetypeMenuStripTool2.Text = 'Theme Selector'
    $ArchetypeMenuStripTool2.Image = $ArchetypeMenuStripToolTheme
    $ArchetypeMenuStrip.Items.Add($ArchetypeMenuStripTool2)
    if ($CounterActive -match "True") { $ArchetypeMenuStripTool2.Enabled = $false } else { $ArchetypeMenuStripTool2.Enabled = $true }

    # Checks if sub selection needs to be enabled or disabled
    if ($ThemeType -match "Archetype") { $ArchetypeMenuStripTool2.DropDownItems.Add("Archetype", $ArchetypeMenuStripMain).Enabled = $false } else {
    
        # Adds click to "Archetype" selection
        $ArchetypeMenuStripTool2.DropDownItems.Add("Archetype", $ArchetypeMenuStripMain).add_Click({ 

            # Grabs the config file in its "current" state
            $SetConfig = "$PWD\Counter Config Files\CounterConfig_$GetProfile.txt"
            $GetConfig = Get-Content $SetConfig

            # Gets the current X and Y coordinates of the form
            $ArchetypeReplaceX = $ArchetypeForm.Bounds.Left
            $ArchetypeReplaceY = $ArchetypeForm.Bounds.Top

            # Replaces and Sets the starting position on the counter form start
            $GetConfig[18] = "Archetype_X=$ArchetypeReplaceX"
            $GetConfig[19] = "Archetype_Y=$ArchetypeReplaceY"

            # Resets theme to Archetype
            $GetConfig[22] = "Theme_Type=Archetype"
    
            # Sets all changes back into the Config file
            $GetConfig | Set-Content -Path $SetConfig
    
            # Starts up Archetype Counter
            Start-Process "$PWD\ArchetypeCounter.bat" -NoNewWindow

        }) 
    
    }

    # Checks if sub selection needs to be enabled or disabled
    if ($ThemeType -match "Default") { $ArchetypeMenuStripTool2.DropDownItems.Add("Default", $ArchetypeMenuStripPokeMMO).Enabled = $false } else {
    
        # Adds click to "Default" selection
        $ArchetypeMenuStripTool2.DropDownItems.Add("Default", $ArchetypeMenuStripPokeMMO).add_Click({ 

            # Grabs the config file in its "current" state
            $SetConfig = "$PWD\Counter Config Files\CounterConfig_$GetProfile.txt"
            $GetConfig = Get-Content $SetConfig

            # Gets the current X and Y coordinates of the form
            $ArchetypeReplaceX = $ArchetypeForm.Bounds.Left
            $ArchetypeReplaceY = $ArchetypeForm.Bounds.Top

            # Replaces and Sets the starting position on the counter form start
            $GetConfig[18] = "Archetype_X=$ArchetypeReplaceX"
            $GetConfig[19] = "Archetype_Y=$ArchetypeReplaceY"

            # Resets theme to Default
            $GetConfig[22] = "Theme_Type=Default"
    
            # Sets all changes back into the Config file
            $GetConfig | Set-Content -Path $SetConfig
    
            # Starts up Archetype Counter
            Start-Process "$PWD\ArchetypeCounter.bat" -NoNewWindow

        }) 
        
    
    }

    # Checks if sub selection needs to be enabled or disabled
    if ($ThemeType -match "Custom") { $ArchetypeMenuStripTool2.DropDownItems.Add("Custom", $ArchetypeMenuStripCustom).Enabled = $false } else {

        # Adds click to "Custom" selection
        $ArchetypeMenuStripTool2.DropDownItems.Add("Custom", $ArchetypeMenuStripCustom).add_Click({ 
        
            # Grabs the config file in its "current" state
            $SetConfig = "$PWD\Counter Config Files\CounterConfig_$GetProfile.txt"
            $GetConfig = Get-Content $SetConfig

            # Gets the current X and Y coordinates of the form
            $ArchetypeReplaceX = $ArchetypeForm.Bounds.Left
            $ArchetypeReplaceY = $ArchetypeForm.Bounds.Top

            # Replaces and Sets the starting position on the counter form start
            $GetConfig[18] = "Archetype_X=$ArchetypeReplaceX"
            $GetConfig[19] = "Archetype_Y=$ArchetypeReplaceY"

            # Resets theme to Custom
            $GetConfig[22] = "Theme_Type=Custom"
    
            # Sets all changes back into the Config file
            $GetConfig | Set-Content -Path $SetConfig
    
            # Starts up Archetype Counter
            Start-Process "$PWD\ArchetypeCounter.bat" -NoNewWindow

        }) 
        
    }
    
    # Adds Sprite - Selection (With Default/3DS/Gen8/Shuffle)
    $ArchetypeMenuStripTool11 = New-Object System.Windows.Forms.ToolStripMenuItem
    $ArchetypeMenuStripTool11.Text = 'Sprite Selector'
    $ArchetypeMenuStripTool11.Image = $ArchetypeMenuStripToolSprite
    $ArchetypeMenuStrip.Items.Add($ArchetypeMenuStripTool11)
    if ($CounterActive -match "True") { $ArchetypeMenuStripTool11.Enabled = $false } else { $ArchetypeMenuStripTool11.Enabled = $true }

    # Checks if sub selection needs to be enabled or disabled
    if ($SpriteType -match "Default") { $ArchetypeMenuStripTool11.DropDownItems.Add("Default", $ArchetypeMenuStripToolDefault).Enabled = $false } else {
    
        # Adds click to "Default" selection 
        $ArchetypeMenuStripTool11.DropDownItems.Add("Default", $ArchetypeMenuStripToolDefault).add_Click({ 

            # Grabs the config file in its "current" state
            $SetConfig = "$PWD\Counter Config Files\CounterConfig_$GetProfile.txt"
            $GetConfig = Get-Content $SetConfig

            # Gets the current X and Y coordinates of the form
            $ArchetypeReplaceX = $ArchetypeForm.Bounds.Left
            $ArchetypeReplaceY = $ArchetypeForm.Bounds.Top

            # Replaces and Sets the starting position on the counter form start
            $GetConfig[18] = "Archetype_X=$ArchetypeReplaceX"
            $GetConfig[19] = "Archetype_Y=$ArchetypeReplaceY"

            # Sets Sprite type to Default
            $GetConfig[25] = "Sprite_Type=Default"
    
            # Sets all changes back into the Config file
            $GetConfig | Set-Content -Path $SetConfig
    
            # Starts up Archetype Counter
            Start-Process "$PWD\ArchetypeCounter.bat" -NoNewWindow

        }) 
        
    }

    # Checks if sub selection needs to be enabled or disabled
    if ($SpriteType -match "3DS") { $ArchetypeMenuStripTool11.DropDownItems.Add("3DS", $ArchetypeMenuStripTool3DS).Enabled = $false } else {

        # Adds click to "3DS" selection 
        $ArchetypeMenuStripTool11.DropDownItems.Add("3DS", $ArchetypeMenuStripTool3DS).add_Click({ 

            # Grabs the config file in its "current" state
            $SetConfig = "$PWD\Counter Config Files\CounterConfig_$GetProfile.txt"
            $GetConfig = Get-Content $SetConfig

            # Gets the current X and Y coordinates of the form
            $ArchetypeReplaceX = $ArchetypeForm.Bounds.Left
            $ArchetypeReplaceY = $ArchetypeForm.Bounds.Top

            # Replaces and Sets the starting position on the counter form start
            $GetConfig[18] = "Archetype_X=$ArchetypeReplaceX"
            $GetConfig[19] = "Archetype_Y=$ArchetypeReplaceY"

            # Sets Sprite type to 3DS
            $GetConfig[25] = "Sprite_Type=3DS"
    
            # Sets all changes back into the Config file
            $GetConfig | Set-Content -Path $SetConfig
    
            # Starts up Archetype Counter
            Start-Process "$PWD\ArchetypeCounter.bat" -NoNewWindow

        }) 
        
    }

    # Checks if sub selection needs to be enabled or disabled
    if ($SpriteType -match "Gen8") { $ArchetypeMenuStripTool11.DropDownItems.Add("Gen 8", $ArchetypeMenuStripToolGen8).Enabled = $false } else {

        # Adds click to "Gen8" selection 
        $ArchetypeMenuStripTool11.DropDownItems.Add("Gen 8", $ArchetypeMenuStripToolGen8).add_Click({ 

            # Grabs the config file in its "current" state
            $SetConfig = "$PWD\Counter Config Files\CounterConfig_$GetProfile.txt"
            $GetConfig = Get-Content $SetConfig

            # Gets the current X and Y coordinates of the form
            $ArchetypeReplaceX = $ArchetypeForm.Bounds.Left
            $ArchetypeReplaceY = $ArchetypeForm.Bounds.Top

            # Replaces and Sets the starting position on the counter form start
            $GetConfig[18] = "Archetype_X=$ArchetypeReplaceX"
            $GetConfig[19] = "Archetype_Y=$ArchetypeReplaceY"

            # Sets Detection count to 1
            $GetConfig[25] = "Sprite_Type=Gen8"
    
            # Sets all changes back into the Config file
            $GetConfig | Set-Content -Path $SetConfig
    
            # Starts up Archetype Counter
            Start-Process "$PWD\ArchetypeCounter.bat" -NoNewWindow

        }) 
        
    }

    # Checks if sub selection needs to be enabled or disabled
    if ($SpriteType -match "Shuffle") { $ArchetypeMenuStripTool11.DropDownItems.Add("Shuffle", $ArchetypeMenuStripToolShuffle).Enabled = $false } else {

        # Adds click to "Shuffle" selection 
        $ArchetypeMenuStripTool11.DropDownItems.Add("Shuffle", $ArchetypeMenuStripToolShuffle).add_Click({ 

            # Grabs the config file in its "current" state
            $SetConfig = "$PWD\Counter Config Files\CounterConfig_$GetProfile.txt"
            $GetConfig = Get-Content $SetConfig

            # Gets the current X and Y coordinates of the form
            $ArchetypeReplaceX = $ArchetypeForm.Bounds.Left
            $ArchetypeReplaceY = $ArchetypeForm.Bounds.Top

            # Replaces and Sets the starting position on the counter form start
            $GetConfig[18] = "Archetype_X=$ArchetypeReplaceX"
            $GetConfig[19] = "Archetype_Y=$ArchetypeReplaceY"

            # Sets Detection count to 1
            $GetConfig[25] = "Sprite_Type=Shuffle"
    
            # Sets all changes back into the Config file
            $GetConfig | Set-Content -Path $SetConfig
    
            # Starts up Archetype Counter
            Start-Process "$PWD\ArchetypeCounter.bat" -NoNewWindow

        }) 
        
    }
    
    # Adds Detection - Selection (With 1/2/3)
    $ArchetypeMenuStripTool5 = New-Object System.Windows.Forms.ToolStripMenuItem
    $ArchetypeMenuStripTool5.Text = 'Detection Selector'
    $ArchetypeMenuStripTool5.Image = $ArchetypeMenuStripToolDetection
    $ArchetypeMenuStrip.Items.Add($ArchetypeMenuStripTool5)
    if ($CounterActive -match "True") { $ArchetypeMenuStripTool5.Enabled = $false } else { $ArchetypeMenuStripTool5.Enabled = $true }

    # Checks if sub selection needs to be enabled or disabled
    if ($DetectionCount -match "1") { $ArchetypeMenuStripTool5.DropDownItems.Add("1 - Displays one Pokemon", $ArchetypeMenuStripToolNumber1).Enabled = $false } else {

        # Adds click to "1" selection 
        $ArchetypeMenuStripTool5.DropDownItems.Add("1 - Displays one Pokemon", $ArchetypeMenuStripToolNumber1).add_Click({ 

            # Grabs the config file in its "current" state
            $SetConfig = "$PWD\Counter Config Files\CounterConfig_$GetProfile.txt"
            $GetConfig = Get-Content $SetConfig

            # Gets the current X and Y coordinates of the form
            $ArchetypeReplaceX = $ArchetypeForm.Bounds.Left
            $ArchetypeReplaceY = $ArchetypeForm.Bounds.Top

            # Replaces and Sets the starting position on the counter form start
            $GetConfig[18] = "Archetype_X=$ArchetypeReplaceX"
            $GetConfig[19] = "Archetype_Y=$ArchetypeReplaceY"

            # Sets Detection count to 1
            $GetConfig[17] = "Detection_Count=1"
    
            # Sets all changes back into the Config file
            $GetConfig | Set-Content -Path $SetConfig
    
            # Starts up Archetype Counter
            Start-Process "$PWD\ArchetypeCounter.bat" -NoNewWindow

        }) 
        
    }

    # Checks if sub selection needs to be enabled or disabled
    if ($DetectionCount -match "2") { $ArchetypeMenuStripTool5.DropDownItems.Add("2 - Displays two Pokemon", $ArchetypeMenuStripToolNumber2).Enabled = $false } else {
    
        # Adds click to "2" selection 
        $ArchetypeMenuStripTool5.DropDownItems.Add("2 - Displays two Pokemon", $ArchetypeMenuStripToolNumber2).add_Click({ 

            # Grabs the config file in its "current" state
            $SetConfig = "$PWD\Counter Config Files\CounterConfig_$GetProfile.txt"
            $GetConfig = Get-Content $SetConfig

            # Gets the current X and Y coordinates of the form
            $ArchetypeReplaceX = $ArchetypeForm.Bounds.Left
            $ArchetypeReplaceY = $ArchetypeForm.Bounds.Top

            # Replaces and Sets the starting position on the counter form start
            $GetConfig[18] = "Archetype_X=$ArchetypeReplaceX"
            $GetConfig[19] = "Archetype_Y=$ArchetypeReplaceY"

            # Sets Detection count to 1
            $GetConfig[17] = "Detection_Count=2"
    
            # Sets all changes back into the Config file
            $GetConfig | Set-Content -Path $SetConfig
    
            # Starts up Archetype Counter
            Start-Process "$PWD\ArchetypeCounter.bat" -NoNewWindow

        }) 
        
    }

    # Checks if sub selection needs to be enabled or disabled
    if ($DetectionCount -match "3") { $ArchetypeMenuStripTool5.DropDownItems.Add("3 - Displays three Pokemon", $ArchetypeMenuStripToolNumber3).Enabled = $false } else {

        # Adds click to "3" selection 
        $ArchetypeMenuStripTool5.DropDownItems.Add("3 - Displays three Pokemon", $ArchetypeMenuStripToolNumber3).add_Click({ 
        
            # Grabs the config file in its "current" state
            $SetConfig = "$PWD\Counter Config Files\CounterConfig_$GetProfile.txt"
            $GetConfig = Get-Content $SetConfig

            # Gets the current X and Y coordinates of the form
            $ArchetypeReplaceX = $ArchetypeForm.Bounds.Left
            $ArchetypeReplaceY = $ArchetypeForm.Bounds.Top

            # Replaces and Sets the starting position on the counter form start
            $GetConfig[18] = "Archetype_X=$ArchetypeReplaceX"
            $GetConfig[19] = "Archetype_Y=$ArchetypeReplaceY"

            # Sets Detection count to 1
            $GetConfig[17] = "Detection_Count=3"
    
            # Sets all changes back into the Config file
            $GetConfig | Set-Content -Path $SetConfig
    
            # Starts up Archetype Counter
            Start-Process "$PWD\ArchetypeCounter.bat" -NoNewWindow

        }) 
        
    }
    
    # Adds Clear Individual Slot - Selection (With 1/2/3/Egg)
    $ArchetypeMenuStripTool6 = New-Object System.Windows.Forms.ToolStripMenuItem
    $ArchetypeMenuStripTool6.Text = 'Reset Selector'
    $ArchetypeMenuStripTool6.Image = $ArchetypeMenuStripToolClear
    $ArchetypeMenuStrip.Items.Add($ArchetypeMenuStripTool6)
    if ($CounterActive -match "True") { $ArchetypeMenuStripTool6.Enabled = $false } else { $ArchetypeMenuStripTool6.Enabled = $true }

    # Adds click to "Poke Slot 1" selection
    $ArchetypeMenuStripTool6.DropDownItems.Add("Poke Slot 1", $ArchetypeMenuStripToolNumber1).add_Click({ 

        # Grabs the config file in its "current" state
        $SetConfig = "$PWD\Counter Config Files\CounterConfig_$GetProfile.txt"
        $GetConfig = Get-Content $SetConfig

        # Gets the current X and Y coordinates of the form
        $ArchetypeReplaceX = $ArchetypeForm.Bounds.Left
        $ArchetypeReplaceY = $ArchetypeForm.Bounds.Top

        # Replaces and Sets the starting position on the counter form start
        $GetConfig[18] = "Archetype_X=$ArchetypeReplaceX"
        $GetConfig[19] = "Archetype_Y=$ArchetypeReplaceY"

        # Sets the Pokemon Slot 1 to Blank
        $GetConfig[8] = 'Pokemon_A=Blank'
        $GetConfig[9] = 'Pokemon_A_Count=0'
        $GetConfig[10] = 'Pokemon_A_Hover='

        # Move pokemon up in slots accordingly
        $GetConfig[8] = "Pokemon_A=$PokemonB"
        $GetConfig[9] = "Pokemon_A_Count=$PokemonCountB"
        $GetConfig[10] = "Pokemon_A_Hover=$PokemonBHover"
        $GetConfig[11] = "Pokemon_B=$PokemonC"
        $GetConfig[12] = "Pokemon_B_Count=$PokemonCountC"
        $GetConfig[13] = "Pokemon_B_Hover=$PokemonCHover"
        $GetConfig[14] = 'Pokemon_C=Blank'
        $GetConfig[15] = 'Pokemon_C_Count=0'
        $GetConfig[16] = 'Pokemon_C_Hover='

        # Sets all changes back into the Config file
        $GetConfig | Set-Content -Path $SetConfig

        # Starts up Archetype Counter
        Start-Process "$PWD\ArchetypeCounter.bat" -NoNewWindow

    })

    # Adds click to "Poke Slot 2" selection
    $ArchetypeMenuStripTool6.DropDownItems.Add("Poke Slot 2", $ArchetypeMenuStripToolNumber2).add_Click({ 
        
        # Grabs the config file in its "current" state
        $SetConfig = "$PWD\Counter Config Files\CounterConfig_$GetProfile.txt"
        $GetConfig = Get-Content $SetConfig

        # Gets the current X and Y coordinates of the form
        $ArchetypeReplaceX = $ArchetypeForm.Bounds.Left
        $ArchetypeReplaceY = $ArchetypeForm.Bounds.Top

        # Replaces and Sets the starting position on the counter form start
        $GetConfig[18] = "Archetype_X=$ArchetypeReplaceX"
        $GetConfig[19] = "Archetype_Y=$ArchetypeReplaceY"

        # Sets the Pokemon Slot 2 to Blank
        $GetConfig[11] = 'Pokemon_B=Blank'
        $GetConfig[12] = 'Pokemon_B_Count=0'
        $GetConfig[13] = 'Pokemon_B_Hover='

        # Move pokemon up in slots accordingly
        $GetConfig[11] = "Pokemon_B=$PokemonC"
        $GetConfig[12] = "Pokemon_B_Count=$PokemonCountC"
        $GetConfig[13] = "Pokemon_B_Hover=$PokemonCHover"
        $GetConfig[14] = 'Pokemon_C=Blank'
        $GetConfig[15] = 'Pokemon_C_Count=0'
        $GetConfig[16] = 'Pokemon_C_Hover='

        # Sets all changes back into the Config file
        $GetConfig | Set-Content -Path $SetConfig

        # Starts up Archetype Counter
        Start-Process "$PWD\ArchetypeCounter.bat" -NoNewWindow

    })

    # Adds click to "Poke Slot 3" selection
    $ArchetypeMenuStripTool6.DropDownItems.Add("Poke Slot 3", $ArchetypeMenuStripToolNumber3).add_Click({ 

        # Grabs the config file in its "current" state
        $SetConfig = "$PWD\Counter Config Files\CounterConfig_$GetProfile.txt"
        $GetConfig = Get-Content $SetConfig

        # Gets the current X and Y coordinates of the form
        $ArchetypeReplaceX = $ArchetypeForm.Bounds.Left
        $ArchetypeReplaceY = $ArchetypeForm.Bounds.Top

        # Replaces and Sets the starting position on the counter form start
        $GetConfig[18] = "Archetype_X=$ArchetypeReplaceX"
        $GetConfig[19] = "Archetype_Y=$ArchetypeReplaceY"

        # Sets the Pokemon Slot 3 to Blank
        $GetConfig[14] = 'Pokemon_C=Blank'
        $GetConfig[15] = 'Pokemon_C_Count=0'
        $GetConfig[16] = 'Pokemon_C_Hover='

        # Sets all changes back into the Config file
        $GetConfig | Set-Content -Path $SetConfig

        # Starts up Archetype Counter
        Start-Process "$PWD\ArchetypeCounter.bat" -NoNewWindow

    })

    # Adds click to "Egg Slot" selection
    $ArchetypeMenuStripTool6.DropDownItems.Add("Egg Count", $ArchetypeMenuStripToolEgg).add_Click({ 

        # Grabs the config file in its "current" state
        $SetConfig = "$PWD\Counter Config Files\CounterConfig_$GetProfile.txt"
        $GetConfig = Get-Content $SetConfig

        # Gets the current X and Y coordinates of the form
        $ArchetypeReplaceX = $ArchetypeForm.Bounds.Left
        $ArchetypeReplaceY = $ArchetypeForm.Bounds.Top

        # Replaces and Sets the starting position on the counter form start
        $GetConfig[18] = "Archetype_X=$ArchetypeReplaceX"
        $GetConfig[19] = "Archetype_Y=$ArchetypeReplaceY"

        # Sets the Egg count to 0
        $GetConfig[20] = 'Egg_Count=0'

        # Sets all changes back into the Config file
        $GetConfig | Set-Content -Path $SetConfig
    
        # Restarts counter to update form
        Start-Process "$PWD\ArchetypeCounter.bat" -NoNewWindow 

    })

    # Divider for clearing slots/counter
    $ArchetypeMenuStripTool6.DropDownItems.Add("-")

    # Adds click to "Reset Counter" selection
    $ArchetypeMenuStripTool6.DropDownItems.Add("Current Hunt Profile", $ArchetypeMenuStripReset).add_Click({ 
        
        # Displays Message Dialog Box - If the user wants to reset the pokemon encounter count 
        $ResetResult = [System.Windows.MessageBox]::Show("Do you want to RESET the counter?","Archetype Counter","YesNo","Question")

        # Checks if Message Dialog Box "Yes" has been selected
        if ($ResetResult -match "Yes") { 

            # Grabs the config file in its "current" state
            $SetConfig = "$PWD\Counter Config Files\CounterConfig_$GetProfile.txt"
            $GetConfig = Get-Content $SetConfig

            # Gets the current X and Y coordinates of the form
            $ArchetypeReplaceX = $ArchetypeForm.Bounds.Left
            $ArchetypeReplaceY = $ArchetypeForm.Bounds.Top

            # Replaces and Sets the starting position on the counter form start
            $GetConfig[18] = "Archetype_X=$ArchetypeReplaceX"
            $GetConfig[19] = "Archetype_Y=$ArchetypeReplaceY"

             # Resets ALL Pokemon counters & images in Config file
            $GetConfig[7] = "Total_Count=0"
            $GetConfig[8] = "Pokemon_A=Blank"
            $GetConfig[9] = "Pokemon_A_Count=0"
            $GetConfig[10] = "Pokemon_A_Hover="
            $GetConfig[11] = "Pokemon_B=Blank"
            $GetConfig[12] = "Pokemon_B_Count=0"
            $GetConfig[13] = "Pokemon_B_Hover="
            $GetConfig[14] = "Pokemon_C=Blank"
            $GetConfig[15] = "Pokemon_C_Count=0"
            $GetConfig[16] = "Pokemon_C_Hover="
            $GetConfig[20] = "Egg_Count=0"
            $GetConfig[38] = "Pokemon_Seen_Count=0"

            # Resets Cotuner Active to "False" (To make menu options available again)
            $GetConfig[34] = 'Counter_Active=False'

            # Sets all changes back into the Config file
            $GetConfig | Set-Content -Path $SetConfig

            # Removes all screenshot(s) from folder (To ensure counter does not grab a previous screenshot)
            if ($DebugMode -match "False") { Remove-Item "$PWD\Counter Functions\ScreenCapture\*.*" | Where { ! $_.PSIsContainer }; Remove-Item "$PWD\Counter Functions\ScreenCapture\DEBUG MODE\*.*" | Where { ! $_.PSIsContainer } }

            # Restarts counter to update
            Start-Process "$PWD\ArchetypeCounter.bat" -NoNewWindow

        }

    })

    # Adds "Counter Mode" selection
    $ArchetypeMenuStripTool21 = New-Object System.Windows.Forms.ToolStripMenuItem
    $ArchetypeMenuStripTool21.Text = 'Counter Mode'
    $ArchetypeMenuStripTool21.Image = $ArchetypeMenuStripToolCounterMode
    $ArchetypeMenuStrip.Items.Add($ArchetypeMenuStripTool21)
    if ($CounterActive -match "True") { $ArchetypeMenuStripTool21.Enabled = $false } else { $ArchetypeMenuStripTool21.Enabled = $true }
    if ($CounterMode -match "Expanded") { $ArchetypeMenuStripTool21.DropDownItems.Add("Expanded", $ArchetypeMenuStripToolExpanded).Enabled = $false } else { $ArchetypeMenuStripTool21.DropDownItems.Add("Expanded", $ArchetypeMenuStripToolExpanded).Add_Click({ $GetConfig = Get-Content $SetConfig; $GetConfig[36] = 'Counter_Mode=Expanded'; $GetConfig | Set-Content -Path $SetConfig; Start-Process "$PWD\ArchetypeCounter.bat" -NoNewWindow }) }
    if ($CounterMode -match "Collapsed_Encounter") { $ArchetypeMenuStripTool21.DropDownItems.Add("Collapsed (Encounter)", $ArchetypeMenuStripToolCollapsed).Enabled = $false } else { $ArchetypeMenuStripTool21.DropDownItems.Add("Collapsed (Encounter)", $ArchetypeMenuStripToolCollapsed).Add_Click({ $GetConfig = Get-Content $SetConfig; $GetConfig[36] = 'Counter_Mode=Collapsed_Encounter'; $GetConfig | Set-Content -Path $SetConfig; Start-Process "$PWD\ArchetypeCounter.bat" -NoNewWindow }) }
    if ($CounterMode -match "Collapsed_Egg") { $ArchetypeMenuStripTool21.DropDownItems.Add("Collapsed (Egg)", $ArchetypeMenuStripToolCollapsed2).Enabled = $false } else { $ArchetypeMenuStripTool21.DropDownItems.Add("Collapsed (Egg)", $ArchetypeMenuStripToolCollapsed2).Add_Click({ $GetConfig = Get-Content $SetConfig; $GetConfig[36] = 'Counter_Mode=Collapsed_Egg'; $GetConfig | Set-Content -Path $SetConfig; Start-Process "$PWD\ArchetypeCounter.bat" -NoNewWindow }) }

    # Adds "Screen Mode" selection
    $ArchetypeMenuStripTool22 = New-Object System.Windows.Forms.ToolStripMenuItem
    $ArchetypeMenuStripTool22.Text = 'Screen Mode'
    $ArchetypeMenuStripTool22.Image = $ArchetypeMenuStripToolScreenMode
    $ArchetypeMenuStrip.Items.Add($ArchetypeMenuStripTool22)
    if ($CounterActive -match "True") { $ArchetypeMenuStripTool22.Enabled = $false } else { $ArchetypeMenuStripTool22.Enabled = $true }
    if ($ScreenMode -match "720") { $ArchetypeMenuStripTool22.DropDownItems.Add("720p", $ArchetypeMenuStripTool720).Enabled = $false } else { $ArchetypeMenuStripTool22.DropDownItems.Add("720p", $ArchetypeMenuStripTool720).Add_Click({ $GetConfig = Get-Content $SetConfig; $GetConfig[39] = 'Screen_Mode=720'; $GetConfig | Set-Content -Path $SetConfig; Start-Process "$PWD\ArchetypeCounter.bat" -NoNewWindow }) }
    if ($ScreenMode -match "HD") { $ArchetypeMenuStripTool22.DropDownItems.Add("HD", $ArchetypeMenuStripToolHD).Enabled = $false } else { $ArchetypeMenuStripTool22.DropDownItems.Add("HD", $ArchetypeMenuStripToolHD).Add_Click({ $GetConfig = Get-Content $SetConfig; $GetConfig[39] = 'Screen_Mode=HD'; $GetConfig | Set-Content -Path $SetConfig; Start-Process "$PWD\ArchetypeCounter.bat" -NoNewWindow }) }
    if ($ScreenMode -match "4K") { $ArchetypeMenuStripTool22.DropDownItems.Add("4K", $ArchetypeMenuStripTool4K).Enabled = $false } else { $ArchetypeMenuStripTool22.DropDownItems.Add("4K", $ArchetypeMenuStripTool4K).Add_Click({ $GetConfig = Get-Content $SetConfig; $GetConfig[39] = 'Screen_Mode=4K'; $GetConfig | Set-Content -Path $SetConfig; Start-Process "$PWD\ArchetypeCounter.bat" -NoNewWindow }) }

    # Adds "Hunt Profiles" selection
    $ArchetypeMenuStripTool15 = New-Object System.Windows.Forms.ToolStripMenuItem
    $ArchetypeMenuStripTool15.Text = 'Hunt Profiles'
    $ArchetypeMenuStripTool15.Image = $ArchetypeMenuStripToolProfiles
    $ArchetypeMenuStrip.Items.Add($ArchetypeMenuStripTool15)
    if ($CounterActive -match "True") { $ArchetypeMenuStripTool15.Enabled = $false } else { $ArchetypeMenuStripTool15.Enabled = $true }
    $SetProfileConfig = "$PWD\Counter Config Files\CurrentProfileState.txt"; $GetProfileConfig = Get-Content $SetProfileConfig; ; $HuntName1 = $GetProfileConfig[8] -replace 'Hunt_Profile_Name_1=', ''; $HuntName2 = $GetProfileConfig[9] -replace 'Hunt_Profile_Name_2=', ''; $HuntName3 = $GetProfileConfig[10] -replace 'Hunt_Profile_Name_3=', ''; $HuntName4 = $GetProfileConfig[11] -replace 'Hunt_Profile_Name_4=', ''; $HuntName5 = $GetProfileConfig[12] -replace 'Hunt_Profile_Name_5=', ''
    if ($GetProfile -match "Profile1") { $ArchetypeMenuStripTool15.DropDownItems.Add("$HuntName1", $ArchetypeMenuStripToolProfile1).Enabled = $false } else { $ArchetypeMenuStripTool15.DropDownItems.Add("$HuntName1", $ArchetypeMenuStripToolProfile1).Add_Click({ $SetProfileConfig = "$PWD\Counter Config Files\CurrentProfileState.txt"; $GetProfileConfig = Get-Content $SetProfileConfig; $HuntName1Replace = $GetProfileConfig[8] -replace 'Hunt_Profile_Name_1=', ''; $GetProfileConfig[7] = "Current_Hunt_Profile=$HuntName1Replace "; $GetProfileConfig | Set-Content -Path $SetProfileConfig; Start-Process "$PWD\ArchetypeCounter.bat" -NoNewWindow }) }
    if ($GetProfile -match "Profile2") { $ArchetypeMenuStripTool15.DropDownItems.Add("$HuntName2", $ArchetypeMenuStripToolProfile2).Enabled = $false } else { $ArchetypeMenuStripTool15.DropDownItems.Add("$HuntName2", $ArchetypeMenuStripToolProfile2).Add_Click({ $SetProfileConfig = "$PWD\Counter Config Files\CurrentProfileState.txt"; $GetProfileConfig = Get-Content $SetProfileConfig; $HuntName2Replace = $GetProfileConfig[9] -replace 'Hunt_Profile_Name_2=', ''; $GetProfileConfig[7] = "Current_Hunt_Profile=$HuntName2Replace "; $GetProfileConfig | Set-Content -Path $SetProfileConfig; Start-Process "$PWD\ArchetypeCounter.bat" -NoNewWindow }) }
    if ($GetProfile -match "Profile3") { $ArchetypeMenuStripTool15.DropDownItems.Add("$HuntName3", $ArchetypeMenuStripToolProfile3).Enabled = $false } else { $ArchetypeMenuStripTool15.DropDownItems.Add("$HuntName3", $ArchetypeMenuStripToolProfile3).Add_Click({ $SetProfileConfig = "$PWD\Counter Config Files\CurrentProfileState.txt"; $GetProfileConfig = Get-Content $SetProfileConfig; $HuntName3Replace = $GetProfileConfig[10] -replace 'Hunt_Profile_Name_3=', ''; $GetProfileConfig[7] = "Current_Hunt_Profile=$HuntName3Replace "; $GetProfileConfig | Set-Content -Path $SetProfileConfig; Start-Process "$PWD\ArchetypeCounter.bat" -NoNewWindow }) }
    if ($GetProfile -match "Profile4") { $ArchetypeMenuStripTool15.DropDownItems.Add("$HuntName4", $ArchetypeMenuStripToolProfile4).Enabled = $false } else { $ArchetypeMenuStripTool15.DropDownItems.Add("$HuntName4", $ArchetypeMenuStripToolProfile4).Add_Click({ $SetProfileConfig = "$PWD\Counter Config Files\CurrentProfileState.txt"; $GetProfileConfig = Get-Content $SetProfileConfig; $HuntName4Replace = $GetProfileConfig[11] -replace 'Hunt_Profile_Name_4=', ''; $GetProfileConfig[7] = "Current_Hunt_Profile=$HuntName4Replace "; $GetProfileConfig | Set-Content -Path $SetProfileConfig; Start-Process "$PWD\ArchetypeCounter.bat" -NoNewWindow }) }
    if ($GetProfile -match "Profile5") { $ArchetypeMenuStripTool15.DropDownItems.Add("$HuntName5", $ArchetypeMenuStripToolProfile5).Enabled = $false } else { $ArchetypeMenuStripTool15.DropDownItems.Add("$HuntName5", $ArchetypeMenuStripToolProfile5).Add_Click({ $SetProfileConfig = "$PWD\Counter Config Files\CurrentProfileState.txt"; $GetProfileConfig = Get-Content $SetProfileConfig; $HuntName5Replace = $GetProfileConfig[12] -replace 'Hunt_Profile_Name_5=', ''; $GetProfileConfig[7] = "Current_Hunt_Profile=$HuntName5Replace "; $GetProfileConfig | Set-Content -Path $SetProfileConfig; Start-Process "$PWD\ArchetypeCounter.bat" -NoNewWindow }) }
    $ArchetypeMenuStripTool15.DropDownItems.Add("-")
    $ArchetypeMenuStripTool15.DropDownItems.Add("Rename Profile 1", $ArchetypeMenuStripEdit).Add_Click({ $Profile1Text = [Microsoft.VisualBasic.Interaction]::InputBox('Name change for Hunt Profile 1:', ' Archetype Counter'); if ($Profile1Text) { $SetProfileConfig = "$PWD\Counter Config Files\CurrentProfileState.txt";$GetProfileConfig = Get-Content $SetProfileConfig; $GetProfileCurrent = $GetProfileConfig[7] -replace 'Current_Hunt_Profile=', ''; $GetProfileHunt1 = $GetProfileConfig[8] -replace 'Hunt_Profile_Name_1=', ''; if ($GetProfileCurrent -match $GetProfileHunt1) { $GetProfileConfig[7] = "Current_Hunt_Profile=$Profile1Text" }; $GetProfileConfig[8] = "Hunt_Profile_Name_1=$Profile1Text"; $GetProfileConfig | Set-Content -Path $SetProfileConfig; Start-Process "$PWD\ArchetypeCounter.bat" -NoNewWindow } })
    $ArchetypeMenuStripTool15.DropDownItems.Add("Rename Profile 2", $ArchetypeMenuStripEdit).Add_Click({ $Profile2Text = [Microsoft.VisualBasic.Interaction]::InputBox('Name change for Hunt Profile 2:', ' Archetype Counter'); if ($Profile2Text) { $SetProfileConfig = "$PWD\Counter Config Files\CurrentProfileState.txt"; $GetProfileConfig = Get-Content $SetProfileConfig; $GetProfileCurrent = $GetProfileConfig[7] -replace 'Current_Hunt_Profile=', ''; $GetProfileHunt2 = $GetProfileConfig[9] -replace 'Hunt_Profile_Name_2=', ''; if ($GetProfileCurrent -match $GetProfileHunt2) { $GetProfileConfig[7] = "Current_Hunt_Profile=$Profile2Text" }; $GetProfileConfig[9] = "Hunt_Profile_Name_2=$Profile2Text"; $GetProfileConfig | Set-Content -Path $SetProfileConfig; Start-Process "$PWD\ArchetypeCounter.bat" -NoNewWindow } })
    $ArchetypeMenuStripTool15.DropDownItems.Add("Rename Profile 3", $ArchetypeMenuStripEdit).Add_Click({ $Profile3Text = [Microsoft.VisualBasic.Interaction]::InputBox('Name change for Hunt Profile 3:', ' Archetype Counter'); if ($Profile3Text) { $SetProfileConfig = "$PWD\Counter Config Files\CurrentProfileState.txt"; $GetProfileConfig = Get-Content $SetProfileConfig; $GetProfileCurrent = $GetProfileConfig[7] -replace 'Current_Hunt_Profile=', ''; $GetProfileHunt3 = $GetProfileConfig[10] -replace 'Hunt_Profile_Name_3=', ''; if ($GetProfileCurrent -match $GetProfileHunt3) { $GetProfileConfig[7] = "Current_Hunt_Profile=$Profile3Text" }; $GetProfileConfig[10] = "Hunt_Profile_Name_3=$Profile3Text"; $GetProfileConfig | Set-Content -Path $SetProfileConfig; Start-Process "$PWD\ArchetypeCounter.bat" -NoNewWindow } })
    $ArchetypeMenuStripTool15.DropDownItems.Add("Rename Profile 4", $ArchetypeMenuStripEdit).Add_Click({ $Profile4Text = [Microsoft.VisualBasic.Interaction]::InputBox('Name change for Hunt Profile 4:', ' Archetype Counter'); if ($Profile4Text) { $SetProfileConfig = "$PWD\Counter Config Files\CurrentProfileState.txt"; $GetProfileConfig = Get-Content $SetProfileConfig; $GetProfileCurrent = $GetProfileConfig[7] -replace 'Current_Hunt_Profile=', ''; $GetProfileHunt4 = $GetProfileConfig[11] -replace 'Hunt_Profile_Name_4=', ''; if ($GetProfileCurrent -match $GetProfileHunt4) { $GetProfileConfig[7] = "Current_Hunt_Profile=$Profile4Text" }; $GetProfileConfig[11] = "Hunt_Profile_Name_4=$Profile4Text"; $GetProfileConfig | Set-Content -Path $SetProfileConfig; Start-Process "$PWD\ArchetypeCounter.bat" -NoNewWindow } })
    $ArchetypeMenuStripTool15.DropDownItems.Add("Rename Profile 5", $ArchetypeMenuStripEdit).Add_Click({ $Profile5Text = [Microsoft.VisualBasic.Interaction]::InputBox('Name change for Hunt Profile 5:', ' Archetype Counter'); if ($Profile5Text) { $SetProfileConfig = "$PWD\Counter Config Files\CurrentProfileState.txt"; $GetProfileConfig = Get-Content $SetProfileConfig; $GetProfileCurrent = $GetProfileConfig[7] -replace 'Current_Hunt_Profile=', ''; $GetProfileHunt5 = $GetProfileConfig[12] -replace 'Hunt_Profile_Name_5=', ''; if ($GetProfileCurrent -match $GetProfileHunt5) { $GetProfileConfig[7] = "Current_Hunt_Profile=$Profile5Text" }; $GetProfileConfig[12] = "Hunt_Profile_Name_5=$Profile5Text"; $GetProfileConfig | Set-Content -Path $SetProfileConfig; Start-Process "$PWD\ArchetypeCounter.bat" -NoNewWindow } })

    # Adds "Backup" selection
    $ArchetypeMenuStripTool7 = New-Object System.Windows.Forms.ToolStripMenuItem
    $ArchetypeMenuStripTool7.Text = 'Backup'
    $ArchetypeMenuStripTool7.Image = $ArchetypeMenuStripToolBackup
    $ArchetypeMenuStrip.Items.Add($ArchetypeMenuStripTool7)
    $ArchetypeMenuStripTool7.DropDownItems.Add("Save Current Counter State (Config File)", $ArchetypeMenuStripToolSave).add_Click({ $TodaysDate = (Get-Date).ToString('MM_dd_yyyy'); New-Item -Path "$PWD\Counter Config Files\Counter Config Backup" -Type Directory -Name $TodaysDate; Copy-Item "$PWD\Counter Config Files\CounterConfig_$GetProfile.txt" -Destination "$PWD\Counter Config Files\Counter Config Backup\$TodaysDate" -Recurse; Copy-Item "$PWD\Counter Config Files\CurrentProfileState.txt" -Destination "$PWD\Counter Config Files\Counter Config Backup\$TodaysDate" -Recurse })
    $ArchetypeMenuStripTool7.DropDownItems.Add("-")
    $ArchetypeMenuStripTool7.DropDownItems.Add("Daily Counter Backup: Enabled", $ArchetypeMenuStripToolDaily).Enabled = $false

    # Adds "Support" selection
    $ArchetypeMenuStripTool4 = New-Object System.Windows.Forms.ToolStripMenuItem
    $ArchetypeMenuStripTool4.Text = 'Support'
    $ArchetypeMenuStripTool4.Image = $ArchetypeMenuStripToolSupport
    $ArchetypeMenuStrip.Items.Add($ArchetypeMenuStripTool4)

    # Adds "Settings" selection 
    $ArchetypeMenuStripToolStartup = [System.Drawing.Bitmap]::FromFile("$PWD\GUI Form Images\Icons\Startup.png")
    $ArchetypeMenuStripTool3 = New-Object System.Windows.Forms.ToolStripMenuItem
    $ArchetypeMenuStripTool3.Text = 'Settings'
    $ArchetypeMenuStripTool3.Image = $ArchetypeMenuStripToolSettings
    $ArchetypeMenuStrip.Items.Add($ArchetypeMenuStripTool3)
    if ($CounterActive -match "True") { $ArchetypeMenuStripTool3.Enabled = $false } else { $ArchetypeMenuStripTool3.Enabled = $true }
    $PokeMMOProcess = Get-Process | where {$_.mainWindowTItle } | where {$_.Name -like "javaw" }
    if ($PokeMMOLaunch -match "True") { $PokeMMOMenuStripText = "Launch PokeMMO with counter: Enabled" } else { $PokeMMOMenuStripText = "Launch PokeMMO with counter: Disabled" }
    if ($CounterActive -match "True" -or $PokeMMOProcess -ne $null) { $ArchetypeMenuStripTool3.DropDownItems.Add("$PokeMMOMenuStripText", $ArchetypeMenuStripToolStartup).Enabled = $false } else { $ArchetypeMenuStripTool3.Enabled = $true; $ArchetypeMenuStripTool3.DropDownItems.Add("$PokeMMOMenuStripText", $ArchetypeMenuStripToolStartup).add_Click({ $SetConfig = "$PWD\Counter Config Files\CounterConfig_$GetProfile.txt"; $GetConfig = Get-Content $SetConfig; $ArchetypeReplaceX = $ArchetypeForm.Bounds.Left; $ArchetypeReplaceY = $ArchetypeForm.Bounds.Top; $GetConfig[18] = "Archetype_X=$ArchetypeReplaceX"; $GetConfig[19] = "Archetype_Y=$ArchetypeReplaceY"; if ($PokeMMOLaunch -match "True") { $GetConfig[24] = 'PokeMMO_Launch=False' } else { $GetConfig[24] = 'PokeMMO_Launch=True' }; $GetConfig | Set-Content -Path $SetConfig; Start-Process "$PWD\ArchetypeCounter.bat" -NoNewWindow }) }
    if ($AlwaysOnTop -match "True") { $PokeMMOMenuAlwaysOnTopText = "Always On Top: Enabled" } else { $PokeMMOMenuAlwaysOnTopText = "Always On Top: Disabled" }
    $ArchetypeMenuStripTool3.DropDownItems.Add("$PokeMMOMenuAlwaysOnTopText", $ArchetypeMenuStripToolAlwaysOnTop).add_Click({ $SetConfig = "$PWD\Counter Config Files\CounterConfig_$GetProfile.txt"; $GetConfig = Get-Content $SetConfig; $ArchetypeReplaceX = $ArchetypeForm.Bounds.Left; $ArchetypeReplaceY = $ArchetypeForm.Bounds.Top; $GetConfig[18] = "Archetype_X=$ArchetypeReplaceX"; $GetConfig[19] = "Archetype_Y=$ArchetypeReplaceY"; if ($AlwaysOnTop -match "True") { $GetConfig[37] = 'Always_On_Top=False' } else { $GetConfig[37] = 'Always_On_Top=True' }; $GetConfig | Set-Content -Path $SetConfig; Start-Process "$PWD\ArchetypeCounter.bat" -NoNewWindow })
    if ($IgnoreSystemLang -match "True") { $PokeMMOMenuSystemLangText = "Ignore System Language: True" } else { $PokeMMOMenuSystemLangText = "Ignore System Language: False" }; $ArchetypeMenuStripTool3.DropDownItems.Add("$PokeMMOMenuSystemLangText", $ArchetypeMenuStripToolSystemLanguage).add_Click({ $SetConfig = "$PWD\Counter Config Files\CounterConfig_$GetProfile.txt"; $GetConfig = Get-Content $SetConfig; $ArchetypeReplaceX = $ArchetypeForm.Bounds.Left; $ArchetypeReplaceY = $ArchetypeForm.Bounds.Top; $GetConfig[18] = "Archetype_X=$ArchetypeReplaceX"; $GetConfig[19] = "Archetype_Y=$ArchetypeReplaceY"; if ($IgnoreSystemLang -match "True") { $GetConfig[41] = 'Ignore_System_Language=False' } else { $GetConfig[41] = 'Ignore_System_Language=True' }; $GetConfig | Set-Content -Path $SetConfig; Start-Process "$PWD\ArchetypeCounter.bat" -NoNewWindow })

    # Adds "Total Current Counts" selection
    $ArchetypeMenuStrip.Items.Add("-")
    $ArchetypeMenuStripCount = [System.Drawing.Bitmap]::FromFile("$PWD\GUI Form Images\Icons\Count.png")
    $ArchetypeMenuStripTool9 = New-Object System.Windows.Forms.ToolStripMenuItem
    $ArchetypeMenuStripTool9.Text = 'Total Current Counts'
    $ArchetypeMenuStripTool9.Image = $ArchetypeMenuStripCount
    $ArchetypeMenuStrip.Items.Add($ArchetypeMenuStripTool9)
    $ArchetypeMenuStripTool9.DropDownItems.Add("Total Counted (Slots+Egg): $TotalCount", $ArchetypeMenuStripToolNumber1).Enabled = $false
    $ArchetypeMenuStripTool9.DropDownItems.Add("Total Individual Slots: $TotalCountNoEgg", $ArchetypeMenuStripToolNumber2).Enabled = $false
    $ArchetypeMenuStripTool9.DropDownItems.Add("Total Pokemon Seen: $TotalPokeSeenCount", $ArchetypeMenuStripToolNumber3).Enabled = $false
    $ArchetypeMenuStripTool9.DropDownItems.Add("-")
    $ArchetypeMenuStripTool9.DropDownItems.Add("Total Alphas: $AlphaCount", $ArchetypeMenuStripToolNumber4).Enabled = $false
    $ArchetypeMenuStripTool9.DropDownItems.Add("Total Shinies: $ShinyCount", $ArchetypeMenuStripToolNumber5).Enabled = $false
    $ArchetypeMenuStripTool4.DropDownItems.Add("Discord: https://discord.gg/rYg7ntqQRY", $ArchetypeMenuStripDiscord).add_Click({ Start-Process "https://discord.gg/rYg7ntqQRY" })

    # Adds "Debug" selection
    $ArchetypeMenuStripTool10 = New-Object System.Windows.Forms.ToolStripMenuItem
    $ArchetypeMenuStripTool10.Text = 'Debug Mode'
    $ArchetypeMenuStripTool10.Image = $ArchetypeMenuStripDebug
    $ArchetypeMenuStrip.Items.Add($ArchetypeMenuStripTool10)
    #if ($CounterActive -match "True") { $ArchetypeMenuStripTool10.Enabled = $false } else { $ArchetypeMenuStripTool10.Enabled = $true }
    if ($DebugMode -match "False") { $PokeMMOMenuStripTextDebug = "Counter Debugging: Disabled" } else { $PokeMMOMenuStripTextDebug = "Counter Debbuging: Enabled" }
    if ($CounterActive -match "True") { $ArchetypeMenuStripTool10.DropDownItems.Add("$PokeMMOMenuStripTextDebug", $ArchetypeMenuStripDebug2).Enabled = $false } else { $ArchetypeMenuStripTool10.DropDownItems.Add("$PokeMMOMenuStripTextDebug", $ArchetypeMenuStripDebug2).add_Click({ $SetConfig = "$PWD\Counter Config Files\CounterConfig_$GetProfile.txt"; $GetConfig = Get-Content $SetConfig; if ($DebugMode -match "True") { $GetConfig[35] = "Debug_Mode=False"; Remove-Item "$PWD\Counter Functions\ScreenCapture\*.*" | Where { ! $_.PSIsContainer } } else { $GetConfig[35] = "Debug_Mode=True" } $GetConfig | Set-Content -Path $SetConfig; Start-Process "$PWD\ArchetypeCounter.bat" -NoNewWindow }) }
    $ArchetypeMenuStripTool10.DropDownItems.Add("-", $ArchetypeMenuStripDebug2)
    $ArchetypeMenuStripTool10.DropDownItems.Add("-> Open DEBUG MODE Folder <-", $ArchetypeMenuStripFolder).add_Click({ Explorer .\Counter Functions\ScreenCapture\DEBUG MODE })

    # Adds "Windows Info" selections (Greyed out)
    $PSVersionMajor = $PSVersionTable.PSVersion.Major; $PSVersionMinor = $PSVersionTable.PSVersion.Minor; $PSVersionInfo = "$PSVersionMajor" + '.' + "$PSVersionMinor"
    $OSName = (Get-WmiObject Win32_OperatingSystem).Caption
    $ArchetypeMenuStripTool4.DropDownItems.Add("-")
    $ArchetypeMenuStripTool4.DropDownItems.Add("Current PowerShell: $PSVersionInfo", $ArchetypeMenuStripPowerShell).Enabled = $false
    $ArchetypeMenuStripTool4.DropDownItems.Add("Current Windows: $OSName", $ArchetypeMenuStripWindows).Enabled = $false
    $ArchetypeMenuStripTool4.DropDownItems.Add("-")
    $ArchetypeMenuStripTool4.DropDownItems.Add("Counter Version: 2.0.0", $ArchetypeMenuStripPowerShell).Enabled = $false

    # Checks if counter menu is in Collapsed Mode
    if ($CounterMode -match "Collapsed_Encounter" -or $CounterMode -match "Collapsed_Egg") {

        # Adds click to "Start Counter" selection
        $ArchetypeMenuStrip.Items.Add("-")
        $ArchetypeMenuStrip.Items.Add("Start Counter", $ArchetypeMenuStripStart).add_Click({ 

            # Grabs the config file in its "current" state
            $SetConfig = "$PWD\Counter Config Files\CounterConfig_$GetProfile.txt"
            $GetConfig = Get-Content $SetConfig

            # Gets the current X and Y coordinates of the form
            $ArchetypeReplaceX = $ArchetypeForm.Bounds.Left
            $ArchetypeReplaceY = $ArchetypeForm.Bounds.Top

            # Replaces and Sets the starting position on the counter form start
            $GetConfig[18] = "Archetype_X=$ArchetypeReplaceX"
            $GetConfig[19] = "Archetype_Y=$ArchetypeReplaceY"

            # Sets Counter Active to "True" (To make menu options available disabled)
            $GetConfig[34] = 'Counter_Active=True'

            # Sets all changes back into the Config file
            $GetConfig | Set-Content -Path $SetConfig

            # Starts the play/record action upon pokemon added or seen count
            PlayAction

        })

        # Adds click to "Stop Counter" selection
        $ArchetypeMenuStrip.Items.Add("Stop Counter", $ArchetypeMenuStripStop).add_Click({ 
        
            # Displays Message Dialog Box - If the user wants to start the pokemon encounter count 
            $StopResult = [System.Windows.MessageBox]::Show("Do you want to STOP the counter?","Archetype Counter","YesNo","Question")

            # Checks if Message Dialog Box "Yes" has been selected
            if ($StopResult -match "Yes") { 

                # Grabs the config file in its "current" state
                $SetConfig = "$PWD\Counter Config Files\CounterConfig_$GetProfile.txt"
                $GetConfig = Get-Content $SetConfig

                # Gets the current X and Y coordinates of the form
                $ArchetypeReplaceX = $ArchetypeForm.Bounds.Left
                $ArchetypeReplaceY = $ArchetypeForm.Bounds.Top

                # Replaces and Sets the starting position on the counter form start
                $GetConfig[18] = "Archetype_X=$ArchetypeReplaceX"
                $GetConfig[19] = "Archetype_Y=$ArchetypeReplaceY"

                # Sets the flag for the counter to not Auto Start on "Stop"
                $GetConfig[33] = "Auto_Restart_Counter=False"

                # Sets all changes back into the Config file
                $GetConfig | Set-Content -Path $SetConfig

                # Removes all screenshot(s) from folder (To ensure counter does not grab a previous screenshot)
                if ($DebugMode -match "False") { Remove-Item "$PWD\Counter Functions\ScreenCapture\*.*" | Where { ! $_.PSIsContainer }; Remove-Item "$PWD\Counter Functions\ScreenCapture\DEBUG MODE\*.*" | Where { ! $_.PSIsContainer } }

                # Starts up Archetype Counter
                Start-Process "$PWD\ArchetypeCounter.bat" -NoNewWindow

            }

        })

        # Adds click to "Exit Counter" selection
        $ArchetypeMenuStrip.Items.Add("Exit Counter", $ArchetypeMenuStripExit).add_Click({  
        
            # Displays Message Dialog Box - If the user wants to exit or not
            $CloseLeftResult = [System.Windows.MessageBox]::Show("Do you want to EXIT the counter?","Archetype Counter","YesNo","Question")

            # Checks if Message Dialog Box "Yes" has been selected
            if ($CloseLeftResult -match "Yes") { 

                # Grabs the config file in its "current" state
                $SetConfig = "$PWD\Counter Config Files\CounterConfig_$GetProfile.txt"
                $GetConfig = Get-Content $SetConfig

                # Gets the current X and Y coordinates of the form
                $ArchetypeReplaceX = $ArchetypeForm.Bounds.Left
                $ArchetypeReplaceY = $ArchetypeForm.Bounds.Top

                # Replaces and Sets the starting position on the counter form start
                $GetConfig[18] = "Archetype_X=$ArchetypeReplaceX"
                $GetConfig[19] = "Archetype_Y=$ArchetypeReplaceY"

                # Resets Counter Active to "False" (To make menu options available again)
                $GetConfig[34] = 'Counter_Active=False'

                # Sets all changes back into the Config file
                $GetConfig | Set-Content -Path $SetConfig

                # Removes all screenshot(s) from folder (To ensure counter does not grab a previous screenshot)
                if ($DebugMode -match "False") { Remove-Item "$PWD\Counter Functions\ScreenCapture\*.*" | Where { ! $_.PSIsContainer }; Remove-Item "$PWD\Counter Functions\ScreenCapture\DEBUG MODE\*.*" | Where { ! $_.PSIsContainer } }

                # This exits the application (Winform) properly 
                [System.Windows.Forms.Application]::Exit(); Stop-Process $PID -Force 

            } 
        
        })

    # Checks if Counter is "Active" and Enable/Disable menu items accordingly
    if ($CounterActive -match "False") { $ArchetypeMenuStrip.Items[18].Enabled = $true; $ArchetypeMenuStrip.Items[19].Enabled = $false } else { $ArchetypeMenuStrip.Items[18].Enabled = $false; $ArchetypeMenuStrip.Items[19].Enabled = $true }

    #$ArchetypeMenuStrip.Items.Add("-")
    #$ArchetypeMenuStripTool27 = New-Object System.Windows.Forms.ToolStripMenuItem
    #$ArchetypeMenuStripTool27.Text = 'Hunt Mode'
    #$ArchetypeMenuStripTool27.Image = $ArchetypeMenuStripToolCounterMode
    #$ArchetypeMenuStrip.Items.Add($ArchetypeMenuStripTool27)
    #$ArchetypeMenuStripTool27.DropDownItems.Add("Normal Encounter", $ArchetypeMenuStripEdit).Add_Click({  })
    #$ArchetypeMenuStripTool27.DropDownItems.Add("Safari Encounter", $ArchetypeMenuStripEdit).Add_Click({  })

    }

    # Sets final counter menu options
    $ArchetypeImage.ShortcutsEnabled = $false
    $ArchetypeImage.ContextMenuStrip = $ArchetypeMenuStrip

    }

})


$ArchetypeForm.controls.Add($ArchetypeImage)

# Main play counter functionality
Function PlayAction {

        # Application Variable - Name
        $ApplicationName = "javaw"

        # Finds application process
        $Process = Get-Process | where {$_.mainWindowTItle } | where {$_.Name -like "$ApplicationName"}

        # Puts $Process.MainWindowHandle into a variable
        $hwnd = $Process.MainWindowHandle
 
        # Performs force active window process
        [void][ForceActiveWin]::SetForegroundWindow($hwnd)

        # Show the Stop image button and hide the play button + refresh form
        if ($CounterMode -match "Collapsed_Encounter" -or $CounterMode -match "Collapsed_Egg") { $ArchetypeMainOnImage.Visible = $false; $ArchetypeStopImage.Visible = $false } else { $ArchetypeMainOnImage.Visible = $true; $ArchetypeStopImage.Visible = $true }
        $ArchetypePlayImage.Visible = $false
        $ArchetypeMainOffImage.Visible = $false
        $ArchetypeForm.Refresh()

        # Created HashTable to pass winform controls to new runspace and back
        $Script:SyncHashTable = [Hashtable]::Synchronized(@{})
        $Script:SyncHashTable.PWD_PokeMMOPath = $PWD_PokeMMOPath
        $Script:SyncHashTable.ArchetypePokeAFile = $ArchetypePokeAFile
        $Script:SyncHashTable.ArchetypePokeAImage = $ArchetypePokeAImage
        $Script:SyncHashTable.ArchetypePokeALabelCount = $ArchetypePokeALabelCount
        $Script:SyncHashTable.ArchetypePokeBFile = $ArchetypePokeBFile
        $Script:SyncHashTable.ArchetypePokeBImage = $ArchetypePokeBImage
        $Script:SyncHashTable.ArchetypePokeBLabelCount = $ArchetypePokeBLabelCount
        $Script:SyncHashTable.ArchetypePokeCFile = $ArchetypePokeCFile
        $Script:SyncHashTable.ArchetypePokeCImage = $ArchetypePokeCImage
        $Script:SyncHashTable.ArchetypePokeCLabelCount = $ArchetypePokeCLabelCount
        $Script:SyncHashTable.ArchetypeEggLabelCount = $ArchetypeEggLabelCount
        $Script:SyncHashTable.ArchetypeCollapsedCount = $ArchetypeCollapsedCount
        $Script:SyncHashTable.ArchetypeForm = $ArchetypeForm

        # Creates a Runspace to run in a separate thread
        $RunSpace = [Management.Automation.Runspaces.RunspaceFactory]::CreateRunspace()
        $RunSpace.ApartmentState = "STA"
        $RunSpace.ThreadOptions = "ReuseThread"
        $RunSpace.Open()
        $RunSpace.SessionStateProxy.SetVariable("SyncHashTable",$Script:SyncHashTable)
        $PowerShellCmd = [Management.Automation.PowerShell]::Create().AddScript({

            # Written by Dr. Tobias Weltner (Copyright = '(c) 2021 Dr. Tobias Weltner. All rights reserved.')
            # Make sure all required assemblies are loaded BEFORE any class definitions use them:
            try {
            
                # Loads required assembly WindowsRuntime
                Add-Type -AssemblyName System.Runtime.WindowsRuntime
    
                # WinRT assemblies are loaded indirectly:
                $null = [Windows.Storage.StorageFile,                Windows.Storage,         ContentType = WindowsRuntime]
                $null = [Windows.Media.Ocr.OcrEngine,                Windows.Foundation,      ContentType = WindowsRuntime]
                $null = [Windows.Foundation.IAsyncOperation`1,       Windows.Foundation,      ContentType = WindowsRuntime]
                $null = [Windows.Graphics.Imaging.SoftwareBitmap,    Windows.Foundation,      ContentType = WindowsRuntime]
                $null = [Windows.Storage.Streams.RandomAccessStream, Windows.Storage.Streams, ContentType = WindowsRuntime]
                $null = [WindowsRuntimeSystemExtensions]
    
                # some WinRT assemblies such as [Windows.Globalization.Language] are loaded indirectly by returning
                # the object types:
                $null = [Windows.Media.Ocr.OcrEngine]::AvailableRecognizerLanguages

                # Grab the async awaiter method:
                Add-Type -AssemblyName System.Runtime.WindowsRuntime
  
                # Find the awaiter method
                $awaiter = [WindowsRuntimeSystemExtensions].GetMember('GetAwaiter', 'Method',  'Public,Static') | Where-Object { $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1' } | Select-Object -First 1

                # Define awaiter function
                Function Invoke-Async([object]$AsyncTask, [Type]$As) {
            
                    return $awaiter.
                    MakeGenericMethod($As).
                    Invoke($null, @($AsyncTask)).
                    GetResult()
                }

            }

            # Does a catch if try is not met
            Catch { throw 'OCR requires Windows 10 and Windows PowerShell. You cannot use this module in PowerShell 7' }

            # Function for the OCR on image
            Function Convert-PsoImageToText {
  
                <#
                    .SYNOPSIS
                    Converts an image file to text by using Windows 10 built-in OCR
                    .DESCRIPTION
                    Detailed Description
                    .EXAMPLE
                    Convert-ImageToText -Path c:\temp\image.png
                    Converts the image in image.png to text
                #>

                [CmdletBinding()]
                param (
                [Parameter(Mandatory,ValueFromPipeline,ValueFromPipelineByPropertyName)]
                [string]
                [Alias('FullName')]
                $Path,
    
                # Dynamically create auto-completion from available OCR languages:
                [ArgumentCompleter({
            
                    # receive information about current state:
                    param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
    
                    [Windows.Media.Ocr.OcrEngine]::AvailableRecognizerLanguages |
                    Foreach-Object {

                        # Create completionresult items:
                        $displayname = $_.DisplayName
                        $id = $_.LanguageTag
                        [System.Management.Automation.CompletionResult]::new($id, $displayname, "ParameterValue", "$displayName`r`n$id")

                    } 
                    
                })]
    
            [Windows.Globalization.Language]
            $Language

            )
  
            # Does a Begin
            Begin { 
    
                # Loads required assembly WindowsRuntime
                Add-Type -AssemblyName System.Runtime.WindowsRuntime
     
                # [Windows.Media.Ocr.OcrEngine]::AvailableRecognizerLanguages
                if ($PSBoundParameters.ContainsKey('Language')) { $ocrEngine = [Windows.Media.Ocr.OcrEngine]::TryCreateFromLanguage($Language) } else { $ocrEngine = [Windows.Media.Ocr.OcrEngine]::TryCreateFromUserProfileLanguages() }
  
                # PowerShell doesn't have built-in support for Async operations, 
                # but all the WinRT methods are Async.
                # This function wraps a way to call those methods, and wait for their results.
    
            }
  
            # Does a Process
            Process {

                # all of these methods run asynchronously because they are tailored for responsive UIs
                # PowerShell is single-threaded and synchronous so a helper function is used to 
                # run the async methods and wait for them to complete, essentially reversing the async 
                # behavior
    
                # Invoke() requires the async method and the desired return type
  
                # Get image file:
                $file = [Windows.Storage.StorageFile]::GetFileFromPathAsync($path)
                $storageFile = Invoke-Async $file -As ([Windows.Storage.StorageFile])
  
                # Read image content:
                $content = $storageFile.OpenAsync([Windows.Storage.FileAccessMode]::Read)
                $fileStream = Invoke-Async $content -As ([Windows.Storage.Streams.IRandomAccessStream])
  
                # Get bitmap decoder:
                $decoder = [Windows.Graphics.Imaging.BitmapDecoder]::CreateAsync($fileStream)
                $bitmapDecoder = Invoke-Async $decoder -As ([Windows.Graphics.Imaging.BitmapDecoder])
  
                # Decode bitmap:
                $bitmap = $bitmapDecoder.GetSoftwareBitmapAsync()
                $softwareBitmap = Invoke-Async $bitmap -As ([Windows.Graphics.Imaging.SoftwareBitmap])
  
                # Do optical text recognition (OCR) and return lines and words:
                $ocrResult = $ocrEngine.RecognizeAsync($softwareBitmap)
                (Invoke-Async $ocrResult -As ([Windows.Media.Ocr.OcrResult])).Lines | Select-Object -Property Text, @{Name='Words';Expression={$_.Words.Text}}
            }

        }

        # Loads all required assembiles for the Winform
        Add-Type -AssemblyName System.Windows.Forms; Add-Type -AssemblyName System.Drawing; Add-Type -AssemblyName PresentationCore; Add-Type -AssemblyName Presentationframework; Add-Type -AssemblyName Microsoft.VisualBasic; Add-Type -AssemblyName WindowsFormsIntegration

        # Do loop for the play functionality of the counter
        Do {

            # Loads values from external sources (Config file)
            #$SetConfig = "$PWD\Counter Config Files\CounterConfig_$GetProfile.txt"
            #$GetConfig = Get-Content $SetConfig
            #$AutoRestartCounter = $GetConfig[33] -replace 'Auto_Restart_Counter=', ''
            #$CounterLoopCount = $GetConfig[42] -replace 'Loop_Count=', ''

            # Checks for counter loop to re-open (To avoid memory issues)
            #if ($CounterLoopCount -ge "10000") { $GetConfig[42] = "Loop_Count=0"; $GetConfig[33] = "Auto_Restart_Counter=True"; $GetConfig | Set-Content -Path $SetConfig; Start-Process "$PWD\ArchetypeCounter.bat" -NoNewWindow; Break } else { $CounterLoopCount = [int]$CounterLoopCount + 1; $GetConfig[42] = "Loop_Count=$CounterLoopCount"; $GetConfig | Set-Content -Path $SetConfig }

            # Collects memory garbage - ensures no memory leak (https://docs.microsoft.com/en-us/dotnet/api/system.gc.collect?view=netframework-4.5)
            [System.GC]::Collect()         
            [GC]::Collect()
            [GC]::WaitForPendingFinalizers()
                
                # Steathly inserts changes for OCR in the PokeMMO default theme (If condition is met - rare case)
                $NewPWDPath = $Script:SyncHashTable.PWD_PokeMMOPath
                $GetDefaultBattleXML = Get-Content "$NewPWDPath\data\themes\default\ui\battle.xml"; $GetDefaultFontsXML = Get-Content "$NewPWDPath\data\themes\default\fonts.xml"
                $GetCounterStrings = Get-ChildItem -Path "$NewPWDPath\data\strings" -Recurse -Filter "*zzz_*"
                if ($GetDefaultFontsXML[22] -match "battle-name" -and $GetDefaultBattleXML[65] -match "battle-name" -and ($GetCounterStrings).Count -match "21") { } else { 

                    # Loads Counter Config file for validataion check
                    $SetConfig = "$PWD\Counter Config Files\CounterConfig_$GetProfile.txt"
                    $GetConfig = Get-Content $SetConfig

                    # Checks if PokeMMO is running - Will close down to allow the insert of .xml files to happen
                    $PokeMMOProcess = Get-Process | where {$_.mainWindowTItle } | where {$_.Name -like "javaw" }
                    if ($PokeMMOProcess -eq $null) { $PokeMMOIsActive = $false } else { $PokeMMOIsActive = $true ; Stop-Process -Name "PokeMMO" -Force; Stop-Process -Name "javaw" -Force }

                    # Specific line changes to insert back into the original .xml files
                    $GetDefaultBattleXML[65] = '		<param name="font"><font>battle-name</font></param>'; $GetDefaultBattleXML[66] = '		<param name="border"><border>0,0,7,0</border></param>'; $GetDefaultBattleXML | Set-Content -Path "$NewPWDPath\data\themes\default\ui\battle.xml"; $GetDefaultFontsXML[22] = '	<fontDef name="battle-name" filename="res/fonts/NotoSansCJK-Medium.ttc" color="#FFFFFF" border_width="1.1" border_color="#A6000000" shadow_offset_x="1" shadow_offset_y="1" shadow_color="#A6000000" size="19" hinting="Full" offsetY="-3"/>'; $GetDefaultFontsXML | Set-Content -Path "$NewPWDPath\data\themes\default\fonts.xml" 

                    # Copies counter string files into PokeMMO strings folder for Egg Delay & encounter "appeared" when using pokeball
                    Copy-Item "$PWD\Counter Sring Files\*" -Destination "$NewPWDPath\data\strings\" -Recurse -Force

                    # Removes "Eng" Unova Egg/Encounter Delay if language is NOT English (To avoid string confliction)
                    if ($SetLanguage -notmatch "English") { Remove-Item "$PWD\data\strings\a_placeholder_for_enabling_unova_edits.xml" }

                    # Waits & Restarts PokeMMO
                    if ($PokeMMOIsActive -eq $true) { Start-Sleep -Milliseconds 500; Start-Process "$NewPWDPath\PokeMMO.exe" }

                    # Displays Dialog box - Indicating change in default theme font and battle xml + String delays
                    [System.Windows.MessageBox]::Show("Values in the Default PokeMMO interface will be modified so it can support OCR detection.`n`nThese are slight adjustments to the font used for monster names in battle. The amount they are changed is almost unnoticeable to the eye. You may revert these modifications at any time by repairing your client.`n`nIn order to accurately track receiving Eggs, the Counter will add several XML files to the strings directory that will automatically load (PokeMMO\data\strings).`n`nTechnical mumbo-jumbo: OCR detection will not trigger without a readable font def and inset because letters such as; g, j, p, y, etc. hang over the HP bars.`n`nConversation where user receives an Egg from the Daycare man is now unskippable to ensure enough time to log count. Failed catch dialog also has been modified in several languages to ensure false-positive count results do not occur.","  Archetype Counter","OK","Warning")

                    # Reset Loop
                    Continue
                }

                # Checks if PokeMMO is process is actively running
                $PokeMMOActive = Get-Process -Name "PokeMMO"

                # Checks if PokeMMO is active window
                if ($PokeMMOActive -ne $null) {
                    
                    # Loads/Sets for Hunt Profile States
                    $SetProfileConfig = "$PWD\Counter Config Files\CurrentProfileState.txt"
                    $GetProfileConfig = Get-Content $SetProfileConfig
                    $GetProfile = $GetProfileConfig[7] -replace 'Current_Hunt_Profile=', ''
                    $CheckProfile1 = $GetProfileConfig[8] -replace 'Hunt_Profile_Name_1=', ''
                    $CheckProfile2 = $GetProfileConfig[9] -replace 'Hunt_Profile_Name_2=', ''
                    $CheckProfile3 = $GetProfileConfig[10] -replace 'Hunt_Profile_Name_3=', ''
                    $CheckProfile4 = $GetProfileConfig[11] -replace 'Hunt_Profile_Name_4=', ''
                    $CheckProfile5 = $GetProfileConfig[12] -replace 'Hunt_Profile_Name_5=', ''
                    if ($GetProfile -match $CheckProfile1) { $GetProfile = 'Profile1' } elseif ($GetProfile -match $CheckProfile2) { $GetProfile = 'Profile2' } elseif ($GetProfile -match $CheckProfile3) { $GetProfile = 'Profile3' } elseif ($GetProfile -match $CheckProfile4) { $GetProfile = 'Profile4' } elseif ($GetProfile -match $CheckProfile5) { $GetProfile = 'Profile5' }

                    # Loads values from external sources (Config file)
                    $SetConfig = "$PWD\Counter Config Files\CounterConfig_$GetProfile.txt"
                    $GetConfig = Get-Content $SetConfig
                    $TotalCount = $GetConfig[7] -replace 'Total_Count=', ''
                    $PokemonA = $GetConfig[8] -replace 'Pokemon_A=', ''
                    $PokemonCountA = $GetConfig[9] -replace 'Pokemon_A_Count=', ''
                    $PokemonAHover = $GetConfig[10] -replace 'Pokemon_A_Hover=', ''
                    $PokemonB = $GetConfig[11] -replace 'Pokemon_B=', ''
                    $PokemonCountB = $GetConfig[12] -replace 'Pokemon_B_Count=', ''
                    $PokemonBHover = $GetConfig[13] -replace 'Pokemon_B_Hover=', ''
                    $PokemonC = $GetConfig[14] -replace 'Pokemon_C=', ''
                    $PokemonCountC = $GetConfig[15] -replace 'Pokemon_C_Count=', ''
                    $PokemonCHover = $GetConfig[16] -replace 'Pokemon_C_Hover=', ''
                    $EggCount = $GetConfig[20] -replace 'Egg_Count=',''
                    $ShinyCount = $GetConfig[21] -replace 'Shiny_Count=',''
                    $SetLanguage = $GetConfig[23] -replace 'Set_Language=', ''
                    $EggCoolDown = $GetConfig[31] -replace 'Egg_Cooldown=', ''
                    $EggCoolDownCount = $GetConfig[32] -replace 'Egg_Cooldown_Count=', ''
                    $DebugMode = $GetConfig[35] -replace 'Debug_Mode=', ''
                    $TotalCountNoEgg = [int]$PokemonCountA + [int]$PokemonCountB + [int]$PokemonCountC
                    $TotalPokeSeenCount = $GetConfig[38] -replace 'Pokemon_Seen_Count=',''
                    $ScreenMode = $GetConfig[39] -replace 'Screen_Mode=', ''
                    $IgnoreSystemLang = $GetConfig[41] -replace 'Ignore_System_Language=', ''

                    # Ensures total count is loaded/correct
                    $TotalCount = [int]$PokemonCountA + [int]$PokemonCountB + [int]$PokemonCountC
                    $GetConfig[7] = "Total_Count=$TotalCount"

                    # Gets the current X and Y coordinates of the form
                    $ArchetypeReplaceX = $Script:SyncHashTable.ArchetypeForm.Bounds.Left
                    $ArchetypeReplaceY = $Script:SyncHashTable.ArchetypeForm.Bounds.Top

                    # Replaces and Sets the starting position on the counter form start
                    $GetConfig[18] = "Archetype_X=$ArchetypeReplaceX"
                    $GetConfig[19] = "Archetype_Y=$ArchetypeReplaceY"

                    # Checks if Egg Cooldown count is met (If it is - reset count to "0" and turn to false)
                    if ($EggCoolDownCount -ge "400") { $GetConfig[31] = "Egg_Cooldown=False"; $GetConfig[32] = "Egg_Cooldown_Count=0" }

                    # Checks if Egg Cooldown is set to "True" (If so - add +1 to count)
                    if ($EggCoolDown -eq $true) { $EggCoolDownCount = [int]$EggCoolDownCount + 1; $GetConfig[32] = "Egg_Cooldown_Count=$EggCoolDownCount" }

                    # Sets all current variables int the counter config file
                    $GetConfig | Set-Content -Path $SetConfig

                    # Re-adds varialbes back into main counter form to "update"
                    $Script:SyncHashTable.ArchetypePokeAFile = [System.Drawing.Image]::Fromfile("$PWD\Pokemon Icon Sprites\$SpriteType\$PokemonA.png")
                    $Script:SyncHashTable.ArchetypePokeAImage.Image = $Script:SyncHashTable.ArchetypePokeAFile
                    $Script:SyncHashTable.ArchetypePokeALabelCount.Text = $PokemonCountA
                    $Script:SyncHashTable.ArchetypePokeBFile = [System.Drawing.Image]::Fromfile("$PWD\Pokemon Icon Sprites\$SpriteType\$PokemonB.png")
                    $Script:SyncHashTable.ArchetypePokeBImage.Image = $Script:SyncHashTable.ArchetypePokeBFile
                    $Script:SyncHashTable.ArchetypePokeBLabelCount.Text = $PokemonCountB
                    $Script:SyncHashTable.ArchetypePokeCFile = [System.Drawing.Image]::Fromfile("$PWD\Pokemon Icon Sprites\$SpriteType\$PokemonC.png")
                    $Script:SyncHashTable.ArchetypePokeCImage.Image = $Script:SyncHashTable.ArchetypePokeCFile
                    $Script:SyncHashTable.ArchetypePokeCLabelCount.Text = $PokemonCountC
                    $Script:SyncHashTable.ArchetypeEggLabelCount.Text = $EggCount

                    # Re-adds the updated variables back into the counter config file
                    $GetConfig | Set-Content -Path $SetConfig

                    # Ensures everything on form is updated/refreshed
                    $Script:SyncHashTable.ArchetypeForm.update()
                    $Script:SyncHashTable.ArchetypeForm.refresh()

                    # Switch checks for which language has been selected on form
                    Switch ($SetLanguage) {
   
                        "English" { $LangTag = 'en'; break }
                        "German" { $LangTag = 'de'; break }
                        "French" { $LangTag = 'fr'; break }
                        "Spanish" { $LangTag = 'es'; break }
                        "Italian" { $LangTag = 'it'; break }
                        "Brazilian Portuguese" { $LangTag = 'pt-BR'; break }
                        "Polish" { $LangTag = 'pl'; break }

                    }

                    # Resets variable
                    $OCRCapturedHordeNumber = ''
                    $OCRCaptured = ''
                    $OCRCapturedHordeNumberCount = ''
                    $TotalPokeSeenCountAmend = ''

                    # Checks if SreenMode is set to 720p/HD/4K for image cropping
                    if ($ScreenMode -match "HD") {

                        # Calls the AHK .exe "ScreenCapture" to take/request screenshot of PokeMMO window directly (Without using Windows screenshot method)
                        $ScreenCaptureCall = "$PWD\Counter Functions\ScreenCapture\HD\ScreenCapture.exe"
                        Start-Process -WindowStyle hidden $ScreenCaptureCall -Wait

                    } elseif ($ScreenMode -match "720") {

                        # Calls the AHK .exe "ScreenCapture4K" to take/request screenshot of PokeMMO window directly (Without using Windows screenshot method)
                        $ScreenCaptureCall = "$PWD\Counter Functions\ScreenCapture\720p\ScreenCapture720.exe"
                        Start-Process -WindowStyle hidden $ScreenCaptureCall -Wait

                    } else {

                        # Calls the AHK .exe "ScreenCapture4K" to take/request screenshot of PokeMMO window directly (Without using Windows screenshot method)
                        $ScreenCaptureCall = "$PWD\Counter Functions\ScreenCapture\4K\ScreenCapture4K.exe"
                        Start-Process -WindowStyle hidden $ScreenCaptureCall -Wait

                    }

                    # Loads the OCR module into a variable
                    if ($IgnoreSystemLang -match "True") { $OCRVariable = Convert-PsoImageToText -Path "$PWD\Counter Functions\ScreenCapture\ArchetypeScreenshot.png" } else { $OCRVariable = Convert-PsoImageToText -Path "$PWD\Counter Functions\ScreenCapture\ArchetypeScreenshot.png" -Language $LangTag; if($?) { } else { $OCRVariable = Convert-PsoImageToText -Path "$PWD\Counter Functions\ScreenCapture\ArchetypeScreenshot.png" -Language en } }
                    if ($OCRVariable -eq $null) { $OCRVariable = Convert-PsoImageToText -Path "$PWD\Counter Functions\ScreenCapture\ArchetypeScreenshot.png" }
                    $OCRVariable.text; $OCRCaptured = $OCRVariable.text

                    # Checks if the word "appeared" is on the screenshot
                    if (($OCRCaptured -match "received egg" -or $OCRCaptured -match "oeuf recu" -or $OCRCaptured -match "ei erhalten" -or $OCRCaptured -match "huevo recibido" -or $OCRCaptured -match "ovo recebido" -or $OCRCaptured -match "uovo ricevuto" -or $OCRCaptured -match "otrzymane jajko") -and ($EggCoolDownCount -match "0")) {

                         # Grabs current counter config file state
                         $SetConfig = "$PWD\Counter Config Files\CounterConfig_$GetProfile.txt"
                         $GetConfig = Get-Content $SetConfig

                         # Sets the Egg Cooldown to "True"
                         $GetConfig[31] = "Egg_Cooldown=True"

                         # Increments the count by 1 (Egg Slot)
                         $GetEggCountForm = $GetConfig[20] -replace 'Egg_Count=', ''
                         $GetEggCountForm = [int]$GetEggCountForm + 1

                         # Adds correct new count to egg slot
                         $GetConfig[20] = "Egg_Count=$GetEggCountForm"

                         # Sets all changes back into the Config file
                         $GetConfig | Set-Content -Path $SetConfig

                         # Wait
                         Start-Sleep -Seconds 2

                         # Break current loop and re-try
                         Continue

                    }

                    # Loads the OCR module into a variable
                    if ($IgnoreSystemLang -match "True") { $OCRVariable = Convert-PsoImageToText -Path "$PWD\Counter Functions\ScreenCapture\ArchetypeScreenshot.png" } else { $OCRVariable = Convert-PsoImageToText -Path "$PWD\Counter Functions\ScreenCapture\ArchetypeScreenshot.png" -Language $LangTag; if($?) { } else { $OCRVariable = Convert-PsoImageToText -Path "$PWD\Counter Functions\ScreenCapture\ArchetypeScreenshot.png" -Language en } }
                    if ($OCRVariable -eq $null) { $OCRVariable = Convert-PsoImageToText -Path "$PWD\Counter Functions\ScreenCapture\ArchetypeScreenshot.png" }
                    $OCRVariable.text; $OCRCaptured = $OCRVariable.text

                    # Checks if the word "appeared" is on the screenshot
                    if (($OCRCaptured | Where-Object { $_ -match '\bappeared\b' }) -or ($OCRCaptured | Where-Object { $_ -match '\bapareció\b' }) -or ($OCRCaptured | Where-Object { $_ -match '\berscheint\b' }) -or ($OCRCaptured | Where-Object { $_ -match '\btauchte auf\b' }) -or ($OCRCaptured | Where-Object { $_ -match '\bapparaît\b' }) -or ($OCRCaptured | Where-Object { $_ -match '\bapareceu\b' }) -or ($OCRCaptured | Where-Object { $_ -match '\bsalvaje\b' }) -or ($OCRCaptured | Where-Object { $_ -match '\bpojawiła się\b' }) -or ($OCRCaptured | Where-Object { $_ -match '\bpojawił się\b' })) {

                        # Wait
                        Start-Sleep -Milliseconds 85

                        # Checks if SreenMode is set to 720p/HD/4K for image cropping
                        if ($ScreenMode -match "HD") {

                            # (WHEN DEBUGGING MODE IS TURN ON!)
                            if ($DebugMode -match "True") { 
                            
                                # Creates a Runspace to run in a separate thread
                                $RunSpace = [Management.Automation.Runspaces.RunspaceFactory]::CreateRunspace()
                                $RunSpace.ApartmentState = "STA"
                                $RunSpace.ThreadOptions = "ReuseThread"
                                $RunSpace.Open()
                                $RunSpace.SessionStateProxy.SetVariable("SyncHashTable",$Script:SyncHashTable)
                                $PowerShellCmd = [Management.Automation.PowerShell]::Create().AddScript({

                                    # Converts PokeMMO image for better readability with NConvert (For OCR detection) - HD
                                    $ScreenCaptureCall = "$PWD\Counter Functions\ScreenCapture\HD\ScreenCaptureEncounterDEBUG.exe"
                                    Start-Process -WindowStyle hidden $ScreenCaptureCall -Wait

                                    $NConvertCall = "$PWD\Counter Functions\NConvert\nconvert.exe"
                                    $CallArguements = "-contrast 90 -exposure 50 -overwrite ""$PWD\Counter Functions\ScreenCapture\DEBUG MODE\ArchetypeScreenshot_DEBUG.png"""
                                    Start-Process -WindowStyle hidden $NConvertCall $CallArguements -Wait

                                })

                                # This section is needed for the PowerShell runspace invoke
                                $PowerShellCmd.Runspace = $RunSpace
                                $PSAsyncObject = $PowerShellCmd.BeginInvoke()

                            }

                            # Calls the AHK .exe "ScreenCaptureEncounter" to take/request screenshot of PokeMMO window directly (Without using Windows screenshot method)
                            $ScreenCaptureCall = "$PWD\Counter Functions\ScreenCapture\HD\ScreenCaptureEncounter.exe"
                            Start-Process -WindowStyle hidden $ScreenCaptureCall -Wait

                            # Converts PokeMMO image for better readability with NConvert (For OCR detection) - HD
                            $NConvertCall = "$PWD\Counter Functions\NConvert\nconvert.exe"
                            $CallArguements = "-contrast 90 -exposure 50 -overwrite ""$PWD\Counter Functions\ScreenCapture\ArchetypeScreenshot.png"""
                            Start-Process -WindowStyle hidden $NConvertCall $CallArguements -Wait

                        } elseif ($ScreenMode -match "720") {

                            # (WHEN DEBUGGING MODE IS TURN ON!)
                            if ($DebugMode -match "True") { 
                            
                                # Creates a Runspace to run in a separate thread
                                $RunSpace = [Management.Automation.Runspaces.RunspaceFactory]::CreateRunspace()
                                $RunSpace.ApartmentState = "STA"
                                $RunSpace.ThreadOptions = "ReuseThread"
                                $RunSpace.Open()
                                $RunSpace.SessionStateProxy.SetVariable("SyncHashTable",$Script:SyncHashTable)
                                $PowerShellCmd = [Management.Automation.PowerShell]::Create().AddScript({

                                    # Converts PokeMMO image for better readability with NConvert (For OCR detection) - HD
                                    $ScreenCaptureCall = "$PWD\Counter Functions\ScreenCapture\720p\ScreenCapture720EncounterDEBUG.exe"
                                    Start-Process -WindowStyle hidden $ScreenCaptureCall -Wait

                                    $NConvertCall = "$PWD\Counter Functions\NConvert\nconvert.exe"
                                    $CallArguements = "-contrast 90 -exposure 50 -overwrite ""$PWD\Counter Functions\ScreenCapture\DEBUG MODE\ArchetypeScreenshot_720_DEBUG.png"""
                                    Start-Process -WindowStyle hidden $NConvertCall $CallArguements -Wait

                                })

                                # This section is needed for the PowerShell runspace invoke
                                $PowerShellCmd.Runspace = $RunSpace
                                $PSAsyncObject = $PowerShellCmd.BeginInvoke()

                            }

                            # Calls the AHK .exe "ScreenCaptureEncounter" to take/request screenshot of PokeMMO window directly (Without using Windows screenshot method)
                            $ScreenCaptureCall = "$PWD\Counter Functions\ScreenCapture\720p\ScreenCapture720Encounter.exe"
                            Start-Process -WindowStyle hidden $ScreenCaptureCall -Wait

                            # Converts PokeMMO image for better readability with NConvert (For OCR detection) - HD
                            $NConvertCall = "$PWD\Counter Functions\NConvert\nconvert.exe"
                            $CallArguements = "-contrast 90 -exposure 50 -overwrite ""$PWD\Counter Functions\ScreenCapture\ArchetypeScreenshot.png"""
                            Start-Process -WindowStyle hidden $NConvertCall $CallArguements -Wait

                        } else {

                            
                            # (WHEN DEBUGGING MODE IS TURN ON!) - 4K
                            if ($DebugMode -match "True") { 
                            
                                # Creates a Runspace to run in a separate thread
                                $RunSpace = [Management.Automation.Runspaces.RunspaceFactory]::CreateRunspace()
                                $RunSpace.ApartmentState = "STA"
                                $RunSpace.ThreadOptions = "ReuseThread"
                                $RunSpace.Open()
                                $RunSpace.SessionStateProxy.SetVariable("SyncHashTable",$Script:SyncHashTable)
                                $PowerShellCmd = [Management.Automation.PowerShell]::Create().AddScript({

                                    # Converts PokeMMO image for better readability with NConvert (For OCR detection) - 4K
                                    $ScreenCaptureCall = "$PWD\Counter Functions\ScreenCapture\4K\ScreenCapture4KEncounterDEBUG.exe"
                                    Start-Process -WindowStyle hidden $ScreenCaptureCall -Wait
                                    
                                    $NConvertCall = "$PWD\Counter Functions\NConvert\nconvert.exe"
                                    $CallArguements = "-contrast 90 -exposure 50 -overwrite ""$PWD\Counter Functions\ScreenCapture\DEBUG MODE\ArchetypeScreenshot_4K_DEBUG.png"""
                                    Start-Process -WindowStyle hidden $NConvertCall $CallArguements -Wait

                                })

                                # This section is needed for the PowerShell runspace invoke
                                $PowerShellCmd.Runspace = $RunSpace
                                $PSAsyncObject = $PowerShellCmd.BeginInvoke()

                            }

                            # Calls the AHK .exe "ScreenCapture4KEncounter" to take/request screenshot of PokeMMO window directly (Without using Windows screenshot method)
                            $ScreenCaptureCall = "$PWD\Counter Functions\ScreenCapture\4K\ScreenCapture4KEncounter.exe"
                            Start-Process -WindowStyle hidden $ScreenCaptureCall -Wait

                            # Converts PokeMMO image for better readability with NConvert (For OCR detection) - HD
                            $NConvertCall = "$PWD\Counter Functions\NConvert\nconvert.exe"
                            $CallArguements = "-contrast 90 -exposure 50 -overwrite ""$PWD\Counter Functions\ScreenCapture\ArchetypeScreenshot.png"""
                            Start-Process -WindowStyle hidden $NConvertCall $CallArguements -Wait

                        }

                        # Loads the OCR module into a variable
                        if ($IgnoreSystemLang -match "True") { $OCRVariable = Convert-PsoImageToText -Path "$PWD\Counter Functions\ScreenCapture\ArchetypeScreenshot.png" } else { $OCRVariable = Convert-PsoImageToText -Path "$PWD\Counter Functions\ScreenCapture\ArchetypeScreenshot.png" -Language $LangTag; if($?) { } else { $OCRVariable = Convert-PsoImageToText -Path "$PWD\Counter Functions\ScreenCapture\ArchetypeScreenshot.png" -Language en } }
                        if ($OCRVariable -eq $null) { $OCRVariable = Convert-PsoImageToText -Path "$PWD\Counter Functions\ScreenCapture\ArchetypeScreenshot.png" }
                        $OCRVariable.text; $OCRCaptured = $OCRVariable.text

                        # (WHEN DEBUGGING MODE IS TURN ON!)
                        if ($DebugMode -match "True") { $OCRCaptured | Out-File "$PWD\Counter Functions\ScreenCapture\DEBUG MODE\DEBUG_OCR_BeforeLogic.txt" }

                        # Removes everything in Pokemon Name - Except the name itself
                        $OCRCaptured = $OCRCaptured | Where-Object { $_.Length -ne '1' }; $OCRCaptured = $OCRCaptured.Substring(0, $OCRCaptured.lastIndexOf('lv.')); $OCRCaptured = $OCRCaptured.Substring(0, $OCRCaptured.lastIndexOf('Lv.')); $OCRCaptured = $OCRCaptured.Substring(0, $OCRCaptured.lastIndexOf('LV.')); $OCRCaptured = $OCRCaptured.Substring(0, $OCRCaptured.lastIndexOf('lvl.')); $OCRCaptured = $OCRCaptured.Substring(0, $OCRCaptured.lastIndexOf('Lvl.')); $OCRCaptured = $OCRCaptured.Substring(0, $OCRCaptured.lastIndexOf('nv.')); $OCRCaptured = $OCRCaptured.Substring(0, $OCRCaptured.lastIndexOf('Nv.')); $OCRCaptured = $OCRCaptured.Substring(0, $OCRCaptured.lastIndexOf('NV.')); $OCRCaptured = $OCRCaptured.Substring(0, $OCRCaptured.lastIndexOf('Niv.')); $OCRCaptured = $OCRCaptured.Substring(0, $OCRCaptured.lastIndexOf('NIV.')); $OCRCaptured = $OCRCaptured.Replace('?','').Replace('•','').Replace('8 Z','').Replace('8 e',''); $OCRCaptured = $OCRCaptured.Replace(' ee','').Replace('  ee',''); $OCRCaptured = $OCRCaptured.Replace(' e','').Replace('  e',''); $OCRCaptured = $OCRCaptured.Replace(',',''); $OCRCaptured = $OCRCaptured -Replace '[0-9]',''; $OCRCaptured = $OCRCaptured -replace [regex]::escape('Lv.'),'' -replace [regex]::escape('L v'),'' -replace [regex]::escape('Lvl.'),'' -replace [regex]::escape('L vl'),'' -replace [regex]::escape('Lv l'),'' -replace [regex]::escape('L v l'),'' -replace [regex]::escape('Nv.'),'' -replace [regex]::escape('N v'),'' -replace [regex]::escape('Niv.'),'' -replace [regex]::escape('Ni v'),'' -replace [regex]::escape('N iv'),'' -replace [regex]::escape('N i v'),'' -replace [regex]::escape('.r'),'' -replace [regex]::escape('.'),'' -replace [regex]::escape("'"),""; $OCRCaptured = $OCRCaptured -replace ' C', '' -replace ' Z', ''; $OCRCaptured = $OCRCaptured -replace '\s+', ''; $OCRCaptured = $OCRCaptured | where { $_ -ne "" }; $OCRCaptured = $OCRCaptured.Replace('*',' 29').Replace('&',' 32').Replace('a"',' 32').Replace('Shiny','Shiny '); $OCRCaptured = $OCRCaptured | Where-Object { $_.Length -ne '1' }

                        # Special check for Mr Mime & Nidoran on OCR check
                        if ($OCRCaptured -match "MrMime") { $OCRCaptured = $OCRCaptured.Replace('MrMime','Mr. Mime') }
                        if ($OCRCaptured -match "MMime") { $OCRCaptured = $OCRCaptured.Replace('MMime','M. Mime') }
                        if ($OCRCaptured -notmatch "Nidoran") { $OCRCaptured = $OCRCaptured -Replace '[0-9]',''; $OCRCaptured = $OCRCaptured -Replace ' ','' }
                        
                        # Checks if "Alpha" Pokemon is found
                        if ($OCRCaptured -match "Alpha") { 
                        
                            # Match logic to count all "Alpha" pokemon found
                            $Regex = "Alpha"; $ReplaceWith = ""; $Count = 0; $Result = [regex]::Replace($OCRCaptured, $Regex, { param($found); $Global:Count++; return $found.Result($ReplaceWith) }); $Count

                            # Adds the count results back into variable (With word "Alpha" removed)
                            $OCRCaptured = $Result; $OCRCaptured = $OCRCaptured -Replace ' ',''

                            # Grabs current counter config file state
                            $SetConfig = "$PWD\Counter Config Files\CounterConfig_$GetProfile.txt"
                            $GetConfig = Get-Content $SetConfig

                            # Increments the count by 1 (Pokemon - Shiny)
                            $GetPokeAlphaCountForm = $GetConfig[40] -replace 'Alpha_Count=', ''
                            $GetPokeAlphaCountForm = [int]$GetPokeShinyCountForm + [int]$Count

                            # Adds correct new count to Shiney Pokemon 
                            $GetConfig[40] = "Alpha_Count=$GetPokeAlphaCountForm"

                            # Sets all changes back into the Config file
                            $GetConfig | Set-Content -Path $SetConfig
                        
                        }

                        # Re-adjust Nidoran name and dex # for matching
                        if ($OCRCaptured -match "Nidoran") { $OCRCaptured = $OCRCaptured -Replace 'Nidoran29','Nidoran 29'; $OCRCaptured = $OCRCaptured -Replace 'Nidoran  29','Nidoran 29'; $OCRCaptured = $OCRCaptured -Replace 'Nidoran32','Nidoran 32'; $OCRCaptured = $OCRCaptured -Replace 'Nidoran  32','Nidoran 32' }

                        # (WHEN DEBUGGING MODE IS TURN ON!)
                        if ($DebugMode -match "True") { $OCRCaptured | Out-File "$PWD\Counter Functions\ScreenCapture\DEBUG MODE\DEBUG_OCR_AfterLogic.txt" }

                        # Grabs current counter config file state
                        $SetConfig = "$PWD\Counter Config Files\CounterConfig_$GetProfile.txt"
                        $GetConfig = Get-Content $SetConfig

                        # Increments Pokemon seen count by correct value (FOR TOTAL ENCOUNTERED POKEMON)
                        $OCRCapturedHordeNumberCount = ($OCRCaptured | Measure-Object -Line).Lines
                        $TotalPokeSeenCountAmend = [int]$TotalPokeSeenCount + [int]$OCRCapturedHordeNumberCount
                        $GetConfig[38] = "Pokemon_Seen_Count=$TotalPokeSeenCountAmend"

                        # Sets all changes back into the Config file
                        $GetConfig | Set-Content -Path $SetConfig

                        # Automatically count/adjust number value when in collapsed mode
                        $Script:SyncHashTable.ArchetypeCollapsedCount.Text = $TotalPokeSeenCountAmend

                        # Ensures everything on form is updated/refreshed
                        $Script:SyncHashTable.ArchetypeForm.update()
                        $Script:SyncHashTable.ArchetypeForm.refresh()

                        # Counts number of lines for a Pokemon HORDE
                        $OCRCapturedHordeNumber = ($OCRCaptured | Measure-Object -Line).Lines; if ($OCRCapturedHordeNumber -eq "1") { $OCRCapturedHordeNumber = 0 }
                        if ($OCRCapturedHordeNumber -gt "1") { $OCRCaptured = $OCRCaptured | Select-Object -First 1 -Skip 2 }

                        # (WHEN DEBUGGING MODE IS TURN ON!)
                        if ($DebugMode -match "True") { $OCRCapturedHordeNumber | Out-File "$PWD\Counter Functions\ScreenCapture\DEBUG MODE\DEBUG_OCR_HordeLogic_Count.txt" }

                        # Grabs and loads + compares to the captures OCR text
                        $SetPokeConfig = "$PWD\Counter Config Files\PokemonNamesWithID_$SetLanguage.txt" 
                        $GetPokeConfig = Get-Content $SetPokeConfig
                        $GetPokemonWithIDFromFile = $GetPokeConfig | Where-Object { $_ -match "$OCRCaptured" } | Select -First 1
                        $GetPokemonID = $GetPokemonWithIDFromFile -Replace '[^0-9]','' -Replace ' ', ''
                        $GetPokemonName = $GetPokemonWithIDFromFile -Replace '[0-9]','' -Replace ' ', ''
                        $CheckForShiny = $OCRCaptured -match 'Shiny'

                        # Loads capture Poke ID into variable for comparison (Increased seen count) + Detection count
                        $ComparePokeA_ID = $GetConfig[8] -replace 'Pokemon_A=', ''
                        $ComparePokeA_Blank = $GetConfig[8] -replace 'Pokemon_A=', ''
                        $ComparePokeB_ID = $GetConfig[11] -replace 'Pokemon_B=', ''
                        $ComparePokeB_Blank = $GetConfig[11] -replace 'Pokemon_B=', ''
                        $ComparePokeC_ID = $GetConfig[14] -replace 'Pokemon_C=', ''
                        $ComparePokeC_Blank = $GetConfig[14] -replace 'Pokemon_C=', ''
                        $DetectionCount = $GetConfig[17] -replace 'Detection_Count=', ''

                        # Checks if current just seen pokemon is a "Shiny"
                        if ($CheckForShiny -eq $true) {

                            # Grabs current counter config file state
                            $SetConfig = "$PWD\Counter Config Files\CounterConfig_$GetProfile.txt"
                            $GetConfig = Get-Content $SetConfig

                            # Increments the count by 1 (Pokemon - Shiny)
                            $GetPokeShinyCountForm = $GetConfig[21] -replace 'Shiny_Count=', ''
                            $GetPokeShinyCountForm = [int]$GetPokeShinyCountForm + 1

                            # Adds correct new count to Shiney Pokemon 
                            $GetConfig[21] = "Shiny_Count=$GetPokeShinyCountForm"

                            # Sets all changes back into the Config file
                            $GetConfig | Set-Content -Path $SetConfig

                            # Removes the word shiny out of the Pokemon name
                            $GetPokemonNameNoShiny = $OCRCaptured -replace 'Shiny', '' -Replace '[0-9]','' -Replace ' ', ''

                            # Displays Message Dialog Box - For a Shiny Pokemon encounter
                            [Microsoft.VisualBasic.Interaction]::MsgBox("You have found a SHINY $GetPokemonNameNoShiny!", "OKOnly,SystemModal,Information", "Archetype Shiny Pokemon")

                            # Sets the flag for the counter to not Auto Start on "Stop"
                            $GetConfig[33] = "Auto_Restart_Counter=True"

                            # Sets all changes back into the Config file
                            $GetConfig | Set-Content -Path $SetConfig

                            # Removes all screenshot(s) from folder (To ensure counter does not grab a previous screenshot)
                            if ($DebugMode -match "False") { Remove-Item "$PWD\Counter Functions\ScreenCapture\*.*" | Where { ! $_.PSIsContainer }; Remove-Item "$PWD\Counter Functions\ScreenCapture\DEBUG MODE\*.*" | Where { ! $_.PSIsContainer } }

                            # Restarts counter to update form
                            Start-Process "$PWD\ArchetypeCounter.bat" -NoNewWindow

                            # Break current loop and re-try
                            Continue

                        }

                        # Checks if Pokemon capture names from OCR is blank/null
                        if ([string]::IsNullOrEmpty($GetPokemonWithIDFromFile) -or [string]::IsNullOrWhitespace($GetPokemonWithIDFromFile) -or $GetPokemonWithIDFromFile -eq $null) {

                            # Creates a Runspace to run in a separate thread
                            $RunSpace = [Management.Automation.Runspaces.RunspaceFactory]::CreateRunspace()
                            $RunSpace.ApartmentState = "STA"
                            $RunSpace.ThreadOptions = "ReuseThread"
                            $RunSpace.Open()
                            $RunSpace.SessionStateProxy.SetVariable("SyncHashTable",$Script:SyncHashTable)
                            $PowerShellCmd = [Management.Automation.PowerShell]::Create().AddScript({

                                # Creates a Windows Balloon popup to indicate PokeMMO is not active window (If $ActiveWindow does not equal PokeMMO)
                                $WindowBallonPopup = New-Object System.Windows.Forms.NotifyIcon
                                $ProcessIconPath = (Get-Process -id $pid).Path
                                $WindowBallonPopup.Icon = [System.Drawing.Icon]::ExtractAssociatedIcon($ProcessIconPath)
                                $WindowBallonPopup.BalloonTipIcon = [System.Windows.Forms.ToolTipIcon]::Warning
                                $WindowBallonPopup.BalloonTipText = "Cannot scan current Pokémon. (Increase Pokémon count manually.)"
                                $WindowBallonPopup.BalloonTipTitle = "Archetype Counter"
                                $WindowBallonPopup.Visible = $true
                                $WindowBallonPopup.ShowBalloonTip(3000)

                                # Waits
                                Start-Sleep -Seconds 3

                                # Disposes the generated Windows Balloon popup
                                $WindowBallonPopup.Visible = $false
                                $WindowBallonPopup.Icon = $null
                                $WindowBallonPopup.Icon.Dispose()
                                $WindowBallonPopup.Dispose()

                                # Starts up the NoTrayOprhans.exe AHK script (Clears out Archetype icons that are left in the system tray)
                                Start-Process "$PWD\Counter Functions\NoTrayOprhans\NoTrayOrphans.exe"

                            })

                            # This section is needed for the PowerShell runspace invoke
                            $PowerShellCmd.Runspace = $RunSpace
                            $PSAsyncObject = $PowerShellCmd.BeginInvoke()

                            # Waits
                            Start-Sleep -Seconds 3

                            # Sets all changes back into the Config file
                            $GetConfig | Set-Content -Path $SetConfig

                            # Break current loop and re-try
                            Continue

                        } 

                        # Checks for pokemon slot 1 and if it is blank (To add pokemon seen)
                        elseif ($ComparePokeA_Blank -match "Blank") {

                            # Grabs current counter config file state
                            $SetConfig = "$PWD\Counter Config Files\CounterConfig_$GetProfile.txt"
                            $GetConfig = Get-Content $SetConfig

                            # Resets Pokemon slot 1 on form with Pokedex ID and Name
                            $GetConfig[8] = "Pokemon_A=$GetPokemonID"
                            $GetConfig[10] = "Pokemon_A_Hover=$GetPokemonName #$GetPokemonID" 

                            # Properly sets the initial Pokemon Count for the form
                            $GetPokeNameACountForm = $GetConfig[9] -replace 'Pokemon_A_Count=', ''
                            if ($OCRCapturedHordeNumber -eq "0") { $OCRCapturedHordeNumber = 1 }
                            $GetPokeNameACountForm = [int]$OCRCapturedHordeNumber
                            $GetConfig[9] = "Pokemon_A_Count=$GetPokeNameACountForm" 

                            # Sets the flag for the counter to not Auto Start on "Stop"
                            $GetConfig[33] = "Auto_Restart_Counter=True"

                            # Sets all changes back into the Config file
                            $GetConfig | Set-Content -Path $SetConfig

                            # Removes all screenshot(s) from folder (To ensure counter does not grab a previous screenshot)
                            if ($DebugMode -match "False") { Remove-Item "$PWD\Counter Functions\ScreenCapture\*.*" | Where { ! $_.PSIsContainer }; Remove-Item "$PWD\Counter Functions\ScreenCapture\DEBUG MODE\*.*" | Where { ! $_.PSIsContainer } }

                            # Restarts counter to update form
                            Start-Process "$PWD\ArchetypeCounter.bat" -NoNewWindow

                            # Break current loop and re-try
                            Break

                        # Checks if same Pokemon has already been seen
                        } elseif($GetPokemonID -match $ComparePokeA_ID) {

                            # Grabs current counter config file state
                            $SetConfig = "$PWD\Counter Config Files\CounterConfig_$GetProfile.txt"
                            $GetConfig = Get-Content $SetConfig

                            # Increments the count by 1 (Pokemon seen)
                            $GetPokeNameACountForm = $GetConfig[9] -replace 'Pokemon_A_Count=', ''
                            if ($OCRCapturedHordeNumber -eq "0") { $OCRCapturedHordeNumber = 1 }
                            $GetPokeNameACountForm = [int]$GetPokeNameACountForm + [int]$OCRCapturedHordeNumber

                            # Adds correct new count to Pokemon slot 1 seen
                            $GetConfig[9] = "Pokemon_A_Count=$GetPokeNameACountForm"

                            # Sets all changes back into the Config file
                            $GetConfig | Set-Content -Path $SetConfig

                            # Removes all screenshot(s) from folder (To ensure counter does not grab a previous screenshot)
                            if ($DebugMode -match "False") { Remove-Item "$PWD\Counter Functions\ScreenCapture\*.*" | Where { ! $_.PSIsContainer }; Remove-Item "$PWD\Counter Functions\ScreenCapture\DEBUG MODE\*.*" | Where { ! $_.PSIsContainer } }

                            # Break current loop and re-try
                            Continue

                        # Checks for pokemon slot 2 and if it is blank (To add pokemon seen)
                        } elseif($ComparePokeB_Blank -match "Blank" -and $DetectionCount -ge "2") {

                            # Grabs current counter config file state
                            $SetConfig = "$PWD\Counter Config Files\CounterConfig_$GetProfile.txt"
                            $GetConfig = Get-Content $SetConfig

                            # Resets Pokemon slot 2 on form with Pokedex ID and Name
                            $GetConfig[11] = "Pokemon_B=$GetPokemonID"
                            $GetConfig[13] = "Pokemon_B_Hover=$GetPokemonName #$GetPokemonID"

                            # Properly sets the initial Pokemon Count for the form
                            $GetPokeNameBCountForm = $GetConfig[12] -replace 'Pokemon_B_Count=', ''
                            if ($OCRCapturedHordeNumber -eq "0") { $OCRCapturedHordeNumber = 1 }
                            $GetPokeNameBCountForm = [int]$OCRCapturedHordeNumber
                            $GetConfig[12] = "Pokemon_B_Count=$GetPokeNameBCountForm"

                            # Sets the flag for the counter to not Auto Start on "Stop"
                            $GetConfig[33] = "Auto_Restart_Counter=True"

                            # Sets all changes back into the Config file
                            $GetConfig | Set-Content -Path $SetConfig

                            # Removes all screenshot(s) from folder (To ensure counter does not grab a previous screenshot)
                            if ($DebugMode -match "False") { Remove-Item "$PWD\Counter Functions\ScreenCapture\*.*" | Where { ! $_.PSIsContainer }; Remove-Item "$PWD\Counter Functions\ScreenCapture\DEBUG MODE\*.*" | Where { ! $_.PSIsContainer } }

                            # Restarts counter to update form
                            Start-Process "$PWD\ArchetypeCounter.bat" -NoNewWindow

                            # Break current loop and re-try
                            Break

                        # Checks if same Pokemon slot 2 has already been seen
                        } elseif($GetPokemonID -match $ComparePokeB_ID -and $DetectionCount -ge "2") {

                            # Grabs current counter config file state
                            $SetConfig = "$PWD\Counter Config Files\CounterConfig_$GetProfile.txt"
                            $GetConfig = Get-Content $SetConfig

                            # Increments the count by 1 (Pokemon seen)
                            $GetPokeNameBCountForm = $GetConfig[12] -replace 'Pokemon_B_Count=', ''
                            if ($OCRCapturedHordeNumber -eq "0") { $OCRCapturedHordeNumber = 1 }
                            $GetPokeNameBCountForm = [int]$GetPokeNameBCountForm + [int]$OCRCapturedHordeNumber

                            # Adds correct new count to Pokemon slot 1 seen
                            $GetConfig[12] = "Pokemon_B_Count=$GetPokeNameBCountForm"

                            # Sets all changes back into the Config file
                            $GetConfig | Set-Content -Path $SetConfig

                            # Removes all screenshot(s) from folder (To ensure counter does not grab a previous screenshot)
                            if ($DebugMode -match "False") { Remove-Item "$PWD\Counter Functions\ScreenCapture\*.*" | Where { ! $_.PSIsContainer }; Remove-Item "$PWD\Counter Functions\ScreenCapture\DEBUG MODE\*.*" | Where { ! $_.PSIsContainer } }

                            # Break current loop and re-try
                            Continue

                        # Checks for pokemon slot 3 and if it is blank (To add pokemon seen)
                        } elseif($ComparePokeC_Blank -match "Blank" -and $DetectionCount -match "3") {

                            # Grabs current counter config file state
                            $SetConfig = "$PWD\Counter Config Files\CounterConfig_$GetProfile.txt"
                            $GetConfig = Get-Content $SetConfig

                            # Resets Pokemon slot 3 on form with Pokedex ID and Name
                            $GetConfig[14] = "Pokemon_C=$GetPokemonID"
                            $GetConfig[16] = "Pokemon_C_Hover=$GetPokemonName #$GetPokemonID"

                            # Properly sets the initial Pokemon Count for the form
                            $GetPokeNameCCountForm = $GetConfig[15] -replace 'Pokemon_C_Count=', ''
                            if ($OCRCapturedHordeNumber -eq "0") { $OCRCapturedHordeNumber = 1 }
                            $GetPokeNameCCountForm = [int]$OCRCapturedHordeNumber
                            $GetConfig[15] = "Pokemon_C_Count=$GetPokeNameCCountForm"

                            # Sets the flag for the counter to not Auto Start on "Stop"
                            $GetConfig[33] = "Auto_Restart_Counter=True"

                            # Sets all changes back into the Config file
                            $GetConfig | Set-Content -Path $SetConfig

                            # Removes all screenshot(s) from folder (To ensure counter does not grab a previous screenshot)
                            if ($DebugMode -match "False") { Remove-Item "$PWD\Counter Functions\ScreenCapture\*.*" | Where { ! $_.PSIsContainer }; Remove-Item "$PWD\Counter Functions\ScreenCapture\DEBUG MODE\*.*" | Where { ! $_.PSIsContainer } }

                            # Restarts counter to update form
                            Start-Process "$PWD\ArchetypeCounter.bat" -NoNewWindow

                            # Break current loop and re-try
                            Break

                        # Checks if same Pokemon slot 3 has already been seen
                        } elseif($GetPokemonID -match $ComparePokeC_ID -and $DetectionCount -match "3") {

                            # Grabs current counter config file state
                            $SetConfig = "$PWD\Counter Config Files\CounterConfig_$GetProfile.txt"
                            $GetConfig = Get-Content $SetConfig

                            # Increments the count by 1 (Pokemon seen)
                            $GetPokeNameCCountForm = $GetConfig[15] -replace 'Pokemon_C_Count=', ''
                            if ($OCRCapturedHordeNumber -eq "0") { $OCRCapturedHordeNumber = 1 }
                            $GetPokeNameCCountForm = [int]$GetPokeNameCCountForm + [int]$OCRCapturedHordeNumber

                            # Adds correct new count to Pokemon slot 1 seen
                            $GetConfig[15] = "Pokemon_C_Count=$GetPokeNameCCountForm"

                            # Sets all changes back into the Config file
                            $GetConfig | Set-Content -Path $SetConfig

                            # Removes all screenshot(s) from folder (To ensure counter does not grab a previous screenshot)
                            if ($DebugMode -match "False") { Remove-Item "$PWD\Counter Functions\ScreenCapture\*.*" | Where { ! $_.PSIsContainer }; Remove-Item "$PWD\Counter Functions\ScreenCapture\DEBUG MODE\*.*" | Where { ! $_.PSIsContainer } }

                            # Break current loop and re-try
                            Continue

                        }

                    }

                # PokeMMO not actively running - throw ballon system tray icon
                } else {

                    # Creates a Runspace to run in a separate thread
                    $RunSpace = [Management.Automation.Runspaces.RunspaceFactory]::CreateRunspace()
                    $RunSpace.ApartmentState = "STA"
                    $RunSpace.ThreadOptions = "ReuseThread"
                    $RunSpace.Open()
                    $RunSpace.SessionStateProxy.SetVariable("SyncHashTable",$Script:SyncHashTable)
                    $PowerShellCmd = [Management.Automation.PowerShell]::Create().AddScript({

                        # Creates a Windows Balloon popup to indicate PokeMMO is not active window (If $ActiveWindow does not equal PokeMMO)
                        $WindowBallonPopup = New-Object System.Windows.Forms.NotifyIcon
                        $ProcessIconPath = (Get-Process -id $pid).Path
                        $ArchetypeFormIcon = New-Object System.Drawing.Icon ("$PWD\GUI Form Images\Icons\Icon\Archetype.ico")
                        $WindowBallonPopup.Icon = $ArchetypeFormIcon
                        $WindowBallonPopup.BalloonTipIcon = [System.Windows.Forms.ToolTipIcon]::Warning
                        $WindowBallonPopup.BalloonTipText = ‘PokeMMO is not currently running for counting encounters or eggs.'
                        $WindowBallonPopup.BalloonTipTitle = "Archetype Counter"
                        $WindowBallonPopup.Visible = $true
                        $WindowBallonPopup.ShowBalloonTip(5000)

                        # Waits
                        Start-Sleep -Seconds 5

                        # Disposes the generated Windows Balloon popup
                        $WindowBallonPopup.Visible = $false
                        $WindowBallonPopup.Icon = $null
                        $WindowBallonPopup.Icon.Dispose()
                        $WindowBallonPopup.Dispose()

                        # Starts up the NoTrayOprhans.exe AHK script (Clears out Archetype icons that are left in the system tray)
                        Start-Process "$PWD\Counter Functions\NoTrayOprhans\NoTrayOrphans.exe"

                    })

                    # This section is needed for the PowerShell runspace invoke
                    $PowerShellCmd.Runspace = $RunSpace
                    $PSAsyncObject = $PowerShellCmd.BeginInvoke()

                    # Waits
                    Start-Sleep -Seconds 5

                }

                # Removes all screenshot(s) from folder (To ensure counter does not grab a previous screenshot)
                if ($DebugMode -match "False") { Remove-Item "$PWD\Counter Functions\ScreenCapture\*.*" | Where { ! $_.PSIsContainer }; Remove-Item "$PWD\Counter Functions\ScreenCapture\DEBUG MODE\*.*" | Where { ! $_.PSIsContainer } }

        # Techncially loops until forever (The stop button will be the way to force the stop of the counter)
        } until ($Forever)

    })

    # This section is needed for the PowerShell runspace invoke
    $PowerShellCmd.Runspace = $RunSpace
    $PSAsyncObject = $PowerShellCmd.BeginInvoke()

}

# Show the ArchetypeForm & Creates an application context (Helps with responsivness and threading)
$ArchetypeForm.Show()
$ArchetypeAppContext = New-Object System.Windows.Forms.ApplicationContext 
[System.Windows.Forms.Application]::Run($ArchetypeAppContext)