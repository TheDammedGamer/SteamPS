﻿# https://lazywinadmin.com/2016/05/using-pester-to-test-your-comment-based.html

$ProjectRoot = Resolve-Path "$($PSScriptRoot)/.."
$ModuleRoot = Split-Path (Resolve-Path "$($ProjectRoot)/*/*.psm1")
$ModuleName = Split-Path $ModuleRoot -Leaf

Import-Module $ModuleRoot

Describe "$($ModuleName) Comment Based Help" -Tags "Module" {
    $FunctionsList = (Get-ChildItem "$($ModuleRoot)\Public").BaseName

    foreach ($Function in $FunctionsList) {
        # Retrieve the Help of the function
        $Help = Get-Help -Name $Function -Full

        $Notes = ($Help.alertSet.Alert.Text -split '\n')

        # Parse the function using AST
        $AST = [System.Management.Automation.Language.Parser]::ParseInput((Get-Content function:$Function), [ref]$null, [ref]$null)

        Context "$Function - Help" {

            It "Synopsis" { $Help.Synopsis | Should -not -BeNullOrEmpty }
            It "Description" { $Help.Description | Should -not -BeNullOrEmpty }
            It "Notes - Author" { $Notes[0].trim() | Should -BeLike "Author: *" }
            #It "Notes - Site" { $Notes[1].trim() | Should Be "hjorslev.com" }

            # Get the Parameters declared in the Comment Based Help
            $RiskMitigationParameters = 'Whatif', 'Confirm'
            $HelpParameters = $Help.Parameters.Parameter | Where-Object Name -NotIn $RiskMitigationParameters

            # Get the Parameters declared in the AST PARAM() Block
            $ASTParameters = $ast.ParamBlock.Parameters.Name.VariablePath.UserPath

            It "Parameter - Compare Count Help/AST" {
                $HelpParameters.Name.Count -eq $ASTParameters.Count | Should Be $true
            }

            # Parameter Description
            If (-not [String]::IsNullOrEmpty($ASTParameters)) {
                # IF ASTParameters are found
                $HelpParameters | ForEach-Object {
                    It "Parameter $($_.Name) - Should contains description" {
                        $_.Description | Should -not -BeNullOrEmpty
                    }
                }
            }

            # Examples
            it "Example - Count should be greater than 0" {
                $Help.Examples.Example.Code.Count | Should BeGreaterthan 0
            }

            # Examples - Remarks (small description that comes with the example)
            foreach ($Example in $Help.Examples.Example) {
                it "Example - Remarks on $($Example.Title)" {
                    $Example.Remarks | Should -not -BeNullOrEmpty
                }
            }
        }
    } # foreach
} # Describe