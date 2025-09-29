@{
    ExcludeRules = @()
    IncludeRules = @(
        'PSUseConsistentWhitespace',
        'PSUseConsistentIndentation',
        'PSAvoidUsingWriteHost',
        'PSUseApprovedVerbs',
        'PSAvoidGlobalVars'
    )
    Rules = @{ PSAvoidUsingCmdletAliases = @{ Enable = $true } }
}