$driveName = "hi3519"
$driveLetter = (Get-WmiObject -Query "SELECT DeviceID FROM Win32_LogicalDisk WHERE VolumeName='${driveName}' AND DriveType=2").DeviceID

Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
using Microsoft.Win32.SafeHandles;

public class Win32 {
    [DllImport("kernel32.dll", SetLastError=true)]
    public static extern IntPtr CreateFile(
        string lpFileName,
        uint dwDesiredAccess,
        uint dwShareMode,
        IntPtr lpSecurityAttributes,
        uint dwCreationDisposition,
        uint dwFlagsAndAttributes,
        IntPtr hTemplateFile);

    [DllImport("kernel32.dll", SetLastError=true)]
    public static extern bool WriteFile(
        IntPtr hFile,
        IntPtr lpBuffer,
        uint nNumberOfBytesToWrite,
        out uint lpNumberOfBytesWritten,
        IntPtr lpOverlapped);

    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool ReadFile(
        IntPtr hFile,
        IntPtr lpBuffer,
        uint nNumberOfBytesToRead,
        out uint lpNumberOfBytesRead,
        IntPtr lpOverlapped);

    [DllImport("kernel32.dll", SetLastError=true)]
    public static extern bool CloseHandle(
        IntPtr hObject);
}
"@

if ($driveLetter) {
    $forwardFilePath = "${driveLetter}\\TRANSMIT_FORWARD"
    $metaFilePath = "${driveLetter}\\TRANSMIT_META"
    $sourceDirectoryPath = "C:\\Users\\16974\\projects\\usb\\test"
    $file_type_list = "*.txt"
    $maxFileSizeMB = 10
    $maxFileSizeBytes = $maxFileSizeMB * 1MB

    $FILE_FLAG_WRITE_THROUGH = [uint32]"0x80000000"
    $FILE_FLAG_NO_BUFFERING = [uint32]"0x20000000"
    $GENERIC_READ = [uint32]"0x80000000"
    $GENERIC_WRITE = [uint32]"0x40000000"
    $OPEN_EXISTING = 3
    $OPEN_FLAGS = $FILE_FLAG_WRITE_THROUGH -bor $FILE_FLAG_NO_BUFFERING

    $alignment = 512
    $metaBufferSize = 512

    $metaRawPtr = [System.Runtime.InteropServices.Marshal]::AllocHGlobal(($metaBufferSize + $alignment - 1) -band (-bnot $alignment + 1))
    $metaBufferAddr = $metaRawPtr.ToInt64() -band (-bnot $alignment + 1)
    $metaBuffer = [System.IntPtr]::Add($metaRawPtr, $metaBufferAddr - $metaRawPtr.ToInt64())


    function WriteMetaData {
        param (
            [uint32]$status,
            [string]$fileName,
            [uint64]$fileSize
        )

        $metaData = "{0}`n{1}`n{2}`n" -f $status, $fileName, $fileSize

        $metaDataBytes = [Text.Encoding]::ASCII.GetBytes($metaData)
        [System.Runtime.InteropServices.Marshal]::Copy($metaDataBytes, 0, $metaBuffer, $metaDataBytes.Length)

        Write-Host "meta content: $($metaData), length: $($metaData.Length)"

        try {
            $metaHandle = [Win32]::CreateFile($metaFilePath, $GENERIC_WRITE, 0, [IntPtr]::Zero, $OPEN_EXISTING, $OPEN_FLAGS, [IntPtr]::Zero)
            if ($metaHandle -ne [IntPtr]::Zero) {
                $bytesWritten = 0
                [Win32]::WriteFile($metaHandle, $metaBuffer, $metaBufferSize, [ref]$bytesWritten, [IntPtr]::Zero)
                [Win32]::CloseHandle($metaHandle)
            } else {
                Write-Host "failed to open meta file: $($metaHandle)"
            }
        } catch {
            Write-Host "failed to write meta file: $($_.Exception.Message)"
        }
    }

    $forwardBufferSize = 512

    $forwardRawPtr = [System.Runtime.InteropServices.Marshal]::AllocHGlobal(($forwardBufferSize + $alignment - 1) -band (-bnot $alignment + 1))
    $forwardBufferAddr = $forwardRawPtr.ToInt64() -band (-bnot $alignment + 1)
    $forwardBuffer = [System.IntPtr]::Add($forwardRawPtr, $forwardBufferAddr - $forwardRawPtr.ToInt64())

    Get-ChildItem -Path $sourceDirectoryPath -Recurse -Include $file_type_list -File -ErrorAction SilentlyContinue | ForEach-Object {
        $file = $_
        try {
            $forwardHandle = [Win32]::CreateFile($forwardFilePath, $GENERIC_WRITE, 0, [IntPtr]::Zero, $OPEN_EXISTING, $OPEN_FLAGS, [IntPtr]::Zero)
            if ($forwardHandle -ne [IntPtr]::Zero) {
                try {
                    $sourceHandle = [Win32]::CreateFile($file.FullName, $GENERIC_READ, 0, [IntPtr]::Zero, $OPEN_EXISTING, 0, [IntPtr]::Zero)
                    if ($sourceHandle -ne [IntPtr]::Zero) {
                        $fileSize = [System.IO.FileInfo]::new($file.FullName).Length
                        $fileName = $file.Name
                        
                        if ($fileSize -le $maxFileSizeBytes) {
                            Write-Host "current transmit file name: $($fileName)"

                            WriteMetaData -status 0 -fileName $fileName -fileSize $fileSize

                            while (1) {
                                $bytesRead = 0
                                [Win32]::ReadFile($sourceHandle, $forwardBuffer, $forwardBufferSize, [ref]$bytesRead, [IntPtr]::Zero)

                                Write-Host "read $($bytesRead) from source file"

                                if ($bytesRead -eq 0) { break }
                                
                                $bytesWrite = 0
                                [Win32]::WriteFile($forwardHandle, $forwardBuffer, $forwardBufferSize, [ref]$bytesWrite, [IntPtr]::Zero)

                                Write-Host "write $($bytesWrite) to forward tunnel"
                            }

                            [Win32]::CloseHandle($sourceHandle)

                            WriteMetaData -status 1 -fileName $fileName -fileSize $fileSize
                        }
                    } else {
                        Write-Host "failed to open source file: $($sourceHandle)"
                    }
                } catch {
                    Write-Host "failed when handling $($file.FullName): $($_.Exception.Message)"
                }
                [Win32]::CloseHandle($forwardHandle)
            } else {
                Write-Host "failed to open forward file: $($forwardHandle)"
            }
        } catch {
            Write-Host "failed when forwarding: $($_.Exception.Message)"
        }
    } 

    [System.Runtime.InteropServices.Marshal]::FreeHGlobal($metaRawPtr)
    [System.Runtime.InteropServices.Marshal]::FreeHGlobal($forwardRawPtr)
} else {
    Write-Host "unable to find driver named '$driveName'."
}