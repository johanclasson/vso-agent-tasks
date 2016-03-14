# Tasks for VSTS-agents

(VSTS was formerly known as VSO)

Invoking PowerShell scripts is often an appealing option for customization of a build workflow. Using PowerShell scripts is especially a good idea when you are making changes that are unique for your solution. Just write your script and invoke it!

Working with builds that directly invokes PowerShell scripts has its limitations:

* If you have to deal with multiple arguments it is easy to get one of them wrong.
* Often when you update a PowerShell script you will affect its signature, and you might have to manually update its calling command at many places.
* Each build have to include the PowerShell script-files in its source code.

Fortunately, it is relatively straightforward to package your scripts in a task of your own. Once such a task is installed, it can be used by all builds in the entire collection.

## Installation

The [TFS Cross Platform Command Line utility (tfx-cli)](https://github.com/Microsoft/tfs-cli) is used to install tasks. It is built on Node.js, so if you have not already got Node.js you have to install it. One way to do that it is to use the Chocolatey command `cinst nodejs`.

Then, to install a task run the following commands in a Node.js command prompt:

* `npm install -g tfx-cli` - *This installs the tfx-cli tool.*
* `tfx login` - *The login is reused throughout the entire session.*
  * Enter collection url > `https://yourname.visualstudio.com/DefaultCollection`
  * Enter personal access token > `2lqewmdba7theldpuoqn7zgs46bmz5c2ppkazlwvk2z2segsgqrq` - *This is obviously a bogus token... You can add tokens to access your account at https://yourname.visualstudio.com/_details/security/tokens.* 
* `tfx build tasks upload --task-path c:\path-to-repo\vso-agent-tasks\ApplySemanticVersioningToAssemblies`
  * *If you change your mind and do not want a task anymore, you can remove it with* `tfx build tasks delete b8df3d76-4ee4-45a9-a659-6ead63b536b4`, *where the Guid is easiest found in the task.json of your task.*

If you make a change to a task that you have previously uploaded, you have to bump its version before you upload it again. The server does not allow overwriting the content of an existing version.

## Tasks

* [Apply Semantic Versioning to Assemblies](#apply-semantic-versioning-to-assemblies)
* [Invoke-Pester](#invoke-pester)
* [Nuget Publisher With Credentials](#nuget-publisher-with-credentials)
* [Invoke Rest Method](#invoke-rest-method)
* [Inline PowerShell](#pnline-powerShell)

## Apply Semantic Versioning to Assemblies

By use of a regular expression, exactly four version numbers (for example 1.2.3.4) are extracted from the build number. All AssemblyInfo.cs files are then iterated and versions are set in the following attributes:

* `AssemblyVersion` - *Is set to either 1, 1.2, 1.2.3 or 1.2.3.4 depending on what you enter under "Version Numbers in AssemblyVersion-attribute". 1.2 is the default.*
* `AssemblyFileVersion` - *Is set to 1.2.3.4. This is not configurable.* 
* `AssemblyInformationalVersion` - *Is set to either 1.2.3, 1.2.3-abc or 1.2.3-abc0004 depending on what you enter under "Make Release Version", "Prerelease Name" and "Include Build Revision Number".* 

When one of these attributes are present in the AssemblyInfo.cs-file, their entered version-string is replaced. Attributes which are not present are instead added at the end of the file.

As you well understand, this task must be placed before the build task to make any difference.

![Apply Semantic Versioning to Assemblies User Interface](/Docs/ApplySemanticVersioningToAssemblies.png?raw=true)

### Practical Use

The informational version format 1.2.3-abc0004, which is compatible with NuGet, can be used to represent prerelease packages from your nightly builds. For example 2.1.3-build0421 could be the semantic version for 421st build targeting the fourth bugfix of the second API update of the 2.0 release.

When packing a project package and to have NuGet use the informational version number, just set the version tag to `<version>$version$</version>` in the nuspec-file and you are good to go. 

When you are planning to make a new release, you might find that it is a good idea to have the version numbers you intend to have on release fixed and let the build revision number update until you are done. If this is the case, use `$(BuildDefinitionName).2.1.3$(Rev:.r)` as the *Build number format* for the build. When you think that you are done, you can simply tick "Make Release Version" and build to make a release version which in this case would be 2.1.3. If you would like to build a release candidate, untick "Include Build Revision Number" and replace the "Prerelease Name" to for example RC1 which would result in 2.1.3-RC1. 

### Version Attributes in .Net

The `AssemblyVersion` is the number that is used by a dll to point out a reference to a specific version of another dll. If this version is changed in a newer dll, those references needs to be updated to target that dll instead. If you follow semantic versioning, the first two version numbers are the ones to increase when the public API changes. Therefore it is a good idea to include just those in the assembly version.

The `AssemblyFileVersion` is not used by .Net directly, but is instead of value as a historical reference. If you would ever try to figure out from what build a dll has come from, then the assembly file version would help you answer that.

The `AssemblyInformationalVersion` is something human-readable that describes a version, for example 1.0-RC1. This can theoretically be whatever text you prefer, but in this task it is only configurable to the format 1.2.3-abc0004. Note that the build number is left padded with zeros. The reason for this is that NuGet sorts prerelease versions alphabetically. Semantic versioning supports Major.Minor.Patch-Prerelease.Build, but NuGet does not. 

### Advanced Options

You can change the *Build Number Pattern* that is used to extract the version numbers from the build number. If you do, then make sure that you enter matching *Split Characters* and that there would still be exactly four versions present.

## Invoke-Pester

Downloads the latest version of Pester from https://github.com/pester/Pester/archive/master.zip and calls Invoke-Pester. The test output is written to "Soruce Directory"\TEST-pester.xml in NUnit-format so that the test results can be published.

## Nuget Publisher With Credentials

A demonstration of how to push packages to a NuGet feed that requires authentication. This is made by temporarily adding the credentials to a local Nuget package source before making the push command.

## Invoke Rest Method

The url is polled once every 10 seconds until a responce is given. The task fails after a configurable timeout period if no responce is given.

The task can handle that the url is not registred when the task is started.

## Inline PowerShell

Runs a PowerShell script that is entered in task instead of running a script file like the stadard PowerShell task does. This overcomes the trouble of having to check in script files in your repository to have them available at build time. But, it also introduce some difficulties. For example it is not a good practice to have redundant scripts around... 