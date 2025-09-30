BeforeAll {
    $ModulePath = Join-Path $PSScriptRoot '..' | Join-Path -ChildPath 'Modules' | Join-Path -ChildPath 'DirectoryPermissionAudit.psd1'
    Import-Module $ModulePath -Force
}

describe 'Filtering' {
    It 'Supports GroupExclude wildcard' {
        InModuleScope DirectoryPermissionAudit {
            $TestRoot = Join-Path ([IO.Path]::GetTempPath()) ("DirAuditFilter_" + ([guid]::NewGuid().ToString('N').Substring(0,6)))
            New-Item -ItemType Directory -Path $TestRoot | Out-Null
            New-Item -ItemType Directory -Path (Join-Path $TestRoot 'A') | Out-Null
            New-Item -ItemType Directory -Path (Join-Path $TestRoot 'B') | Out-Null
            # Create simple ACL assignment using BUILTIN\Users so at least one ACE is present.
            Get-ChildItem -Directory -Path $TestRoot -Recurse | ForEach-Object {
                $acl = Get-Acl $_.FullName
                $id = New-Object System.Security.Principal.NTAccount('BUILTIN','Users')
                $rule = New-Object System.Security.AccessControl.FileSystemAccessRule($id,'ReadAndExecute','ContainerInherit,ObjectInherit','None','Allow')
                $acl.AddAccessRule($rule) | Out-Null
                Set-Acl -Path $_.FullName -AclObject $acl
            }
            Invoke-DirectoryPermissionAnalysis -RootPath $TestRoot -MaxDepth 1 -GroupExclude '*DoesNotExist*' -IncludeSystemAccounts
            $script:VZinfosGesamt | Should -Not -BeNullOrEmpty
            Remove-Item -Path $TestRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
    It 'Handles PruneEmpty without errors' {
        InModuleScope DirectoryPermissionAudit {
            $TestRoot = Join-Path ([IO.Path]::GetTempPath()) ("DirAuditFilter_" + ([guid]::NewGuid().ToString('N').Substring(0,6)))
            New-Item -ItemType Directory -Path $TestRoot | Out-Null
            New-Item -ItemType Directory -Path (Join-Path $TestRoot 'A') | Out-Null
            New-Item -ItemType Directory -Path (Join-Path $TestRoot 'B') | Out-Null
            # Create simple ACL assignment using BUILTIN\Users so at least one ACE is present.
            Get-ChildItem -Directory -Path $TestRoot -Recurse | ForEach-Object {
                $acl = Get-Acl $_.FullName
                $id = New-Object System.Security.Principal.NTAccount('BUILTIN','Users')
                $rule = New-Object System.Security.AccessControl.FileSystemAccessRule($id,'ReadAndExecute','ContainerInherit,ObjectInherit','None','Allow')
                $acl.AddAccessRule($rule) | Out-Null
                Set-Acl -Path $_.FullName -AclObject $acl
            }
            Invoke-DirectoryPermissionAnalysis -RootPath $TestRoot -MaxDepth 1 -GroupInclude 'ZzxNoMatch*' -PruneEmpty -IncludeSystemAccounts
            # Expect no entries
            ($script:VZinfosGesamt | Measure-Object).Count | Should -Be 0
            Remove-Item -Path $TestRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}
