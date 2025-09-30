# Pester minimal smoke tests for DirectoryPermissionAudit
# Requires: Pester 5.x (GitHub Action will install if needed)

BeforeAll {
    $ModulePath = Join-Path $PSScriptRoot '..' | Join-Path -ChildPath 'Modules' | Join-Path -ChildPath 'DirectoryPermissionAudit.psd1'
    Import-Module $ModulePath -Force
}

describe 'Module Import' {
    it 'Exports Start-DirectoryPermissionAudit' {
        Get-Command Start-DirectoryPermissionAudit -ErrorAction Stop | Should -Not -BeNullOrEmpty
    }
}

describe 'Module Import' {
    it 'Exports Start-DirectoryPermissionAudit' {
        Get-Command Start-DirectoryPermissionAudit -ErrorAction Stop | Should -Not -BeNullOrEmpty
    }
}

describe 'Analysis basic run (no AD assumptions)' {
    It 'Produces report objects for a temp folder' {
        InModuleScope DirectoryPermissionAudit {
            $tempRoot = Join-Path ([IO.Path]::GetTempPath()) ("DirAuditTest_" + ([guid]::NewGuid().ToString('N').Substring(0,8)))
            New-Item -ItemType Directory -Path $tempRoot | Out-Null
            $sub = New-Item -ItemType Directory -Path (Join-Path $tempRoot 'SubA')
            # Add an ACL entry for BUILTIN\\Users to ensure at least one ACE
            $acl = Get-Acl $sub.FullName
            $id = New-Object System.Security.Principal.NTAccount('BUILTIN','Users')
            $rule = New-Object System.Security.AccessControl.FileSystemAccessRule($id,'ReadAndExecute','ContainerInherit,ObjectInherit','None','Allow')
            $acl.AddAccessRule($rule) | Out-Null
            Set-Acl -Path $sub.FullName -AclObject $acl

            Invoke-DirectoryPermissionAnalysis -RootPath $tempRoot -MaxDepth 1 -IncludeInherited -IncludeSystemAccounts
            $script:VZinfosGesamt | Should -Not -BeNullOrEmpty
            ($script:VZinfosGesamt | Measure-Object).Count | Should -BeGreaterOrEqual 1

            Remove-Item -Path $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}
